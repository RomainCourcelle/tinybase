import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tinybase_client/tinybase_client.dart';

void main() {
  group('TinyBaseClient', () {
    test('normalise le trailing slash du baseUrl', () {
      final client = TinyBaseClient(
        baseUrl: 'https://api.example.com/',
        tokenStore: InMemoryTokenStore(),
      );
      expect(client.baseUrl, 'https://api.example.com');
      expect(
        client.uri('/api/health').toString(),
        'https://api.example.com/api/health',
      );
    });

    test('requestJson lève TinyBaseException avec le message error', () async {
      final mock = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Identifiants invalides'}), 401);
      });
      final client = TinyBaseClient(
        baseUrl: 'https://api.example.com',
        tokenStore: InMemoryTokenStore(),
        httpClient: mock,
      );

      expect(
        () => client.requestJson(
          'POST',
          '/api/auth/login',
          body: {'email': 'a@b.c', 'password': 'x'},
          auth: false,
        ),
        throwsA(
          isA<TinyBaseException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Identifiants invalides'),
        ),
      );
    });

    test('retry une fois après 401 si refresh OK', () async {
      var calls = 0;
      final store = InMemoryTokenStore();
      await store.writeSession(
        accessToken: 'old',
        refreshToken: 'refresh-token',
        userJson: jsonEncode({'id': 'u1', 'email': 'a@b.c'}),
      );

      final mock = MockClient((request) async {
        calls++;
        if (request.url.path == '/api/auth/refresh') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'email': 'a@b.c'},
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
            }),
            200,
          );
        }
        if (request.headers['Authorization'] == 'Bearer old') {
          return http.Response('{"error":"expired"}', 401);
        }
        if (request.headers['Authorization'] == 'Bearer new-access') {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('unexpected', 500);
      });

      final client = TinyBaseClient(
        baseUrl: 'https://api.example.com',
        tokenStore: store,
        httpClient: mock,
      );

      final json = await client.requestJson('GET', '/api/auth/me');
      expect(json, {'ok': true});
      expect(calls, greaterThanOrEqualTo(3)); // me 401 + refresh + me retry
      expect(await store.readAccessToken(), 'new-access');
    });
  });

  group('TinyBaseAuth.restore', () {
    Future<TinyBaseClient> clientWithSession(MockClient mock) async {
      final store = InMemoryTokenStore();
      await store.writeSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        userJson: jsonEncode({'id': 'u1', 'email': 'a@b.c'}),
      );
      return TinyBaseClient(
        baseUrl: 'https://api.example.com',
        tokenStore: store,
        httpClient: mock,
      );
    }

    test('garde la session sur 502', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/auth/refresh');
        return http.Response(jsonEncode({'error': 'bad gateway'}), 502);
      });
      final client = await clientWithSession(mock);
      final ok = await client.auth.restore();
      expect(ok, isTrue);
      expect(await client.tokenStore.readRefreshToken(), 'refresh');
    });

    test('déconnecte sur 400 (refresh révoqué)', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          return http.Response(jsonEncode({'error': 'révoqué'}), 400);
        }
        if (request.url.path == '/api/auth/logout') {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('nope', 500);
      });
      final client = await clientWithSession(mock);
      final ok = await client.auth.restore();
      expect(ok, isFalse);
      expect(await client.tokenStore.readRefreshToken(), isNull);
    });

    test('isFatalAuthStatus ne couvre pas 429/502', () {
      expect(TinyBaseAuth.isFatalAuthStatus(400), isTrue);
      expect(TinyBaseAuth.isFatalAuthStatus(401), isTrue);
      expect(TinyBaseAuth.isFatalAuthStatus(429), isFalse);
      expect(TinyBaseAuth.isFatalAuthStatus(502), isFalse);
      expect(TinyBaseAuth.isFatalAuthStatus(0), isFalse);
    });

    test('access token vide n\'est pas authentifié', () async {
      final store = InMemoryTokenStore();
      await store.writeSession(
        accessToken: '',
        refreshToken: 'refresh',
        userJson: jsonEncode({'id': 'u1', 'email': 'a@b.c'}),
      );
      final mock = MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          return http.Response(jsonEncode({'error': 'bad gateway'}), 502);
        }
        return http.Response('nope', 500);
      });
      final client = TinyBaseClient(
        baseUrl: 'https://api.example.com',
        tokenStore: store,
        httpClient: mock,
      );
      // Simule restore partiel sans accès valide.
      final refresh = await store.readRefreshToken();
      expect(refresh, 'refresh');
      final access = await store.readAccessToken();
      expect(access, '');
      if (access != null && access.isNotEmpty) {
        // ne doit pas arriver
        fail('access devrait être vide');
      }
      expect(client.auth.isAuthenticated, isFalse);
      final ok = await client.auth.restore();
      // 502 + access vide → pas de session offline valide
      expect(ok, isFalse);
      expect(client.auth.isAuthenticated, isFalse);
    });
  });

  group('TinyBaseCollection', () {
    test('list parse RecordPage', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/collections/notes/records');
        return http.Response(
          jsonEncode({
            'items': [
              {'id': '1', 'title': 'A'},
            ],
            'totalItems': 1,
            'page': 1,
            'perPage': 30,
          }),
          200,
        );
      });
      final client = TinyBaseClient(
        baseUrl: 'https://api.example.com',
        tokenStore: InMemoryTokenStore(),
        httpClient: mock,
      );

      final page = await client.collection('notes').list();
      expect(page.totalItems, 1);
      expect(page.items.single['title'], 'A');
    });
  });
}
