import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:tinybase/api/middleware/rate_limit_middleware.dart';
import 'package:tinybase/api/public_origin.dart';
import 'package:tinybase/api/routes/discord_auth_routes.dart';
import 'package:tinybase/services/filter_parser.dart';

void main() {
  group('clientIp', () {
    test('préfère X-Real-IP', () {
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {
          'x-real-ip': '9.9.9.9',
          'x-forwarded-for': '1.1.1.1, 2.2.2.2',
        },
      );
      expect(clientIp(req), '9.9.9.9');
    });

    test('prend le dernier hop X-Forwarded-For (non falsifiable)', () {
      final req = Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'x-forwarded-for': '1.2.3.4, 10.0.0.8'},
      );
      expect(clientIp(req), '10.0.0.8');
    });
  });

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

  group('publicOrigin', () {
    test('fallback sur requestedUri si PUBLIC_BASE_URL absent', () {
      final req = Request('GET', Uri.parse('https://api.example.com/api/auth/discord/callback'));
      expect(publicOrigin(req), 'https://api.example.com');
    });
  });

  group('oauthAppRedirect', () {
    test('met les tokens en query (pas en fragment)', () {
      final url = oauthAppRedirect(
        target: 'cerebrum://auth/callback',
        accessToken: 'acc+1',
        refreshToken: 'ref/2',
      );
      final uri = Uri.parse(url);
      expect(uri.scheme, 'cerebrum');
      expect(uri.fragment, isEmpty);
      expect(uri.queryParameters['accessToken'], 'acc+1');
      expect(uri.queryParameters['refreshToken'], 'ref/2');
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
