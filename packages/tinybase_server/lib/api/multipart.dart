import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

import '../core/config.dart';
import '../services/files_service.dart';

/// Corps de requête records : soit JSON pur, soit multipart (data + fichiers).
class RecordRequestBody {
  final Map<String, dynamic> data;
  final Map<String, UploadedFile> files;

  const RecordRequestBody({required this.data, this.files = const {}});
}

/// Parse le body d'une requête create/update records.
Future<RecordRequestBody> readRecordBody(Request request) async {
  final contentType = request.headers['content-type'] ?? '';
  if (contentType.toLowerCase().contains('multipart/form-data')) {
    return _readMultipart(request, contentType);
  }
  final body = await request.readAsString();
  if (body.isEmpty) return const RecordRequestBody(data: {});
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Le corps de la requête doit être un objet JSON');
  }
  return RecordRequestBody(data: decoded);
}

Future<RecordRequestBody> _readMultipart(Request request, String contentType) async {
  final mediaType = MediaType.parse(contentType);
  final boundary = mediaType.parameters['boundary'];
  if (boundary == null || boundary.isEmpty) {
    throw const FormatException('Boundary multipart manquant');
  }

  final maxBody = Config.maxMultipartBodySize;
  final transformer = MimeMultipartTransformer(boundary);
  // MimeMultipartTransformer : bind le body plutôt que Stream.transform.
  final parts = transformer.bind(request.read());

  final data = <String, dynamic>{};
  final files = <String, UploadedFile>{};
  var totalBytes = 0;

  await for (final part in parts) {
    final disposition = part.headers['content-disposition'];
    if (disposition == null) continue;
    final name = _headerParam(disposition, 'name');
    if (name == null) continue;
    final filename = _headerParam(disposition, 'filename');

    final builder = BytesBuilder(copy: false);
    await for (final chunk in part) {
      totalBytes += chunk.length;
      if (totalBytes > maxBody) {
        throw FormatException(
          'Corps multipart trop volumineux (max $maxBody octets)',
        );
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();

    if (filename != null) {
      files[name] = UploadedFile(
        originalName: filename,
        bytes: Uint8List.fromList(bytes),
        contentType: part.headers['content-type'],
      );
      continue;
    }

    final text = utf8.decode(bytes);
    if (name == 'data') {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Le champ "data" doit être un objet JSON');
      }
      data.addAll(decoded);
    } else {
      data[name] = text;
    }
  }

  return RecordRequestBody(data: data, files: files);
}

String? _headerParam(String header, String key) {
  final re = RegExp('$key="([^"]*)"', caseSensitive: false);
  final m = re.firstMatch(header);
  if (m != null) return m.group(1);
  final re2 = RegExp('$key=([^;\\s]+)', caseSensitive: false);
  final m2 = re2.firstMatch(header);
  return m2?.group(1);
}
