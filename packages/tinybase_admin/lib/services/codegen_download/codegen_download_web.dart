import 'dart:convert';
import 'dart:html' as html;

/// Vraie implémentation, utilisée quand ce fichier est réellement compilé
/// pour le web (voir l'import conditionnel dans codegen_download.dart) —
/// déclenche le téléchargement navigateur d'un fichier texte via un blob
/// éphémère.
void downloadFile(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
