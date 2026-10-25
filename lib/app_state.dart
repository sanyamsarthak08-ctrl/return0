import 'dart:math' as math;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'data_mock.dart';
import 'models.dart';
import 'services/backend_service.dart';
import 'utils.dart';

enum AppView { board, upload, projects, profile }

enum SortBy { ending, bounty, open }

class PlanAnalysis {
  final Map<String, int> idx;
  final List<int> lvl;
  final Set<int> crit;
  final int total, steps;
  const PlanAnalysis(this.idx, this.lvl, this.crit, this.total, this.steps);
}

/// Longest-path analysis for the dependency graph (port of analyse() from the HTML).
PlanAnalysis analyse(List<PlanTask> plan) {
  final idx = {for (var i = 0; i < plan.length; i++) plan[i].id: i};
  final n = plan.length;
  final lvl = List<int>.filled(n, 0);
  final par = List<int>.filled(n, -1);
  final dist = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    var l = 0, best = 0, p = -1;
    for (final d in plan[i].deps) {
      final j = idx[d];
      if (j == null) continue;
      l = math.max(l, lvl[j] + 1);
      if (dist[j] > best) {
        best = dist[j];
        p = j;
      }
    }
    lvl[i] = l;
    dist[i] = best + plan[i].eff;
    par[i] = p;
  }
  var end = 0;
  for (var i = 0; i < n; i++) {
    if (dist[i] > dist[end]) end = i;
  }
  final crit = <int>{};
  var c = n == 0 ? -1 : end;
  while (c >= 0) {
    crit.add(c);
    c = par[c];
  }
  return PlanAnalysis(idx, lvl, crit, n == 0 ? 0 : dist[end], crit.length);
}

/// Single source of truth for the UI.
///
/// Everything marked `FIREBASE:` is currently in-memory mock logic.
/// Your job is to replace each one with Firestore / Cloud Functions calls.
class AppState extends ChangeNotifier {
  AppState({required this.user}) {
    _listenWallet();
    _listenBoard();
  }

  bool _gone = false;
  void _safeNotify() {
    if (!_gone) notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    _walletSub?.cancel();
    _userSub?.cancel();
    _tasksSub?.cancel();
    _claimsSub?.cancel();
    super.dispose();
  }

  final AppUser user;

  // ---- navigation / board filters ----
  AppView view = AppView.board;
  Kind? filter; // null = all
  SortBy sort = SortBy.ending;

  // ---- profile numbers ----
  // FIREBASE: stream users/{uid} and read coins, rep, completed, selected, skills.
  int coins = 0, rep = 0, completed = 63, selected = 17; // coins and rep come live from Firestore
  final int level = 14;
  final Map<String, int> mySkills = Map.of(mockSkills);
  String selectedNode = 'React';
  bool questDone = false;

  // ---- board ----
  // FIREBASE: stream the `tasks` collection (only status == 'open').
  List<Task> tasks = []; // live from Firestore (status == 'published')
  bool boardLoaded = false;
  Object? boardError;
  final Set<String> claimed = {}, squad = {}, submitted = {};

  // ---- project composer ----
  String brief = sampleBrief;
  int pool = 900, mult = 3, maxB = 5, sprint = 24;
  List<PlanTask> plan = []; // filled by the AI (shredProject)
  int planVersion = 0; // bump to force text fields to rebuild
  bool shredding = false, published = false;
  String scanMsg = 'Reading your brief…';

  // ---- real backend state for the composer ----
  String? draftProjectId; // Firestore project created by shredProject
  List<String> aiDocIds = []; // Firestore task id for each plan row
  List<int> aiCoins = []; // AI price (coins) for each plan row
  int draftCost = 0; // total escrow needed to publish
  List<String> aiIssues = []; // what the AI critic changed
  bool publishing = false;
  String? shredError, publishError;

  // FIREBASE: stream projects where ownerUid == uid.
  final List<Project> projects = [];

