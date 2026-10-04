import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:tinybase_shared/tinybase_shared.dart';

import 'app_settings.dart';

export 'app_settings.dart';

/// Un fichier Dart généré par la route `/codegen` — voir tinybase_codegen
/// côté serveur (même forme que `GeneratedFile.toJson()` là-bas).
class GeneratedFile {
  final String path;
  final String content;
  const GeneratedFile({required this.path, required this.content});

  factory GeneratedFile.fromJson(Map<String, dynamic> json) => GeneratedFile(
        path: json['path'] as String,
        content: json['content'] as String,
      );
}

/// Réglages globaux — modèles dans app_settings.dart.

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Session admin renvoyée par `/api/admin/auth/setup` ou `/login` — voir
/// `AdminSession.toJson()` côté serveur (admin_service.dart).
class AdminSession {
  final String adminId;
  final String email;
  final String accessToken;

  const AdminSession({required this.adminId, required this.email, required this.accessToken});

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>;
    return AdminSession(
      adminId: admin['id'] as String,
      email: admin['email'] as String,
      accessToken: json['accessToken'] as String,
    );
  }
}

/// Client HTTP SANS jeton — uniquement pour `/api/admin/auth/*`, les seules
/// routes admin publiques (voir admin_auth_routes.dart côté serveur) :
/// c'est elles qui délivrent le jeton que [ApiClient] utilisera ensuite.
/// Séparé de [ApiClient] plutôt qu'un jeton optionnel dessus : ça évite un
/// état "ApiClient sans token" ambigu partout ailleurs dans l'app.
class AdminAuthClient {
  final String baseUrl;
  const AdminAuthClient({required this.baseUrl});

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Future<T> _handle<T>(Future<http.Response> Function() call, T Function(dynamic json) onSuccess) async {
    final http.Response response;
    try {
      response = await call();
    } catch (e) {
      throw ApiException(0, 'Connexion au serveur impossible : $e');
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return onSuccess(decoded);
    }
    final message = (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw ApiException(response.statusCode, message);
  }

  /// Dit si un compte admin existe déjà sur cette instance — détermine si
  /// l'écran affiché ensuite est "créer le premier compte admin" ou "se
  /// connecter".
  Future<bool> hasAdmin() {
    return _handle(
      () => http.get(_uri('/api/admin/auth/status')).timeout(const Duration(seconds: 8)),
      (json) => (json as Map)['hasAdmin'] as bool,
    );
  }

  /// Ne réussit qu'une seule fois par instance (tant qu'aucun admin n'existe
  /// encore) — voir AdminService côté serveur.
  Future<AdminSession> setup(String email, String password) {
    return _handle(
      () => http.post(
        _uri('/api/admin/auth/setup'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
      (json) => AdminSession.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminSession> login(String email, String password) {
    return _handle(
      () => http.post(
        _uri('/api/admin/auth/login'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
      (json) => AdminSession.fromJson(json as Map<String, dynamic>),
    );
  }
}

/// Client HTTP vers l'API admin de TinyBase. Toutes les requêtes portent le
/// header `Authorization: Bearer <jwt>` (compte admin email/mot de passe —
/// voir AdminService côté serveur) — c'est ce qui donne accès aussi bien au
/// schéma (`/api/admin/collections`) qu'aux records de TOUTES les
/// collections sans être bridé par leurs règles owner-based (voir le
/// bypass admin ajouté côté serveur dans rules_service.dart). Remplace le
/// jeton statique `X-Admin-Token` de la V1.
class ApiClient {
  final String baseUrl;
  final String accessToken;

  ApiClient({required this.baseUrl, required this.accessToken});

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $accessToken',
      };

  Future<T> _handle<T>(Future<http.Response> Function() call, T Function(dynamic json) onSuccess) async {
    final http.Response response;
    try {
      response = await call();
    } catch (e) {
      throw ApiException(0, 'Connexion au serveur impossible : $e');
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return onSuccess(decoded);
    }
    final message = (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw ApiException(response.statusCode, message);
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(_uri('/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Collections (schéma) ------------------------------------------------

  Future<List<CollectionDefinition>> listCollections() {
    return _handle(
      () => http.get(_uri('/api/admin/collections'), headers: _headers),
      (json) => (json as List).map((c) => CollectionDefinition.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  Future<CollectionDefinition> createCollection({
    required String name,
    required CollectionType type,
    required List<FieldDefinition> fields,
    String? listRule = '',
    String? viewRule = '',
    String? createRule = '',
    String? updateRule = '',
    String? deleteRule = '',
  }) {
    return _handle(
      () => http.post(
        _uri('/api/admin/collections'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'type': type.name,
          'fields': fields.map((f) => f.toJson()).toList(),
          'listRule': listRule,
          'viewRule': viewRule,
          'createRule': createRule,
          'updateRule': updateRule,
          'deleteRule': deleteRule,
        }),
      ),
      (json) => CollectionDefinition.fromJson(json as Map<String, dynamic>),
    );
  }

  /// [renames] mappe ancien nom -> nouveau nom pour les champs renommés
  /// (indispensable pour ne pas perdre les données de la colonne — voir
  /// collections_service.dart côté serveur).
  ///
  /// Les 5 règles sont TOUJOURS envoyées (même `null`, qui veut dire "admin
  /// seulement" côté serveur — voir rules_service.dart) : contrairement à
  /// [newName]/[fields]/[renames], un `String?` ici ne peut pas représenter
  /// à la fois "ne pas toucher" et "mettre à null", donc on ne propose pas
  /// l'option "ne pas toucher" pour ces 5 paramètres — le seul appelant
  /// (CollectionFormScreen) enregistre toujours les 5 règles ensemble.
  Future<CollectionDefinition> updateCollection(
    String currentName, {
    String? newName,
    List<FieldDefinition>? fields,
    Map<String, String>? renames,
    required String? listRule,
    required String? viewRule,
    required String? createRule,
    required String? updateRule,
    required String? deleteRule,
  }) {
    final body = <String, dynamic>{
      'listRule': listRule,
      'viewRule': viewRule,
      'createRule': createRule,
      'updateRule': updateRule,
      'deleteRule': deleteRule,
    };
    if (newName != null) body['name'] = newName;
    if (fields != null) body['fields'] = fields.map((f) => f.toJson()).toList();
    if (renames != null) body['renames'] = renames;

    return _handle(
      () => http.patch(_uri('/api/admin/collections/$currentName'), headers: _headers, body: jsonEncode(body)),
      (json) => CollectionDefinition.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> deleteCollection(String name) {
    return _handle(
      () => http.delete(_uri('/api/admin/collections/$name'), headers: _headers),
      (_) => null,
    );
  }

  /// Génère modèle + repository + couche state Dart pour la collection.
  /// [style] : `provider` (ChangeNotifier) ou `riverpod` (annotations).
  Future<List<GeneratedFile>> codegen(
    String collectionName, {
    String style = 'provider',
  }) {
    return _handle(
      () => http.get(
        _uri('/api/admin/collections/$collectionName/codegen', {'style': style}),
        headers: _headers,
      ),
      (json) => ((json as Map)['files'] as List)
          .map((f) => GeneratedFile.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Génère la couche Auth (voir AuthCodegenService).
  /// [style] : `provider` ou `riverpod`.
  Future<List<GeneratedFile>> authCodegen({String style = 'provider'}) {
    return _handle(
      () => http.get(
        _uri('/api/admin/settings/codegen', {'style': style}),
        headers: _headers,
      ),
      (json) => ((json as Map)['files'] as List)
          .map((f) => GeneratedFile.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  // --- Réglages ---------------------------------------------------------------

  Future<AppSettings> getSettings() {
    return _handle(
      () => http.get(_uri('/api/admin/settings'), headers: _headers),
      (json) => AppSettings.fromJson(json as Map<String, dynamic>),
    );
  }

  /// `null` = ne pas toucher ce champ. Pour [discordClientSecret], une
  /// chaîne vide ou null compte aussi comme "ne pas toucher" (il n'est
  /// jamais réaffiché, donc un champ laissé vide ne peut pas vouloir dire
  /// "efface-le" — voir settings_service.dart côté serveur). Utilise
  /// [disableDiscord] pour effacer explicitement id + secret d'un coup.
  Future<AppSettings> updateSettings({
    bool? registrationsOpen,
    String? discordClientId,
    String? discordClientSecret,
    bool disableDiscord = false,
    String? googleClientId,
    String? googleClientSecret,
    bool disableGoogle = false,
    String? microsoftClientId,
    String? microsoftClientSecret,
    bool disableMicrosoft = false,
    String? appleClientId,
    String? appleTeamId,
    String? appleKeyId,
    String? applePrivateKey,
    bool disableApple = false,
    int? accessTokenTtlHours,
    int? refreshTokenTtlDays,
  }) {
    final body = <String, dynamic>{};
    if (registrationsOpen != null) body['registrationsOpen'] = registrationsOpen;
    if (discordClientId != null) body['discordClientId'] = discordClientId;
    if (discordClientSecret != null) body['discordClientSecret'] = discordClientSecret;
    if (disableDiscord) body['disableDiscord'] = true;
    if (googleClientId != null) body['googleClientId'] = googleClientId;
    if (googleClientSecret != null) body['googleClientSecret'] = googleClientSecret;
    if (disableGoogle) body['disableGoogle'] = true;
    if (microsoftClientId != null) body['microsoftClientId'] = microsoftClientId;
    if (microsoftClientSecret != null) body['microsoftClientSecret'] = microsoftClientSecret;
    if (disableMicrosoft) body['disableMicrosoft'] = true;
    if (appleClientId != null) body['appleClientId'] = appleClientId;
    if (appleTeamId != null) body['appleTeamId'] = appleTeamId;
    if (appleKeyId != null) body['appleKeyId'] = appleKeyId;
    if (applePrivateKey != null) body['applePrivateKey'] = applePrivateKey;
    if (disableApple) body['disableApple'] = true;
    if (accessTokenTtlHours != null) body['accessTokenTtlHours'] = accessTokenTtlHours;
    if (refreshTokenTtlDays != null) body['refreshTokenTtlDays'] = refreshTokenTtlDays;

    return _handle(
      () => http.patch(_uri('/api/admin/settings'), headers: _headers, body: jsonEncode(body)),
      (json) => AppSettings.fromJson(json as Map<String, dynamic>),
    );
  }

  // --- Records ---------------------------------------------------------------

  Future<({List<Map<String, dynamic>> items, int totalItems, int page, int perPage})> listRecords(
    String collectionName, {
    int page = 1,
    int perPage = 50,
    String sort = '',
  }) {
    return _handle(
      () => http.get(
        _uri('/api/collections/$collectionName/records', {
          'page': page,
          'perPage': perPage,
          if (sort.isNotEmpty) 'sort': sort,
        }),
        headers: _headers,
      ),
      (json) => (
        items: (json['items'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList(),
        totalItems: json['totalItems'] as int,
        page: json['page'] as int,
        perPage: json['perPage'] as int,
      ),
    );
  }

  Future<Map<String, dynamic>> createRecord(String collectionName, Map<String, dynamic> data) {
    return _handle(
      () => http.post(
        _uri('/api/collections/$collectionName/records'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<Map<String, dynamic>> updateRecord(String collectionName, String id, Map<String, dynamic> data) {
    return _handle(
      () => http.patch(
        _uri('/api/collections/$collectionName/records/$id'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> deleteRecord(String collectionName, String id) {
    return _handle(
      () => http.delete(_uri('/api/collections/$collectionName/records/$id'), headers: _headers),
      (_) => null,
    );
  }

  /// Active/désactive ("ban") un compte `users` — voir
  /// users_admin_routes.dart côté serveur. Distinct de [updateRecord] :
  /// `users` est une collection auth, create/update y sont bloqués même
  /// pour l'admin (voir records_service.dart).
  Future<void> setUserDisabled(String userId, bool disabled) {
    return _handle(
      () => http.patch(
        _uri('/api/admin/users/$userId/disabled'),
        headers: _headers,
        body: jsonEncode({'disabled': disabled}),
      ),
      (_) => null,
    );
  }
}
