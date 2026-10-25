import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data_mock.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/quest_card.dart';
import 'shell.dart' show Avatar;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    return LayoutBuilder(builder: (context, cons) {
      final wide = cons.maxWidth >= 800;
      final tree = Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelHead('Skill tree', sub: 'Each ring fills as verified tasks add XP. Select a node for details.'),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _SkillTree(selected: s.selectedNode, onSelect: s.selectNode),
        ),
        const SizedBox(height: 8),
        _NodeInfo(name: s.selectedNode),
      ]));
      final side = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PanelHead('Badges', sub: 'Earned in the Proving Grounds.'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35,
            children: const [
              _Badge(Icons.emoji_events_outlined, 'First Bake', 'First approved task', false),
              _Badge(Icons.check, 'Syntax Surgeon', '10 bugs fixed', false),
              _Badge(Icons.lock_outline, 'Hook Smith', '3 of 5 copy quests', true),
              _Badge(Icons.lock_outline, 'Squad Captain', 'Lead 3 squads', true),
            ],
          ),
        ])),
        const SizedBox(height: 32),
        const QuestCard(),
      ]);

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Hero(),
        const SizedBox(height: 32),
        _Stats(narrow: cons.maxWidth < 600),
        const SizedBox(height: 48),
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 19, child: tree),
                const SizedBox(width: 48),
                Expanded(flex: 10, child: side),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [tree, const SizedBox(height: 48), side]),
        const SizedBox(height: 48),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PanelHead('Verified contributions', sub: 'Open an entry to read the AI feedback you received.'),
          const SizedBox(height: 16),
          // FIREBASE: stream users/{uid}/history
          for (final h in mockHistory) _HistoryTile(item: h),
        ])),
      ]);
    });
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 18, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 96, height: 96,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(96, 96), painter: RingPainter(frac: .78, track: c.line, color: c.accent, stroke: 7)),
            Avatar(s.user.initials, size: 66),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(3)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_fire_department_outlined, size: 13, color: c.bg),
                const SizedBox(width: 6),
                Text('LV ${s.level} · JOURNEYMAN', style: T.mono(12.5, w: FontWeight.w700, color: c.bg)),
              ]),
            ),
            const SizedBox(height: 10),
            Text(s.user.name, style: T.disp(30)),
            Text('Full-stack student builder · 4 branches, 11 skills unlocked', style: T.body(14, color: c.ink2)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('2,340 XP', style: T.body(12.5, w: FontWeight.w600, color: c.ink2)),
              Text('660 to Level ${s.level + 1}', style: T.body(12.5, w: FontWeight.w600, color: c.ink2)),
            ]),
            const SizedBox(height: 5),
            Bar(.78, color: c.accent, height: 7),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Btn('Export portfolio', icon: Icons.ios_share, style: BtnStyle.primary, onPressed: () => showExportDialog(context)),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_user_outlined, size: 14, color: c.ok),
            const SizedBox(width: 6),
            Text('Every entry verified', style: T.body(12, w: FontWeight.w600, color: c.ok)),
          ]),
        ]),
      ]),
    );
  }
}

class _Stats extends StatelessWidget {
  final bool narrow;
  const _Stats({required this.narrow});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    Widget cell(String label, Widget value, String sub) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: T.body(11.5, w: FontWeight.w600, color: c.ink3, ls: .6)),
              const SizedBox(height: 2),
              value,
              Text(sub, style: T.body(12.5, color: c.ink2)),
            ]),
          ),
        );
    Text big(String v) => Text(v, style: T.mono(26, w: FontWeight.w500));
    final cells = [
      cell('Balance', Row(children: [const CoinIcon(size: 22), const SizedBox(width: 8), big(fmt(s.coins))]), 'crumbs earned'),
      cell('Tasks done', big('${s.completed}'), 'approved submissions'),
      cell('Selected', big('${s.selected}'), '${(s.selected / s.completed * 100).round()}% win rate'),
      cell('Reputation', big('${s.rep}'), 'top 6% of builders'),
    ];
    Widget vline() => Container(width: 1, color: c.line);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
      child: narrow
          ? Column(children: [
              IntrinsicHeight(child: Row(children: [cells[0], vline(), cells[1]])),
              Container(height: 1, color: c.line),
              IntrinsicHeight(child: Row(children: [cells[2], vline(), cells[3]])),
            ])
          : IntrinsicHeight(child: Row(children: [cells[0], vline(), cells[1], vline(), cells[2], vline(), cells[3]])),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool locked;
  const _Badge(this.icon, this.title, this.sub, this.locked);
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Opacity(
      opacity: locked ? .65 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: locked ? c.surface : c.coinSoft,
              borderRadius: BorderRadius.circular(4),
              border: locked ? Border.all(color: c.line2) : null,
            ),
            child: Icon(icon, size: 18, color: locked ? c.ink3 : c.coinInk),
          ),
          const Spacer(),
          Text(title, style: T.disp(14, h: 1.2)),
          Text(sub, style: T.body(12, color: c.ink3)),
        ]),
      ),
    );
  }
}

