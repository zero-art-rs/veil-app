import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AppStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final AppStorage shared = AppStorage();

  clear() {
    _storage.deleteAll();
  }

  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  Future<void> setArray(String key, List<Map<String, dynamic>> values) async {
    final jsonString = jsonEncode(values);
    await _storage.write(key: key, value: jsonString);
  }

  Future<List<Map<String, dynamic>>> getObjectArray(String key) async {
    final jsonString = await _storage.read(key: key);
    if (jsonString == null) return [];

    final raw = jsonDecode(jsonString) as List<dynamic>;

    return raw.cast<Map<String, dynamic>>();
  }

  Future<void> appendToArray(String key, Map<String, dynamic> value) async {
    final list = await getObjectArray(key);
    list.add(value);
    await setArray(key, list);
  }

  Future<void> removeWhere(
    String key,
    bool Function(Map<String, dynamic>) callback,
  ) async {
    final list = await getObjectArray(key);
    list.removeWhere(callback);
    await setArray(key, list);
  }

  Future<void> updateWhere(
    String key,
    bool Function(Map<String, dynamic> elem) callback,
    Map<String, dynamic> newValue,
  ) async {
    final list = await getObjectArray(key);

    for (int i = 0; i < list.length; i++) {
      if (callback(list[i])) {
        list[i] = newValue;
      }
    }
    await setArray(key, list);
  }
}
