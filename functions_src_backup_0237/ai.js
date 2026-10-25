// The ONLY place that talks to Gemini. The key lives in Firebase Secret Manager, never in the app.
const { extractJson } = require('./validate');

const MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';
const CHEAP_MODEL = process.env.GEMINI_MODEL_CHEAP || 'gemini-3.1-flash-lite';
const TIMEOUT_MS = 120000; // give up on a stuck call instead of hanging for 5 minutes

class AiError extends Error {}

// Pull the model's answer out of an Interactions API response.
function pickText(data) {
  if (!data) return '';
  if (typeof data.output_text === 'string' && data.output_text) return data.output_text;
  const out = [];
  const take = (content) => {
    const list = Array.isArray(content) ? content : (typeof content === 'string' ? [{ type: 'text', text: content }] : []);
    for (const c of list) if (c && typeof c.text === 'string' && (!c.type || c.type === 'text')) out.push(c.text);
  };
  const steps = Array.isArray(data.steps) ? data.steps : [];
  for (const s of steps) if (s && s.type === 'model_output') take(s.content);
  if (!out.length) { // fallback: any step that is not the user's input or the model's private thinking
    for (const s of steps) if (s && s.type !== 'user_input' && s.type !== 'thought') take(s.content);
  }
  return out.join('');
}

// Gemini 3.x models use the Interactions API. The old generateContent call returns 404 for them.
async function callGemini(apiKey, model, prompt) {
  console.log('Calling Gemini model:', model);
  const res = await fetch('https://generativelanguage.googleapis.com/v1beta/interactions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({ model, input: prompt, }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw new AiError(`Gemini HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const text = pickText(data);
  if (!text) throw new AiError('Gemini returned no text: ' + JSON.stringify(data).slice(0, 300));
  return text;
}

// Ask for JSON. If it cannot be read, retry once (as the AI notes say), then give up.
async function askJson(apiKey, prompt, { cheap = false } = {}) {
  const model = cheap ? CHEAP_MODEL : MODEL;
  let lastErr;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      return extractJson(await callGemini(apiKey, model, prompt));
    } catch (e) { console.error('Gemini attempt failed:', e && e.message); lastErr = e; }
  }
  throw new AiError(`AI output could not be read: ${lastErr && lastErr.message}`);
}

module.exports = { askJson, AiError };