  // ================= helpers =================
  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  int filledFor(Task t) => t.claimed + (claimed.contains(t.id) ? 1 : 0);

  List<Task> get visibleTasks {
    final l = tasks.where((t) => filter == null || t.kind == filter).toList();
    int cmp(Task a, Task b) => switch (sort) {
          SortBy.ending => a.endsAt.compareTo(b.endsAt),
          SortBy.bounty => (b.base * b.mult).compareTo(a.base * a.mult),
          SortBy.open => a.claimed.compareTo(b.claimed),
        };
    l.sort((a, b) {
      final f = (b.fresh ? 1 : 0) - (a.fresh ? 1 : 0);
      return f != 0 ? f : cmp(a, b);
    });
    return l;
  }

  int countFor(Kind? k) => k == null ? tasks.length : tasks.where((t) => t.kind == k).length;

  List<Reward> planCalc() {
    // Real prices come from the backend. Winner bonus = coins * (multiplier 2 - 1) = coins.
    if (aiCoins.isNotEmpty && aiCoins.length == plan.length) {
      return [for (final c in aiCoins) Reward(c, c)];
    }
    final sumW = plan.fold<double>(0, (a, t) => a + t.w);
    final w = sumW == 0 ? 1.0 : sumW;
    return plan.map((t) {
      final budget = pool * t.w / w;
      final base = math.max(2, (budget * .08).round());
      return Reward(base, base * mult);
    }).toList();
  }

  String get projName {
    final m = RegExp(r'^\s*([A-Z][\w-]*(?:\s[A-Z][\w-]*)?)').firstMatch(brief)?.group(1);
    return (m != null && m.length < 28) ? m : 'Untitled project';
  }

  // ================= real wallet =================
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _walletSub, _userSub;

  /// Keeps coins and reputation equal to the real Firestore documents at all times.
  /// Every payout, escrow hold, refund and spam penalty done by the backend shows up here.
  void _listenWallet() {
    final db = FirebaseFirestore.instance;
    _walletSub = db.collection('wallets').doc(user.uid).snapshots().listen((d) {
      final b = (d.data()?['balance'] as num?)?.toInt();
      if (b != null) {
        coins = b;
        _safeNotify();
      }
    }, onError: (Object e) => debugPrint('wallet stream failed: $e'));
    _userSub = db.collection('users').doc(user.uid).snapshots().listen((d) {
      final data = d.data();
      final r = (data?['reputation'] as num?)?.toInt();
      if (r != null) rep = r;
      // the backend counts passed Proving Grounds quests in users/{uid}.questsPassed
      final qp = data?['questsPassed'];
      if (qp is num && qp > 0) questDone = true;
      final sp = data?['skillPoints'];
      if (sp is Map) {
        _skillPoints
          ..clear()
          ..addAll({for (final e in sp.entries) e.key.toString(): (e.value as num?)?.toInt() ?? 0});
      }
      _safeNotify();
    }, onError: (Object e) => debugPrint('user stream failed: $e'));
  }

  /// AI skill names -> the UI's task kinds.
  static Kind _kindOf(String skill) => switch (skill) {
        'UI Design' => Kind.design,
        'Frontend' => Kind.frontend,
        'Backend' || 'Database' || 'DevOps' || 'Data/AI' => Kind.backend,
        'Copywriting' => Kind.copy,
        'Testing' => Kind.qa,
        _ => Kind.frontend,
      };

  // ================= navigation =================
  void go(AppView v) {
    view = v;
    notifyListeners();
  }

  void setFilter(Kind? k) {
    filter = k;
    notifyListeners();
  }

  void setSort(SortBy s) {
    sort = s;
    notifyListeners();
  }

