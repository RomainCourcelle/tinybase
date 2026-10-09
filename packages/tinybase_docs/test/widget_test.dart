import 'package:flutter_test/flutter_test.dart';
import 'package:tinybase_docs/main.dart';

void main() {
  testWidgets('App loads home', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('TinyBase'), findsWidgets);
  });
}
