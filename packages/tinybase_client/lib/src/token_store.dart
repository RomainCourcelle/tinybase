import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance of access/refresh tokens (and optional serialized user JSON).
abstract class TokenStore {
  /// Returns the stored access token, or `null` if none.
  Future<String?> readAccessToken();

  /// Returns the stored refresh token, or `null` if none.
  Future<String?> readRefreshToken();

  /// Returns the stored user JSON payload, or `null` if none.
  Future<String?> readUserJson();

  /// Persists a full session (access, refresh, user JSON).
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  });

  /// Clears all stored session data.
  Future<void> clear();
}

/// In-memory [TokenStore] for tests and non-Flutter environments.
class InMemoryTokenStore implements TokenStore {
  /// Creates an empty in-memory store.
  InMemoryTokenStore();

  String? _access;
  String? _refresh;
  String? _user;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<String?> readUserJson() async => _user;

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    _user = userJson;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _user = null;
  }
}

/// Flutter [TokenStore] backed by [SharedPreferences] (localStorage on web).
///
/// Prefer [SecureTokenStore] on Android/iOS (Keystore / Keychain).
class SharedPreferencesTokenStore implements TokenStore {
  /// Creates a SharedPreferences-backed store.
  SharedPreferencesTokenStore();

  static const kAccess = 'tinybase_client.access_token';
  static const kRefresh = 'tinybase_client.refresh_token';
  static const kUser = 'tinybase_client.user_json';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> readAccessToken() async => (await _ensure()).getString(kAccess);

  @override
  Future<String?> readRefreshToken() async => (await _ensure()).getString(kRefresh);

  @override
  Future<String?> readUserJson() async => (await _ensure()).getString(kUser);

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    final p = await _ensure();
    await p.setString(kAccess, accessToken);
    await p.setString(kRefresh, refreshToken);
    await p.setString(kUser, userJson);
  }

  @override
  Future<void> clear() async {
    final p = await _ensure();
    await p.remove(kAccess);
    await p.remove(kRefresh);
    await p.remove(kUser);
  }
}

/// [TokenStore] using platform secure storage (Android Keystore / iOS Keychain).
///
/// On first use, migrates a legacy [SharedPreferencesTokenStore] session (0.3.x)
/// into secure storage and clears the plaintext prefs keys.
class SecureTokenStore implements TokenStore {
  /// Creates a secure store.
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = SharedPreferencesTokenStore.kAccess;
  static const _kRefresh = SharedPreferencesTokenStore.kRefresh;
  static const _kUser = SharedPreferencesTokenStore.kUser;

  final FlutterSecureStorage _storage;
  Future<void>? _migrateFuture;

  Future<void> _ensureMigrated() {
    return _migrateFuture ??= _migrateFromPrefs();
  }

  Future<void> _migrateFromPrefs() async {
    final existing = await _storage.read(key: _kRefresh);
    final prefs = await SharedPreferences.getInstance();
    final legacyRefresh = prefs.getString(_kRefresh);
    final legacyAccess = prefs.getString(_kAccess);
    final legacyUser = prefs.getString(_kUser);

    if ((existing == null || existing.isEmpty) &&
        legacyRefresh != null &&
        legacyRefresh.isNotEmpty) {
      await _storage.write(key: _kAccess, value: legacyAccess ?? '');
      await _storage.write(key: _kRefresh, value: legacyRefresh);
      await _storage.write(key: _kUser, value: legacyUser ?? '');
    }

    // Always wipe legacy plaintext keys once we've checked.
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
  }

  @override
  Future<String?> readAccessToken() async {
    await _ensureMigrated();
    return _storage.read(key: _kAccess);
  }

  @override
  Future<String?> readRefreshToken() async {
    await _ensureMigrated();
    return _storage.read(key: _kRefresh);
  }

  @override
  Future<String?> readUserJson() async {
    await _ensureMigrated();
    return _storage.read(key: _kUser);
  }

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    await _ensureMigrated();
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kUser, value: userJson);
  }

  @override
  Future<void> clear() async {
    await _ensureMigrated();
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}

/// Default store: [SecureTokenStore] on mobile, [SharedPreferencesTokenStore] on web.
TokenStore createDefaultTokenStore() {
  if (kIsWeb) return SharedPreferencesTokenStore();
  return SecureTokenStore();
}
