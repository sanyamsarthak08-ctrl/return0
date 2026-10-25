const SKILLS = ['UI Design', 'Frontend', 'Backend', 'Database', 'Copywriting', 'Testing', 'DevOps', 'Data/AI', 'Other'];
const MAX_TASKS = 12;

// Pull a JSON object out of an AI reply, even if it was wrapped in fences or extra text.
function extractJson(text) {
  if (typeof text !== 'string') throw new Error('empty AI reply');
  let t = text.trim().replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  try { return JSON.parse(t); } catch (_) { /* fall through */ }
  const a = t.indexOf('{'), b = t.lastIndexOf('}');
  if (a >= 0 && b > a) return JSON.parse(t.slice(a, b + 1));
  throw new Error('AI reply is not JSON');
}

function str(v, d = '') { return typeof v === 'string' ? v : d; }
function strList(v) { return Array.isArray(v) ? v.map(x => String(x)) : []; }

function hasCycle(tasks) {
  const deps = new Map(tasks.map(t => [t.id, t.depends_on]));
  const state = new Map();
  const visit = (id) => {
    if (state.get(id) === 1) return true;
    if (state.get(id) === 2) return false;
    state.set(id, 1);
    for (const d of deps.get(id) || []) if (visit(d)) return true;
    state.set(id, 2);
    return false;
  };
  return tasks.some(t => visit(t.id));
}

// Clean up a Planner/Critic plan so the rest of the app can trust it.
function normalizePlan(raw) {
  const list = Array.isArray(raw && raw.tasks) ? raw.tasks.slice(0, MAX_TASKS) : [];
  if (!list.length) throw new Error('plan has no tasks');
  const tasks = list.map((t, i) => ({
    id: str(t.id, `T${i + 1}`),
    title: str(t.title, `Task ${i + 1}`).slice(0, 120),
    description: str(t.description),
    context: str(t.context, 'None given in the brief.'),
    deliverables: strList(t.deliverables),
    skill: SKILLS.includes(t.skill) ? t.skill : 'Other',
    depends_on: strList(t.depends_on),
    open_questions: strList(t.open_questions),
  }));
  const ids = new Set(tasks.map(t => t.id));
  if (ids.size !== tasks.length) throw new Error('duplicate task ids');
  for (const t of tasks) t.depends_on = t.depends_on.filter(d => ids.has(d) && d !== t.id);
  if (hasCycle(tasks)) for (const t of tasks) t.depends_on = []; // safest fallback
  return tasks;
}

function clampInt(v, lo, hi, d) {
  const n = Math.round(Number(v));
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : d;
}

// Judge output is only a PROPOSAL, but we still enforce the hard rules in code.
function sanitizeJudge(j, spam, verifierResults) {
  const anyUnclear = (verifierResults || []).some(r => r.result === 'unclear');
  const spamFlag = spam && spam.verdict !== 'genuine';
  let score = clampInt(j && j.score, 0, 100, 0);
  let needs = !!(j && j.needs_human_review) || anyUnclear || spamFlag;
  let rec = ['suggest_accept', 'suggest_changes', 'needs_review'].includes(j && j.recommendation) ? j.recommendation : 'needs_review';
  if (needs) rec = 'needs_review';
  if (!needs && rec === 'suggest_accept' && ((verifierResults || []).some(r => r.result === 'fail') || score < 80)) rec = 'suggest_changes';
  let reason = str(j && j.review_reason);
  if (needs && !reason) reason = spamFlag ? 'Spam Guard flagged this submission.' : anyUnclear ? 'Some criteria could not be verified.' : 'The AI was not confident.';
  if (!needs) reason = '';
  const isSpam = spam && spam.verdict === 'spam';
  return {
    score, recommendation: rec, needs_human_review: needs, review_reason: reason,
    feedback: str(j && j.feedback), missing: strList(j && j.missing),
    skill_points: isSpam ? 0 : Math.floor(score / 10), why: str(j && j.why),
  };
}

function sanitizeSpam(s) {
  const verdict = ['genuine', 'needs_review', 'spam'].includes(s && s.verdict) ? s.verdict : 'needs_review';
  const c = Number(s && s.confidence);
  return { verdict, confidence: Number.isFinite(c) ? Math.min(1, Math.max(0, c)) : 0.5, why: str(s && s.why) };
}

function sanitizeVerifier(v, criteriaCount) {
  const arr = Array.isArray(v && v.results) ? v.results : [];
  const out = [];
  for (let n = 1; n <= criteriaCount; n++) {
    const r = arr.find(x => Number(x.criterion_number) === n) || {};
    out.push({
      criterion_number: n,
      result: ['pass', 'fail', 'unclear'].includes(r.result) ? r.result : 'unclear',
      evidence: str(r.evidence, 'Not found in submission.').slice(0, 200),
      why: str(r.why),
    });
  }
  return out;
}

module.exports = { SKILLS, MAX_TASKS, extractJson, normalizePlan, hasCycle, sanitizeJudge, sanitizeSpam, sanitizeVerifier, clampInt, str, strList };