  // ================= live board (tasks + my claims from Firestore) =================
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub, _claimsSub;
  List<Map<String, dynamic>> _taskDocs = [], _claimDocs = [];
  final Map<String, Map<String, dynamic>> _localClaim = {}; // claims made in this session, until Firestore confirms them
  final Map<String, String> _claimIdByTask = {};
  final Map<String, String> claimStatus = {}; // taskId -> active | submitted | changes_requested | done | rejected
  final Set<String> ownTasks = {};
  final Map<String, int> _skillPoints = {};

  void _listenBoard() {
    final db = FirebaseFirestore.instance;
    _tasksSub = db.collection('tasks').where('status', isEqualTo: 'published').snapshots().listen((q) {
      _taskDocs = [for (final d in q.docs) {...d.data(), 'id': d.id}];
      boardLoaded = true;
      boardError = null;
      _rebuildTasks();
    }, onError: (Object e) {
      boardError = e;
      boardLoaded = true;
      debugPrint('tasks stream failed: $e');
      _safeNotify();
    });
    // only the claims where I am a member (the backend stores members: [uid, ...])
    _claimsSub = db.collection('claims').where('members', arrayContains: user.uid).snapshots().listen((q) {
      _claimDocs = [for (final d in q.docs) {...d.data(), 'id': d.id}];
      _rebuildTasks();
    }, onError: (Object e) => debugPrint('claims stream failed: $e'));
  }

