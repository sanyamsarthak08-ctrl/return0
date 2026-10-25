const { onCall } = require('firebase-functions/v2/https');
const C = require('./src/common');
const { db, FieldValue, Timestamp, HttpsError, GEMINI_API_KEY, AI_OPTS, BASE_OPTS, uidOf, bad, failed, wrapAi, walletRef, ledger, loadOwned, recomputeCost, P, V } = C;
const { ruleCheck } = require('./src/rules');
const { shred, repriceTask, autoQA } = require('./src/pipelines');

const STARTER_COINS = 3000;   // demo grant for new users; change or remove for production
const CLAIM_REVIEW_EXTENSION_HOURS = 6; // extra time when the owner asks for changes

// ---------- 1. user + wallet ----------
exports.initUser = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const userRef = db.collection('users').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (snap.exists) return { created: false };
    tx.set(userRef, {
      displayName: (req.auth.token.name || 'Pirate').toString().slice(0, 40), email: req.auth.token.email || null,
      xp: 0, skillPoints: {}, reputation: 50, questsPassed: 0, badges: [], createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(walletRef(uid), { balance: STARTER_COINS, escrowHeld: 0 });
    ledger(tx, uid, { type: 'starter_grant', amount: STARTER_COINS, ref: null });
    return { created: true, balance: STARTER_COINS };
  });
});

// ---------- 2. Task Shredder ----------
const taskMechanics = (t) => ({ minLevel: P.requiredLevel(t.difficulty), sprintHours: P.sprintHours(t.estimated_hours), surgePercent: P.initialSurge(t.difficulty) });

exports.shredProject = onCall(AI_OPTS, async (req) => {
  const uid = uidOf(req);
  const brief = V.str(req.data.brief).trim();
  if (brief.length < 30) throw bad('Please describe your project in a bit more detail.');
  if (brief.length > 6000) throw bad('The brief is too long (max 6000 characters).');

  let projectRef, title = V.str(req.data.title).trim().slice(0, 100);
  if (req.data.projectId) {
    const own = await loadOwned('projects', req.data.projectId, uid, 'project');
    if (own.data.status !== 'draft') throw failed('Only draft projects can be regenerated.');
    projectRef = own.ref; title = own.data.title;
  } else {
    if (!title) throw bad('Please give the project a title.');
    projectRef = db.collection('projects').doc();
  }
  const result = await wrapAi(() => shred(GEMINI_API_KEY.value(), brief));

  const batch = db.batch();
  if (req.data.projectId) {
    const old = await db.collection('tasks').where('projectId', '==', projectRef.id).get();
    old.docs.forEach(d => batch.delete(d.ref));
    batch.update(projectRef, { brief, updatedAt: FieldValue.serverTimestamp() });
  } else {
    batch.set(projectRef, { ownerId: uid, title, brief, status: 'draft', cost: 0, createdAt: FieldValue.serverTimestamp() });
  }
  const out = [];
  for (const t of result.tasks) {
    const ref = db.collection('tasks').doc(`${projectRef.id}_${t.id}`);
    const doc = {
      ...t, ...taskMechanics(t), localId: t.id, ownerId: uid, projectId: projectRef.id, projectTitle: title, status: 'draft',
      edited_by_user: false, requiresLink: /link|url|figma|github|repo|demo|deployed/i.test(t.deliverables.join(' ')),
      claimsCount: 0, escrowRemaining: 0, paidOut: 0, createdAt: FieldValue.serverTimestamp(),
    };
    batch.set(ref, doc);
    out.push({ ...doc, id: ref.id, createdAt: null });
  }
  const cost = P.projectCost(result.tasks.map(t => t.coins));
  batch.update(projectRef, { cost, issues_found: result.issues_found });
  await batch.commit();
  return { projectId: projectRef.id, cost, issues_found: result.issues_found, tasks: out };
});