class _NodeInfo extends StatelessWidget {
  final String name;
  const _NodeInfo({required this.name});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    SkillNode? f;
    Branch? b;
    for (final br in mockBranches) {
      for (final n in br.nodes) {
        if (n.name == name) {
          f = n;
          b = br;
        }
      }
    }
    if (f == null || b == null) return const SizedBox.shrink();
    final box = BoxDecoration(color: c.surface2, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4));
    if (f.level == 0) {
      return Container(
        padding: const EdgeInsets.all(16), decoration: box,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$name · locked', style: T.disp(17)),
              const SizedBox(height: 4),
              Text('Finish approved tasks in this branch to unlock it. Gated bounties here pay 80+ crumbs.', style: T.body(13.5, color: c.ink2)),
            ]),
          ),
          const SizedBox(width: 12),
          Tag('Locked', c.bad, icon: Icons.lock_outline),
        ]),
      );
    }
    final need = ((1 - f.progress) * (100 + f.level * 30)).round();
    return Container(
      padding: const EdgeInsets.all(16), decoration: box,
      child: Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name · Level ${f.level}', style: T.disp(17)),
            const SizedBox(height: 4),
            Text('Unlocks bounties up to ${40 + f.level * 15} crumbs. $need XP to Level ${f.level + 1}.', style: T.body(13.5, color: c.ink2)),
          ]),
        ),
        SizedBox(width: 180, child: Bar(f.progress, color: c.branch(b.colorIdx), height: 7)),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  const _HistoryTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final h = item;
    final rej = h.outcome == Outcome.rejected;
    final (label, icon, col, bg) = switch (h.outcome) {
      Outcome.selected => ('Selected', Icons.emoji_events_outlined, c.coinInk, c.coinSoft),
      Outcome.approved => ('Approved', Icons.check, c.ok, c.okSoft),
      Outcome.rejected => ('Rejected as spam', Icons.close, c.bad, c.badSoft),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: c.ink2,
          collapsedIconColor: c.ink2,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.title, style: T.disp(16)),
            Text('${h.project} · ${h.when}', style: T.body(12.5, color: c.ink3)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 13, color: col),
                  const SizedBox(width: 6),
                  Text(label, style: T.body(12.5, w: FontWeight.w600, color: col)),
                ]),
              ),
              for (final x in h.xp) SkillChip(x, outlined: true),
              Text(rej ? h.delta : '${h.delta} crumbs', style: T.mono(13, w: FontWeight.w600, color: rej ? c.bad : c.ink)),
            ]),
          ]),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: c.b3, borderRadius: BorderRadius.circular(3)),
                child: Text('AI', style: T.body(11, w: FontWeight.w600, color: c.onB, ls: .6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Feedback. ', style: T.body(13.5, w: FontWeight.w700, color: c.ink)),
                  TextSpan(text: h.feedback),
                ]), style: T.body(13.5, color: c.ink2, h: 1.5)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- skill tree

