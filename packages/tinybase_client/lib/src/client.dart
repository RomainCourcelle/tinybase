import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth.dart';
import 'collection.dart';
import 'token_store.dart';

class TinyBaseException implements Exception {
  final int statusCode;
  final String message;
  TinyBaseException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Point d'entrée du SDK TinyBase.
class TinyBaseClient {
  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _http;

  late final TinyBaseAuth auth = TinyBaseAuth(this);

  TinyBaseClient({
    required String baseUrl,
    TokenStore? tokenStore,
    http.Client? httpClient,
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        tokenStore = tokenStore ?? SharedPreferencesTokenStore(),
        _http = httpClient ?? http.Client();

  TinyBaseCollection collection(String name) => TinyBaseCollection(this, name);

  Uri uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Requête HTTP avec Bearer + retry une fois après refresh si 401.
  Future<http.Response> send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (auth) {
      final token = await tokenStore.readAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final url = uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _http.get(url, headers: headers);
        case 'POST':
          response = await _http.post(url, headers: headers, body: encoded);
        case 'PATCH':
          response = await _http.patch(url, headers: headers, body: encoded);
        case 'DELETE':
          response = await _http.delete(url, headers: headers);
        default:
          throw TinyBaseException(0, 'Méthode HTTP non supportée : $method');
      }
    } catch (e) {
      if (e is TinyBaseException) rethrow;
      throw TinyBaseException(0, 'Connexion au serveur impossible : $e');
    }

    if (response.statusCode == 401 && auth && !retried) {
      final refreshed = await this.auth.tryRefresh();
      if (refreshed) {
        return send(method, path, query: query, body: body, auth: auth, retried: true);
      }
    }

    return response;
  }

  /// Décode JSON et lève [TinyBaseException] si status >= 400.
  Future<dynamic> requestJson(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
  }) async {
    final response = await send(method, path, query: query, body: body, auth: auth);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message =
        (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw TinyBaseException(response.statusCode, message);
  }
}
