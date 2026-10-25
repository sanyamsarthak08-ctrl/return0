import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.visibleTasks;
    final filters = <(Kind?, String)>[
      (null, 'All'),
      (Kind.frontend, 'Frontend'),
      (Kind.backend, 'Backend'),
      (Kind.design, 'Design'),
      (Kind.copy, 'Copy'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(open: s.tasks.length),
        const SizedBox(height: 40),
        Wrap(
          spacing: 20,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in filters)
                  FilterChipX(
                    f.$2,
                    s.countFor(f.$1),
                    s.filter == f.$1,
                    () => s.setFilter(f.$1),
                  ),
              ],
            ),
            Seg<SortBy>(
              options: const {
                SortBy.ending: 'Tide turns soon',
                SortBy.bounty: 'Richest bounty',
                SortBy.open: 'Fewest pirates',
              },
              value: s.sort,
              onChanged: s.setSort,
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              s.boardError != null
                  ? 'Could not load bounties. Is the emulator running?'
                  : !s.boardLoaded
                  ? 'Scanning the horizon…'
                  : s.tasks.isEmpty
                  ? 'No open bounties yet. Post a voyage and set sail, then come back.'
                  : 'No bounties in this category.',
              style: T.body(15, color: context.cc.ink2),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, cons) {
              final cols = math.max(1, (cons.maxWidth / 330).floor());
              const gap = 24.0;
              final w = (cons.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final t in list)
                    SizedBox(
                      width: w,
                      child: TaskCard(key: ValueKey(t.id), task: t),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Shows the server's answer (success or friendly error) once the call finishes.
void _say(BuildContext context, Future<String> job) {
  job.then((m) {
    if (context.mounted) toast(context, m);
  });
}

// ---------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  final int open;
  const _Hero({required this.open});

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    const steps = [
      ('Claim a bounty', 'Up to 5 pirates chase the same bounty at once.'),
      (
        'Bring back the loot before the timer ends',
        'AI checks it and pays a baseline for honest work.',
      ),
      (
        'The captain picks the top pirate',
        'The winner earns a bonus multiplier and skill XP.',
      ),
    ];
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.ink, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: c.ink.o(.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: Icon(Icons.explore, size: 110, color: c.ink.o(.07)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sailing, size: 18, color: c.accent),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      open == 0
                          ? 'No open bounties yet'
                          : '$open open bount${open == 1 ? 'y' : 'ies'} on the board right now',
                      style: T.mono(12, color: c.ink2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Claim a bounty. Up to four other pirates are hunting it too. ',
                    ),
                    TextSpan(
                      text: 'The best loot takes the bonus.',
                      style: TextStyle(color: c.accent),
                    ),
                  ],
                ),
                style: T.disp(
                  MediaQuery.sizeOf(context).width < 700 ? 28 : 38,
                  h: 1.15,
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, cons) {
                  final row = cons.maxWidth > 640;
                  Widget step(int i) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.coinSoft,
                          border: Border.all(color: c.ink, width: 1.5),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: T.mono(
                            12.5,
                            w: FontWeight.w600,
                            color: c.coinInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(steps[i].$1, style: T.disp(17)),
                            const SizedBox(height: 2),
                            Text(
                              steps[i].$2,
                              style: T.body(14, color: c.ink2, h: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  return row
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 32),
                              Expanded(child: step(i)),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: step(i),
                              ),
                          ],
                        );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- card

class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    final t = task;
    final you = s.claimed.contains(t.id);
    final sub = s.submitted.contains(t.id);
    final status = s.claimStatus[t.id] ?? '';
    final own = s.ownTasks.contains(t.id);
    final filled = s.filledFor(t);
    final full = filled >= t.max && !you;
    final k = c.kind(t.kind);

    Widget acts;
    if (own) {
      acts = Btn('Your own bounty', icon: Icons.person_outline, expand: true);
    } else if (status == 'done') {
      acts = Btn(
        'Mission accomplished',
        icon: Icons.check,
        style: BtnStyle.ok,
        expand: true,
      );
    } else if (status == 'rejected') {
      acts = Btn('Missed the boat', expand: true);
    } else if (sub) {
      acts = Btn(
        'Awaiting the captain',
        icon: Icons.check,
        style: BtnStyle.ok,
        expand: true,
      );
    } else if (you) {
      acts = Btn(
        status == 'changes_requested'
            ? 'Mend the sails'
            : 'Bring back the loot',
        icon: Icons.description_outlined,
        style: BtnStyle.primary,
        expand: true,
        onPressed: () => showSubmitDialog(context, t),
      );
    } else if (full) {
      acts = Btn('Treasure race full', expand: true);
    } else {
      // The server checks the quest and skill level and answers with a friendly reason if you are not allowed yet.
      acts = Row(
        children: [
          Expanded(
            child: Btn(
              'Claim bounty',
              style: BtnStyle.primary,
              onPressed: () => _say(context, s.claim(t.id)),
            ),
          ),
          if (t.squad) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Btn(
                s.squad.contains(t.id) ? 'Crew open' : 'Rally the crew',
                icon: Icons.groups_outlined,
                onPressed: () => _say(context, s.toggleSquad(t.id)),
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line2, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: c.ink.o(.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 5, color: k),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      t.project.toUpperCase(),
                      style: T.body(
                        12,
                        w: FontWeight.w600,
                        color: c.ink3,
                        ls: .7,
                      ),
                    ),
                    Tag(t.kind.label, k),
                    if (t.fresh)
                      Tag('NEW', c.ok)
                    else if (t.surge > 0)
                      Tag('Storm bonus +${t.surge}%', c.accent, icon: Icons.bolt),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(t.title, style: T.disp(20, h: 1.2))),
                    const SizedBox(width: 8),
                    Icon(Icons.sailing, size: 20, color: k.o(.8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.desc, style: T.body(14, color: c.ink2, h: 1.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (final r in t.skills)
                      () {
                        final bad = r.lv > 0 && s.skillLevel(r.name) < r.lv;
                        return SkillChip(
                          r.lv > 0 ? '${r.name} Lv ${r.lv}' : r.name,
                          icon: bad ? Icons.lock_outline : null,
                          color: bad ? c.bad : c.ink3,
                          outlined: bad,
                        );
                      }(),
                    if (t.crit)
                      SkillChip(
                        'Critical path',
                        icon: Icons.local_fire_department_outlined,
                        color: c.accent,
                        outlined: true,
                      ),
                    if (t.unblocks > 0) SkillChip('Unblocks ${t.unblocks}'),
                  ],
                ),
                const SizedBox(height: 14),
                _Pay(base: t.base, mult: t.mult),
                const SizedBox(height: 6),
                Hint(
                  'Passing the cargo check pays at least ${AppState.participationMin(t.base)} crumbs right away.',
                ),
                const SizedBox(height: 14),
                Countdown(endsAt: t.endsAt, total: t.total),
                const SizedBox(height: 14),
                _Claims(task: t, you: you, filled: filled, full: full),
                const SizedBox(height: 16),
                acts,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pay extends StatelessWidget {
  final int base, mult;
  const _Pay({required this.base, required this.mult});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    Widget cell(String label, Widget value, {bool win = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        color: win ? c.coinSoft : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: T.body(
                11,
                w: FontWeight.w600,
                color: (win ? c.coinInk : c.ink).o(.75),
                ls: .6,
              ),
            ),
            const SizedBox(height: 2),
            value,
          ],
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.line2, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell(
                'Full pay',
                Row(
                  children: [
                    const CoinIcon(size: 16),
                    const SizedBox(width: 6),
                    Text('$base', style: T.mono(18)),
                  ],
                ),
              ),
              Container(width: 1.5, color: c.line2),
              cell(
                'Top pirate bonus',
                Row(
                  children: [
                    const CoinIcon(size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '+${base * (mult - 1)}',
                      style: T.mono(18, color: c.coinInk),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'x$mult',
                      style: T.body(12, w: FontWeight.w600, color: c.coinInk),
                    ),
                  ],
                ),
                win: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Claims extends StatelessWidget {
  final Task task;
  final bool you, full;
  final int filled;
  const _Claims({
    required this.task,
    required this.you,
    required this.filled,
    required this.full,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final cols = [c.b1, c.b2, c.b3, c.b4];
    const ini = ['KM', 'RT', 'SJ', 'NP', 'DV'];
    Widget pip(int i) {
      Color bg = c.surface2;
      Widget? child;
      Border border = Border.all(color: c.line2);
      if (i < task.claimed) {
        bg = cols[i % 4];
        border = Border.all(color: c.surface, width: 2);
        child = Text(
          ini[i % 5],
          style: T.body(9.5, w: FontWeight.w700, color: c.onB),
        );
      } else if (i == task.claimed && you) {
        bg = c.accent;
        border = Border.all(color: c.surface, width: 2);
        child = Text(
          'You',
          style: T.body(9, w: FontWeight.w700, color: c.accentInk),
        );
      }
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border,
        ),
        child: child,
      );
    }

    final txt = filled == 0
        ? 'No pirates yet. The storm bonus pays extra.'
        : '$filled of ${task.max} pirates${full ? ' (full)' : ''}';
    return Row(
      children: [
        SizedBox(
          width: (task.max - 1) * 20.0 + 26,
          height: 26,
          child: Stack(
            children: [
              for (var i = 0; i < task.max; i++)
                Positioned(left: i * 20.0, child: pip(i)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            txt,
            style: T.body(13, w: FontWeight.w600, color: c.ink2),
          ),
        ),
      ],
    );
  }
}

/// Live sprint timer. Turns red under one hour.
class Countdown extends StatelessWidget {
  final DateTime endsAt;
  final int total;
  const Countdown({super.key, required this.endsAt, required this.total});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return TickBuilder(
      builder: (context) {
        final rem = math.max(0, endsAt.difference(DateTime.now()).inSeconds);
        final urgent = rem < 3600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hms(rem),
                  style: T.mono(26, color: urgent ? c.bad : c.ink),
                ),
                Text(
                  'left before the tide turns',
                  style: T.body(12, w: FontWeight.w600, color: c.ink3),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Bar(
              total == 0 ? 1 : 1 - rem / total,
              color: urgent ? c.bad : c.ink,
            ),
          ],
        );
      },
    );
  }
}
