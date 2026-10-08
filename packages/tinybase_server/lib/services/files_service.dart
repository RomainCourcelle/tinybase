import 'dart:io';
import 'dart:typed_data';

import 'package:tinybase_shared/tinybase_shared.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';

const _uuid = Uuid();

/// Fichier uploadé en mémoire (partie multipart déjà lue).
class UploadedFile {
  final String originalName;
  final String? contentType;
  final Uint8List bytes;

  const UploadedFile({
    required this.originalName,
    required this.bytes,
    this.contentType,
  });
}

/// Stockage local des fichiers de champs [FieldType.file].
/// Chemin : `<filesDir>/<collection>/<recordId>/<field>_<uuid>_<safeName>`.
class FilesService {
  final String rootDir;

  FilesService({String? rootDir}) : rootDir = rootDir ?? Config.filesDir;

  Directory _recordDir(String collection, String recordId) {
    return Directory('$rootDir${Platform.pathSeparator}$collection${Platform.pathSeparator}$recordId');
  }

  File resolve(String collection, String recordId, String storedName) {
    // Empêche path traversal : le nom stocké ne doit contenir aucun séparateur.
    if (storedName.contains('/') || storedName.contains('\\') || storedName.contains('..')) {
      throw FormatException('Nom de fichier invalide');
    }
    return File('${_recordDir(collection, recordId).path}${Platform.pathSeparator}$storedName');
  }

  /// Écrit [upload] sur disque et retourne le nom stocké (valeur colonne TEXT).
  /// [fieldDef] applique `max:` / `mime:` ; sinon plafond [Config.maxFileSize].
  Future<String> save({
    required String collection,
    required String recordId,
    required String field,
    required UploadedFile upload,
    FieldDefinition? fieldDef,
  }) async {
    _validateUpload(upload, fieldDef);
    final dir = _recordDir(collection, recordId);
    await dir.create(recursive: true);
    final safe = _safeFileName(upload.originalName);
    final stored = '${field}_${_uuid.v4()}_$safe';
    final file = File('${dir.path}${Platform.pathSeparator}$stored');
    await file.writeAsBytes(upload.bytes, flush: true);
    return stored;
  }

  void _validateUpload(UploadedFile upload, FieldDefinition? fieldDef) {
    final fieldMax = fieldDef?.fileMaxSizeBytes;
    final maxBytes = (fieldMax != null && fieldMax > 0) ? fieldMax : Config.maxFileSize;
    if (upload.bytes.length > maxBytes) {
      throw FormatException('Fichier trop volumineux (max $maxBytes octets)');
    }
    final mimes = fieldDef?.fileMimeAllowlist ?? const [];
    if (mimes.isNotEmpty) {
      final ct = upload.contentType?.split(';').first.trim().toLowerCase();
      final allowed = mimes.map((m) => m.toLowerCase()).toSet();
      if (ct == null || !allowed.contains(ct)) {
        throw FormatException(
          'Type MIME non autorisé${ct != null ? ' ($ct)' : ''}. '
          'Autorisés : ${mimes.join(', ')}',
        );
      }
    }
  }

  Future<void> deleteIfExists(String collection, String recordId, String? storedName) async {
    if (storedName == null || storedName.isEmpty) return;
    final file = resolve(collection, recordId, storedName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Supprime tout le dossier d'un record (à l'appel de delete record).
  Future<void> deleteRecordFiles(String collection, String recordId) async {
    final dir = _recordDir(collection, recordId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static String _safeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final cleaned = base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (cleaned.isEmpty) return 'file';
    return cleaned.length > 80 ? cleaned.substring(cleaned.length - 80) : cleaned;
  }
}
