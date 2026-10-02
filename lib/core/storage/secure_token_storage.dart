import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage so tokens are never floating around
/// as plain in-memory state — this is what makes "stay logged in
/// after closing the app" work.
class SecureTokenStorage {
  final _storage = const FlutterSecureStorage();
  static const _accessKey = 'plannedit_access_token';
  static const _refreshKey = 'plannedit_refresh_token';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<String?> readRaw(String key) => _storage.read(key: key);
  Future<void> writeRaw(String key, String value) =>
      _storage.write(key: key, value: value);
}
