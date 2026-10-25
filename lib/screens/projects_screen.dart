
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    if (s.projects.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PanelHead('Nothing published yet',
                sub: 'Post a brief and AI splits it into tasks. Once you publish, the project shows up here with live progress.'),
            const SizedBox(height: 20),
            Btn('Post a project', icon: Icons.add, style: BtnStyle.primary, onPressed: () => s.go(AppView.upload)),
          ]),
        ),
      );
    }
    return Column(children: [
      for (var pi = 0; pi < s.projects.length; pi++)
        Padding(padding: const EdgeInsets.only(bottom: 32), child: _ProjectCard(project: s.projects[pi], initiallyOpen: pi == 0, c: c)),
    ]);
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool initiallyOpen;
  final CC c;
  const _ProjectCard({required this.project, required this.initiallyOpen, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = project;
    var filled = 0;
    for (final t in p.tasks) {
      final k = s.taskById(t.id);
      if (k != null) filled += s.filledFor(k);
    }
    final cap = p.tasks.length * p.max;

    Widget stat(String v, String l) => Padding(
          padding: const EdgeInsets.only(right: 32, top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: T.disp(32, w: FontWeight.w500, h: 1)),
            const SizedBox(height: 4),
            Text(l, style: T.body(13, color: c.ink3)),
          ]),
        );

    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line2))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyOpen,
          tilePadding: const EdgeInsets.only(top: 20),
          childrenPadding: const EdgeInsets.only(top: 16, bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: c.ink2,
          collapsedIconColor: c.ink2,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: T.disp(28)),
            Hint('Published ${ago(p.at)}'),
            Wrap(children: [
              stat('${p.tasks.length}', 'tasks'),
              stat('$filled/$cap', 'builder slots filled'),
              stat(fmt(p.pool), 'crumbs in escrow'),
            ]),
          ]),
          children: [
            Bar(cap == 0 ? 0 : filled / cap, color: c.ink),
            const SizedBox(height: 20),
            for (final t in p.tasks) _ProjectTaskRow(pt: t, project: p),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
              Hint('${p.sprint}h sprints, winner bonus x${p.mult}'),
              Btn('View on the Task Board', small: true, onPressed: () => s.go(AppView.board)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ProjectTaskRow extends StatelessWidget {
  final ProjectTask pt;
  final Project project;
  const _ProjectTaskRow({required this.pt, required this.project});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    final live = s.taskById(pt.id);
    final k = c.kind(pt.kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: k, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(pt.title, style: T.body(14, w: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.coinSoft, borderRadius: BorderRadius.circular(3)),
            child: Text('${pt.base} + ${pt.base * project.mult}', style: T.mono(13, color: c.coinInk)),
          ),
        ]),
        const SizedBox(height: 8),
        TickBuilder(builder: (context) {
          final left = live == null ? 0 : live.remaining;
          final n = live == null ? 0 : s.filledFor(live);
          return Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tag(pt.kind.label, k),
            Text('$n of ${project.max} builders', style: T.body(12.5, color: c.ink3)),
            Text(live == null ? 'Preview data resets on reload' : (left > 0 ? '${hms(left)} left' : 'Sprint ended'),
                style: T.body(12.5, color: c.ink3)),
          ]);
        }),
      ]),
    );
  }
}
