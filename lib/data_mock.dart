import 'models.dart';

/// Everything here is placeholder data. Replace with Firestore reads.
const sampleBrief =
    'CampusSwap is a peer-to-peer marketplace for college students to buy and sell used textbooks, dorm furniture and electronics.\n\n'
    'Students sign in with their college email. Sellers post listings with photos and a price. Buyers search and filter by category, price and distance, then chat with the seller in the app. Payment is held in escrow until both sides confirm the handoff.\n\n'
    'We need a brand, the listing UI, the backend for accounts and listings, search, chat, launch copy, and tests for the checkout flow. Launch is in three weeks.';

const mockSkills = <String, int>{
  'HTML & CSS': 9, 'React': 8, 'State & Perf': 4, 'Testing': 0,
  'UI Design': 7, 'Prototyping': 3, 'Design Systems': 0,
  'Copywriting': 7, 'Microcopy': 2, 'Brand Voice': 0,
  'REST APIs': 6, 'Databases': 3, 'Auth & Security': 0, 'Scaling': 0,
};

int _s(int h, int m, [int s = 0]) => h * 3600 + m * 60 + s;

Task _t(String id, String project, String title, String desc, Kind kind, List<SkillReq> skills,
    int base, int mult, int claimed, int left, int total, int surge, int unblocks,
    {bool squad = false, bool crit = false}) {
  return Task(
    id: id, project: project, title: title, desc: desc, kind: kind, skills: skills,
    base: base, mult: mult, claimed: claimed, max: 5, total: total,
    endsAt: DateTime.now().add(Duration(seconds: left)),
    surge: surge, unblocks: unblocks, squad: squad, crit: crit,
  );
}

List<Task> mockTasks() => [
      _t('a1', 'Orbit CRM', 'Kanban drag-and-drop board',
          'Cards move between columns, keyboard accessible, order persists on refresh.',
          Kind.frontend, const [SkillReq('React', 8), SkillReq('State & Perf', 5)],
          40, 3, 0, _s(21, 30), _s(24, 0), 60, 3, squad: true),
      _t('a2', 'LedgerLite', 'Fix pagination off-by-one in invoices API',
          'Last page repeats the final row. Add a regression test.',
          Kind.backend, const [SkillReq('REST APIs', 4)],
          9, 3, 5, _s(0, 41, 20), _s(12, 0), 0, 1),
      _t('a3', 'CampusSwap', 'Search and filter bar with URL state',
          'Debounced search, category chips, filters survive a page reload.',
          Kind.frontend, const [SkillReq('React', 6), SkillReq('State & Perf', 3)],
          22, 3, 1, _s(19, 5, 31), _s(24, 0), 35, 2, squad: true, crit: true),
      _t('a4', 'Verdant', 'Three launch-email subject lines with preview text',
          'Warm, specific, under 45 characters. A/B ready.',
          Kind.copy, const [SkillReq('Copywriting', 3)],
          8, 4, 3, _s(5, 57, 3), _s(12, 0), 0, 1),
      _t('a5', 'Trailhead', 'Mobile onboarding flow, four screens',
          'Permissions, first hike, trail match, success. Figma-ready frames.',
          Kind.design, const [SkillReq('UI Design', 6), SkillReq('Prototyping', 3)],
          30, 3, 2, _s(14, 12, 9), _s(24, 0), 0, 2, squad: true),
      _t('a6', 'Orbit CRM', 'Role-based auth middleware',
          'Admin, manager and viewer roles on every route. Include tests.',
          Kind.backend, const [SkillReq('REST APIs', 7), SkillReq('Auth & Security', 4)],
          55, 3, 0, _s(22, 2), _s(24, 0), 80, 4),
      _t('a7', 'Verdant', 'Pricing page hero in 50 words',
          'One hook, one proof point, one reason to act today.',
          Kind.copy, const [SkillReq('Copywriting', 5)],
          10, 4, 4, _s(8, 44, 50), _s(12, 0), 0, 1),
      _t('a8', 'LedgerLite', 'Empty-state illustration set',
          'Four spot illustrations for invoices, clients, reports and settings.',
          Kind.design, const [SkillReq('UI Design', 5)],
          12, 3, 2, _s(7, 42, 10), _s(12, 0), 0, 3),
      _t('a9', 'Trailhead', 'Postgres schema and migrations',
          'Users, trails, hikes and photos with indexes and seed data.',
          Kind.backend, const [SkillReq('Databases', 3)],
          16, 3, 1, _s(9, 44, 50), _s(12, 0), 15, 2),
    ];

