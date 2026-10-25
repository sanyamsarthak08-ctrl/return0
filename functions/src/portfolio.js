// Public Skill Tree / portfolio. Built only from verified decisions; signed so edits are detectable.
const crypto = require('crypto');
const { onCall } = require('firebase-functions/v2/https');
const { db, FieldValue, PORTFOLIO_SECRET, BASE_OPTS, uidOf, failed, HttpsError, P, V } = require('./common');

const OPTS = { ...BASE_OPTS, secrets: [PORTFOLIO_SECRET] };

// stable stringify so the signature does not depend on key order
const canon = (v) => Array.isArray(v) ? `[${v.map(canon).join(',')}]`
  : v && typeof v === 'object' ? `{${Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canon(v[k])).join(',')}}` : JSON.stringify(v);
const sign = (payload) => crypto.createHmac('sha256', PORTFOLIO_SECRET.value()).update(canon(payload)).digest('hex');

exports.publishPortfolio = onCall(OPTS, async (req) => {
  const uid = uidOf(req);
  const userRef = db.collection('users').doc(uid);
  const u = await userRef.get();
  if (!u.exists) throw failed('Please sign in again to finish setting up your account.');
  const user = u.data();

  const dec = await db.collection('decisions').where('members', 'array-contains', uid).get();
  const contributions = dec.docs.map(d => d.data()).filter(d => d.final_decision === 'accepted')
    .sort((a, b) => b.decided_at.toMillis() - a.decided_at.toMillis()).slice(0, 50)
    .map(d => ({ task: d.taskTitle, project: d.projectTitle, skill: d.skill, score: d.final_score, selected: !!d.isWinner, date: d.decided_at.toDate().toISOString().slice(0, 10) }));
  const skills = Object.entries(user.skillPoints || {}).map(([skill, points]) => ({ skill, points, level: P.levelOf(points) }))
    .sort((a, b) => b.points - a.points);

  const payload = {
    name: user.displayName, xp: user.xp || 0, reputation: user.reputation ?? 50, badges: user.badges || [],
    skills, contributions, selectedCount: contributions.filter(c => c.selected).length, generatedAt: new Date().toISOString(),
  };
  const slug = user.portfolioSlug || crypto.randomBytes(6).toString('hex');
  await db.collection('portfolios').doc(slug).set({ ownerUid: uid, payload, signature: sign(payload), updatedAt: FieldValue.serverTimestamp() });
  if (!user.portfolioSlug) await userRef.update({ portfolioSlug: slug });
  return { slug, payload };
});

// anyone (an employer) can check that a portfolio was not edited after the server signed it
exports.verifyPortfolio = onCall(OPTS, async (req) => {
  const snap = await db.collection('portfolios').doc(V.str(req.data.slug)).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Portfolio not found.');
  return { valid: sign(snap.data().payload) === snap.data().signature };
});
