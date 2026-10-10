import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'client.dart';
import 'file_upload.dart';
import 'realtime.dart';

/// Paginated list of raw JSON records.
class RecordPage {
  /// Records for the current page.
  final List<Map<String, dynamic>> items;

  /// Total number of matching records.
  final int totalItems;

  /// Current 1-based page index.
  final int page;

  /// Page size used for this response.
  final int perPage;

  /// Creates a page result.
  const RecordPage({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.perPage,
  });
}

/// Result of [TinyBaseCollection.downloadFile].
class DownloadedFile {
  /// Raw bytes.
  final List<int> bytes;

  /// Content-Type header when present.
  final String? contentType;

  /// Creates a download result.
  const DownloadedFile({required this.bytes, this.contentType});
}

/// Generic CRUD helper for `/api/collections/<name>/records`.
class TinyBaseCollection {
  /// Parent client (handles auth + refresh).
  final TinyBaseClient client;

  /// Collection name as defined in TinyBase admin.
  final String name;

  /// Creates a collection accessor.
  TinyBaseCollection(this.client, this.name);

  /// Lists records with optional pagination, sort and filter.
  Future<RecordPage> list({
    int page = 1,
    int perPage = 30,
    String sort = '',
    String filter = '',
  }) async {
    final json = await client.requestJson(
      'GET',
      '/api/collections/$name/records',
      query: {
        'page': page,
        'perPage': perPage,
        if (sort.isNotEmpty) 'sort': sort,
        if (filter.isNotEmpty) 'filter': filter,
      },
    ) as Map<String, dynamic>;
    return RecordPage(
      items: (json['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      totalItems: json['totalItems'] as int,
      page: json['page'] as int,
      perPage: json['perPage'] as int,
    );
  }

  /// Fetches a single record by [id].
  Future<Map<String, dynamic>> getOne(String id) async {
    final json = await client.requestJson('GET', '/api/collections/$name/records/$id');
    return Map<String, dynamic>.from(json as Map);
  }

  /// Creates a record from [data]. Pass [files] for `file` fields (multipart).
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, {
    Map<String, FileUpload>? files,
  }) async {
    if (files == null || files.isEmpty) {
      final json = await client.requestJson('POST', '/api/collections/$name/records', body: data);
      return Map<String, dynamic>.from(json as Map);
    }
    final json = await client.requestMultipart(
      'POST',
      '/api/collections/$name/records',
      data: data,
      files: files,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Updates record [id] with [data] (PATCH). Pass [files] for `file` fields.
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> data, {
    Map<String, FileUpload>? files,
  }) async {
    if (files == null || files.isEmpty) {
      final json = await client.requestJson('PATCH', '/api/collections/$name/records/$id', body: data);
      return Map<String, dynamic>.from(json as Map);
    }
    final json = await client.requestMultipart(
      'PATCH',
      '/api/collections/$name/records/$id',
      data: data,
      files: files,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  /// Deletes record [id].
  Future<void> delete(String id) async {
    await client.requestJson('DELETE', '/api/collections/$name/records/$id');
  }

  /// Absolute URL to download a file field value (requires Bearer — prefer [downloadFile]).
  String fileUrl(String recordId, String field) {
    return client.uri('/api/collections/$name/records/$recordId/files/$field').toString();
  }

  /// Downloads a file field with Authorization (and one refresh retry on 401).
  Future<DownloadedFile> downloadFile(String recordId, String field) async {
    Future<http.Response> doGet({bool retried = false}) async {
      final headers = <String, String>{};
      final token = await client.tokenStore.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await client.httpClient
          .get(
            client.uri('/api/collections/$name/records/$recordId/files/$field'),
            headers: headers,
          )
          .timeout(client.requestTimeout);
      if (response.statusCode == 401 && !retried) {
        final refreshed = await client.auth.tryRefresh();
        if (refreshed) return doGet(retried: true);
      }
      return response;
    }

    try {
      final response = await doGet();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TinyBaseException(response.statusCode, response.body);
      }
      return DownloadedFile(
        bytes: response.bodyBytes,
        contentType: response.headers['content-type'],
      );
    } on TimeoutException {
      throw TinyBaseException(0, 'Délai d\'attente dépassé');
    }
  }

  /// Subscribes to realtime SSE changes on this collection.
  ///
  /// Auto-reconnects with backoff on disconnect. Cancel the subscription to stop.
  Stream<RecordChange> subscribe() {
    late StreamController<RecordChange> controller;
    http.StreamedResponse? response;
    StreamSubscription<String>? bytesSub;
    var buffer = '';
    var cancelled = false;
    var attempt = 0;

    Future<void> connect({bool retried = false}) async {
      if (cancelled || controller.isClosed) return;

      final headers = <String, String>{
        'Accept': 'text/event-stream',
      };
      final token = await client.tokenStore.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final request = http.Request('GET', client.uri('/api/collections/$name/realtime'));
      request.headers.addAll(headers);

      try {
        response = await client.httpClient.send(request);
      } catch (e) {
        if (cancelled || controller.isClosed) return;
        attempt++;
        final delay = Duration(milliseconds: (500 * attempt).clamp(500, 15000));
        await Future<void>.delayed(delay);
        if (!cancelled) await connect();
        return;
      }

      if (response!.statusCode == 401 && !retried) {
        final refreshed = await client.auth.tryRefresh();
        if (refreshed) {
          await connect(retried: true);
          return;
        }
      }

      if (response!.statusCode < 200 || response!.statusCode >= 300) {
        final body = await response!.stream.bytesToString();
        if (!controller.isClosed) {
          controller.addError(TinyBaseException(response!.statusCode, body));
          await controller.close();
        }
        return;
      }

      attempt = 0;
      // utf8.decoder reassembles multi-byte chars split across TCP chunks.
      bytesSub = response!.stream.transform(utf8.decoder).listen(
        (chunk) {
          buffer += chunk;
          while (true) {
            final sep = buffer.indexOf('\n\n');
            if (sep < 0) break;
            final block = buffer.substring(0, sep);
            buffer = buffer.substring(sep + 2);
            final change = _parseSseBlock(block);
            if (change != null && !controller.isClosed) {
              controller.add(change);
            }
          }
        },
        onError: (Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
        },
        onDone: () {
          if (cancelled || controller.isClosed) return;
          attempt++;
          final delay = Duration(milliseconds: (500 * attempt).clamp(500, 15000));
          // ignore: discarded_futures
          Future<void>.delayed(delay, () {
            if (!cancelled) connect();
          });
        },
        cancelOnError: false,
      );
    }

    controller = StreamController<RecordChange>(
      onListen: () {
        // ignore: discarded_futures
        connect();
      },
      onCancel: () async {
        cancelled = true;
        await bytesSub?.cancel();
      },
    );

    return controller.stream;
  }

  RecordChange? _parseSseBlock(String block) {
    String? event;
    final dataLines = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (event != null && event != 'record') return null;
    if (dataLines.isEmpty) return null;
    final raw = dataLines.join('\n');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return RecordChange.fromJson(Map<String, dynamic>.from(decoded));
  }
}
