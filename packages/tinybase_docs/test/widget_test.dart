import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tinybase_docs/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Getting Started s\'affiche', (tester) async {
    await tester.pumpWidget(const DocsApp());
    await tester.pumpAndSettle();
    expect(find.text('TinyBase'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Riverpod'), findsOneWidget);
  });
}
