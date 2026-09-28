import 'codegen_service.dart';

/// Génère le code d'authentification côté client — pour une app qui
/// consomme TinyBase SANS passer par `nexus_code_launcher` (qui le fait
/// déjà pendant le scaffolding). Contrairement à [CodegenService]
/// (spécifique à une collection), ce générateur est statique : la
/// collection `users` a toujours la même forme côté API (voir
/// auth_routes.dart/discord_auth_routes.dart côté serveur), donc pas besoin
/// de [CollectionDefinition] en entrée.
///
/// Dépendances attendues côté app cliente (à ajouter au pubspec si absentes) :
/// `http`, `shared_preferences`, `provider`.
class AuthCodegenService {
  /// [includeDiscord] : si `false` (Discord désactivé/non configuré, voir
  /// AppSettings.discordEnabled), les méthodes liées au login Discord ne
  /// sont PAS générées — sinon le code généré appellerait des routes
  /// (`/api/auth/discord/*`) qui répondent systématiquement 400 côté
  /// serveur (voir discord_auth_routes.dart), ce qui n'a aucun sens à
  /// exposer dans le code client. Voir settings_routes.dart pour l'appel
  /// (lit `settingsService.get().discordEnabled`).
  static List<GeneratedFile> generate({bool includeDiscord = true}) {
    return [
      const GeneratedFile(path: 'lib/models/app_user.dart', content: _userModel),
      GeneratedFile(path: 'lib/repositories/auth_repository.dart', content: _authRepository(includeDiscord)),
      GeneratedFile(path: 'lib/providers/auth_provider.dart', content: _authProvider(includeDiscord)),
    ];
  }

  static const _userModel = '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (bouton "Générer le code auth" dans Réglages).

/// L'utilisateur courant — tel que renvoyé par /api/auth/register, /login,
/// /refresh (dans `session.user`) et /me. Si tu as ajouté des champs
/// personnalisés à la collection "users", ils n'apparaissent PAS ici : ce
/// modèle ne reflète que ce que ces routes renvoient réellement (id + email).
class AppUser {
  final String id;
  final String email;
  const AppUser({required this.id, required this.email});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
      );
}
''';

  static String _authRepository(bool includeDiscord) => '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (bouton "Générer le code auth" dans Réglages).
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';

class AuthApiException implements Exception {
  final int statusCode;
  final String message;
  AuthApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Une session obtenue après register/login/refresh — voir auth_service.dart
/// côté serveur (`AuthSession.toJson()`).
class AuthSession {
  final AppUser user;
  final String accessToken;
  final String refreshToken;
  const AuthSession({required this.user, required this.accessToken, required this.refreshToken});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

/// Accès aux routes /api/auth/* de TinyBase (email/mot de passe${includeDiscord ? ' + Discord' : ''}).
///
/// [baseUrl] est l'URL du serveur TinyBase (ex. https://mon-instance.up.railway.app).
class AuthRepository {
  final String baseUrl;
  const AuthRepository({required this.baseUrl});

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('\$normalizedBase\$path');
  }

  Future<AuthSession> register({required String email, required String password}) =>
      _postSession('/api/auth/register', {'email': email, 'password': password});

  Future<AuthSession> login({required String email, required String password}) =>
      _postSession('/api/auth/login', {'email': email, 'password': password});

  Future<AuthSession> refresh(String refreshToken) =>
      _postSession('/api/auth/refresh', {'refreshToken': refreshToken});

  /// Récupère l'utilisateur courant à partir d'un access token${includeDiscord ? ' — utile après\n  /// un login Discord (le callback ne renvoie que les tokens, pas l\'email,\n  /// voir [parseDiscordCallback])' : ''}.
  Future<AppUser> me(String accessToken) async {
    final http.Response response;
    try {
      response = await http.get(_uri('/api/auth/me'), headers: {'Authorization': 'Bearer \$accessToken'});
    } catch (e) {
      throw AuthApiException(0, 'Connexion au serveur impossible : \$e');
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AppUser.fromJson(decoded as Map<String, dynamic>);
    }
    final message = (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw AuthApiException(response.statusCode, message);
  }
${includeDiscord ? '''
  /// URL à ouvrir pour démarrer le login Discord — voir
  /// discord_auth_routes.dart côté serveur. [target] est le deep link de
  /// retour de TON app (ex. \`monapp://auth-callback\`), qui recevra
  /// \`accessToken\`/\`refreshToken\` en query params une fois le flow terminé
  /// (voir [parseDiscordCallback]).
  ///
  /// IMPORTANT : ouvre cette URL dans un navigateur EXTERNE (`url_launcher`
  /// avec `LaunchMode.externalApplication`, ou `flutter_web_auth_2`), jamais
  /// une WebView — Discord bloque l'OAuth dans les WebView embarquées. Sur
  /// Android, il faut aussi déclarer un intent-filter pour ce deep link dans
  /// AndroidManifest.xml et l'écouter côté Dart (package `app_links`).
  Uri discordAuthorizeUrl(String target) =>
      _uri('/api/auth/discord/authorize').replace(queryParameters: {'target': target});

  /// À appeler avec l'URI reçue par ton listener de deep link. Renvoie les
  /// tokens si cette URI est bien un retour de login Discord (sinon `null`,
  /// donc pas la peine de vérifier l'URI toi-même avant d'appeler ça).
  ({String accessToken, String refreshToken})? parseDiscordCallback(Uri callbackUri) {
    final access = callbackUri.queryParameters['accessToken'];
    final refresh = callbackUri.queryParameters['refreshToken'];
    if (access == null || refresh == null) return null;
    return (accessToken: access, refreshToken: refresh);
  }
