import 'dart:convert';

import 'client.dart';

enum OAuthProvider { discord, google, apple, microsoft }

class TinyBaseUser {
  final String id;
  final String email;
  const TinyBaseUser({required this.id, required this.email});

  factory TinyBaseUser.fromJson(Map<String, dynamic> json) => TinyBaseUser(
        id: json['id'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'email': email};
}

class TinyBaseSession {
  final TinyBaseUser user;
  final String accessToken;
  final String refreshToken;
  const TinyBaseSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory TinyBaseSession.fromJson(Map<String, dynamic> json) => TinyBaseSession(
        user: TinyBaseUser.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

/// Auth email/password + OAuth (browser Discord/Microsoft, native Google/Apple).
class TinyBaseAuth {
  final TinyBaseClient _client;
  TinyBaseUser? _user;
  String? _accessToken;

  TinyBaseAuth(this._client);

  TinyBaseUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  /// Restaure la session depuis [TokenStore] (refresh si besoin).
  Future<bool> restore() async {
    final refresh = await _client.tokenStore.readRefreshToken();
    if (refresh == null) return false;
    try {
      await _refreshWith(refresh);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<TinyBaseSession> register({required String email, required String password}) async {
    final json = await _client.requestJson(
      'POST',
      '/api/auth/register',
      body: {'email': email, 'password': password},
      auth: false,
    );
    return _persistSession(TinyBaseSession.fromJson(json as Map<String, dynamic>));
  }

  Future<TinyBaseSession> login({required String email, required String password}) async {
    final json = await _client.requestJson(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    return _persistSession(TinyBaseSession.fromJson(json as Map<String, dynamic>));
  }

  Future<TinyBaseUser> me() async {
    final json = await _client.requestJson('GET', '/api/auth/me');
    final user = TinyBaseUser.fromJson(json as Map<String, dynamic>);
    _user = user;
    return user;
  }

  Future<void> logout() async {
    _user = null;
    _accessToken = null;
    await _client.tokenStore.clear();
  }

  /// URL à ouvrir (Custom Tab / navigateur externe) pour Discord ou Microsoft.
  Uri authorizeUrl(OAuthProvider provider, {required String target}) {
    if (provider != OAuthProvider.discord && provider != OAuthProvider.microsoft) {
      throw TinyBaseException(
        0,
        'authorizeUrl est pour discord/microsoft — utilise signInWithIdToken pour google/apple',
      );
    }
    final path = '/api/auth/${provider.name}/authorize';
    return _client.uri(path, {'target': target});
  }

  /// Parse un deep-link de retour OAuth browser ; persiste la session si tokens présents.
  Future<TinyBaseSession?> handleOAuthCallback(Uri callbackUri) async {
    final access = callbackUri.queryParameters['accessToken'];
    final refresh = callbackUri.queryParameters['refreshToken'];
    if (access == null || refresh == null) return null;
    await _client.tokenStore.writeSession(
      accessToken: access,
      refreshToken: refresh,
      userJson: jsonEncode({'id': '', 'email': ''}),
    );
    _accessToken = access;
    final user = await me();
    final session = TinyBaseSession(user: user, accessToken: access, refreshToken: refresh);
    await _client.tokenStore.writeSession(
      accessToken: access,
      refreshToken: refresh,
      userJson: jsonEncode(user.toJson()),
    );
    return session;
  }

  /// Échange un idToken natif (google_sign_in / sign_in_with_apple) contre une session.
  Future<TinyBaseSession> signInWithIdToken(OAuthProvider provider, {required String idToken}) async {
    if (provider != OAuthProvider.google && provider != OAuthProvider.apple) {
      throw TinyBaseException(0, 'signInWithIdToken est pour google/apple uniquement');
    }
    final json = await _client.requestJson(
      'POST',
      '/api/auth/${provider.name}/native',
      body: {'idToken': idToken},
      auth: false,
    );
    return _persistSession(TinyBaseSession.fromJson(json as Map<String, dynamic>));
  }

  /// Appelé par [TinyBaseClient.send] sur 401. Retourne false si impossible.
  Future<bool> tryRefresh() async {
    final refresh = await _client.tokenStore.readRefreshToken();
    if (refresh == null) return false;
    try {
      await _refreshWith(refresh);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> _refreshWith(String refreshToken) async {
    final json = await _client.requestJson(
      'POST',
      '/api/auth/refresh',
      body: {'refreshToken': refreshToken},
      auth: false,
    );
    await _persistSession(TinyBaseSession.fromJson(json as Map<String, dynamic>));
  }

  Future<TinyBaseSession> _persistSession(TinyBaseSession session) async {
    _user = session.user;
    _accessToken = session.accessToken;
    await _client.tokenStore.writeSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userJson: jsonEncode(session.user.toJson()),
    );
    return session;
  }
}
