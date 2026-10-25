// Pure logic (no Firebase). Team can change these constants.
const COINS_PER_WEIGHT = 10;
const WINNER_MULTIPLIER = 2;
const MAX_CLAIMS_PER_TASK = 5;

function taskCoins(difficulty, hours) {
  return difficulty * hours * COINS_PER_WEIGHT;
}
function projectCost(coinsList) {
  return coinsList.reduce((a, b) => a + b, 0);
}
function canPublish(balance, cost) {
  return balance >= cost;
}
// what ONE contributor gets for an accepted submission (winner bonus is paid separately)
function basePayout(decision, base) {
  return decision === 'accepted' ? base : 0;
}
function winnerBonus(base) {
  return base * (WINNER_MULTIPLIER - 1);
}
// split a payout between the creator's remaining escrow and the platform
function drawFromEscrow(escrowRemaining, amount) {
  const fromEscrow = Math.min(escrowRemaining, amount);
  return { fromEscrow, fromPlatform: amount - fromEscrow };
}

// ---- blueprint mechanics ----
const MAX_SQUAD = 3;
const REQUIRE_QUEST_TO_CLAIM = true;   // Proving Grounds gate; set false to let anyone claim during demos
const SURGE_STEP = 10;                 // +10% bounty per hourly sweep while a task has no claims
const MAX_SURGE = 100;                 // bounty never more than 2x
const SPAM_PENALTY = 10;               // coins taken for confident spam
const SPAM_CONFIDENCE = 0.85;          // below this the case goes to the owner, no penalty
const REP_SPAM_PENALTY = 5;
const REP_ACCEPTED_BONUS = 2;
const QUEST_REWARD = 20;
const QUEST_PASS_SCORE = 60;
const QUEST_DAILY_LIMIT = 12;          // quests a user can start per day

// ---- Proving Grounds pricing by difficulty ----
const QUEST_DIFFICULTIES = ['easy', 'medium', 'hard'];
const QUEST_REWARDS = { easy: 10, medium: 20, hard: 40 };           // coins paid for passing
const QUEST_PASS_SCORES = { easy: 60, medium: 60, hard: 70 };       // grade (0-100) needed to pass
const QUEST_SKILL_MULT = { easy: 1, medium: 2, hard: 3 };           // harder quests level a skill up faster (20 points = 1 level)
const questReward = (difficulty) => QUEST_REWARDS[difficulty] || QUEST_REWARD;
const questPassScore = (difficulty) => QUEST_PASS_SCORES[difficulty] || QUEST_PASS_SCORE;
const questSkillPoints = (score, difficulty) => Math.floor((score || 0) / 10) * (QUEST_SKILL_MULT[difficulty] || 1);

// ---- reward tiers (what a contributor earns) ----
// Tier 1: ANY submission that passes the Spam Guard is paid a guaranteed minimum automatically.
// Tier 2: if the owner accepts it, the contributor is topped up to the full base price.
// Tier 3: the one submission the owner picks as the winner also gets the winner bonus (base x (WINNER_MULTIPLIER - 1)).
const PARTICIPATION_PERCENT = 25;      // % of the task's base price paid when the Spam Guard says 'genuine'
const MIN_PARTICIPATION = 5;           // ...but never fewer coins than this (keep it below SPAM_PENALTY so farming does not pay)
const participationPayout = (base) => Math.min(base, Math.max(MIN_PARTICIPATION, Math.round(base * PARTICIPATION_PERCENT / 100)));

const lockedCoins = (base, surgePercent) => Math.ceil(base * (1 + (surgePercent || 0) / 100));
const levelOf = (points) => Math.floor((points || 0) / 20);          // 20 skill points per level
const requiredLevel = (difficulty) => (difficulty >= 5 ? 2 : difficulty >= 4 ? 1 : 0);
const initialSurge = (difficulty) => (difficulty >= 4 ? 20 : 0);     // hard tasks start with a higher bounty
const sprintHours = (estimatedHours) => (estimatedHours <= 2 ? 12 : 24);

// split coins between squad members; any remainder goes to the first member (the leader)
function splitEven(amount, n) {
  const share = Math.floor(amount / n);
  const out = Array(n).fill(share);
  out[0] += amount - share * n;
  return out;
}

// returns a message if this user may not claim the task, else null
function claimBlocker(user, task, { squad = false } = {}) {
  if (REQUIRE_QUEST_TO_CLAIM && !((user && user.questsPassed) > 0)) return 'Pass a Proving Grounds quest first to unlock real tasks.';
  const need = task.minLevel || 0;
  const have = levelOf(((user && user.skillPoints) || {})[task.skill] || 0);
  if (!squad && need > 0 && have < need) return `This task needs ${task.skill} level ${need} (you are level ${have}). Squads can team up for it.`;
  return null;
}

module.exports = {
  PARTICIPATION_PERCENT, MIN_PARTICIPATION, participationPayout,
  COINS_PER_WEIGHT, WINNER_MULTIPLIER, MAX_CLAIMS_PER_TASK, MAX_SQUAD, REQUIRE_QUEST_TO_CLAIM, SURGE_STEP, MAX_SURGE,
  SPAM_PENALTY, SPAM_CONFIDENCE, REP_SPAM_PENALTY, REP_ACCEPTED_BONUS, QUEST_REWARD, QUEST_PASS_SCORE, QUEST_DAILY_LIMIT,
  QUEST_DIFFICULTIES, QUEST_REWARDS, QUEST_PASS_SCORES, QUEST_SKILL_MULT, questReward, questPassScore, questSkillPoints,
  taskCoins, projectCost, canPublish, basePayout, winnerBonus, drawFromEscrow,
  lockedCoins, levelOf, requiredLevel, initialSurge, sprintHours, splitEven, claimBlocker,
};
