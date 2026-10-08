import 'dart:typed_data';

/// Fichier à envoyer en multipart sur create/update d'un record.
class FileUpload {
  /// Nom original du fichier (ex. `photo.png`).
  final String filename;

  /// Contenu binaire.
  final Uint8List bytes;

  /// MIME type optionnel (ex. `image/png`).
  final String? contentType;

  /// Creates a file upload payload.
  const FileUpload({
    required this.filename,
    required this.bytes,
    this.contentType,
  });
}
