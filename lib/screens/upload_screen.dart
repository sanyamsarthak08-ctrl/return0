import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final over = s.draftCost > s.coins;
    return LayoutBuilder(builder: (context, cons) {
      final wide = cons.maxWidth >= 900;
      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        _BriefPanel(),
        SizedBox(height: 48),
        _RewardsPanel(),
      ]);
      const plan = _PlanPanel();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: left),
                const SizedBox(width: 48),
                const Expanded(flex: 7, child: plan),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 48), plan]),
        const SizedBox(height: 48),
        // ---- launch bar
        Panel(
          boxed: true,
          child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, spacing: 12, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ready to set sail?', style: T.disp(20)),
              const Hint('Setting sail holds the total price in escrow. Unspent crumbs come back to your chest.'),
            ]),
            s.published
                ? Btn('View on the Bounty Board', onPressed: () => s.go(AppView.board))
                : Btn('Set Sail with ${s.plan.length} bounties', icon: Icons.sailing, style: BtnStyle.primary,
                    onPressed: (over || s.plan.isEmpty || s.shredding || s.publishing)
                        ? null
                        : () async {
                            final n = await s.publish();
                            if (!context.mounted) return;
                            toast(context, n != null ? '$n bounties are on the board' : (s.publishError ?? 'Could not set sail'));
                          }),
          ]),
        ),
      ]);
    });
  }
}

// ---------------------------------------------------------------- brief

class _BriefPanel extends StatefulWidget {
  const _BriefPanel();
  @override
  State<_BriefPanel> createState() => _BriefPanelState();
}

class _BriefPanelState extends State<_BriefPanel> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: context.read<AppState>().brief);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }
Future<void> _attach() async {
    final s = context.read<AppState>();
    
    // Updated syntax: pickFile() directly on FilePicker, no 'platform' or 'withData' needed
    final file = await FilePicker.pickFile(
      type: FileType.custom, 
      allowedExtensions: ['txt', 'md'],
    );
    
    if (file == null) return;
    
    // In the new version, bytes are read directly from the file object
    final bytes = await file.readAsBytes();
    
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.length > 6000) text = text.substring(0, 6000);
    _ctl.text = text;
    s.setBrief(text);
    if (mounted) toast(context, 'Brief loaded from the scroll');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelHead('Chart your voyage', sub: 'Write it, paste a brief, or attach a text file.'),
        const SizedBox(height: 22),
        Text('Voyage brief', style: T.body(14.5, w: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _ctl, minLines: 9, maxLines: 14, style: T.body(15, h: 1.5),
          decoration: crumbInput(context, hint: 'Describe what you want built, Captain…'),
          onChanged: s.setBrief,
        ),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
          Hint('${s.brief.length} characters'),
          Wrap(spacing: 8, children: [
            Btn('Use sample brief', small: true, onPressed: () { s.useSample(); _ctl.text = s.brief; }),
            Btn('Attach file', icon: Icons.description_outlined, small: true, onPressed: _attach),
          ]),
        ]),
        const SizedBox(height: 20),
        Btn('Shred into bounties', icon: Icons.content_cut, style: BtnStyle.primary, expand: true,
            onPressed: s.shredding ? null : () async {
              final n = await s.shred();
              if (!context.mounted) return;
              toast(context, s.shredError ?? 'Brief shredded into $n bounties');
            }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- rewards

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    final bases = s.planCalc().map((e) => e.base).toList();
    final over = s.draftCost - s.coins;
    Widget cell(String l, String v, {bool border = true}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: border ? c.line : Colors.transparent))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.toUpperCase(), style: T.body(12, w: FontWeight.w600, color: c.ink3, ls: .6)),
              Text(v, style: T.mono(16, w: FontWeight.w600)),
            ]),
          ),
        );

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelHead('Loot and rules', sub: 'The First Mate prices every bounty by difficulty and hours.'),
        const SizedBox(height: 22),
        Hint('Your chest holds ${fmt(s.coins)} crumbs'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(border: Border.all(color: c.line)),
          child: Row(children: [
            cell('Baseline', bases.isEmpty ? '0' : '${bases.reduce(math.min)}–${bases.reduce(math.max)}', border: false),
            cell('Top Pirate bonus', 'x2'),
            cell('Escrow', fmt(s.draftCost)),
          ]),
        ),
        const SizedBox(height: 10),
        if (s.plan.isEmpty)
          const Hint('Shred your brief to see the price of the voyage.')
        else if (over > 0)
          Notice('You need ${fmt(over)} more crumbs to fund this. Earn them on the Bounty Board, then come back, Captain.', good: false)
        else
          Notice('${fmt(s.draftCost)} crumbs will be held in escrow. Unspent crumbs return to your chest.', good: true),
      ]),
    );
  }
}

// ---------------------------------------------------------------- plan

class _PlanPanel extends StatelessWidget {
  const _PlanPanel();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;