// creator override: edit wording; coins are NEVER accepted from the client
exports.updateTask = onCall(AI_OPTS, async (req) => {
  const uid = uidOf(req);
  const { ref, data: task } = await loadOwned('tasks', V.str(req.data.taskId), uid, 'task');
  if (task.status !== 'draft') throw failed('Only draft tasks can be edited.');
  const f = req.data.fields || {};
  const next = { ...task };
  let reword = false;
  for (const k of ['title', 'description', 'context']) {
    if (f[k] !== undefined) { if (typeof f[k] !== 'string' || !f[k].trim() || f[k].length > 3000) throw bad(`Invalid ${k}.`); next[k] = f[k].trim(); reword = true; }
  }
  for (const k of ['deliverables', 'acceptance_criteria', 'open_questions']) {
    if (f[k] !== undefined) { if (!Array.isArray(f[k]) || f[k].length > 10) throw bad(`Invalid ${k}.`); next[k] = V.strList(f[k]).map(s => s.slice(0, 500)); }
  }
  if (!next.acceptance_criteria.length) throw bad('A task needs at least one acceptance criterion.');
  let priced = {};
  if (reword) {
    const r = await wrapAi(() => repriceTask(GEMINI_API_KEY.value(), next));
    priced = { difficulty: r.difficulty, estimated_hours: r.estimated_hours, ai_reason: r.ai_reason, coins: r.coins, ...taskMechanics(r) };
  }
  const update = {
    title: next.title, description: next.description, context: next.context, deliverables: next.deliverables,
    acceptance_criteria: next.acceptance_criteria, open_questions: next.open_questions,
    ...priced, edited_by_user: true, updatedAt: FieldValue.serverTimestamp(),
  };
  await ref.update(update);
  return { task: { ...task, ...update, id: ref.id, createdAt: null, updatedAt: null }, cost: await recomputeCost(task.projectId) };
});

// creator merges two tasks by deleting one and editing the other; deleting keeps dependency lists valid
exports.deleteTask = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const { ref, data: task } = await loadOwned('tasks', V.str(req.data.taskId), uid, 'task');
  if (task.status !== 'draft') throw failed('Only draft tasks can be deleted.');
  const siblings = await db.collection('tasks').where('projectId', '==', task.projectId).get();
  const batch = db.batch();
  batch.delete(ref);
  siblings.docs.forEach(d => {
    const deps = d.data().depends_on || [];
    if (deps.includes(task.localId)) batch.update(d.ref, { depends_on: deps.filter(x => x !== task.localId) });
  });
  await batch.commit();
  return { cost: await recomputeCost(task.projectId) };
});

// ---------- 3. Publish + escrow ----------
exports.publishProject = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const projectRef = db.collection('projects').doc(V.str(req.data.projectId));
  return db.runTransaction(async (tx) => {
    const pSnap = await tx.get(projectRef);
    if (!pSnap.exists || pSnap.data().ownerId !== uid) throw new HttpsError('permission-denied', 'Project not found.');
    if (pSnap.data().status !== 'draft') throw failed('This project is already published.');
    const tSnap = await tx.get(db.collection('tasks').where('projectId', '==', projectRef.id));
    if (tSnap.empty) throw failed('Add at least one task first.');
    const wSnap = await tx.get(walletRef(uid));
    const balance = wSnap.exists ? wSnap.data().balance : 0;
    const cost = P.projectCost(tSnap.docs.map(d => d.data().coins));
    if (!P.canPublish(balance, cost)) throw failed('Not enough coins');
    tx.update(walletRef(uid), { balance: FieldValue.increment(-cost), escrowHeld: FieldValue.increment(cost) });
    ledger(tx, uid, { type: 'escrow_hold', amount: -cost, ref: projectRef.id });
    tSnap.docs.forEach(d => tx.update(d.ref, { status: 'published', escrowRemaining: d.data().coins, publishedAt: FieldValue.serverTimestamp() }));
    tx.update(projectRef, { status: 'published', cost, publishedAt: FieldValue.serverTimestamp() });
    return { cost, balanceAfter: balance - cost };
  });
});

