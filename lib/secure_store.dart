import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Пустая защищённая запись не является сохранённым секретом и должна быть
/// заменена значением из старого локального хранилища при миграции.
bool shouldMigrateSecret(String? secureValue) =>
    secureValue == null || secureValue.isEmpty;

class SecretStore {
  const SecretStore();
  // Data Protection Keychain requires a provisioning profile on macOS.
  // The regular Keychain keeps items encrypted with the local ad-hoc build;
  // Windows uses its native secure-storage implementation.
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
}