  static int? _int(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.round();
    }
    return null;
  }

  static String? _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is num) {
      final n = v.toInt();
      return DateTime.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n);
    }
    return null;
  }

  static List<String> _strings(dynamic v) {
    if (v is List) {
      return [
        for (final x in v)
          if (x is Map) (x['message'] ?? x['text'] ?? x['issue'] ?? '').toString() else x.toString()
      ].where((s) => s.trim().isNotEmpty).toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return const [];
  }

  /// Level in a skill = skill points / 20 (same rule as the backend).
  int skillLevel(String skill) => (_skillPoints[skill] ?? 0) ~/ 20;

  void _rebuildTasks() {
    final mine = <String, Map<String, dynamic>>{};
    for (final c in _claimDocs) {
      final tid = c['taskId']?.toString();
      if (tid == null) continue;
      final st = (c['status'] ?? '').toString();
      if (st == 'expired') continue; // an expired claim does not count, same as the backend
      mine[tid] = c;
    }
    _localClaim.removeWhere((tid, _) => mine.containsKey(tid));
    for (final e in _localClaim.entries) {
      mine[e.key] = e.value;
    }
    _claimIdByTask
      ..clear()
      ..addAll({for (final e in mine.entries) e.key: (e.value['id'] ?? '').toString()});
    claimed
      ..clear()
      ..addAll(mine.keys);
    claimStatus
      ..clear()
      ..addAll({for (final e in mine.entries) e.key: (e.value['status'] ?? 'active').toString()});
    for (final e in mine.entries) {
      final st = (e.value['status'] ?? '').toString();
      if (st == 'submitted' || st == 'done' || st == 'rejected') submitted.add(e.key);
      if (e.value['squad'] == true) squad.add(e.key);
    }
    // tasks that were sent back for changes can be submitted again
    submitted.removeWhere((tid) => claimStatus[tid] == 'changes_requested' || claimStatus[tid] == 'active');

    ownTasks
      ..clear()
      ..addAll([for (final m in _taskDocs) if (m['ownerId'] == user.uid) m['id'].toString()]);

    final next = <Task>[];
    for (final m in _taskDocs) {
      final id = m['id'].toString();
      final skill = _str(m, ['skill']);
      final c = mine[id];
      final hours = _int(m, ['sprintHours']) ?? 24;
      // The countdown starts with the first claim and is shared (task.sprintEndsAt). Before that, show a full sprint.
      final ends = (c != null ? _dt(c['deadline'] ?? c['deadlineMs']) : null) ??
          _dt(m['sprintEndsAt']) ??
          DateTime.now().add(Duration(hours: hours));
      final localId = m['localId']?.toString();
      final unblocks = localId == null
          ? 0
          : _taskDocs.where((o) => o['projectId'] == m['projectId'] && o['id'] != m['id'] && (o['depends_on'] is List) && (o['depends_on'] as List).map((x) => x.toString()).contains(localId)).length;
      final created = _dt(m['createdAt']) ?? _dt(m['publishedAt']);
      final count = _int(m, ['claimsCount']) ?? 0;
      next.add(Task(
        id: id,
        project: _str(m, ['projectTitle']) ?? 'Project',
        title: _str(m, ['title']) ?? 'Untitled task',
        desc: _str(m, ['description', 'desc', 'summary']) ?? '',
        kind: _kindOf(skill ?? 'Other'),
        skills: skill == null ? const [] : [SkillReq(skill, _int(m, ['minLevel']) ?? 0)],
        base: _int(m, ['coins']) ?? 0,
        mult: 2,
        claimed: math.max(0, count - (c != null ? 1 : 0)),
        max: 5,
        total: hours * 3600,
        endsAt: ends,
        surge: _int(m, ['surgePercent']) ?? 0,
        unblocks: unblocks,
        squad: true,
        crit: false,
        fresh: created != null && DateTime.now().difference(created).inHours < 6,
      ));
    }
    tasks = next;
    _safeNotify();
  }

  /// Display only. Mirrors PARTICIPATION_PERCENT / MIN_PARTICIPATION in functions/src/pricing.js.
  static int participationMin(int base) => math.max(5, (base * 0.25).round());

  String _msg(Object e, String fallback) => e is BackendException ? e.message : fallback;

  // ================= claiming (real: Cloud Function claimTask) =================
  Future<String> claim(String id) async {
    try {
      final res = await BackendService.instance.claimTask(id);
      _localClaim[id] = {'id': (res['claimId'] ?? '').toString(), 'deadlineMs': res['deadlineMs'], 'status': 'active'};
      _rebuildTasks();
      final t = taskById(id);
      return t == null ? 'Claimed.' : 'Claimed. Timer is running, ${hms(t.remaining)} left.';
    } catch (e) {
      debugPrint('claim failed: $e');
      return _msg(e, 'Could not claim this task. Is the emulator running?');
    }
  }

  /// The backend has no "withdraw" function yet, so this changes nothing.
  String withdraw(String id) => 'Withdrawing is not available yet.';

  // ================= squads (real: createSquad) =================
  Future<String> toggleSquad(String id) async {
    if (squad.contains(id)) return 'Your squad lobby is already open.';
    try {
      final res = await BackendService.instance.createSquad(id);
      squad.add(id);
      _localClaim[id] = {'id': (res['claimId'] ?? '').toString(), 'deadlineMs': res['deadlineMs'], 'status': 'active', 'squad': true};
      _rebuildTasks();
      return 'Squad lobby open. Invite up to 2 teammates.';
    } catch (e) {
      debugPrint('createSquad failed: $e');
      return _msg(e, 'Could not open a squad.');
    }
  }

  // ================= submission + AI check (real: Cloud Function submitWork) =================
  Future<CheckResult> runCheck(String id, String text) async {
    final claimId = _claimIdByTask[id];
    if (claimId == null || claimId.isEmpty) {
      return const CheckResult(passed: false, ruleFail: true, message: 'Claim this task before you submit.');
    }
    try {
      final res = await BackendService.instance.submitWork(claimId, text.trim());
      if (res['ok'] == false) {
        return CheckResult(
          passed: false,
          ruleFail: true,
          message: (res['message'] ?? 'Your submission did not pass the basic checks.').toString(),
        );
      }
      final sid = res['submissionId']?.toString();
      if (res['discarded'] == true) {
        return CheckResult(
          passed: false,
          delta: -((res['penalty'] as num?)?.toInt() ?? 0),
          message: (res['message'] ?? 'This looks like spam, so it was discarded.').toString(),
        );
      }
      // The AI review is saved in aiResults/{submissionId}. Reading it is optional: if it fails we still show the result.
      var score = 0;
      var aiFailed = false;
      var issues = <String>[];
      if (sid != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('aiResults').doc(sid).get();
          final ai = snap.data();
          if (ai != null) {
            aiFailed = ai['error'] != null;
            final judge = ai['judge'];
            if (judge is Map) {
              final s = judge['score'];
              if (s is num) score = (s <= 1 ? s * 100 : s).round();
              issues = _strings(judge['issues'] ?? judge['feedback'] ?? judge['summary']);
            }
          }
        } catch (e) {
          debugPrint('could not read aiResults: $e');
        }
      }
      claimStatus[id] = 'submitted';
      submitted.add(id);
      _safeNotify();
      return CheckResult(
        passed: true,
        score: score,
        base: (res['participation'] as num?)?.toInt() ?? 0,
        message: aiFailed ? 'The AI review could not finish, so the owner will review this by hand.' : (res['message'] ?? '').toString(),
        issues: issues,
      );
    } catch (e) {
      debugPrint('submitWork failed: $e');
      return CheckResult(passed: false, ruleFail: true, message: _msg(e, 'Could not submit. Is the emulator running?'));
    }
  }

  // ================= Proving Grounds quest (real: getQuest / submitQuest) =================
  Map<String, dynamic>? quest;

  /// Display only. Mirrors QUEST_REWARDS in functions/src/pricing.js (the server decides the real reward).
  static const questRewards = {'easy': 10, 'medium': 20, 'hard': 40};

  Future<Map<String, dynamic>> loadQuest({String? skill, String? difficulty}) async {
    final q = await BackendService.instance.getQuest(skill: skill, difficulty: difficulty);
    quest = q;
    return q;
  }

  Future<Map<String, dynamic>> sendQuest(String answer) async {
    final q = quest ?? await loadQuest();
    final res = await BackendService.instance.submitQuest(q['id'].toString(), answer);
    if (res['passed'] == true) {
      questDone = true;
      _safeNotify();
    }
    return res;
  }

  // ================= profile =================
  void selectNode(String name) {
    selectedNode = name;
    notifyListeners();
  }

  // ================= composer =================
  void setBrief(String v) {
    brief = v;
    notifyListeners();
  }

  void useSample() {
    brief = sampleBrief;
    notifyListeners();
  }

  void setPool(int v) {
    pool = v.clamp(0, 5000);
    notifyListeners();
  }

  void setMult(int v) {
    mult = v;
    notifyListeners();
  }

  void setMaxB(int v) {
    maxB = v;
    notifyListeners();
  }

  void setSprint(int v) {
    sprint = v;
    notifyListeners();
  }

  void renameTask(int i, String v) {
    plan[i].title = v;
    notifyListeners();
  }

  /// Sends the brief to the real AI pipeline (Cloud Function shredProject).
  /// Returns the number of tasks, or 0 on failure (see shredError).
  Future<int> shred() async {
    if (shredding) return plan.length;
    shredError = null;
    if (brief.trim().length < 30) {
      shredError = 'Please describe your project in a bit more detail (at least 30 characters).';
      _safeNotify();
      return 0;
    }
    shredding = true;
    published = false;
    scanMsg = 'Reading your brief…';
    notifyListeners();

    // The AI takes a while, so rotate the status text while we wait.
    var waiting = true;
    () async {
      const msgs = [
        'Reading your brief…',
        'Finding the atomic pieces…',
        'Mapping dependencies…',
        'Writing acceptance criteria…',
        'Estimating rewards…',
      ];
      var i = 0;
      while (waiting && !_gone) {
        scanMsg = msgs[i % msgs.length];
        i++;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 4));
      }
    }();

    try {
      final res = await BackendService.instance.shredProject(
        title: projName,
        brief: brief.trim(),
        projectId: draftProjectId,
      );
      final raw = (res['tasks'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final next = <PlanTask>[];
      final ids = <String>[];
      final coinsList = <int>[];
      for (final t in raw) {
        final skill = (t['skill'] ?? 'Other').toString();
        next.add(PlanTask(
          id: (t['localId'] ?? t['id']).toString(),
          title: (t['title'] ?? 'Untitled task').toString(),
          kind: _kindOf(skill),
          skills: [skill],
          eff: (t['estimated_hours'] as num?)?.toInt() ?? 3,
          w: ((t['coins'] as num?) ?? 1).toDouble(),
          deps: [for (final d in (t['depends_on'] as List? ?? const [])) d.toString()],
        ));
        ids.add(t['id'].toString());
        coinsList.add((t['coins'] as num?)?.toInt() ?? 0);
      }
      plan = next;
      aiDocIds = ids;
      aiCoins = coinsList;
      draftProjectId = res['projectId']?.toString();
      draftCost = (res['cost'] as num?)?.toInt() ?? coinsList.fold<int>(0, (a, b) => a + b);
      pool = draftCost;
      aiIssues = [for (final x in (res['issues_found'] as List? ?? const [])) x.toString()];
      planVersion++;
      return plan.length;
    } catch (e) {
      shredError = e is BackendException ? e.message : 'Could not reach the AI. Is the emulator running?';
      debugPrint('shred failed: $e');
      return 0;
    } finally {
      waiting = false;
      shredding = false;
      _safeNotify();
    }
  }

  // Merging is switched off while the AI plan lives on the server (each row is a Firestore task).
  void mergeAt(int i) {}

  void deleteAt(int j) {
    if (j < 0 || j >= plan.length) return;
    final rm = plan[j];
    for (final t in plan) {
      if (t.deps.contains(rm.id)) {
        t.deps = [
          ...t.deps.where((q) => q != rm.id),
          ...rm.deps.where((q) => !t.deps.contains(q)),
        ];
      }
    }
    plan.removeAt(j);
    if (j < aiDocIds.length && j < aiCoins.length) {
      final docId = aiDocIds.removeAt(j);
      aiCoins.removeAt(j);
      draftCost = aiCoins.fold<int>(0, (a, b) => a + b);
      pool = draftCost;
      BackendService.instance.deleteTask(docId).catchError((Object e) {
        debugPrint('deleteTask failed: $e');
        return <String, dynamic>{};
      });
    }
    published = false;
    planVersion++;
    notifyListeners();
  }

  /// Publishes the draft: the server checks your balance and moves the coins
  /// into escrow in one transaction (Cloud Function publishProject).
  /// Returns the number of tasks, or null on failure (see publishError).
  Future<int?> publish() async {
    if (publishing) return null;
    final pid = draftProjectId;
    if (pid == null || plan.isEmpty) {
      publishError = 'Shred a brief first.';
      _safeNotify();
      return null;
    }
    if (draftCost > coins) {
      publishError = 'Not enough crumbs.';
      _safeNotify();
      return null;
    }
    publishing = true;
    publishError = null;
    notifyListeners();
    try {
      final res = await BackendService.instance.publishProject(pid);
      final calc = planCalc();
      final n = plan.length;
      projects.insert(
        0,
        Project(
          id: pid, name: projName, at: DateTime.now(), pool: draftCost, mult: 2, max: 5, sprint: 24,
          tasks: [for (var i = 0; i < n; i++) ProjectTask(aiDocIds[i], plan[i].title, plan[i].kind, calc[i].base)],
        ),
      );
      final after = (res['balanceAfter'] as num?)?.toInt();
      if (after != null) coins = after;
      draftProjectId = null; // a published project cannot be published again
      published = true;
      filter = null;
      sort = SortBy.ending;
      view = AppView.projects;
      return n;
    } catch (e) {
      publishError = e is BackendException ? e.message : 'Could not publish. Is the emulator running?';
      debugPrint('publish failed: $e');
      return null;
    } finally {
      publishing = false;
      _safeNotify();
    }
  }
}