// ---------- 4. Claims: solo, squads, sprint timer, surge lock, expertise gate ----------
async function otherClaimOnTask(tx, uid, taskId) {
  const mine = await tx.get(db.collection('claims').where('members', 'array-contains', uid));
  return mine.docs.some(d => d.data().taskId === taskId && d.data().status !== 'expired');
}
const sprintOver = (ts) => ts && ts.toMillis() <= Date.now();

async function makeClaim(uid, taskId, squad) {
  const taskRef = db.collection('tasks').doc(taskId);
  const claimRef = db.collection('claims').doc(`${taskId}_${uid}`);
  return db.runTransaction(async (tx) => {
    const [t, u] = await Promise.all([tx.get(taskRef), tx.get(db.collection('users').doc(uid))]);
    if (!t.exists || t.data().status !== 'published') throw failed('This task is not open.');
    const task = t.data();
    if (task.ownerId === uid) throw failed('You cannot claim your own task.');
    if (!u.exists) throw failed('Please sign in again to finish setting up your account.');
    if (await otherClaimOnTask(tx, uid, taskId)) throw failed('You already claimed this task.');
    if (sprintOver(task.sprintEndsAt)) throw failed('The sprint for this task has ended.');
    if ((task.claimsCount || 0) >= P.MAX_CLAIMS_PER_TASK) throw failed('This task has enough claims already.');
    const blocker = P.claimBlocker(u.data(), task, { squad });
    if (blocker) throw failed(blocker);
    // the countdown starts with the first claim and is shared by everyone on the task
    const endsAt = task.sprintEndsAt || Timestamp.fromMillis(Date.now() + (task.sprintHours || 24) * 3600 * 1000);
    tx.set(claimRef, {
      uid, ownerId: task.ownerId, taskId, projectId: task.projectId, status: 'active', squad, members: [uid],
      lockedCoins: P.lockedCoins(task.coins, task.surgePercent), // the surge bounty at claim time is locked in
      claimedAt: FieldValue.serverTimestamp(), deadline: endsAt,
    });
    tx.update(taskRef, { claimsCount: FieldValue.increment(1), sprintEndsAt: endsAt, sprintSwept: false });
    return { claimId: claimRef.id, deadlineMs: endsAt.toMillis() };
  });
}
exports.claimTask = onCall(BASE_OPTS, async (req) => makeClaim(uidOf(req), V.str(req.data.taskId), false));
exports.createSquad = onCall(BASE_OPTS, async (req) => makeClaim(uidOf(req), V.str(req.data.taskId), true));

exports.joinSquad = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const claimRef = db.collection('claims').doc(V.str(req.data.claimId));
  return db.runTransaction(async (tx) => {
    const cSnap = await tx.get(claimRef);
    if (!cSnap.exists || !cSnap.data().squad || cSnap.data().status !== 'active') throw failed('This squad is not open.');
    const claim = cSnap.data();
    const [t, u] = await Promise.all([tx.get(db.collection('tasks').doc(claim.taskId)), tx.get(db.collection('users').doc(uid))]);
    if (!u.exists) throw failed('Please sign in again to finish setting up your account.');
    if (claim.members.length >= P.MAX_SQUAD) throw failed('This squad is full.');
    if (claim.ownerId === uid) throw failed('You cannot join a squad on your own task.');
    if (claim.deadline.toMillis() <= Date.now()) throw failed('The sprint for this task has ended.');
    if (await otherClaimOnTask(tx, uid, claim.taskId)) throw failed('You already claimed this task.');
    const blocker = P.claimBlocker(u.data(), t.data(), { squad: true });
    if (blocker) throw failed(blocker);
    tx.update(claimRef, { members: FieldValue.arrayUnion(uid) });
    return { members: claim.members.length + 1 };
  });
});

