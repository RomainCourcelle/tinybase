import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth.dart';
import 'collection.dart';
import 'token_store.dart';

/// Error returned by the TinyBase API or the client itself.
class TinyBaseException implements Exception {
  /// HTTP status code (`0` for client-side / network errors).
  final int statusCode;

  /// Human-readable error message.
  final String message;

  /// Creates an API or client error.
  TinyBaseException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Entry point of the TinyBase Flutter/Dart SDK.
class TinyBaseClient {
  /// API base URL without trailing slash.
  final String baseUrl;

  /// Persistence layer for JWT tokens.
  final TokenStore tokenStore;

  final http.Client _http;

  /// Auth API (login, register, OAuth, restore).
  late final TinyBaseAuth auth = TinyBaseAuth(this);

  /// Creates a client for [baseUrl].
  ///
  /// Defaults to [SharedPreferencesTokenStore] and a new [http.Client].
  TinyBaseClient({
    required String baseUrl,
    TokenStore? tokenStore,
    http.Client? httpClient,
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        tokenStore = tokenStore ?? SharedPreferencesTokenStore(),
        _http = httpClient ?? http.Client();

  /// Returns a CRUD helper for the named collection.
  TinyBaseCollection collection(String name) => TinyBaseCollection(this, name);

  /// Builds an absolute [Uri] for [path] with optional [query] parameters.
  Uri uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Sends an HTTP request with Bearer token and one refresh retry on `401`.
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

  /// Decodes JSON and throws [TinyBaseException] when status >= 400.
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
