import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../pirate_words.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/pirate_background.dart';
import '../widgets/quest_card.dart';
import 'board_screen.dart';
import 'profile_screen.dart';
import 'projects_screen.dart';
import 'upload_screen.dart';

class _NavItem {
  final AppView v;
  final String label, short;
  final IconData icon;
  const _NavItem(this.v, this.label, this.short, this.icon);
}

const _nav = [
  _NavItem(AppView.board, Pirate.board, 'Board', Icons.explore_outlined),
  _NavItem(AppView.upload, Pirate.newProject, 'Voyage', Icons.sailing_outlined),
  _NavItem(AppView.projects, 'My Voyages', 'Voyages', Icons.flag_outlined),
  _NavItem(AppView.profile, Pirate.profile, 'Ship', Icons.anchor),
];

const _titles = {
  AppView.board: (Pirate.board, 'Live bounties. Claim one and earn crumbs.'),
  AppView.upload: (
    Pirate.newProject,
    'Paste your plan and the First Mate splits it into bounties.',
  ),
  AppView.projects: (
    'My Voyages',
    'Every voyage you have set sail on, and how it is going.',
  ),
  AppView.profile: (
    'Your Treasure Map',
    'Built only from loot that was checked.',
  ),
};

class Shell extends StatelessWidget {
  final AuthService auth;
  const Shell({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    final wide = MediaQuery.sizeOf(context).width >= 880;

    final content = SingleChildScrollView(
      key: ValueKey(s.view),
      padding: EdgeInsets.fromLTRB(
        wide ? 0 : 16,
        wide ? 40 : 20,
        wide ? 32 : 16,
        48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(view: s.view, wide: wide),
              const SizedBox(height: 40),
              switch (s.view) {
                AppView.board => const BoardScreen(),
                AppView.upload => const UploadScreen(),
                AppView.projects => const ProjectsScreen(),
                AppView.profile => const ProfileScreen(),
              },
            ],
          ),
        ),
      ),
    );

    return PirateBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 264, child: _Side(auth: auth)),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
        bottomNavigationBar: wide
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      for (final n in _nav)
                        Expanded(
                          child: InkWell(
                            onTap: () => s.go(n.v),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: s.view == n.v
                                        ? c.accent
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    n.icon,
                                    size: 22,
                                    color: s.view == n.v ? c.accent : c.ink3,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    n.short,
                                    style: T.body(
                                      12,
                                      w: FontWeight.w600,
                                      color: s.view == n.v ? c.accent : c.ink3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppView view;
  final bool wide;
  const _Header({required this.view, required this.wide});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    final t = _titles[view]!;
    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: c.coinSoft,
            border: Border.all(color: c.line2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const CoinIcon(size: 18),
              const SizedBox(width: 8),
              Text(
                fmt(s.coins),
                style: T.mono(14, w: FontWeight.w600, color: c.coinInk),
              ),
              if (wide) ...[
                const SizedBox(width: 6),
                Text(
                  Pirate.currency.toLowerCase(),
                  style: T.body(12, color: c.coinInk),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: c.ink2),
              const SizedBox(width: 8),
              Text('${s.rep}', style: T.mono(14, w: FontWeight.w600)),
              if (wide) ...[
                const SizedBox(width: 6),
                Text('renown', style: T.body(12, color: c.ink2)),
              ],
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.ink)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!wide)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  const CrumbLogo(size: 28),
                  const SizedBox(width: 8),
                  Text(Pirate.appName, style: T.disp(22)),
                  const Spacer(),
                  chips,
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$1, style: T.disp(wide ? 40 : 32, h: 1.1)),
                    const SizedBox(height: 6),
                    Text(t.$2, style: T.body(14, color: c.ink2)),
                  ],
                ),
              ),
              if (wide) chips,
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final AuthService auth;
  const _Side({required this.auth});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.cc;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CrumbLogo(size: 34),
              const SizedBox(width: 10),
              Text(Pirate.appName, style: T.disp(26)),
            ],
          ),
          const SizedBox(height: 36),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Column(
              children: [
                for (final n in _nav)
                  InkWell(
                    onTap: () => s.go(n.v),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        s.view == n.v ? 14 : 8,
                        14,
                        8,
                        14,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: c.line),
                          left: BorderSide(
                            color: s.view == n.v
                                ? c.accent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            n.icon,
                            size: 20,
                            color: s.view == n.v ? c.ink : c.ink2,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              n.label,
                              style: T.body(
                                14.5,
                                w: s.view == n.v
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: s.view == n.v ? c.ink : c.ink2,
                              ),
                            ),
                          ),
                          if (n.v == AppView.board)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: c.ink,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${s.tasks.length}',
                                style: T.mono(11, color: c.bg),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const QuestCard(),
          const SizedBox(height: 28),
          InkWell(
            onTap: () => s.go(AppView.profile),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Avatar(s.user.initials, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.body(14, w: FontWeight.w600),
                        ),
                        Text(
                          'Lv ${s.level} · ${Pirate.levelName(s.level)}',
                          style: T.body(12, color: c.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: auth.signOut,
            icon: Icon(Icons.logout, size: 16, color: c.ink3),
            label: Text('Leave the ship', style: T.body(13, color: c.ink3)),
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  const Avatar(this.initials, {super.key, this.size = 38});
  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.b3,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        initials,
        style: T.disp(size * .37, w: FontWeight.w700, color: c.onB),
      ),
    );
  }
}
