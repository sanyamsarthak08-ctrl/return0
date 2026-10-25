// Tests the REAL Spam Guard on its own, with no app and no emulator needed.
// Run from the functions/ folder:
//   set -a; source .secret.local; set +a; node scripts/test_spam.js
const { askJson } = require('../src/ai');
const P = require('../src/prompts');
const V = require('../src/validate');
const { SPAM_CONFIDENCE, SPAM_PENALTY } = require('../src/pricing');

const TASK = `Pricing page hero in 50 words (skill: Copywriting)
Write one hook, one proof point and one reason to act today for the pricing page of a student marketplace.`;

const CASES = [
  { label: 'real attempt', expect: 'genuine',
    text: 'Stop overpaying for textbooks. 4,000 students at 30 colleges already swap books, dorm gear and electronics safely with escrow-protected payments. List your first item in two minutes and keep every rupee of what you earn. Join this week and your first three listings are free.' },
  { label: 'random characters', expect: 'spam (penalty)',
    text: 'asdkjh qwe qwe lkjasd 12345 zzzz asdf asdf' },
  { label: 'advertisement', expect: 'spam (penalty)',
    text: 'BUY CHEAP WATCHES NOW!!! Visit www.best-deals-4u.biz for 90% off. Click here to win a free phone.' },
  { label: 'copy of the task', expect: 'spam (penalty)',
    text: 'Write one hook, one proof point and one reason to act today for the pricing page of a student marketplace.' },
  { label: 'unrelated text', expect: 'spam (penalty)',
    text: 'The mitochondria is the powerhouse of the cell. It produces ATP through oxidative phosphorylation in eukaryotic organisms.' },
  { label: 'short but related', expect: 'needs_review (NO penalty)',
    text: 'Save money on books. Join now.' },
];

(async () => {
  const key = process.env.GEMINI_API_KEY;
  if (!key) { console.error('GEMINI_API_KEY is empty. Run: set -a; source .secret.local; set +a'); process.exit(1); }
  console.log(`Penalty applies only when verdict is "spam" AND confidence >= ${SPAM_CONFIDENCE} (${SPAM_PENALTY} coins).\n`);
  for (const c of CASES) {
    try {
      const r = V.sanitizeSpam(await askJson(key, P.spamGuard(TASK, c.text), { cheap: true }));
      const penalised = r.verdict === 'spam' && r.confidence >= SPAM_CONFIDENCE;
      console.log(`${c.label.padEnd(20)} expected: ${c.expect.padEnd(26)} got: ${r.verdict.padEnd(12)} conf ${r.confidence.toFixed(2)}  penalised: ${penalised ? 'YES' : 'no'}\n  why: ${r.why}`);
    } catch (e) {
      console.log(`${c.label.padEnd(20)} FAILED: ${e.message}`);
    }
  }
})();
