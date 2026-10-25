import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/backend_service.dart';
import '../theme.dart';
import '../utils.dart';
import 'common.dart';

class CrumbDialog extends StatelessWidget {
  final String title;
  final String? sub;
  final List<Widget> children;
  final List<Widget> actions;
  const CrumbDialog({super.key, required this.title, this.sub, required this.children, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: c.ink, width: 1.5)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.anchor, size: 22, color: c.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: T.disp(26))),
            ]),
            if (sub != null) ...[const SizedBox(height: 4), Hint(sub!)],
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
            ]),
          ]),
        ),
      ),
    );
  }
}

InputDecoration crumbInput(BuildContext context, {String? hint}) {
  final c = context.cc;
  OutlineInputBorder b(Color col, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: col, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: T.body(14, color: c.ink3),
    filled: true,
    fillColor: c.surface,
    contentPadding: const EdgeInsets.all(14),
    enabledBorder: b(c.line2),
    focusedBorder: b(c.accent, 2),
  );
}

class ResultBox extends StatelessWidget {
  final bool good;
  final String title, body;
  final int? score;
  const ResultBox({super.key, required this.good, required this.title, required this.body, this.score});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: good ? c.okSoft : c.badSoft, borderRadius: BorderRadius.circular(4)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (score != null)
          SizedBox(
            width: 64, height: 64,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(64, 64), painter: RingPainter(frac: score! / 100, track: c.line2, color: c.ok, stroke: 6)),
              Text('$score%', style: T.mono(16)),
            ]),
          )
        else
          Icon(good ? Icons.check : Icons.close, size: 30, color: good ? c.ok : c.bad),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.disp(16)),
            const SizedBox(height: 3),
            Text(body, style: T.body(13.5, color: c.ink2)),
          ]),
        ),
      ]),
    );
  }
}

Widget _scan(BuildContext context, String msg) => Row(children: [
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.cc.accent)),
      const SizedBox(width: 10),
      Text(msg, style: T.body(14, w: FontWeight.w600, color: context.cc.ink2)),
    ]);

// ------------------------------------------------------------ submit work

Future<void> showSubmitDialog(BuildContext context, Task t) =>
    showDialog(context: context, builder: (_) => _SubmitDialog(task: t, state: context.read<AppState>()));

class _SubmitDialog extends StatefulWidget {
  final Task task;
  final AppState state;
  const _SubmitDialog({required this.task, required this.state});
  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  final _ctl = TextEditingController();
  bool _checking = false;
  CheckResult? _res;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _checking = true; _res = null; });
    final r = await widget.state.runCheck(widget.task.id, _ctl.text);
    if (!mounted) return;
    setState(() { _checking = false; _res = r; });
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    final done = r?.passed == true;
    return CrumbDialog(
      title: 'Bring back the loot',
      sub: '${widget.task.title} · ${widget.task.project}',
      children: [
        Text('Paste your solution, a link, or a short write-up', style: T.body(13.5, w: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _ctl, minLines: 6, maxLines: 10, enabled: !done,
          style: T.body(14, h: 1.5),
          decoration: crumbInput(context, hint: 'Describe your approach and include your result…'),
        ),
        const SizedBox(height: 6),
        const Hint('The First Mate checks relevance, effort and originality. Bring back a real attempt.'),
        if (_checking || r != null) const SizedBox(height: 14),
        if (_checking) _scan(context, 'The First Mate is checking your loot…'),
        if (r != null && !r.passed)
          ResultBox(
            good: false,
            title: r.ruleFail ? 'Loot not accepted' : 'Thrown overboard (spam)',
            body: r.message.isNotEmpty ? r.message : 'Share a real attempt: explain your approach or include a link.',
          ),
        if (r != null && r.passed)
          ResultBox(
            good: true,
            score: r.score > 0 ? r.score : null,
            title: r.base > 0 ? 'Cargo check passed · +${r.base} crumbs paid' : 'Sent to the Captain for review',
            body: r.base > 0
                ? 'Your guaranteed minimum is already in your chest. If the Captain accepts it you get the rest, and the Top Pirate earns a bonus.'
                : (r.message.isNotEmpty ? r.message : 'The First Mate was not sure, so the Captain will review it. No penalty.'),
          ),
        if (r != null && r.passed && r.issues.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final i in r.issues.take(4)) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $i', style: T.body(13, color: context.cc.ink2))),
        ],
      ],
      actions: [
        Btn('Close', onPressed: () => Navigator.pop(context)),
        if (done)
          Btn('Aye, done', style: BtnStyle.primary, onPressed: () => Navigator.pop(context))
        else
          Btn('Check my loot', style: BtnStyle.primary, onPressed: _checking ? null : _run),
      ],
    );
  }
}

// ------------------------------------------------------------ daily quest

Future<void> showQuestDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => _QuestDialog(state: context.read<AppState>()));

class _QuestDialog extends StatefulWidget {
  final AppState state;
  const _QuestDialog({required this.state});
  @override
  State<_QuestDialog> createState() => _QuestDialogState();
}

class _QuestDialogState extends State<_QuestDialog> {
  static const _fields = ['Frontend', 'Backend', 'UI Design', 'Database', 'DevOps', 'Data/AI', 'Copywriting', 'Testing'];

  final _ctl = TextEditingController();
  Map<String, dynamic>? _quest, _res;
  String? _error, _skill, _diff; // _diff: null (any), easy, medium or hard
  bool _picked = false, _loading = false, _grading = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _why(Object e) => e is BackendException ? e.message : 'Could not reach the server. Is the emulator running?';

