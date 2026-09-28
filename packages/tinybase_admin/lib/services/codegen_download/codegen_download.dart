/// Point d'entrée conditionnel : la vraie implémentation `dart:html` n'est
/// choisie QUE quand `dart:html` est effectivement disponible pour la cible
/// de compilation (web) — sinon (VM, dont `flutter test`/`dart test`) c'est
/// le stub qui est lié, sans jamais importer `dart:html` dans ce cas. Sans
/// ça, importer `dart:html` sans condition depuis codegen_dialog.dart casse
/// la COMPILATION de `flutter test` (pas juste son exécution) dès que
/// n'importe quel écran atteignable depuis `AdminApp` référence ce fichier
/// — régression trouvée en lançant `flutter test` pour la première fois
/// (voir widget_test.dart).
library;

export 'codegen_download_stub.dart' if (dart.library.html) 'codegen_download_web.dart';
