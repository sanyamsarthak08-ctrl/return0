import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'dialogs.dart';

class QuestCard extends StatelessWidget {
  const QuestCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    final done = context.watch<AppState>().questDone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: done ? c.okSoft : null,
        border: Border.all(color: c.line2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PROVING GROUNDS', style: T.body(11, w: FontWeight.w600, color: c.ink3, ls: .8)),
        const SizedBox(height: 8),
        Text(done ? 'Trial cleared' : 'Pass the entry trial', style: T.disp(16, h: 1.25)),
        const SizedBox(height: 6),
        if (done) ...[
          Text('You can claim bounties now. Every extra trial earns more crumbs.', style: T.body(12.5, color: c.ok)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn('More trials', icon: Icons.map_outlined, small: true, onPressed: () => showQuestDialog(context)),
          ),
        ] else ...[
          const Hint('Pass once to unlock claiming bounties. Easy pays 10, medium 20, hard 40 crumbs.'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn('Start trial', icon: Icons.map_outlined, small: true, style: BtnStyle.primary, onPressed: () => showQuestDialog(context)),
          ),
        ],
      ]),
    );
  }
}