  Future<void> _start(String? skill) async {
    setState(() { _skill = skill; _picked = true; _loading = true; _error = null; _quest = null; _res = null; _ctl.clear(); });
    try {
      final q = await widget.state.loadQuest(skill: skill, difficulty: _diff);
      if (!mounted) return;
      setState(() { _quest = q; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _why(e); _loading = false; });
    }
  }

  Future<void> _grade() async {
    setState(() { _grading = true; _res = null; _error = null; });
    try {
      final r = await widget.state.sendQuest(_ctl.text);
      if (!mounted) return;
      setState(() { _res = r; _grading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _why(e); _grading = false; });
    }
  }

  Widget _chip(String label, bool on, VoidCallback tap, {IconData? icon}) => on
      ? Btn(label, icon: icon, small: true, style: BtnStyle.primary, onPressed: tap)
      : Btn(label, icon: icon, small: true, onPressed: tap);

  void _another() => setState(() { _picked = false; _quest = null; _res = null; _error = null; _ctl.clear(); });

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final q = _quest;
    final r = _res;
    final passed = r?['passed'] == true;
    final feedback = (r?['feedback'] ?? '').toString();
    final reward = r?['reward'] ?? q?['reward'];
    return CrumbDialog(
      title: 'Proving Grounds',
      sub: q == null
          ? 'Trials in many fields. Each pass earns crumbs and pearls.'
          : '${q['skill'] ?? 'Skill'} · ${q['difficulty'] ?? 'trial'} · +${q['reward'] ?? ''} crumbs',
      children: [
        if (!_picked) ...[
          Text('1. Pick the weather (harder pays more)', style: T.body(13.5, w: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Any', _diff == null, () => setState(() => _diff = null)),
            for (final k in const ['easy', 'medium', 'hard'])
              _chip('${k[0].toUpperCase()}${k.substring(1)} · ${AppState.questRewards[k]} crumbs', _diff == k, () => setState(() => _diff = k)),
          ]),
          const SizedBox(height: 18),
          Text('2. Tap a field to start', style: T.body(13.5, w: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn('Surprise me', icon: Icons.shuffle, small: true, style: BtnStyle.primary, onPressed: () => _start(null)),
            for (final f in _fields) Btn(f, small: true, onPressed: () => _start(f)),
          ]),
        ],
        if (_loading) _scan(context, 'Preparing your trial…'),
        if (q != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
            child: SelectableText((q['prompt'] ?? '').toString(), style: T.body(14, h: 1.5)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl, minLines: 5, maxLines: 10, enabled: !passed,
            style: T.mono(13), decoration: crumbInput(context, hint: 'Write your answer here…'),
          ),
        ],
        if (_grading) ...[const SizedBox(height: 14), _scan(context, 'The First Mate is grading your answer…')],
        if (_error != null) ...[const SizedBox(height: 14), ResultBox(good: false, title: 'Something went wrong', body: _error!)],
        if (r != null) ...[
          const SizedBox(height: 14),
          ResultBox(
            good: passed,
            title: passed ? 'Trial cleared' : 'Not quite, matey',
            body: [
              if (feedback.isNotEmpty) feedback,
              if (passed && reward != null) '+$reward crumbs added to your chest.',
            ].join(' '),
          ),
        ],
      ],
      actions: [
        Btn('Close', onPressed: () => Navigator.pop(context)),
        if (passed)
          Btn('Another trial', style: BtnStyle.primary, onPressed: _another)
        else if (q != null)
          Btn('Grade my answer', style: BtnStyle.primary, onPressed: _grading ? null : _grade)
        else if (_picked && !_loading)
          Btn('Pick a field', style: BtnStyle.primary, onPressed: _another),
      ],
    );
  }
}

// ------------------------------------------------------------ export portfolio

Future<void> showExportDialog(BuildContext context) {
  final s = context.read<AppState>();
  return showDialog(context: context, builder: (_) => _ExportDialog(state: s));
}

class _ExportDialog extends StatelessWidget {
  final AppState state;
  const _ExportDialog({required this.state});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final link = 'crumb.app/p/${state.user.slug}';
    final rows = [('React', 8, .8, c.b1), ('UI Design', 7, .7, c.b2), ('REST APIs', 6, .6, c.b4)];
    return CrumbDialog(
      title: "Your ship's log",
      sub: 'Anyone with the link sees your treasure map and verified loot. No self-written resume.',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${state.user.name} · Lv ${state.level}', style: T.disp(16)),
            const SizedBox(height: 10),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 100, child: Text(r.$1, style: T.body(13, w: FontWeight.w600))),
                  Expanded(child: Bar(r.$3, color: r.$4, height: 8)),
                  SizedBox(width: 34, child: Text('${r.$2}', textAlign: TextAlign.right, style: T.mono(13))),
                ]),
              ),
            const Hint('4 verified contributions · 17 selected'),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: link), readOnly: true,
              style: T.mono(13), decoration: crumbInput(context),
            ),
          ),
          const SizedBox(width: 8),
          Btn('Copy', icon: Icons.copy, style: BtnStyle.primary, onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            toast(context, 'Link copied');
          }),
        ]),
      ],
      actions: [Btn('Close', onPressed: () => Navigator.pop(context))],
    );
  }
}
