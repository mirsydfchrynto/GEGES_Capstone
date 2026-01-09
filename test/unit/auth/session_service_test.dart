import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/session_service.dart';
import 'package:geges_smartbarber/services/secure_storage_interface.dart';

class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _m = {};
  @override
  Future<String?> read({required String key}) async => _m[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      _m[key] = value;
  @override
  Future<void> delete({required String key}) async => _m.remove(key);
}

void main() {
  test('SessionService saves, retrieves and clears session', () async {
    final storage = InMemorySecureStorage();
    final s = SessionService(storage);

    expect(await s.hasSession(), isFalse);

    await s.saveSession(uid: 'u123', idToken: 'token123');
    final session = await s.getSession();
    expect(session['uid'], 'u123');
    expect(session['idToken'], 'token123');
    expect(session['lastLogin'], isNotNull);

    expect(await s.hasSession(), isTrue);

    await s.clearSession();
    expect(await s.hasSession(), isFalse);
    final session2 = await s.getSession();
    expect(session2['uid'], isNull);
  });
}