List<PlanTask> mockPlan() => [
      PlanTask(id: 't1', title: 'Brand mark and color palette', kind: Kind.design, skills: ['UI Design'], eff: 5, w: 1, deps: []),
      PlanTask(id: 't2', title: 'Listing card and grid UI', kind: Kind.design, skills: ['UI Design', 'HTML & CSS'], eff: 6, w: 1.2, deps: ['t1']),
      PlanTask(id: 't3', title: 'Sign-in and verify-email API', kind: Kind.backend, skills: ['REST APIs'], eff: 6, w: 1.3, deps: []),
      PlanTask(id: 't4', title: 'Listings CRUD endpoints', kind: Kind.backend, skills: ['REST APIs', 'Databases'], eff: 8, w: 1.6, deps: ['t3']),
      PlanTask(id: 't5', title: 'Search and filter bar', kind: Kind.frontend, skills: ['React'], eff: 7, w: 1.4, deps: ['t2', 't4']),
      PlanTask(id: 't6', title: 'Launch copy and onboarding text', kind: Kind.copy, skills: ['Copywriting'], eff: 3, w: .8, deps: ['t1']),
      PlanTask(id: 't7', title: 'Seller chat component', kind: Kind.frontend, skills: ['React', 'State & Perf'], eff: 8, w: 1.7, deps: ['t2']),
      PlanTask(id: 't8', title: 'End-to-end checkout tests', kind: Kind.qa, skills: ['Testing'], eff: 5, w: 1, deps: ['t4', 't5', 't7']),
    ];

const mockBranches = <Branch>[
  Branch('FRONTEND', 1, [SkillNode('HTML & CSS', 9, .62), SkillNode('React', 8, .35), SkillNode('State & Perf', 4, .8), SkillNode('Testing', 0, 0)]),
  Branch('DESIGN', 2, [SkillNode('UI Design', 7, .5), SkillNode('Prototyping', 3, .2), SkillNode('Design Systems', 0, 0)]),
  Branch('COPY', 3, [SkillNode('Copywriting', 7, .7), SkillNode('Microcopy', 2, .4), SkillNode('Brand Voice', 0, 0)]),
  Branch('BACKEND', 4, [SkillNode('REST APIs', 6, .45), SkillNode('Databases', 3, .9), SkillNode('Auth & Security', 0, 0), SkillNode('Scaling', 0, 0)]),
];

const mockHistory = <HistoryItem>[
  HistoryItem(title: 'Responsive pricing table', project: 'Verdant', outcome: Outcome.selected, delta: '+14 +42', xp: ['React +10', 'HTML & CSS +6'], when: '2 days ago',
      feedback: 'Clean CSS grid and a sensible breakpoint plan. Add a visible focus style to the billing toggle so keyboard users can see it.'),
  HistoryItem(title: 'Dark-mode toggle component', project: 'Orbit CRM', outcome: Outcome.selected, delta: '+16 +48', xp: ['React +10', 'HTML & CSS +5'], when: '4 days ago',
      feedback: 'Respects the system setting and stores the choice. Consider moving the theme tokens into one file so other components can reuse them.'),
  HistoryItem(title: 'Onboarding empty states', project: 'Trailhead', outcome: Outcome.approved, delta: '+12', xp: ['UI Design +8'], when: '5 days ago',
      feedback: 'Friendly and consistent. The second screen needs a stronger call to action.'),
  HistoryItem(title: 'GET /orders with pagination', project: 'LedgerLite', outcome: Outcome.approved, delta: '+18', xp: ['REST APIs +9'], when: '1 week ago',
      feedback: 'Cursor pagination is a good call. Return a total count or a next-cursor flag so clients know when to stop.'),
  HistoryItem(title: 'Subject lines for launch email', project: 'Verdant', outcome: Outcome.rejected, delta: '-10 rep -3', xp: [], when: '1 week ago',
      feedback: 'The submission repeated the brief and did not propose any copy. Write three distinct options and explain the angle of each.'),
];
