import 'package:tinybase_shared/tinybase_shared.dart';

import 'string_utils.dart';

/// Génère un repository HTTP pour la collection — CRUD via `/api/collections/
/// <name>/records`, avec le token utilisateur (`Authorization: Bearer ...`),
/// PAS le jeton admin (ce fichier est destiné à une app cliente, pas à
/// l'admin). Même style que ApiClient (tinybase_admin) : http + jsonDecode +
/// une exception dédiée.
class RepositoryGenerator {
  static String generate(CollectionDefinition collection) {
    final className = toPascalCase(collection.name);
    final repoName = '${className}Repository';
    final collectionName = collection.name;

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (collection "$collectionName").
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/${toSnakeCase(collection.name)}.dart';

class ${repoName}Exception implements Exception {
  final int statusCode;
  final String message;
  ${repoName}Exception(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Accès CRUD à la collection "$collectionName" de TinyBase.
///
/// [baseUrl] est l'URL du serveur TinyBase (ex. https://mon-instance.up.railway.app).
/// [accessToken] fournit le JWT courant (celui obtenu au login) à chaque
/// appel — un callback plutôt qu'une valeur figée, pour toujours utiliser
/// le token le plus à jour (après un refresh par exemple).
class $repoName {
  final String baseUrl;
  final String? Function() accessToken;

  $repoName({required this.baseUrl, required this.accessToken});

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('\$normalizedBase\$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> get _headers {
    final token = accessToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer \$token',
    };
  }

  Future<T> _handle<T>(Future<http.Response> Function() call, T Function(dynamic json) onSuccess) async {
    final http.Response response;
    try {
      response = await call();
    } catch (e) {
      throw ${repoName}Exception(0, 'Connexion au serveur impossible : \$e');
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return onSuccess(decoded);
    }
    final message = (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw ${repoName}Exception(response.statusCode, message);
  }

  Future<({List<$className> items, int totalItems, int page, int perPage})> list({
    int page = 1,
    int perPage = 30,
    String sort = '',
    String filter = '',
  }) {
    return _handle(
      () => http.get(
        _uri('/api/collections/$collectionName/records', {
          'page': page,
          'perPage': perPage,
          if (sort.isNotEmpty) 'sort': sort,
          if (filter.isNotEmpty) 'filter': filter,
        }),
        headers: _headers,
      ),
      (json) => (
        items: (json['items'] as List).map((r) => $className.fromJson(r as Map<String, dynamic>)).toList(),
        totalItems: json['totalItems'] as int,
        page: json['page'] as int,
        perPage: json['perPage'] as int,
      ),
    );
  }

  Future<$className> getOne(String id) {
    return _handle(
      () => http.get(_uri('/api/collections/$collectionName/records/\$id'), headers: _headers),
      (json) => $className.fromJson(json as Map<String, dynamic>),
    );
  }

  /// [data] : les clés attendues sont celles de [$className.toJson] — passe
  /// une map partielle pour ne modifier que certains champs (utile pour
  /// [update]). On prend une Map plutôt qu'un [$className] complet ici
  /// exprès : au moment du create, tu n'as pas encore d'id/created/updated
  /// à donner à un $className.
  Future<$className> create(Map<String, dynamic> data) {
    return _handle(
      () => http.post(
        _uri('/api/collections/$collectionName/records'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      (json) => $className.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<$className> update(String id, Map<String, dynamic> data) {
    return _handle(
      () => http.patch(
        _uri('/api/collections/$collectionName/records/\$id'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      (json) => $className.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> delete(String id) {
    return _handle(
      () => http.delete(_uri('/api/collections/$collectionName/records/\$id'), headers: _headers),
      (_) => null,
    );
  }
}
''';
  }
}
