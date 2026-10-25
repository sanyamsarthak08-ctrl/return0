const test = require('node:test');
const assert = require('node:assert');
const P = require('../src/pricing');
const { ruleCheck } = require('../src/rules');
const V = require('../src/validate');

test('sample project from the AI notes costs 740 coins', () => {
  const t = [[2,2],[3,4],[1,2],[2,2],[2,2],[3,3],[2,3],[2,3],[3,4],[2,3],[3,3]].map(([d,h]) => P.taskCoins(d,h));
  assert.strictEqual(t[1], 120); assert.strictEqual(t[2], 20);
  assert.strictEqual(P.projectCost(t), 740);
  assert.strictEqual(P.canPublish(600, 740), false);
  assert.strictEqual(P.canPublish(740, 740), true);
});

// replays the payout design: Task A pays 120 and platform covers 90; Task B refunds 30
function settle(base, decisions, winnerIndex) {
  let esc = base, paid = 0, platform = 0;
  decisions.forEach((d, i) => {
    let amt = P.basePayout(d, base);
    if (i === winnerIndex) amt += P.winnerBonus(base);
    const { fromEscrow, fromPlatform } = P.drawFromEscrow(esc, amt);
    esc -= fromEscrow; platform += fromPlatform; paid += amt;
  });
  return { paid, platform, refund: esc };
}
test('Task A: 3 accepted, one winner', () => {
  const r = settle(30, ['rejected','rejected','accepted','accepted','accepted'], 4);
  assert.deepStrictEqual(r, { paid: 120, platform: 90, refund: 0 });
});
test('Task B: nobody accepted', () => {
  assert.deepStrictEqual(settle(30, ['rejected','rejected'], -1), { paid: 0, platform: 0, refund: 30 });
});

test('rule checks', () => {
  const earlier = ['Here is my finished design for the home page.'];
  const rc = (s, l) => ruleCheck({ submission: s, requiresLink: l, earlierSubmissions: earlier });
  assert.strictEqual(rc(' ', false).passed, false);
  assert.strictEqual(rc('Done', false).passed, false);
  assert.strictEqual(rc('I finished the design and it looks great.', true).passed, false);
  assert.deepStrictEqual([rc('Here is my finished design for the home page.', false).passed, rc('Here is my finished design for the home page.', false).needsReview], [true, true]);
  assert.strictEqual(rc('My finished design: https://example.com/design', true).passed, true);
  assert.strictEqual(rc('https://figma.com/x', true).passed, true); // short valid link is allowed
});

test('extractJson handles fences and chatter', () => {
  assert.deepStrictEqual(V.extractJson('```json\n{"a":1}\n```'), { a: 1 });
  assert.deepStrictEqual(V.extractJson('Sure! {"a":1} hope that helps'), { a: 1 });
  assert.throws(() => V.extractJson('no json here'));
});

test('normalizePlan fixes skills, bad deps, cycles, caps at 12', () => {
  const mk = (id, deps, skill = 'Frontend') => ({ id, title: id, description: 'd', context: 'c', deliverables: [], skill, depends_on: deps, open_questions: [] });
  const plan = V.normalizePlan({ tasks: [mk('T1', ['T9']), mk('T2', ['T1'], 'Magic')] });
  assert.deepStrictEqual(plan[0].depends_on, []); assert.strictEqual(plan[1].skill, 'Other');
  const cyc = V.normalizePlan({ tasks: [mk('T1', ['T2']), mk('T2', ['T1'])] });
  assert.deepStrictEqual(cyc.map(t => t.depends_on), [[], []]);
  assert.strictEqual(V.normalizePlan({ tasks: Array.from({ length: 20 }, (_, i) => mk('T' + (i + 1), [])) }).length, 12);
});

test('judge guard: unclear or spam forces human review; accept needs 80+ and no fail', () => {
  const j = { score: 90, recommendation: 'suggest_accept', needs_human_review: false, feedback: 'ok', missing: [], why: 'w' };
  const ok = [{ result: 'pass' }];
  assert.strictEqual(V.sanitizeJudge(j, { verdict: 'genuine' }, ok).recommendation, 'suggest_accept');
  const u = V.sanitizeJudge(j, { verdict: 'genuine' }, [{ result: 'unclear' }]);
  assert.deepStrictEqual([u.needs_human_review, u.recommendation], [true, 'needs_review']);
  const s = V.sanitizeJudge(j, { verdict: 'spam' }, ok);
  assert.strictEqual(s.skill_points, 0);
  assert.strictEqual(V.sanitizeJudge(j, { verdict: 'genuine' }, [{ result: 'fail' }]).recommendation, 'suggest_changes');
});

test('surge locks in at claim time, squads split evenly, gating works', () => {
  assert.strictEqual(P.lockedCoins(40, 0), 40);
  assert.strictEqual(P.lockedCoins(40, 25), 50);
  assert.strictEqual(P.lockedCoins(45, 10), 50); // rounds up
  assert.deepStrictEqual(P.splitEven(100, 3), [34, 33, 33]);
  assert.strictEqual(P.splitEven(100, 3).reduce((a, b) => a + b, 0), 100);
  assert.deepStrictEqual(P.splitEven(40, 1), [40]);
  const task = { skill: 'Frontend', minLevel: 1 };
  assert.match(P.claimBlocker({ questsPassed: 0 }, task), /Proving Grounds/);
  assert.match(P.claimBlocker({ questsPassed: 1, skillPoints: { Frontend: 10 } }, task), /level 1/);
  assert.strictEqual(P.claimBlocker({ questsPassed: 1, skillPoints: { Frontend: 20 } }, task), null);
  assert.strictEqual(P.claimBlocker({ questsPassed: 1, skillPoints: {} }, task, { squad: true }), null); // squads pool skills
  assert.deepStrictEqual([P.requiredLevel(3), P.requiredLevel(4), P.requiredLevel(5)], [0, 1, 2]);
  assert.deepStrictEqual([P.sprintHours(2), P.sprintHours(3)], [12, 24]);
});

test('a squad of 3 on a winning task pays exactly baseline x2 in total', () => {
  const base = 30, members = 3;
  const total = P.splitEven(P.basePayout('accepted', base), members).concat(P.splitEven(P.winnerBonus(base), members));
  assert.strictEqual(total.reduce((a, b) => a + b, 0), 60);
});
