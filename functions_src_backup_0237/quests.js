// Proving Grounds: mini-tests that solve the cold start. Ready-made quests come first (fast, reliable);
// when a user has done every ready-made quest for a field + difficulty, the AI makes a fresh one.
// Reward, pass mark and skill XP depend on difficulty (see pricing.js).
const { onCall } = require('firebase-functions/v2/https');
const { db, FieldValue, GEMINI_API_KEY, AI_OPTS, uidOf, bad, failed, wrapAi, walletRef, ledger, HttpsError, P, V } = require('./common');
const { generateQuest, gradeQuest } = require('./pipelines');
const { QUEST_BANK } = require('./questBank');

const questSkills = V.SKILLS.filter(s => s !== 'Other');
const DIFFS = P.QUEST_DIFFICULTIES; // ['easy', 'medium', 'hard']

exports.getQuest = onCall(AI_OPTS, async (req) => {
  const uid = uidOf(req);
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) throw failed('Please sign in again to finish setting up your account.');
  const col = db.collection('users').doc(uid).collection('quests');

  const open = await col.where('status', '==', 'open').limit(1).get();
  if (!open.empty) {
    const d = open.docs[0].data();
    return { id: open.docs[0].id, skill: d.skill, prompt: d.prompt, reward: d.reward, difficulty: d.difficulty || null };
  }

  const dayStart = new Date(); dayStart.setHours(0, 0, 0, 0);
  const today = await col.where('createdAt', '>=', dayStart).get();
  if (today.size >= P.QUEST_DAILY_LIMIT) throw failed('You have done all of today\'s quests. Come back tomorrow.');

  const data = req.data || {};
  const skill = questSkills.includes(data.skill) ? data.skill : questSkills[Math.floor(Math.random() * questSkills.length)];
  const wantDiff = DIFFS.includes(data.difficulty) ? data.difficulty : null;
  const level = P.levelOf((userSnap.data().skillPoints || {})[skill] || 0);

  // ready-made quests this user has not seen yet
  const seen = new Set((await col.get()).docs.map(d => d.data().bankId).filter(Boolean));
  let pool = (QUEST_BANK[skill] || []).filter(x => !seen.has(x.id));
  // no difficulty chosen: match the user's level in this skill (new = easy, level 1 = medium, level 2+ = hard)
  const target = wantDiff || DIFFS[Math.min(level, DIFFS.length - 1)];
  const matching = pool.filter(x => x.difficulty === target);
  if (wantDiff) pool = matching;
  else if (matching.length) pool = matching;

  let picked, bankId = null, difficulty = target;
  if (pool.length) {
    const pick = pool[Math.floor(Math.random() * pool.length)];
    picked = { prompt: pick.prompt, rubric: pick.rubric };
    bankId = pick.id;
    difficulty = pick.difficulty;
  } else {
    picked = await wrapAi(() => generateQuest(GEMINI_API_KEY.value(), skill, DIFFS.indexOf(target)));
  }

  const reward = P.questReward(difficulty);
  const ref = col.doc();
  const batch = db.batch();
  batch.set(ref, { skill, prompt: picked.prompt, reward, difficulty, status: 'open', bankId, createdAt: FieldValue.serverTimestamp() });
  batch.set(db.collection('questKeys').doc(ref.id), { uid, rubric: picked.rubric }); // secret: no client can read this
  await batch.commit();
  return { id: ref.id, skill, prompt: picked.prompt, reward, difficulty };
});

exports.submitQuest = onCall(AI_OPTS, async (req) => {
  const uid = uidOf(req);
  const answer = V.str(req.data.answer).trim();
  if (answer.length < 3) throw bad('Please write an answer.');
  if (answer.length > 3000) throw bad('Your answer is too long (max 3000 characters).');
  const qRef = db.collection('users').doc(uid).collection('quests').doc(V.str(req.data.questId));
  const [q, key] = await Promise.all([qRef.get(), db.collection('questKeys').doc(qRef.id).get()]);
  if (!q.exists || !key.exists || key.data().uid !== uid) throw new HttpsError('not-found', 'Quest not found.');
  if (q.data().status !== 'open') throw failed('This quest was already answered.');

  const difficulty = q.data().difficulty || null;
  const reward = q.data().reward || P.QUEST_REWARD;                 // the price was fixed when the quest was handed out
  const passMark = difficulty ? P.questPassScore(difficulty) : P.QUEST_PASS_SCORE;

  const g = await wrapAi(() => gradeQuest(GEMINI_API_KEY.value(), q.data().prompt, key.data().rubric, answer));
  const passed = g.score >= passMark;   // the code decides pass/fail, not the AI

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(qRef);                 // guards against double submission
    if (fresh.data().status !== 'open') throw failed('This quest was already answered.');
    tx.update(qRef, { status: passed ? 'passed' : 'failed', score: g.score, feedback: g.feedback, answeredAt: FieldValue.serverTimestamp() });
    if (passed) {
      const skill = q.data().skill;
      const pts = difficulty ? P.questSkillPoints(g.score, difficulty) : Math.floor(g.score / 10);
      tx.set(walletRef(uid), { balance: FieldValue.increment(reward) }, { merge: true });
      ledger(tx, uid, { type: 'quest_reward', amount: reward, ref: qRef.id });
      tx.set(db.collection('users').doc(uid), {
        questsPassed: FieldValue.increment(1), xp: FieldValue.increment(pts), skillPoints: { [skill]: FieldValue.increment(pts) },
        badges: FieldValue.arrayUnion(`${skill} Apprentice`),
      }, { merge: true });
    }
  });
  return { passed, score: g.score, feedback: g.feedback, reward: passed ? reward : 0, difficulty, passMark };
});
