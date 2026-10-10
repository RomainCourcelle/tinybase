import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'auth.dart';
import 'collection.dart';
import 'file_upload.dart';
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

  /// HTTP timeout applied to JSON requests (not SSE streams).
  final Duration requestTimeout;

  final http.Client _http;

  /// Underlying HTTP client (used for streaming / multipart).
  http.Client get httpClient => _http;

  /// Auth API (login, register, OAuth, restore).
  late final TinyBaseAuth auth = TinyBaseAuth(this);

  /// Creates a client for [baseUrl].
  ///
  /// Defaults to [createDefaultTokenStore] (secure on mobile) and a 30s timeout.
  TinyBaseClient({
    required String baseUrl,
    TokenStore? tokenStore,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        tokenStore = tokenStore ?? createDefaultTokenStore(),
        _http = httpClient ?? http.Client();

  /// Returns a CRUD helper for the named collection.
  TinyBaseCollection collection(String name) => TinyBaseCollection(this, name);

  /// Builds an absolute [Uri] for [path] with optional [query] parameters.
  Uri uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Public meta (`GET /api/meta`) — branding, etc.
  Future<Map<String, dynamic>> meta() async {
    final json = await requestJson('GET', '/api/meta', auth: false);
    return Map<String, dynamic>.from(json as Map);
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
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final url = uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response response;
    try {
      final Future<http.Response> future;
      switch (method.toUpperCase()) {
        case 'GET':
          future = _http.get(url, headers: headers);
        case 'POST':
          future = _http.post(url, headers: headers, body: encoded);
        case 'PATCH':
          future = _http.patch(url, headers: headers, body: encoded);
        case 'DELETE':
          future = _http.delete(url, headers: headers);
        default:
          throw TinyBaseException(0, 'Méthode HTTP non supportée : $method');
      }
      response = await future.timeout(requestTimeout);
    } on TimeoutException {
      throw TinyBaseException(0, 'Délai d\'attente dépassé');
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

  /// Multipart create/update with a JSON `data` field + named file parts.
  Future<dynamic> requestMultipart(
    String method,
    String path, {
    required Map<String, dynamic> data,
    required Map<String, FileUpload> files,
    bool auth = true,
    bool retried = false,
  }) async {
    final request = http.MultipartRequest(method.toUpperCase(), uri(path));
    if (auth) {
      final token = await tokenStore.readAccessToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    request.fields['data'] = jsonEncode(data);
    for (final entry in files.entries) {
      request.files.add(
        http.MultipartFile.fromBytes(
          entry.key,
          entry.value.bytes,
          filename: entry.value.filename,
          contentType: entry.value.contentType == null
              ? null
              : MediaType.parse(entry.value.contentType!),
        ),
      );
    }

    late http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(requestTimeout);
    } on TimeoutException {
      throw TinyBaseException(0, 'Délai d\'attente dépassé');
    } catch (e) {
      if (e is TinyBaseException) rethrow;
      throw TinyBaseException(0, 'Connexion au serveur impossible : $e');
    }

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && auth && !retried) {
      final refreshed = await this.auth.tryRefresh();
      if (refreshed) {
        return requestMultipart(method, path, data: data, files: files, auth: auth, retried: true);
      }
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message =
        (decoded is Map && decoded['error'] != null) ? decoded['error'].toString() : response.body;
    throw TinyBaseException(response.statusCode, message);
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
