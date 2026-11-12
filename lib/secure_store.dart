import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Пустая защищённая запись не является сохранённым секретом и должна быть
/// заменена значением из старого локального хранилища при миграции.
bool shouldMigrateSecret(String? secureValue) =>
    secureValue == null || secureValue.isEmpty;

/// Все секреты хранятся одним элементом Keychain.
///
/// Раньше каждый ключ был отдельным элементом, поэтому macOS запрашивал
/// пароль для каждого из них после пересборки приложения. Один контейнер
/// уменьшает число запросов до одного, а при стабильной подписи — до нуля
/// после первого «Всегда разрешать».
class SecretStore {
  const SecretStore();
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );
  static const _containerKey = 'crm_secrets_v1';
  static final Map<String, String> _cache = <String, String>{};
  static bool _loaded = false;
  static Future<void> _writeQueue = Future<void>.value();

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _containerKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value != null) _cache[key.toString()] = value.toString();
          });
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _flush() {
    final snapshot = jsonEncode(_cache);
    _writeQueue = _writeQueue.then(
      (_) => _storage.write(key: _containerKey, value: snapshot),
    );
    return _writeQueue;
  }

  Future<String?> read(String key) async {
    await _ensureLoaded();
    if (_cache.containsKey(key)) return _cache[key];
    // Однократное чтение старых отдельных элементов для миграции.
    try {
      final legacy = await _storage.read(key: key);
      if (legacy != null) {
        _cache[key] = legacy;
        await _flush();
      }
      return legacy;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    await _ensureLoaded();
    _cache[key] = value;
    await _flush();
  }

  Future<void> delete(String key) async {
    await _ensureLoaded();
    _cache.remove(key);
    await _flush();
  }
}
