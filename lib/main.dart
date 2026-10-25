import 'firebase_init.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'models.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'widgets/welcome_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  runApp(CrumbApp(auth: FirebaseAuthService())); // FIREBASE: FirebaseAuthService()
}

class CrumbApp extends StatelessWidget {
  final AuthService auth;
  const CrumbApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crumb · Pirate Cove',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: StreamBuilder<AppUser?>(
        stream: auth.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE5483A))));
          }
          final user = snap.data;
          if (user == null) return LoginScreen(auth: auth);
          // A fresh AppState per user, so switching accounts never leaks data.
          return ChangeNotifierProvider(
            key: ValueKey(user.uid),
            create: (_) => AppState(user: user),
            child: _WelcomeGate(child: Shell(auth: auth)),
          );
        },
      ),
    );
  }
}

/// Shows the welcome popup once, right after the main screen appears.
class _WelcomeGate extends StatefulWidget {
  final Widget child;
  const _WelcomeGate({required this.child});

  @override
  State<_WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<_WelcomeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showWelcomeDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}