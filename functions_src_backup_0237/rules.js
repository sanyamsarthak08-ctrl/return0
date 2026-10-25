// Rule checks (plain code). Fix from the AI notes: a short but valid link is not "too short".
function ruleCheck({ submission, requiresLink, earlierSubmissions }) {
  const text = (submission || '').trim();
  if (!text) return { passed: false, needsReview: false, message: 'Please add your work before submitting.' };
  const hasLink = /https?:\/\//i.test(text);
  if (text.length < 20 && !hasLink) {
    return { passed: false, needsReview: false, message: 'Your submission is too short. Please add more detail.' };
  }
  if (requiresLink && !hasLink) {
    return { passed: false, needsReview: false, message: 'This task needs a link. Please add one.' };
  }
  const lower = text.toLowerCase();
  for (const old of earlierSubmissions || []) {
    if ((old || '').trim().toLowerCase() === lower) {
      return { passed: true, needsReview: true, message: 'Identical to an earlier submission. Owner should review.' };
    }
  }
  return { passed: true, needsReview: false, message: 'Passed rule checks.' };
}
module.exports = { ruleCheck };
