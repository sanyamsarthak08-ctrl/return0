// Hourly job: surge pricing for ignored tasks + sprint expiry so projects never stall.
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall } = require('firebase-functions/v2/https');
const { db, FieldValue, Timestamp, REGION, HttpsError, P } = require('./common');

async function sweep() {
  let surged = 0, expired = 0, reopened = 0;

  // 1) bounty scaling: no claims yet -> the payout climbs a step each hour, up to the cap
  const idle = await db.collection('tasks').where('status', '==', 'published').where('claimsCount', '==', 0).get();
  for (const d of idle.docs) {
    const cur = d.data().surgePercent || 0;
    if (cur < P.MAX_SURGE) { await d.ref.update({ surgePercent: Math.min(P.MAX_SURGE, cur + P.SURGE_STEP) }); surged++; }
  }

  // 2) sprint expiry (single-field query, status filtered in code to avoid a composite index)
  const due = await db.collection('tasks').where('sprintEndsAt', '<=', Timestamp.now()).get();
  for (const d of due.docs) {
    const task = d.data();
    if (task.status !== 'published' || task.sprintSwept) continue;
    const claims = await db.collection('claims').where('taskId', '==', d.id).get();
    const batch = db.batch();
    let alive = 0;
    claims.docs.forEach(c => {
      if (c.data().status === 'active') { batch.update(c.ref, { status: 'expired' }); expired++; }
      else if (c.data().status !== 'expired') alive++;
    });
    if (alive === 0) { // nobody delivered: reopen with a bigger bounty
      batch.update(d.ref, { sprintEndsAt: null, claimsCount: 0, surgePercent: Math.min(P.MAX_SURGE, (task.surgePercent || 0) + P.SURGE_STEP * 2) });
      reopened++;
    } else {
      batch.update(d.ref, { sprintSwept: true, claimsCount: alive });
    }
    await batch.commit();
  }
  return { surged, expired, reopened };
}

exports.hourlySweep = onSchedule({ schedule: 'every 60 minutes', region: REGION }, async () => { console.log(await sweep()); });

// emulator only: lets you trigger the sweep from the app during a demo
exports.debugSweep = onCall({ region: REGION }, async () => {
  if (process.env.FUNCTIONS_EMULATOR !== 'true') throw new HttpsError('permission-denied', 'Emulator only.');
  return sweep();
});
