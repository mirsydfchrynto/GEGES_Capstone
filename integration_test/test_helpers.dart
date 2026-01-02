import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this in integration tests to initialize Firebase and connect to
/// the local emulator when `FIRESTORE_EMULATOR_HOST` is set in env.
Future<void> initFirebaseForIntegrationTests() async {
  await Firebase.initializeApp();

  // If running against emulator, set emulator host via env var.
  final emulator = const String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: '');
  if (emulator.isNotEmpty) {
    var parts = emulator.split(':');
    var host = parts[0];
    final port = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 8080;

    // Map localhost to 10.0.2.2 for Android emulator
    if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
      host = '10.0.2.2';
    }

    FirebaseFirestore.instance.useFirestoreEmulator(host, port);
  }
}
