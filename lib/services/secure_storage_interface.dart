// lib/services/secure_storage_interface.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class FlutterSecureStorageAdapter implements SecureStorage {
  final FlutterSecureStorage _s;
  FlutterSecureStorageAdapter([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) async => await _s.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) async => await _s.read(key: key);

  @override
  Future<void> delete({required String key}) async => await _s.delete(key: key);
}
