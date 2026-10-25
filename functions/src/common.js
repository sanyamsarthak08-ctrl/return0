// Shared Firebase handles and helpers.
const { HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { AiError } = require('./ai');
const P = require('./pricing');
const V = require('./validate');

if (!getApps().length) initializeApp();
const db = getFirestore();
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const PORTFOLIO_SECRET = defineSecret('PORTFOLIO_SECRET');
const REGION = 'us-central1';
const AI_OPTS = { secrets: [GEMINI_API_KEY], timeoutSeconds: 300, memory: '512MiB', region: REGION };
const BASE_OPTS = { region: REGION };

const uidOf = (req) => { if (!req.auth) throw new HttpsError('unauthenticated', 'Please sign in.'); return req.auth.uid; };
const bad = (m) => new HttpsError('invalid-argument', m);
const failed = (m) => new HttpsError('failed-precondition', m);
const wrapAi = async (fn) => {
  try { return await fn(); }
  catch (e) {
    if (e instanceof AiError || /AI output|Gemini|plan has no tasks|duplicate task ids/.test(e.message || '')) {
      console.error('AI error', e);
      throw new HttpsError('unavailable', 'The AI could not produce a readable answer. Please try again.');
    }
    throw e;
  }
};
const walletRef = (uid) => db.collection('wallets').doc(uid);
const ledger = (tx, uid, entry) =>
  tx.set(walletRef(uid).collection('ledger').doc(), { ...entry, createdAt: FieldValue.serverTimestamp() });

async function loadOwned(coll, id, uid, what) {
  const ref = db.collection(coll).doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', `${what} not found.`);
  if (snap.data().ownerId !== uid) throw new HttpsError('permission-denied', `You do not own this ${what}.`);
  return { ref, data: snap.data() };
}
async function recomputeCost(projectId) {
  const snap = await db.collection('tasks').where('projectId', '==', projectId).get();
  const cost = P.projectCost(snap.docs.map(d => d.data().coins || 0));
  await db.collection('projects').doc(projectId).update({ cost, updatedAt: FieldValue.serverTimestamp() });
  return cost;
}

module.exports = {
  db, FieldValue, Timestamp, HttpsError, GEMINI_API_KEY, PORTFOLIO_SECRET, REGION, AI_OPTS, BASE_OPTS,
  uidOf, bad, failed, wrapAi, walletRef, ledger, loadOwned, recomputeCost, P, V,
};