    if (s.shredding) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent)),
            const SizedBox(width: 10),
            Text(s.scanMsg, style: T.body(14, w: FontWeight.w600, color: c.ink2)),
          ]),
          const SizedBox(height: 16),
          for (var i = 0; i < 5; i++)
            Container(margin: const EdgeInsets.only(bottom: 10), height: 44, decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(4))),
        ]),
      );
    }

    final a = analyse(s.plan);
    final calc = s.planCalc();
    final depth = a.lvl.isEmpty ? 0 : a.lvl.reduce(math.max) + 1;

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("First Mate's plan", style: T.disp(26)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill('${s.plan.length} bounties', hot: true),
          Pill('$depth decks deep'),
          Pill('Critical path: ${a.steps} steps, ${a.total} crew-hours'),
        ]),
        const SizedBox(height: 18),
        if (s.plan.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Hint('No bounties left. Hit "Shred into bounties" to start again.'))
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.all(8),
            child: PlanGraph(plan: s.plan, analysis: a),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 22, height: 3, color: c.accent), const SizedBox(width: 6), Text('Critical path', style: T.body(13.5, w: FontWeight.w600, color: c.ink2))]),
          Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 22, height: 2, color: c.line2), const SizedBox(width: 6), Text('Crew can work at the same time', style: T.body(13.5, w: FontWeight.w600, color: c.ink2))]),
        ]),
        const SizedBox(height: 28),
        Text('Edit before you set sail', style: T.disp(20)),
        const SizedBox(height: 4),
        const Hint('Remove bounties you do not need. Rewards show baseline plus Top Pirate bonus in crumbs.'),
        const SizedBox(height: 14),
        for (var i = 0; i < s.plan.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TaskRow(index: i, task: s.plan[i], reward: calc[i], analysis: a, isLast: i == s.plan.length - 1),
          ),
      ]),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final int index;
  final PlanTask task;
  final Reward reward;
  final PlanAnalysis analysis;
  final bool isLast;
  const _TaskRow({required this.index, required this.task, required this.reward, required this.analysis, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final c = context.cc;
    final k = c.kind(task.kind);
    final deps = [
      for (final d in task.deps)
        if (analysis.idx[d] != null) s.plan[analysis.idx[d]!].title,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: k, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: ValueKey('${task.id}-${s.planVersion}'),
              initialValue: task.title,
              style: T.body(15, w: FontWeight.w600),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 6)),
              onChanged: (v) => s.renameTask(index, v),
            ),
          ),
          IconBtn(Icons.call_merge, 'Merge (coming soon)', onPressed: null),
          const SizedBox(width: 4),
          IconBtn(Icons.delete_outline, 'Remove bounty', onPressed: () { s.deleteAt(index); toast(context, 'Bounty removed'); }),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Tag(task.kind.label, k),
          for (final sk in task.skills) SkillChip(sk, outlined: true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.coinSoft, borderRadius: BorderRadius.circular(3)),
            child: Text('${reward.base} + ${reward.bonus}', style: T.mono(13, color: c.coinInk)),
          ),
          Text(deps.isEmpty ? 'ready to sail now' : 'after ${deps.join(', ')}', style: T.body(13.5, color: c.ink3)),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- dependency graph

class PlanGraph extends StatelessWidget {
  final List<PlanTask> plan;
  final PlanAnalysis analysis;
  const PlanGraph({super.key, required this.plan, required this.analysis});

  static const nw = 176.0, nh = 50.0, cw = 222.0, rh = 68.0;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final cols = a.lvl.reduce(math.max) + 1;
    final per = <int, int>{};
    final rowOf = <int>[];
    for (var i = 0; i < plan.length; i++) {
      per[a.lvl[i]] = (per[a.lvl[i]] ?? 0) + 1;
      rowOf.add(per[a.lvl[i]]! - 1);
    }
    final maxR = per.values.reduce(math.max);
    final w = cols * cw - (cw - nw) + 24;
    final h = maxR * rh + 20;
    final pos = [
      for (var i = 0; i < plan.length; i++)
        Offset(12 + a.lvl[i] * cw, 10 + (maxR - per[a.lvl[i]]!) / 2 * rh + rowOf[i] * rh),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: CustomPaint(
        size: Size(w, h),
        painter: _GraphPainter(plan: plan, a: a, pos: pos, c: context.cc),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<PlanTask> plan;
  final PlanAnalysis a;
  final List<Offset> pos;
  final CC c;
  _GraphPainter({required this.plan, required this.a, required this.pos, required this.c});

  void _text(Canvas canvas, String s, Offset o, TextStyle st, double maxW) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
      ..layout(maxWidth: maxW);
    tp.paint(canvas, o);
  }

  void _edge(Canvas canvas, Offset from, Offset to, bool crit) {
    final col = crit ? c.accent : c.line2;
    final p = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx + 42, from.dy, to.dx - 42, to.dy, to.dx - 6, to.dy);
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = crit ? 3 : 1.8
      ..color = col);
    final arrow = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - 8, to.dy - 4.5)
      ..lineTo(to.dx - 8, to.dy + 4.5)
      ..close();
    canvas.drawPath(arrow, Paint()..color = col);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const nw = PlanGraph.nw, nh = PlanGraph.nh;
    // normal edges first, critical on top
    for (final pass in [false, true]) {
      for (var i = 0; i < plan.length; i++) {
        for (final d in plan[i].deps) {
          final j = a.idx[d];
          if (j == null) continue;
          final crit = a.crit.contains(i) && a.crit.contains(j);
          if (crit != pass) continue;
          _edge(canvas, Offset(pos[j].dx + nw, pos[j].dy + nh / 2), Offset(pos[i].dx, pos[i].dy + nh / 2), crit);
        }
      }
    }
    for (var i = 0; i < plan.length; i++) {
      final t = plan[i], p = pos[i], crit = a.crit.contains(i);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(p.dx, p.dy, nw, nh), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = c.surface);
      canvas.drawRRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = crit ? 2 : 1.5
        ..color = crit ? c.accent : c.line2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 10, p.dy + 11, 4, nh - 22), const Radius.circular(2)),
        Paint()..color = c.kind(t.kind),
      );
      _text(canvas, t.title, Offset(p.dx + 24, p.dy + 9), T.body(13, w: FontWeight.w600, color: c.ink), nw - 32);
      _text(canvas, '${t.kind.label} · ${t.eff}h${crit ? ' · critical' : ''}', Offset(p.dx + 24, p.dy + 28), T.body(12, w: FontWeight.w500, color: c.ink3), nw - 32);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}
