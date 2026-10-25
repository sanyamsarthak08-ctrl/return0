import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pirate_background.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  const LoginScreen({super.key, required this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _err;

  Future<void> _signIn() async {
    setState(() { _busy = true; _err = null; });
    try {
      await widget.auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _err = 'Sign-in failed. Please try again, matey.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cc;
    return Scaffold(
      body: PirateBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Panel(
                  boxed: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CrumbLogo(size: 42),
                      const SizedBox(width: 12),
                      Text('Crumb', style: T.disp(34)),
                    ]),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.ink, width: 1.5))),
                      child: Text('Take on bounties.\nGet paid in crumbs.', style: T.disp(38, h: 1.1)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Claim bounties, race four other pirates, and grow a Treasure Map made only of verified work.',
                      style: T.body(16, color: c.ink2, h: 1.5),
                    ),
                    const SizedBox(height: 28),
                    Btn(
                      _busy ? 'Hoisting the anchor…' : 'Board with Google',
                      icon: Icons.anchor,
                      style: BtnStyle.primary,
                      expand: true,
                      onPressed: _busy ? null : _signIn,
                    ),
                    if (_err != null) ...[const SizedBox(height: 12), Notice(_err!, good: false)],
                    const SizedBox(height: 16),
                    Text(
                      'New crew members start with a small chest of crumbs.',
                      style: T.body(14, color: c.ink3, h: 1.4),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
