// lib/pirate_words.dart
// All pirate words live here. Change a word here and it changes everywhere.
// This only changes labels on screen, never the database or the AI.

class Pirate {
  // People & money
  static const appName = 'Crumb';
  static const tagline = 'The Pirate Bounty Board';
  static const currency = 'Crumbs';
  static const creator = 'Captain';
  static const contributor = 'Crew';
  static const wallet = 'Chest';
  static const escrow = 'Locked in the chest';
  static const bonus = 'Bonus crumbs';
  static const skillPoints = 'Pearls';
  static const skillTree = 'Treasure Map';

  // Projects & tasks
  static const project = 'Voyage';
  static const projects = 'Voyages';
  static const task = 'Bounty';
  static const tasks = 'Bounties';
  static const board = 'Bounty Board';
  static const deliverables = 'Loot to Deliver';
  static const criteria = "Pirate's Code";
  static const openQuestions = 'Questions for the Captain';
  static const publishButton = 'Set Sail';
  static const race = 'Treasure Race';
  static const starterTasks = 'Training Bounties';
  static const newProject = 'New Voyage';
  static const quests = 'Proving Grounds';

  // Status
  static const statusDraft = 'Draft';
  static const statusApproved = 'Ready to Sail';
  static const statusPublished = 'Sailing';

  // Review & rewards
  static const needsReview = 'Awaiting the Captain';
  static const accepted = 'Mission Accomplished';
  static const changesRequested = 'Mend the Sails';
  static const rejected = 'Missed the Boat';
  static const bestSubmission = 'Top Pirate';

  // AI helpers
  static const aiJudge = 'First Mate';
  static const aiVerifier = 'Cargo Check';
  static const aiDifficulty = 'Weather Check';

  // Screens
  static const home = 'Harbor';
  static const profile = 'My Ship';
  static const notifications = 'Messages';

  // Levels (1 to 5)
  static const levels = ['Cabin Boy', 'Sailor', 'Pirate', "Captain's Hand", 'Legend'];

  // Difficulty (1 to 5)
  static const difficulty = ['Calm', 'Breezy', 'Windy', 'Stormy', 'Hurricane'];

  static String levelName(int level) =>
      levels[(level - 1).clamp(0, levels.length - 1)];

  static String difficultyName(int d) =>
      difficulty[(d - 1).clamp(0, difficulty.length - 1)];

  // Messages
  static const notEnoughCrumbs =
      'Your chest is too light, Captain. Add more crumbs to set sail.';
  static const emptySubmission = 'Nothing to bring back! Add your work first.';
  static const nobodyPassed =
      'No bounty claimed. Your crumbs are back in your chest.';
  static String welcomeAboard(int crumbs) =>
      'Welcome Aboard! You earned $crumbs crumbs.';
}
