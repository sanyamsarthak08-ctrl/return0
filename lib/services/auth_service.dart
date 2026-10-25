import 'dart:async';

import '../models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'backend_service.dart';
/// UI only talks to this interface, so swapping mock -> Firebase touches one file.
abstract class AuthService {
  /// Emits the current user (or null) immediately, then on every change.
  Stream<AppUser?> authStateChanges();
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

/// Fake login so the UI runs before Firebase exists.
class MockAuthService implements AuthService {
  final _c = StreamController<AppUser?>.broadcast();
  AppUser? _u;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _u;
    yield* _c.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 700));
    _u = const AppUser(uid: 'demo-uid', name: 'Aarav Sharma', email: 'aarav@gmail.com');
    _c.add(_u);
  }

  @override
  Future<void> signOut() async {
    _u = null;
    _c.add(null);
  }
}
/// Real Firebase Auth. Works against the Auth emulator while you test.
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppUser? _map(User? u) {
    if (u == null) return null;
    final fallback = u.isAnonymous
        ? 'Guest builder'
        : (u.email?.split('@').first ?? 'Builder');
    return AppUser(
      uid: u.uid,
      name: (u.displayName?.isNotEmpty ?? false) ? u.displayName! : fallback,
      email: u.email ?? '',
      photoUrl: u.photoURL,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _auth.signInAnonymously();
      }
    } catch (e) {
      debugPrint('Google sign-in failed ($e). Falling back to guest.');
      await _auth.signInAnonymously();
    }
    try {
      await BackendService.instance.initUser(); // creates the wallet doc
    } catch (e) {
      debugPrint('initUser failed: $e');
    }
  }
  

  @override
  Future<void> signOut() => _auth.signOut();
}
// FIREBASE: replace MockAuthService with something like this
// (google_sign_in 6.x API; v7 uses GoogleSignIn.instance.authenticate()).
//
// class FirebaseAuthService implements AuthService {
//   final _auth = FirebaseAuth.instance;
//
//   AppUser? _map(User? u) => u == null
//       ? null
//       : AppUser(uid: u.uid, name: u.displayName ?? 'Builder',
//                 email: u.email ?? '', photoUrl: u.photoURL);
//
//   @override
//   Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);
//
//   @override
//   Future<void> signInWithGoogle() async {
//     final g = await GoogleSignIn().signIn();
//     if (g == null) return; // cancelled
//     final a = await g.authentication;
//     final cred = GoogleAuthProvider.credential(
//         accessToken: a.accessToken, idToken: a.idToken);
//     await _auth.signInWithCredential(cred);
//     // First login? create users/{uid} with starting coins
//     // (best done in a Cloud Function triggered on user create).
//   }
//
//   @override
//   Future<void> signOut() async {
//     await GoogleSignIn().signOut();
//     await _auth.signOut();
//   }
// }
