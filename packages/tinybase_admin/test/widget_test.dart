// Smoke test très basique : l'app démarre et, sans session persistée,
// atterrit sur l'écran de connexion (voir _Gate dans main.dart). Remplace
// le test "Counter increments" du template Flutter par défaut, qui ne
// correspondait à rien dans cette app (classe MyApp inexistante).
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tinybase_admin/main.dart';

void main() {
  setUpAll(() {
    // Sans ça, google_fonts (utilisé dans _buildTheme, main.dart) tente de
    // télécharger la police Lexend depuis le réseau au premier build — dans
    // l'environnement (restreint ou pas) d'un `flutter test`, ce
    // téléchargement peut ne jamais aboutir, et `pumpAndSettle` boucle tant
    // qu'il reste des frames en attente : le test timeout ("pumpAndSettle
    // timed out") sans rapport avec le widget testé lui-même. Ceci force le
    // repli immédiat sur une police système, réseau non sollicité.
    GoogleFonts.config.allowRuntimeFetching = false;
    // Idem pour shared_preferences (lu par ConnectionProvider.tryRestoreSession
    // au démarrage) : sans valeurs mockées explicites, le plugin peut mettre
    // un tour de boucle supplémentaire à résoudre en environnement de test,
    // ce qui suffit à faire hésiter pumpAndSettle. Simule "aucune session
    // sauvegardée" directement.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Démarre sur l\'écran de connexion sans session persistée', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();

    expect(find.text('TinyBase'), findsOneWidget);
  });
}
