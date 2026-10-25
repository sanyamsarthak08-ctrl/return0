import 'package:flutter/material.dart';

import '../pirate_words.dart';
import '../theme.dart';
import 'common.dart';

Future<void> showWelcomeDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const WelcomeDialog(),
  );
}

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  static const _howItWorks = [
    [
      'Start with Training Bounties',
      'New here? The app gives you a few quick practice bounties, like fixing a small bug or writing a short marketing hook. The First Mate (AI) grades them instantly. Passing earns your first crumbs and medals, and unlocks real bounties from Captains. They exist so every pirate starts with proven skills and a balance to build on.'
    ],
    [
      'Plan a voyage',
      'Post a project. The First Mate (AI) splits it into small bounties and sets the crumb reward for each one.'
    ],
    [
      'Claim and deliver',
      'Pick bounties, bring back your loot before the timer ends, and earn crumbs.'
    ],
    [
      'Review',
      'The First Mate (AI) scores each submission first, then the Captain approves it and picks the Top Pirate.'
    ],
    [
      'Spend',
      'Use your earned crumbs to post your own voyages and get them built.'
    ],
  ];

  static const _terms = [
    [
      'Ownership and loss of IP',
      'All work you submit belongs entirely to the Captain (the project owner) from the moment you submit it. You permanently give up all intellectual property rights, including copyright and the right to reuse, resell, or republish it, whether or not your submission is selected, approved, or paid.'
    ],
    [
      'Rewards',
      'Bounty rewards are set by AI based on the bounty\u2019s size and difficulty, and may change over time. Rewards are final once a voyage is set sail.'
    ],
    [
      'First Mate check (AI)',
      'Every submission is checked by AI for spam and quality. If it passes, you earn 25% of the bounty reward (minimum 5 crumbs).'
    ],
    [
      'Approved by the Captain',
      'When the Captain approves your work, you receive the full bounty reward.'
    ],
    [
      'Top Pirate',
      'The Captain\u2019s selected winner earns a bonus equal to the bounty reward, on top of the reward.'
    ],
    [
      'Spam penalty',
      'If the AI is 85% or more confident that your submission is spam, it is rejected and you lose 10 crumbs.'
    ],
    [
      'Crumbs',
      'Crumbs are in-app points only. They have no cash value and can\u2019t be exchanged for money.'
    ],
  ];

  Widget _list(BuildContext context, List<List<String>> items) {
    final c = context.cc;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (_, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.coinSoft,
              border: Border.all(color: c.ink, width: 1.5),
            ),
            child: Text(
              '${i + 1}',
              style: T.mono(13, w: FontWeight.w600, color: c.coinInk),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[i][0], style: T.disp(19)),
                const SizedBox(height: 3),
                Text(
                  items[i][1],
                  style: T.body(14, color: c.ink2, h: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.ink, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 640),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
                child: Row(
                  children: [
                    const CrumbLogo(size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ahoy, welcome aboard!', style: T.disp(27)),
                          Text(
                            Pirate.tagline,
                            style: T.body(13, color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: c.ink),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TabBar(
                labelColor: c.ink,
                unselectedLabelColor: c.ink3,
                indicatorColor: c.accent,
                indicatorWeight: 3,
                dividerColor: c.line2,
                labelStyle: T.disp(18, w: FontWeight.w400),
                unselectedLabelStyle: T.disp(18, w: FontWeight.w400),
                tabs: const [
                  Tab(text: 'How it works'),
                  Tab(text: 'Terms & Conditions'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _list(context, _howItWorks),
                    _list(context, _terms),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line2)),
                ),
                child: Btn(
                  "Aye, let's sail!",
                  icon: Icons.sailing,
                  style: BtnStyle.primary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
