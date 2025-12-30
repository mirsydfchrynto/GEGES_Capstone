import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this in integration tests to initialize Firebase and connect to
/// the local emulator when `FIRESTORE_EMULATOR_HOST` is set in env.
Future<void> initFirebaseForIntegrationTests() async {
  await Firebase.initializeApp();

  // If running against emulator, set emulator host via env var.
  final emulator = const String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: '');
  if (emulator.isNotEmpty) {
    final parts = emulator.split(':');
    final host = parts[0];
    final port = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 8080;
    FirebaseFirestore.instance.useFirestoreEmulator(host, port);
  }
}
