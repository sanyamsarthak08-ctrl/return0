// AI pipelines. These only PROPOSE; they never touch coins or Firestore.
const P = require('./prompts');
const { askJson, AiError } = require('./ai');
const V = require('./validate');
const { taskCoins } = require('./pricing');

const chunk = (arr, n) => { const out = []; for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n)); return out; };
const brief4 = (t) => ({ id: t.id, title: t.title, description: t.description, context: t.context, deliverables: t.deliverables, skill: t.skill });
const taskText = (t) => `${t.title} (skill: ${t.skill})\n${t.description}`;

async function writeCriteria(apiKey, tasks) {
  const map = new Map();
  for (const batch of chunk(tasks, 4)) { // batches of ~4, otherwise the AI stops early
    const r = await askJson(apiKey, P.criteriaWriter(JSON.stringify(batch.map(brief4))));
    for (const c of (r && r.criteria) || []) map.set(c.id, V.strList(c.acceptance_criteria));
  }
  for (const t of tasks) { // one more try for any task that got nothing
    if (!(map.get(t.id) || []).length) {
      const r = await askJson(apiKey, P.criteriaWriter(JSON.stringify([brief4(t)])));
      const c = ((r && r.criteria) || []).find(x => x.id === t.id);
      map.set(t.id, c ? V.strList(c.acceptance_criteria) : []);
    }
    if (!(map.get(t.id) || []).length) throw new AiError(`no acceptance criteria for ${t.id}`);
  }
  return map;
}

async function analyseDifficulty(apiKey, tasks) {
  const map = new Map();
  for (const batch of chunk(tasks, 6)) {
    const r = await askJson(apiKey, P.difficultyAnalyst(JSON.stringify(batch.map(brief4))));
    for (const d of (r && r.difficulty) || []) map.set(d.id, d);
  }
  return map;
}

function applyPricing(task, d) {
  const difficulty = V.clampInt(d && d.difficulty, 1, 5, 3);
  const hours = V.clampInt(d && d.estimated_hours, 1, 6, 3);
  return { ...task, difficulty, estimated_hours: hours, ai_reason: V.str(d && d.why), coins: taskCoins(difficulty, hours) };
}

// brief in -> priced tasks out
async function shred(apiKey, brief) {
  const planned = V.normalizePlan(await askJson(apiKey, P.planner(brief)));
  let tasks = planned, issues = [];
  try {
    const crit = await askJson(apiKey, P.critic(JSON.stringify({ tasks: planned })));
    tasks = V.normalizePlan(crit);
    issues = V.strList(crit.issues_found);
  } catch (e) {
    issues = ['The Critic step failed, so the first plan is used as is.'];
  }
  const criteria = await writeCriteria(apiKey, tasks);
  const diff = await analyseDifficulty(apiKey, tasks);
  const priced = tasks.map(t => ({ ...applyPricing(t, diff.get(t.id)), acceptance_criteria: criteria.get(t.id) }));
  return { tasks: priced, issues_found: issues };
}

// creator edited the wording -> re-run difficulty + pricing for that one task
async function repriceTask(apiKey, task) {
  const diff = await analyseDifficulty(apiKey, [task]);
  return applyPricing(task, diff.get(task.id));
}

// submission in -> suggestion out
async function autoQA(apiKey, task, submission) {
  const tt = taskText(task);
  const spam = V.sanitizeSpam(await askJson(apiKey, P.spamGuard(tt, submission), { cheap: true }));
  if (spam.verdict === 'spam') {
    // clearly junk: skip the expensive steps, send to the owner's queue
    const judge = V.sanitizeJudge({ score: 0, recommendation: 'needs_review', needs_human_review: true,
      review_reason: 'Spam Guard marked this as spam.', feedback: '', missing: [], why: 'Marked as spam.' }, spam, []);
    return { spam_guard: spam, verifier: [], judge };
  }
  const numbered = task.acceptance_criteria.map((c, i) => `${i + 1}. ${c}`).join('\n');
  const verifier = V.sanitizeVerifier(await askJson(apiKey, P.verifier(tt, numbered, submission)), task.acceptance_criteria.length);
  const rawJudge = await askJson(apiKey, P.judge(tt, JSON.stringify(spam), JSON.stringify({ results: verifier })));
  return { spam_guard: spam, verifier, judge: V.sanitizeJudge(rawJudge, spam, verifier) };
}

async function generateQuest(apiKey, skill, level) {
  const r = await askJson(apiKey, P.questGenerator(skill, level));
  const prompt = V.str(r && r.prompt).trim();
  const rubric = V.strList(r && r.rubric).slice(0, 5);
  if (prompt.length < 20 || rubric.length < 2) throw new AiError('quest was not usable');
  return { prompt, rubric };
}

async function gradeQuest(apiKey, prompt, rubric, answer) {
  const r = await askJson(apiKey, P.questGrader(prompt, rubric.map((x, i) => `${i + 1}. ${x}`).join('\n'), answer), { cheap: true });
  return { score: V.clampInt(r && r.score, 0, 100, 0), feedback: V.str(r && r.feedback) };
}

module.exports = { shred, repriceTask, autoQA, generateQuest, gradeQuest };
