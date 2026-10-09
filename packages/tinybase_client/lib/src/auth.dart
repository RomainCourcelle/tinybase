import 'dart:convert';

import 'client.dart';

/// Supported OAuth providers.
enum OAuthProvider {
  /// Discord browser OAuth.
  discord,

  /// Google native idToken flow.
  google,

  /// Apple native identityToken flow.
  apple,

  /// Microsoft browser OAuth.
  microsoft,
}

/// Authenticated TinyBase user (id, email + custom profile fields).
class TinyBaseUser {
  /// User id.
  final String id;

  /// User email.
  final String email;

  /// Custom profile fields from the `users` collection schema.
  final Map<String, dynamic> fields;

  /// Creates a user.
  const TinyBaseUser({
    required this.id,
    required this.email,
    this.fields = const {},
  });

  /// Parses a user from API JSON (`id`, `email`, plus custom fields).
  factory TinyBaseUser.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    final id = map.remove('id') as String;
    final email = map.remove('email') as String;
    map.remove('password_hash');
    return TinyBaseUser(id: id, email: email, fields: map);
  }

  /// Serializes this user to JSON (includes custom [fields]).
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        ...fields,
      };

  /// Convenience accessor for a custom field.
  dynamic operator [](String key) => fields[key];
}

/// Auth session returned by login/register/OAuth.
class TinyBaseSession {
  /// Authenticated user.
  final TinyBaseUser user;

  /// Short-lived access JWT.
  final String accessToken;

  /// Long-lived refresh JWT.
  final String refreshToken;

