import 'package:test/test.dart';

import 'package:tinybase/api/routes/discord_auth_routes.dart';
import 'package:tinybase/services/filter_parser.dart';

void main() {
  group('FilterParser null', () {
    test('= null devient IS NULL', () {
      final (sql, params) = FilterParser.parse('title = null', {'title'});
      expect(sql, '"title" IS NULL');
      expect(params, isEmpty);
    });

    test('!= null devient IS NOT NULL', () {
      final (sql, params) = FilterParser.parse('title != null', {'title'});
      expect(sql, '"title" IS NOT NULL');
      expect(params, isEmpty);
    });

    test('= "null" reste une comparaison de chaîne', () {
      final (sql, params) = FilterParser.parse('title = "null"', {'title'});
      expect(sql, '"title" = ?');
      expect(params, ['null']);
    });
  });

  group('isAllowedOAuthTarget', () {
    test('accepte deep-links custom et localhost', () {
      expect(isAllowedOAuthTarget('myapp://login-callback'), isTrue);
      expect(isAllowedOAuthTarget('fr.romainc.hub://auth'), isTrue);
      expect(isAllowedOAuthTarget('http://localhost:3000/cb'), isTrue);
      expect(isAllowedOAuthTarget('https://127.0.0.1/cb'), isTrue);
    });

    test('refuse open-redirect http(s) distant et schémas dangereux', () {
      expect(isAllowedOAuthTarget('https://evil.example/steal'), isFalse);
      expect(isAllowedOAuthTarget('http://evil.example'), isFalse);
      expect(isAllowedOAuthTarget('javascript:alert(1)'), isFalse);
      expect(isAllowedOAuthTarget('data:text/html,hi'), isFalse);
      expect(isAllowedOAuthTarget('not a url'), isFalse);
    });
  });
}