// ---------- 5. Submit + Auto-QA + spam penalty ----------
async function applySpamPenalty(sub, submissionId) {
  return db.runTransaction(async (tx) => {
    const w = await tx.get(walletRef(sub.uid));
    const amt = Math.min(w.exists ? w.data().balance : 0, P.SPAM_PENALTY); // balance never goes negative
    if (amt > 0) { tx.update(walletRef(sub.uid), { balance: FieldValue.increment(-amt) }); ledger(tx, sub.uid, { type: 'spam_penalty', amount: -amt, ref: sub.taskId }); }
    tx.set(db.collection('users').doc(sub.uid), { reputation: FieldValue.increment(-P.REP_SPAM_PENALTY) }, { merge: true });
    tx.update(db.collection('submissions').doc(submissionId), { status: 'discarded' });
    tx.update(db.collection('claims').doc(sub.claimId), { status: 'rejected' });
    tx.update(db.collection('aiResults').doc(submissionId), { discarded: true, penalty: amt });
    return amt;
  });
}

// Tier 1: a submission that passed the Spam Guard earns a guaranteed minimum, paid once, no matter what the owner decides later.
async function payParticipation(submissionId) {
  const subRef = db.collection('submissions').doc(submissionId);
  return db.runTransaction(async (tx) => {
    const sSnap = await tx.get(subRef);
    if (!sSnap.exists) return 0;
    const sub = sSnap.data();
    if (sub.participationPaid || sub.status !== 'in_review') return 0;      // never pay twice, never pay discarded work
    const [tSnap, cSnap] = await Promise.all([tx.get(db.collection('tasks').doc(sub.taskId)), tx.get(db.collection('claims').doc(sub.claimId))]);
    if (!tSnap.exists || !cSnap.exists || tSnap.data().status !== 'published') return 0;
    const task = tSnap.data(), claim = cSnap.data();
    const members = claim.members || [sub.uid];
    const amount = P.participationPayout(claim.lockedCoins || task.coins);
    const { fromEscrow, fromPlatform } = P.drawFromEscrow(task.escrowRemaining || 0, amount);
    tx.update(subRef, { participationPaid: amount });
    tx.update(tSnap.ref, { escrowRemaining: FieldValue.increment(-fromEscrow), paidOut: FieldValue.increment(amount) });
    if (fromEscrow > 0) tx.update(walletRef(task.ownerId), { escrowHeld: FieldValue.increment(-fromEscrow) });
    payMembers(tx, members, P.splitEven(amount, members.length), { type: 'participation_payout', ref: sub.taskId });
    if (fromPlatform > 0) tx.set(db.collection('platform').doc('stats'), { coinsCovered: FieldValue.increment(fromPlatform) }, { merge: true });
    return amount;
  });
}

async function runReview(submissionId) {
  const subRef = db.collection('submissions').doc(submissionId);
  const sub = (await subRef.get()).data();
  const task = (await db.collection('tasks').doc(sub.taskId).get()).data();
  const prior = await db.collection('submissions').where('taskId', '==', sub.taskId).limit(100).get();
  const earlier = prior.docs.filter(d => d.id !== submissionId).map(d => d.data().text);
  const rule = ruleCheck({ submission: sub.text, requiresLink: !!task.requiresLink, earlierSubmissions: earlier });
  const base = { uid: sub.uid, members: sub.members, ownerId: sub.ownerId, taskId: sub.taskId, rule_check: rule, createdAt: FieldValue.serverTimestamp() };
  try {
    const qa = await autoQA(GEMINI_API_KEY.value(), task, sub.text);
    const queue = qa.judge.needs_human_review || rule.needsReview || qa.spam_guard.verdict !== 'genuine';
    await db.collection('aiResults').doc(submissionId).set({ ...base, ...qa, needs_review_queue: queue });
    // only CONFIDENT spam is discarded and penalised; borderline cases wait for the owner
    if (qa.spam_guard.verdict === 'spam' && qa.spam_guard.confidence >= P.SPAM_CONFIDENCE) {
      return { discarded: true, penalty: await applySpamPenalty(sub, submissionId) };
    }
    // passed the Spam Guard: pay the guaranteed minimum right away
    if (qa.spam_guard.verdict === 'genuine') return { discarded: false, penalty: 0, participation: await payParticipation(submissionId) };
  } catch (e) {
    console.error('Auto-QA failed', e);
    await db.collection('aiResults').doc(submissionId).set({ ...base, error: 'The AI review failed. The owner will review this by hand.', needs_review_queue: true });
  }
  return { discarded: false, penalty: 0, participation: 0 };
}