''' : ''}
  Future<AuthSession> _postSession(String path, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await http.post(
        _uri(path),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(body),
      );
    } catch (e) {
      throw AuthApiException(0, 'Connexion au serveur impossible : \$e');
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AuthSession.fromJson(decoded as Map<String, dynamic>);
    }
    final message = (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw AuthApiException(response.statusCode, message);
  }
}
''';

  static String _authProvider(bool includeDiscord) => '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (bouton "Générer le code auth" dans Réglages).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

/// Session utilisateur de l'app — login/register email+mot de passe${includeDiscord ? ' et\n/// connexion Discord' : ''},
/// persistée entre lancements (access + refresh token
/// dans [SharedPreferences]). Au démarrage, appelle [tryRestoreSession]
/// avant d'afficher l'app (voir ConnectionProvider dans tinybase_admin pour
/// le même pattern).
class AuthProvider extends ChangeNotifier {
  static const _kAccessTokenKey = 'tinybase_auth_access_token';
  static const _kRefreshTokenKey = 'tinybase_auth_refresh_token';

  final AuthRepository repository;
  AuthProvider(this.repository);

  AppUser? _user;
  String? _accessToken;
  bool _isRestoring = true;
  String? _errorMessage;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;
  bool get isRestoring => _isRestoring;
  String? get errorMessage => _errorMessage;

  Future<void> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_kRefreshTokenKey);
    if (refreshToken == null) {
      _isRestoring = false;
      notifyListeners();
      return;
    }
    try {
      final session = await repository.refresh(refreshToken);
      await _persistSession(session, prefs: prefs);
    } catch (_) {
      await _clear(prefs: prefs);
    }
    _isRestoring = false;
    notifyListeners();
  }

  Future<bool> register({required String email, required String password}) =>
      _runAuth(() => repository.register(email: email, password: password));

  Future<bool> login({required String email, required String password}) =>
      _runAuth(() => repository.login(email: email, password: password));
${includeDiscord ? '''
  /// URL à ouvrir dans un navigateur externe pour démarrer le login Discord
  /// — voir la doc de [AuthRepository.discordAuthorizeUrl].
  Uri discordAuthorizeUrl(String target) => repository.discordAuthorizeUrl(target);

  /// À appeler depuis ton listener de deep link avec l'URI reçue. Termine le
  /// login Discord si c'est bien un retour de ce flow (renvoie `true`),
  /// sinon ne fait rien (`false`) — l'URI peut alors être traitée par un
  /// autre handler de deep link de ton app.
  Future<bool> handleDiscordCallback(Uri callbackUri) async {
    final tokens = repository.parseDiscordCallback(callbackUri);
    if (tokens == null) return false;
    _errorMessage = null;
    try {
      final user = await repository.me(tokens.accessToken);
      final prefs = await SharedPreferences.getInstance();
      _user = user;
      _accessToken = tokens.accessToken;
      await prefs.setString(_kAccessTokenKey, tokens.accessToken);
      await prefs.setString(_kRefreshTokenKey, tokens.refreshToken);
    } on AuthApiException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
    return true;
  }
''' : ''}
  Future<void> logout() async {
    await _clear();
    notifyListeners();
  }

  Future<bool> _runAuth(Future<AuthSession> Function() call) async {
    _errorMessage = null;
    try {
      final session = await call();
      await _persistSession(session);
      notifyListeners();
      return true;
    } on AuthApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> _persistSession(AuthSession session, {SharedPreferences? prefs}) async {
    _user = session.user;
    _accessToken = session.accessToken;
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_kAccessTokenKey, session.accessToken);
    await p.setString(_kRefreshTokenKey, session.refreshToken);
  }

  Future<void> _clear({SharedPreferences? prefs}) async {
    _user = null;
    _accessToken = null;
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_kAccessTokenKey);
    await p.remove(_kRefreshTokenKey);
  }
}
''';
}
