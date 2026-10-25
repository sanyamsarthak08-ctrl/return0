enum Kind { design, frontend, backend, copy, qa }

extension KindX on Kind {
  String get label => switch (this) {
        Kind.design => 'Design',
        Kind.frontend => 'Frontend',
        Kind.backend => 'Backend',
        Kind.copy => 'Copy',
        Kind.qa => 'QA',
      };
}

class SkillReq {
  final String name;
  final int lv;
  const SkillReq(this.name, this.lv);
}

/// Signed-in user. FIREBASE: map from `User` (uid, displayName, email, photoURL).
class AppUser {
  final String uid, name, email;
  final String? photoUrl;
  const AppUser({required this.uid, required this.name, required this.email, this.photoUrl});

  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
  }

  String get slug => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

class Task {
  final String id, project, title, desc;
  final Kind kind;
  final List<SkillReq> skills;
  final int base, mult, max, total, surge, unblocks; // total = sprint seconds, surge = %
  final bool squad, crit;
  final DateTime endsAt;
  int claimed; // builders (other than you) who claimed
  bool fresh;

  Task({
    required this.id, required this.project, required this.title, required this.desc,
    required this.kind, required this.skills, required this.base, required this.mult,
    required this.claimed, required this.max, required this.total, required this.endsAt,
    this.surge = 0, this.unblocks = 0, this.squad = false, this.crit = false, this.fresh = false,
  });

  int get remaining {
    final s = endsAt.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }
}

/// A task inside the AI-generated plan, before publishing.
class PlanTask {
  final String id;
  String title;
  final Kind kind;
  List<String> skills;
  int eff; // builder-hours
  double w; // reward weight
  List<String> deps;

  PlanTask({
    required this.id, required this.title, required this.kind, required this.skills,
    required this.eff, required this.w, required this.deps,
  });

  PlanTask copy() => PlanTask(
        id: id, title: title, kind: kind, skills: [...skills], eff: eff, w: w, deps: [...deps]);
}

class Reward {
  final int base, bonus;
  const Reward(this.base, this.bonus);
}

class ProjectTask {
  final String id, title;
  final Kind kind;
  final int base;
  const ProjectTask(this.id, this.title, this.kind, this.base);
}

class Project {
  final String id, name;
  final DateTime at;
  final int pool, mult, max, sprint;
  final List<ProjectTask> tasks;
  const Project({
    required this.id, required this.name, required this.at, required this.pool,
    required this.mult, required this.max, required this.sprint, required this.tasks,
  });
}

class SkillNode {
  final String name;
  final int level;
  final double progress; // 0..1 toward next level
  const SkillNode(this.name, this.level, this.progress);
}

class Branch {
  final String name;
  final int colorIdx; // 1..4 -> b1..b4
  final List<SkillNode> nodes;
  const Branch(this.name, this.colorIdx, this.nodes);
}

enum Outcome { selected, approved, rejected }

class HistoryItem {
  final String title, project, delta, when, feedback;
  final Outcome outcome;
  final List<String> xp;
  const HistoryItem({
    required this.title, required this.project, required this.outcome, required this.delta,
    required this.xp, required this.when, required this.feedback,
  });
}

class CheckResult {
  final bool passed;
  final int score, base; // base = crumbs paid right now as the guaranteed minimum
  final int delta; // coin change caused by this check (negative = spam penalty)
  final bool ruleFail; // true when the submission was refused before the AI looked at it
  final String message; // text from the server, shown to the person
  final List<String> issues; // notes from the AI review
  const CheckResult({
    required this.passed, this.score = 0, this.base = 0, this.delta = 0,
    this.ruleFail = false, this.message = '', this.issues = const [],
  });
}