exports.submitWork = onCall(AI_OPTS, async (req) => {
  const uid = uidOf(req);
  const text = V.str(req.data.text);
  if (text.length > 10000) throw bad('Your submission is too long (max 10000 characters).');
  const claimRef = db.collection('claims').doc(V.str(req.data.claimId));
  const cSnap = await claimRef.get();
  if (!cSnap.exists || !cSnap.data().members.includes(uid)) throw new HttpsError('permission-denied', 'Claim not found.');
  const claim = cSnap.data();
  if (!['active', 'changes_requested'].includes(claim.status)) throw failed('This claim is not open for submissions.');
  if (claim.deadline.toMillis() <= Date.now()) throw failed('The sprint is over, so this task no longer accepts work.');
  const task = (await db.collection('tasks').doc(claim.taskId).get()).data();
  if (task.status !== 'published') throw failed('This task is closed.');

  const prior = await db.collection('submissions').where('taskId', '==', claim.taskId).limit(100).get();
  const rule = ruleCheck({ submission: text, requiresLink: !!task.requiresLink, earlierSubmissions: prior.docs.map(d => d.data().text) });
  if (!rule.passed) return { ok: false, message: rule.message };

  const subRef = db.collection('submissions').doc();
  await subRef.set({
    uid, members: claim.members, ownerId: claim.ownerId, taskId: claim.taskId, projectId: claim.projectId, claimId: claimRef.id,
    text: text.trim(), status: 'in_review', createdAt: FieldValue.serverTimestamp(),
  });
  await claimRef.update({ status: 'submitted' });
  const r = await runReview(subRef.id);
  if (r.discarded) return { ok: true, submissionId: subRef.id, discarded: true, penalty: r.penalty,
    message: 'This looks like spam, so it was discarded.' + (r.penalty ? ` ${r.penalty} coins were deducted.` : '') + ' If this is a mistake, the owner can restore it.' };
  return { ok: true, submissionId: subRef.id, participation: r.participation || 0,
    message: r.participation ? `Your work passed the spam check, so ${r.participation} coins were paid. The owner can still accept it for the rest.` : undefined };
});

exports.rerunReview = onCall(AI_OPTS, async (req) => {
  const uid = uidOf(req);
  const { data } = await loadOwned('submissions', V.str(req.data.submissionId), uid, 'submission');
  if (data.status !== 'in_review') throw failed('This submission was already decided.');
  await runReview(req.data.submissionId);
  return { ok: true };
});

// owner can undo a spam discard: penalty is refunded
exports.restoreSubmission = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const subRef = db.collection('submissions').doc(V.str(req.data.submissionId));
  const aiRef = db.collection('aiResults').doc(subRef.id);
  return db.runTransaction(async (tx) => {
    const [s, a] = await Promise.all([tx.get(subRef), tx.get(aiRef)]);
    if (!s.exists || s.data().ownerId !== uid) throw new HttpsError('permission-denied', 'Submission not found.');
    if (s.data().status !== 'discarded') throw failed('This submission was not discarded.');
    const sub = s.data();
    const penalty = a.exists ? a.data().penalty || 0 : 0;
    tx.update(subRef, { status: 'in_review' });
    tx.update(db.collection('claims').doc(sub.claimId), { status: 'submitted' });
    tx.update(aiRef, { discarded: false, penalty: 0, restored: true, needs_review_queue: true });
    if (penalty > 0) { tx.set(walletRef(sub.uid), { balance: FieldValue.increment(penalty) }, { merge: true }); ledger(tx, sub.uid, { type: 'penalty_refund', amount: penalty, ref: sub.taskId }); }
    tx.set(db.collection('users').doc(sub.uid), { reputation: FieldValue.increment(P.REP_SPAM_PENALTY) }, { merge: true });
    return { refunded: penalty };
  });
});

// ---------- 6. Owner decision, two-stage rewards, squads split ----------
function payMembers(tx, members, shares, entry) {
  members.forEach((m, i) => {
    if (shares[i] <= 0) return;
    tx.set(walletRef(m), { balance: FieldValue.increment(shares[i]) }, { merge: true });
    ledger(tx, m, { ...entry, amount: shares[i] });
  });
}

