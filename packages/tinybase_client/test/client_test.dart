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
