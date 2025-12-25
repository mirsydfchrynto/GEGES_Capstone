// lib/services/session_service.dart
import 'package:flutter/foundation.dart';
import 'secure_storage_interface.dart';

class SessionService {
  static const _kUid = 'session_uid';
  static const _kIdToken = 'session_id_token';
  static const _kLastLogin = 'session_last_login';

  final SecureStorage _storage;
  SessionService([SecureStorage? storage])
    : _storage = storage ?? FlutterSecureStorageAdapter();

  Future<void> saveSession({required String uid, String? idToken}) async {
    await _storage.write(key: _kUid, value: uid);
    if (idToken != null) await _storage.write(key: _kIdToken, value: idToken);
    await _storage.write(
      key: _kLastLogin,
      value: DateTime.now().toIso8601String(),
    );
    if (kDebugMode) debugPrint('Session saved for $uid');
  }

  Future<Map<String, String?>> getSession() async {
    final uid = await _storage.read(key: _kUid);
    final idToken = await _storage.read(key: _kIdToken);
    final last = await _storage.read(key: _kLastLogin);
    return {'uid': uid, 'idToken': idToken, 'lastLogin': last};
  }

  Future<bool> hasSession() async {
    final uid = await _storage.read(key: _kUid);
    return uid != null;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kUid);
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kLastLogin);
  }
}