exports.decideSubmission = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const decision = req.data.decision;
  if (!['accepted', 'changes_requested', 'rejected'].includes(decision)) throw bad('Invalid decision.');
  const note = V.str(req.data.ownerNote).slice(0, 1000);
  const subRef = db.collection('submissions').doc(V.str(req.data.submissionId));
  const decRef = db.collection('decisions').doc(subRef.id);
  const aiRef = db.collection('aiResults').doc(subRef.id);

  return db.runTransaction(async (tx) => {
    const sSnap = await tx.get(subRef);
    if (!sSnap.exists || sSnap.data().ownerId !== uid) throw new HttpsError('permission-denied', 'Submission not found.');
    const sub = sSnap.data();
    if (sub.members.includes(uid)) throw failed('You cannot decide your own submission.');
    if (sub.status === 'discarded') throw failed('Restore this submission first, or leave it discarded.');
    const [tSnap, dSnap, aSnap, cSnap] = await Promise.all([
      tx.get(db.collection('tasks').doc(sub.taskId)), tx.get(decRef), tx.get(aiRef), tx.get(db.collection('claims').doc(sub.claimId)),
    ]);
    const task = tSnap.data(), claim = cSnap.data();
    if (task.status !== 'published') throw failed('This task is already closed.');
    if (dSnap.exists && (dSnap.data().payout || 0) > 0) throw failed('This submission was already accepted and paid.');

    const aiScore = aSnap.exists && aSnap.data().judge ? aSnap.data().judge.score : 0;
    const finalScore = V.clampInt(req.data.finalScore, 0, 100, aiScore);
    const members = claim.members || [sub.uid];
    const alreadyPaid = sub.participationPaid || 0;                          // tier 1 was paid when the Spam Guard passed it
    const fullBase = P.basePayout(decision, claim.lockedCoins || task.coins); // tier 2: the full base price for an accepted submission
    const payout = Math.max(0, fullBase - alreadyPaid);                       // only the remainder is paid now
    const { fromEscrow, fromPlatform } = P.drawFromEscrow(task.escrowRemaining || 0, payout);

    tx.set(decRef, {
      uid: sub.uid, members, ownerId: uid, taskId: sub.taskId, taskTitle: task.title, projectTitle: task.projectTitle || '', skill: task.skill,
      final_decision: decision, decided_by: uid, decided_at: FieldValue.serverTimestamp(), owner_note: note, final_score: finalScore,
      criterion_overrides: Array.isArray(req.data.criterionOverrides) ? req.data.criterionOverrides.slice(0, 10) : [],
      payout, participation: alreadyPaid, isWinner: false,
    });
    tx.update(subRef, { status: decision });
    const claimStatus = decision === 'changes_requested' ? 'changes_requested' : decision === 'accepted' ? 'done' : 'rejected';
    const claimUpdate = { status: claimStatus };
    if (decision === 'changes_requested') claimUpdate.deadline = Timestamp.fromMillis(Date.now() + CLAIM_REVIEW_EXTENSION_HOURS * 3600 * 1000);
    tx.update(cSnap.ref, claimUpdate);

    if (payout > 0) {
      tx.update(tSnap.ref, { escrowRemaining: FieldValue.increment(-fromEscrow), paidOut: FieldValue.increment(payout) });
      tx.update(walletRef(uid), { escrowHeld: FieldValue.increment(-fromEscrow) });
      payMembers(tx, members, P.splitEven(payout, members.length), { type: 'task_payout', ref: sub.taskId });
      if (fromPlatform > 0) tx.set(db.collection('platform').doc('stats'), { coinsCovered: FieldValue.increment(fromPlatform) }, { merge: true });
    }
    if (decision === 'accepted') {
      const pts = Math.floor(finalScore / 10);  // skill tree: every verified task levels up its skill node
      members.forEach(m => tx.set(db.collection('users').doc(m), {
        xp: FieldValue.increment(pts), skillPoints: { [task.skill]: FieldValue.increment(pts) }, reputation: FieldValue.increment(P.REP_ACCEPTED_BONUS),
      }, { merge: true }));
    }
    return { payout, final_score: finalScore };
  });
});

