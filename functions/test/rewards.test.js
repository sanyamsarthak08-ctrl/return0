const test = require('node:test');
const assert = require('node:assert');
const P = require('../src/pricing');

test('tier 1: passing the Spam Guard pays a guaranteed minimum, never more than the base', () => {
  assert.strictEqual(P.participationPayout(90), 23);                 // 25% of 90, rounded
  assert.strictEqual(P.participationPayout(10), 5);                  // floor of 5 coins
  assert.strictEqual(P.participationPayout(3), 3);                   // never above the base itself
  for (const base of [10, 24, 90, 150, 300]) {
    const p = P.participationPayout(base);
    assert.ok(p >= Math.min(base, P.MIN_PARTICIPATION) && p <= base, `bad minimum for ${base}`);
  }
});

test('the minimum is smaller than the spam penalty, so farming junk does not pay', () => {
  assert.ok(P.MIN_PARTICIPATION < P.SPAM_PENALTY);
});

test('tiers add up: minimum + remainder = base, winner gets base + bonus', () => {
  for (const base of [10, 90, 300]) {
    const min = P.participationPayout(base);
    const remainder = Math.max(0, P.basePayout('accepted', base) - min);   // what decideSubmission pays now
    assert.strictEqual(min + remainder, base);
    const winnerTotal = min + remainder + P.winnerBonus(base);
    assert.strictEqual(winnerTotal, base * P.WINNER_MULTIPLIER);
    assert.ok(winnerTotal > base, 'the chosen submission must earn more');
  }
});

test('a rejected submission that passed the Spam Guard keeps its minimum and gets nothing more', () => {
  const base = 90;
  const min = P.participationPayout(base);
  const remainder = Math.max(0, P.basePayout('rejected', base) - min);
  assert.strictEqual(remainder, 0);
  assert.ok(min > 0);
});

test('squads split the minimum evenly', () => {
  const parts = P.splitEven(P.participationPayout(90), 3);
  assert.strictEqual(parts.reduce((a, b) => a + b, 0), 23);
});
