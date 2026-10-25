import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

const _hostOverride = String.fromEnvironment('EMU_HOST');

String get emuHost {
  if (_hostOverride.isNotEmpty) return _hostOverride; // real phone
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo',
      appId: '1:1:web:1',
      messagingSenderId: '1',
      projectId: 'demo-no-project',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator(emuHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emuHost, 8080);
  FirebaseFunctions.instanceFor(region: 'us-central1')
      .useFunctionsEmulator(emuHost, 5001);
}