class _SkillTree extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _SkillTree({required this.selected, required this.onSelect});

  static const rows = [55.0, 145.0, 235.0, 325.0];
  static const cx = [190.0, 340.0, 490.0, 640.0];

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final level = context.read<AppState>().level;
    return GestureDetector(
      onTapDown: (d) {
        for (var r = 0; r < mockBranches.length; r++) {
          final nodes = mockBranches[r].nodes;
          for (var i = 0; i < nodes.length; i++) {
            if ((d.localPosition - Offset(cx[i], rows[r])).distance <= 34) {
              onSelect(nodes[i].name);
              return;
            }
          }
        }
      },
      child: CustomPaint(size: const Size(830, 385), painter: _TreePainter(c: c, selected: selected, level: level)),
    );
  }
}

class _TreePainter extends CustomPainter {
  final CC c;
  final String selected;
  final int level;
  _TreePainter({required this.c, required this.selected, required this.level});

  void _label(Canvas canvas, String s, Offset center, TextStyle st) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dashedCircle(Canvas canvas, Offset ctr, double r, Paint p) {
    const dash = 4.0, gap = 5.0;
    final path = Path()..addOval(Rect.fromCircle(center: ctr, radius: r));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
        d += dash + gap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const rows = _SkillTree.rows, cx = _SkillTree.cx;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var r = 0; r < mockBranches.length; r++) {
      final b = mockBranches[r];
      final col = c.branch(b.colorIdx);
      final y = rows[r];
      // trunk -> branch
      canvas.drawPath(
        Path()
          ..moveTo(78, 190)
          ..cubicTo(130, 190, 130, y, 164, y),
        stroke..strokeWidth = 3..color = col.o(.85),
      );
      // links between nodes
      for (var i = 1; i < b.nodes.length; i++) {
        final open = b.nodes[i].level > 0;
        final p = stroke..strokeWidth = 3..color = open ? col : c.line2;
        if (open) {
          canvas.drawLine(Offset(cx[i - 1] + 26, y), Offset(cx[i] - 26, y), p);
        } else {
          for (var x = cx[i - 1] + 26; x < cx[i] - 26; x += 9) {
            canvas.drawLine(Offset(x, y), Offset(math.min(x + 2, cx[i] - 26), y), p);
          }
        }
      }
      _label(canvas, b.name, Offset(705 + 30, y), T.body(11, w: FontWeight.w700, color: c.ink3, ls: 1.1));
    }

    // level badge
    canvas.drawCircle(const Offset(52, 190), 26, Paint()..color = c.accent);
    _label(canvas, 'LV', const Offset(52, 181), T.mono(11, w: FontWeight.w600, color: c.accentInk));
    _label(canvas, '$level', const Offset(52, 198), T.mono(17, w: FontWeight.w600, color: c.accentInk));

    // nodes
    for (var r = 0; r < mockBranches.length; r++) {
      final b = mockBranches[r];
      final col = c.branch(b.colorIdx);
      for (var i = 0; i < b.nodes.length; i++) {
        final n = b.nodes[i];
        final ctr = Offset(cx[i], rows[r]);
        final locked = n.level == 0;
        if (selected == n.name) {
          canvas.drawCircle(ctr, 33, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = c.ink);
        }
        canvas.drawCircle(ctr, 26, Paint()..color = c.surface);
        if (locked) {
          _dashedCircle(canvas, ctr, 26, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c.line2);
          final ic = Icons.lock_outline;
          final tp = TextPainter(
            text: TextSpan(text: String.fromCharCode(ic.codePoint), style: TextStyle(fontSize: 18, fontFamily: ic.fontFamily, package: ic.fontPackage, color: c.ink3)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, ctr - Offset(tp.width / 2, tp.height / 2));
        } else {
          canvas.drawCircle(ctr, 26, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = c.line2);
          canvas.drawArc(Rect.fromCircle(center: ctr, radius: 26), -math.pi / 2, 2 * math.pi * n.progress, false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..strokeCap = StrokeCap.round
                ..color = col);
          _label(canvas, '${n.level}', ctr, T.mono(15, w: FontWeight.w600, color: c.ink));
        }
        _label(canvas, n.name, Offset(ctr.dx, ctr.dy + 44), T.body(12, w: FontWeight.w600, color: locked ? c.ink3 : c.ink));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) => old.selected != selected || old.level != level || old.c != c;
}
