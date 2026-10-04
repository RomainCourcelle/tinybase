import 'package:shared_preferences/shared_preferences.dart';

/// Persistance access + refresh tokens (et éventuellement l'user sérialisé).
abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<String?> readUserJson();
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  });
  Future<void> clear();
}

/// Store en mémoire — tests et environnements sans SharedPreferences.
class InMemoryTokenStore implements TokenStore {
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

/// Implémentation Flutter via [SharedPreferences] (localStorage sur Web).
class SharedPreferencesTokenStore implements TokenStore {
  static const _kAccess = 'tinybase_client.access_token';
  static const _kRefresh = 'tinybase_client.refresh_token';
  static const _kUser = 'tinybase_client.user_json';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> readAccessToken() async => (await _ensure()).getString(_kAccess);

  @override
  Future<String?> readRefreshToken() async => (await _ensure()).getString(_kRefresh);

  @override
  Future<String?> readUserJson() async => (await _ensure()).getString(_kUser);

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    final p = await _ensure();
    await p.setString(_kAccess, accessToken);
    await p.setString(_kRefresh, refreshToken);
    await p.setString(_kUser, userJson);
  }

  @override
  Future<void> clear() async {
    final p = await _ensure();
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
    await p.remove(_kUser);
  }
}
