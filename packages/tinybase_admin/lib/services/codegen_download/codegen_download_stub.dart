/// Implémentation de repli quand `dart:html` n'existe pas sur la plateforme
/// qui compile ce code — en pratique, l'exécutable de test (`flutter test`
/// tourne sur la VM Dart, jamais sur un navigateur, voir codegen_download.dart)
/// et, un jour, une éventuelle cible non-web de l'admin. Jamais réellement
/// appelée en usage normal (l'admin tourne en Flutter Web, voir pubspec.yaml).
void downloadFile(String filename, String content) {
  throw UnsupportedError('Téléchargement de fichier non supporté sur cette plateforme');
}