  /// Creates a session.
  const TinyBaseSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  /// Parses a session from API JSON.
  factory TinyBaseSession.fromJson(Map<String, dynamic> json) => TinyBaseSession(
        user: TinyBaseUser.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

/// Email/password auth plus OAuth helpers.
class TinyBaseAuth {
  final TinyBaseClient _client;
  TinyBaseUser? _user;
  String? _accessToken;

  /// Creates the auth helper bound to [client].
  TinyBaseAuth(this._client);

  /// Current user, if authenticated.
  TinyBaseUser? get user => _user;

  /// Current access token in memory (may be null before [restore]).
  String? get accessToken => _accessToken;

  /// Whether an access token is currently held in memory.
  bool get isAuthenticated => _accessToken != null;

  Future<bool>? _refreshInFlight;

  /// Restores a session from [TokenStore] (refreshes if needed).
  ///
  /// Network errors do **not** clear the stored session (offline-friendly).
  /// Auth failures (invalid/revoked refresh) still call [logout].
  Future<bool> restore() async {
    final refresh = await _client.tokenStore.readRefreshToken();
    if (refresh == null) return false;

    final access = await _client.tokenStore.readAccessToken();
    final userJson = await _client.tokenStore.readUserJson();
    if (access != null) _accessToken = access;
    if (userJson != null) {
      try {
        _user = TinyBaseUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    try {
      await _refreshWith(refresh);
      return true;
    } on TinyBaseException catch (e) {
      if (e.statusCode == 0) {
        // Offline / timeout : keep local tokens.
        return _accessToken != null;
      }
      await logout();
      return false;
    } catch (_) {
      return _accessToken != null;
    }
  }

  /// Registers a new account and persists the session.
  ///
  /// [fields] are custom `users` collection fields (see admin schema).
  Future<TinyBaseSession> register({
    required String email,
    required String password,
    Map<String, dynamic> fields = const {},
  }) async {
    final json = await _client.requestJson(
      'POST',
      '/api/auth/register',
      body: {'email': email, 'password': password, ...fields},
      auth: false,
    );
    return _persistSession(TinyBaseSession.fromJson(json as Map<String, dynamic>));
  }

  /// Logs in and persists the session.
  Future<TinyBaseSession> login({required String email, required String password}) async {
    final json = await _client.requestJson(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    return _persistSession(TinyBaseSession.fromJson(json as Map<String, dynamic>));
  }

  /// Fetches `/api/auth/me` and updates the in-memory user.
  Future<TinyBaseUser> me() async {
    final json = await _client.requestJson('GET', '/api/auth/me');
    final user = TinyBaseUser.fromJson(json as Map<String, dynamic>);
    _user = user;
    return user;
  }

  /// Updates custom profile fields via `PATCH /api/auth/me`.
  Future<TinyBaseUser> updateMe(Map<String, dynamic> fields) async {
    final json = await _client.requestJson('PATCH', '/api/auth/me', body: fields);
    final user = TinyBaseUser.fromJson(json as Map<String, dynamic>);
    _user = user;
    final refresh = await _client.tokenStore.readRefreshToken();
    if (refresh != null && _accessToken != null) {
      await _client.tokenStore.writeSession(
        accessToken: _accessToken!,
        refreshToken: refresh,
        userJson: jsonEncode(user.toJson()),
      );
    }
    return user;
  }

  /// Clears the in-memory session and [TokenStore], and revokes refresh on server.
  Future<void> logout() async {
    final refresh = await _client.tokenStore.readRefreshToken();
    try {
      if (refresh != null) {
        await _client.requestJson(
          'POST',
          '/api/auth/logout',
          body: {'refreshToken': refresh},
          auth: false,
        );
      }
    } catch (_) {
      // Best effort — always clear local session.
    }
    _user = null;
    _accessToken = null;
    await _client.tokenStore.clear();
  }

  /// Deletes the authenticated account (`DELETE /api/auth/me`) then clears local session.
  ///
  /// The server also removes records owned by this user and their files.
  Future<void> deleteAccount() async {
    await _client.requestJson('DELETE', '/api/auth/me');
    _user = null;
    _accessToken = null;
    await _client.tokenStore.clear();
  }

  /// Requests a password-reset email/token (`POST /api/auth/forgot-password`).
  ///
  /// Always returns `{ok: true}` from the server (no email enumeration).
  /// When the server has `RETURN_PASSWORD_RESET_TOKEN=true`, [resetToken] is set.
  Future<String?> forgotPassword(String email) async {
    final json = await _client.requestJson(
      'POST',
      '/api/auth/forgot-password',
      body: {'email': email},
      auth: false,
    ) as Map<String, dynamic>;
    return json['resetToken'] as String?;
  }

  /// Completes password reset with the token from [forgotPassword] / email link.
  Future<void> resetPassword({required String token, required String password}) async {
    await _client.requestJson(
      'POST',
      '/api/auth/reset-password',
      body: {'token': token, 'password': password},
      auth: false,
    );
  }

  /// Browser authorize URL for Discord or Microsoft (`target` = deep-link scheme).
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

  /// Parses an OAuth browser callback deep-link and persists the session.
  ///
  /// Tokens are preferably in the URI fragment (`#accessToken=…`); query
  /// params remain supported for older redirects.
  Future<TinyBaseSession?> handleOAuthCallback(Uri callbackUri) async {
    final fromFragment = _parseFragmentParams(callbackUri.fragment);
    final access = fromFragment['accessToken'] ?? callbackUri.queryParameters['accessToken'];
    final refresh = fromFragment['refreshToken'] ?? callbackUri.queryParameters['refreshToken'];
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

  /// Exchanges a native Google/Apple idToken for a TinyBase session.
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

  /// Called by [TinyBaseClient.send] on `401`. Returns `false` if refresh fails.
  ///
  /// Concurrent callers share a single in-flight refresh.
  Future<bool> tryRefresh() async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _tryRefreshOnce().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<bool> _tryRefreshOnce() async {
    final refresh = await _client.tokenStore.readRefreshToken();
    if (refresh == null) return false;
    try {
      await _refreshWith(refresh);
      return true;
    } on TinyBaseException catch (e) {
      if (e.statusCode == 0) return false; // network — keep session
      await logout();
      return false;
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
    _accessToken = session.accessToken;
    await _client.tokenStore.writeSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userJson: jsonEncode(session.user.toJson()),
    );
    // Hydrate custom profile fields from /me when available.
    try {
      final full = await me();
      final hydrated = TinyBaseSession(
        user: full,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      await _client.tokenStore.writeSession(
        accessToken: hydrated.accessToken,
        refreshToken: hydrated.refreshToken,
        userJson: jsonEncode(full.toJson()),
      );
      return hydrated;
    } catch (_) {
      _user = session.user;
      return session;
    }
  }

  static Map<String, String> _parseFragmentParams(String fragment) {
    if (fragment.isEmpty) return const {};
    return Uri.splitQueryString(fragment);
  }
}