// stage 2: owner selects the best accepted submission; the bonus is minted by the platform beyond remaining escrow
exports.pickWinner = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const subRef = db.collection('submissions').doc(V.str(req.data.submissionId));
  const decRef = db.collection('decisions').doc(subRef.id);
  return db.runTransaction(async (tx) => {
    const sSnap = await tx.get(subRef);
    if (!sSnap.exists || sSnap.data().ownerId !== uid) throw new HttpsError('permission-denied', 'Submission not found.');
    const sub = sSnap.data();
    if (sub.members.includes(uid)) throw failed('You cannot pick your own submission.');
    const [tSnap, dSnap] = await Promise.all([tx.get(db.collection('tasks').doc(sub.taskId)), tx.get(decRef)]);
    const task = tSnap.data();
    if (!dSnap.exists || dSnap.data().final_decision !== 'accepted') throw failed('Accept this submission first.');
    if (task.winnerSubmissionId) throw failed('A winner was already picked for this task.');
    if (task.status !== 'published') throw failed('This task is already closed.');
    const members = sub.members;
    const bonus = P.winnerBonus(task.coins);
    const { fromEscrow, fromPlatform } = P.drawFromEscrow(task.escrowRemaining || 0, bonus);
    tx.update(tSnap.ref, { winnerSubmissionId: subRef.id, escrowRemaining: FieldValue.increment(-fromEscrow), paidOut: FieldValue.increment(bonus) });
    tx.update(decRef, { isWinner: true, payout: FieldValue.increment(bonus) });
    tx.update(walletRef(uid), { escrowHeld: FieldValue.increment(-fromEscrow) });
    payMembers(tx, members, P.splitEven(bonus, members.length), { type: 'winner_bonus', ref: sub.taskId });
    if (fromPlatform > 0) tx.set(db.collection('platform').doc('stats'), { coinsCovered: FieldValue.increment(fromPlatform) }, { merge: true });
    return { bonus };
  });
});

// ---------- 7. Close: unused escrow returns to the creator ----------
async function closeTaskTx(uid, taskId) {
  const taskRef = db.collection('tasks').doc(taskId);
  return db.runTransaction(async (tx) => {
    const tSnap = await tx.get(taskRef);
    if (!tSnap.exists || tSnap.data().ownerId !== uid) throw new HttpsError('permission-denied', 'Task not found.');
    const task = tSnap.data();
    if (task.status !== 'published') return { refund: 0 };
    const pending = await tx.get(db.collection('submissions').where('taskId', '==', taskId).where('status', '==', 'in_review').limit(1));
    if (!pending.empty) throw failed('Decide all pending submissions first.');
    const refund = task.escrowRemaining || 0;
    tx.update(taskRef, { status: 'closed', escrowRemaining: 0, closedAt: FieldValue.serverTimestamp() });
    if (refund > 0) {
      tx.update(walletRef(uid), { balance: FieldValue.increment(refund), escrowHeld: FieldValue.increment(-refund) });
      ledger(tx, uid, { type: 'escrow_refund', amount: refund, ref: taskId });
    }
    return { refund };
  });
}
exports.closeTask = onCall(BASE_OPTS, async (req) => closeTaskTx(uidOf(req), V.str(req.data.taskId)));
exports.closeProject = onCall(BASE_OPTS, async (req) => {
  const uid = uidOf(req);
  const { ref } = await loadOwned('projects', V.str(req.data.projectId), uid, 'project');
  const tasks = await db.collection('tasks').where('projectId', '==', ref.id).get();
  let refund = 0;
  for (const t of tasks.docs) refund += (await closeTaskTx(uid, t.id)).refund;
  await ref.update({ status: 'closed', closedAt: FieldValue.serverTimestamp() });
  return { refund };
});

Object.assign(exports, require('./src/quests'), require('./src/portfolio'), require('./src/sweep'));
