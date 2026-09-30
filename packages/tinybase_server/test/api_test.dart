// Batterie de tests automatisés bout-en-bout de l'API TinyBase — exécute
// l'app RÉELLE (buildApp(), le même Handler que bin/server.dart) contre une
// base SQLite temporaire, sans ouvrir de vrai socket TCP (on appelle le
// Handler directement avec des `Request` shelf construites à la main —
// beaucoup plus rapide et sans risque de collision de port).
//
// Lancer : `dart test` depuis packages/tinybase_server. Chaque `group`
// reprend une section de la batterie de tests manuelle (voir le doc partagé
// avec Romain) — les groupes s'exécutent dans l'ordre déclaré et partagent
// un état (admin connecté, utilisateurs créés, collections créées), comme
// un vrai scénario d'utilisation plutôt que des tests unitaires isolés.
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:tinybase/api/app.dart';
import 'package:tinybase/core/config.dart';
import 'package:tinybase/db/database.dart';

/// Petit client de test par-dessus le Handler shelf — évite de reconstruire
/// une `Request` à la main à chaque appel. Volontairement minimal (pas de
/// gestion d'upload de fichiers, inutile ici).
class _TestClient {
  final Handler handler;
  _TestClient(this.handler);

  Future<(int status, dynamic body)> _send(
    String method,
    String path, {
    Map<String, dynamic>? json,
    String? token,
  }) async {
    final headers = <String, String>{
      'content-type': 'application/json; charset=utf-8',
      if (token != null) 'authorization': 'Bearer $token',
    };
    final request = Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: json == null ? null : jsonEncode(json),
    );
    final response = await handler(request);
    final rawBody = await response.readAsString();
    final decoded = rawBody.isEmpty ? null : jsonDecode(rawBody);
    return (response.statusCode, decoded);
  }

  Future<(int, dynamic)> get(String path, {String? token}) => _send('GET', path, token: token);
  Future<(int, dynamic)> post(String path, {Map<String, dynamic>? json, String? token}) =>
      _send('POST', path, json: json, token: token);
  Future<(int, dynamic)> patch(String path, {Map<String, dynamic>? json, String? token}) =>
      _send('PATCH', path, json: json, token: token);
  Future<(int, dynamic)> delete(String path, {String? token}) => _send('DELETE', path, token: token);
}

void main() {
  late Directory tempDir;
  late _TestClient client;

  setUpAll(() async {
    // Base isolée par run de test — jamais la vraie base de dev (voir le
    // paramètre `path` ajouté à Database.init() spécifiquement pour ça).
    tempDir = Directory.systemTemp.createTempSync('tinybase_test_');
    // Secret JWT figé pour les tests (évite d'écrire `.jwt_secret` et
    // garantit un secret déterministe).
    await Config.init(jwtSecretOverride: 'test-jwt-secret-16c');
    await Database.init(path: '${tempDir.path}/test.db');
    client = _TestClient(buildApp());
  });

  tearDownAll(() async {
    // Sur Windows, un fichier ouvert par sqlite_async (isolate séparé) reste
    // verrouillé tant qu'on ne ferme pas explicitement la DB — contrairement
    // à Linux/macOS, supprimer le dossier pendant que le fichier est encore
    // ouvert échoue avec PathAccessException (errno 32, "utilisé par un
    // autre processus"). `close()` attend que l'isolate ait bien relâché le
    // fichier avant de continuer.
    await Database.instance.close();
    tempDir.deleteSync(recursive: true);
  });

  group('0. Démarrage', () {
    test('GET /health répond ok', () async {
      final (status, body) = await client.get('/health');
      expect(status, 200);
      expect(body['ok'], true);
    });
  });

  group('1. Comptes admin', () {
    late String adminToken;

    test('status : pas encore d\'admin sur une base vierge', () async {
      final (status, body) = await client.get('/api/admin/auth/status');
      expect(status, 200);
      expect(body['hasAdmin'], false);
    });

    test('une route admin protégée refuse sans jeton', () async {
      final (status, _) = await client.get('/api/admin/collections');
      expect(status, 403);
    });

    test('setup refuse un mot de passe trop court', () async {
      final (status, body) = await client.post('/api/admin/auth/setup', json: {
        'email': 'admin@example.com',
        'password': 'short',
      });
      expect(status, 400);
      expect(body['error'], contains('8 caractères'));
    });

    test('setup crée le premier compte admin', () async {
      final (status, body) = await client.post('/api/admin/auth/setup', json: {
        'email': 'admin@example.com',
        'password': 'admin1234',
      });
      expect(status, 201);
      expect(body['admin']['email'], 'admin@example.com');
      expect(body['accessToken'], isNotEmpty);
      adminToken = body['accessToken'] as String;
    });

    test('status : un admin existe désormais', () async {
      final (status, body) = await client.get('/api/admin/auth/status');
      expect(status, 200);
      expect(body['hasAdmin'], true);
    });

    test('setup refuse un deuxième compte (V1 : un seul admin)', () async {
      final (status, body) = await client.post('/api/admin/auth/setup', json: {
        'email': 'autre@example.com',
        'password': 'admin1234',
      });
      expect(status, 400);
      expect(body['error'], contains('existe déjà'));
    });

    test('le jeton admin donne accès à une route protégée', () async {
      final (status, body) = await client.get('/api/admin/collections', token: adminToken);
      expect(status, 200);
      // La collection `users` (type auth) existe toujours par défaut.
      expect((body as List).any((c) => c['name'] == 'users'), isTrue);
    });

    test('login refuse un mauvais mot de passe', () async {
      final (status, _) = await client.post('/api/admin/auth/login', json: {
        'email': 'admin@example.com',
        'password': 'mauvais-mot-de-passe',
      });
      expect(status, 400);
    });

    test('login accepte le bon mot de passe et son jeton fonctionne aussi', () async {
      final (status, body) = await client.post('/api/admin/auth/login', json: {
        'email': 'admin@example.com',
        'password': 'admin1234',
      });
      expect(status, 200);
      final freshToken = body['accessToken'] as String;
      final (protectedStatus, _) = await client.get('/api/admin/collections', token: freshToken);
      expect(protectedStatus, 200);
    });

    test('un jeton bidon est refusé', () async {
      final (status, _) = await client.get('/api/admin/collections', token: 'ceci-nest-pas-un-jwt');
      expect(status, 403);
    });

    // Le reste de la batterie a besoin d'un jeton admin valide.
    test('(garde le jeton pour la suite)', () async {
      expect(adminToken, isNotEmpty);
      _sharedAdminToken = adminToken;
    });
  });

  group('2-3. Collections + règles d\'accès', () {
    test('crée une collection "notes" (règle : privé par utilisateur)', () async {
      final (status, body) = await client.post('/api/admin/collections', json: {
        'name': 'notes',
        'type': 'base',
        'fields': [
          {'name': 'title', 'type': 'text', 'required': true},
        ],
        'listRule': '@request.auth.id = owner',
        'viewRule': '@request.auth.id = owner',
        'createRule': '@request.auth.id != ""',
        'updateRule': '@request.auth.id = owner',
        'deleteRule': '@request.auth.id = owner',
      }, token: _sharedAdminToken);
      expect(status, 201);
      expect(body['name'], 'notes');
      expect(body['fields'], hasLength(1));
    });

    test('crée une collection "admin_only" (règle : admin seulement)', () async {
      final (status, body) = await client.post('/api/admin/collections', json: {
        'name': 'admin_only',
        'type': 'base',
        'fields': [
          {'name': 'secret', 'type': 'text'},
        ],
        'listRule': null,
        'viewRule': null,
        'createRule': null,
        'updateRule': null,
        'deleteRule': null,
      }, token: _sharedAdminToken);
      expect(status, 201);
      // Régression du bug kRuleUnset : une règle explicitement `null` doit
      // être écrite telle quelle, pas silencieusement remplacée par `''`.
      expect(body['listRule'], isNull);
      expect(body['createRule'], isNull);
    });

    test('régression kRuleUnset : PATCH ne touchant pas les règles les laisse intactes', () async {
      final (status, body) = await client.patch('/api/admin/collections/admin_only', json: {
        'fields': [
          {'name': 'secret', 'type': 'text'},
          {'name': 'extra', 'type': 'text'},
        ],
        // Pas de clés de règles dans ce body du tout -> doivent rester `null`.
      }, token: _sharedAdminToken);
      expect(status, 200);
      expect(body['listRule'], isNull, reason: 'kRuleUnset doit préserver une règle admin-only existante');
      expect(body['fields'], hasLength(2));
    });

    test('PATCH peut re-basculer une règle de null à publique explicitement', () async {
      final (status, body) = await client.patch('/api/admin/collections/admin_only', json: {
        'listRule': '',
      }, token: _sharedAdminToken);
      expect(status, 200);
      expect(body['listRule'], '');
      // Les autres règles, non mentionnées, restent `null`.
      expect(body['createRule'], isNull);
    });

    test('renomme un champ sans perdre la collection', () async {
      final (status, body) = await client.patch('/api/admin/collections/notes', json: {
        'fields': [
          {'name': 'title', 'type': 'text', 'required': true},
        ],
      }, token: _sharedAdminToken);
      expect(status, 200);
      expect(body['name'], 'notes');
    });

    test('supprime la collection "admin_only"', () async {
      final (status, body) = await client.delete('/api/admin/collections/admin_only', token: _sharedAdminToken);
      expect(status, 200);
      expect(body['ok'], true);

      final (getStatus, _) = await client.get('/api/admin/collections/admin_only', token: _sharedAdminToken);
      expect(getStatus, 404);
    });
  });

  group('4. Auth utilisateurs', () {
    test('register refuse un email déjà pris', () async {
      await client.post('/api/auth/register', json: {'email': 'alice@example.com', 'password': 'password1'});
      final (status, body) = await client.post(
        '/api/auth/register',
        json: {'email': 'alice@example.com', 'password': 'autremdp1'},
      );
      expect(status, 400);
      expect(body['error'], contains('existe déjà'));
    });

    test('register valide renvoie user + tokens', () async {
      final (status, body) = await client.post(
        '/api/auth/register',
        json: {'email': 'bob@example.com', 'password': 'password1'},
      );
      expect(status, 201);
      expect(body['user']['email'], 'bob@example.com');
      expect(body['accessToken'], isNotEmpty);
      expect(body['refreshToken'], isNotEmpty);
    });

    test('login refuse un mauvais mot de passe', () async {
      final (status, _) = await client.post(
        '/api/auth/login',
        json: {'email': 'alice@example.com', 'password': 'mauvais'},
      );
      expect(status, 400);
    });

    test('login + refresh + me renvoient un état cohérent', () async {
      final (loginStatus, loginBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'alice@example.com', 'password': 'password1'},
      );
      expect(loginStatus, 200);
      final accessToken = loginBody['accessToken'] as String;
      final refreshToken = loginBody['refreshToken'] as String;

      final (refreshStatus, refreshBody) = await client.post('/api/auth/refresh', json: {'refreshToken': refreshToken});
      expect(refreshStatus, 200);
      expect(refreshBody['accessToken'], isNotEmpty);

      // Régression : /me doit renvoyer email en plus de id (voir
      // AuthRepository.me() généré par AuthCodegenService, qui désérialise
      // en AppUser({id, email}) et plantait sur un email manquant).
      final (meStatus, meBody) = await client.get('/api/auth/me', token: accessToken);
      expect(meStatus, 200);
      expect(meBody['id'], isNotEmpty);
      expect(meBody['email'], 'alice@example.com');
    });

    test('/me sans jeton -> 401', () async {
      final (status, _) = await client.get('/api/auth/me');
      expect(status, 401);
    });

    test('couper "inscriptions ouvertes" bloque /register puis le réactiver le débloque', () async {
      final (patchStatus, _) = await client.patch(
        '/api/admin/settings',
        json: {'registrationsOpen': false},
        token: _sharedAdminToken,
      );
      expect(patchStatus, 200);

      final (registerStatus, registerBody) = await client.post(
        '/api/auth/register',
        json: {'email': 'carol@example.com', 'password': 'password1'},
      );
      expect(registerStatus, 400);
      expect(registerBody['error'], contains('fermées'));

      final (reopenStatus, _) = await client.patch(
        '/api/admin/settings',
        json: {'registrationsOpen': true},
        token: _sharedAdminToken,
      );
      expect(reopenStatus, 200);

      final (registerAgainStatus, _) = await client.post(
        '/api/auth/register',
        json: {'email': 'carol@example.com', 'password': 'password1'},
      );
      expect(registerAgainStatus, 201);
    });

    test('un utilisateur normal ne peut pas supprimer un compte "users" via l\'API records', () async {
      final (loginStatus, loginBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'carol@example.com', 'password': 'password1'},
      );
      expect(loginStatus, 200);
      final carolId = loginBody['user']['id'] as String;
      final carolToken = loginBody['accessToken'] as String;

      // Même carol, sur son propre compte : la collection `users` reste
      // bloquée en écriture pour un non-admin, quel que soit le record visé.
      final (status, _) = await client.delete('/api/collections/users/records/$carolId', token: carolToken);
      expect(status, 403);
    });

    test('l\'admin PEUT supprimer un compte "users" (régression : signalé en lecture seule à tort)', () async {
      final (loginStatus, loginBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'carol@example.com', 'password': 'password1'},
      );
      expect(loginStatus, 200);
      final carolId = loginBody['user']['id'] as String;

      final (deleteStatus, _) = await client.delete(
        '/api/collections/users/records/$carolId',
        token: _sharedAdminToken,
      );
      expect(deleteStatus, 200);

      // Le compte n'existe plus -> se reconnecter échoue désormais.
      final (loginAgainStatus, _) = await client.post(
        '/api/auth/login',
        json: {'email': 'carol@example.com', 'password': 'password1'},
      );
      expect(loginAgainStatus, 400);
    });

    test('ban : un utilisateur normal ne peut pas se bannir/débannir lui-même', () async {
      final (registerStatus, registerBody) = await client.post(
        '/api/auth/register',
        json: {'email': 'dave@example.com', 'password': 'password1'},
      );
      expect(registerStatus, 201);
      final daveId = registerBody['user']['id'] as String;
      final daveToken = registerBody['accessToken'] as String;

      final (status, _) = await client.patch(
        '/api/admin/users/$daveId/disabled',
        json: {'disabled': true},
        token: daveToken,
      );
      expect(status, 403);
    });

    test('ban admin : bloque login, révoque immédiatement le jeton déjà émis, et est réversible', () async {
      final (loginStatus, loginBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'dave@example.com', 'password': 'password1'},
      );
      expect(loginStatus, 200);
      final daveId = loginBody['user']['id'] as String;
      final daveToken = loginBody['accessToken'] as String;

      // Le jeton fonctionne avant le ban.
      final (meBeforeStatus, _) = await client.get('/api/auth/me', token: daveToken);
      expect(meBeforeStatus, 200);

      final (banStatus, banBody) = await client.patch(
        '/api/admin/users/$daveId/disabled',
        json: {'disabled': true},
        token: _sharedAdminToken,
      );
      expect(banStatus, 200);
      expect(banBody['disabled'], true);

      // Jeton d'accès déjà émis AVANT le ban -> révoqué immédiatement, pas
      // seulement au prochain login (voir AuthService.verifyAccessToken).
      final (meAfterStatus, _) = await client.get('/api/auth/me', token: daveToken);
      expect(meAfterStatus, 401);

      // Nouvelle tentative de connexion -> refusée tant que banni.
      final (loginWhileBannedStatus, loginWhileBannedBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'dave@example.com', 'password': 'password1'},
      );
      expect(loginWhileBannedStatus, 400);
      expect(loginWhileBannedBody['error'], contains('désactivé'));

      // Réversible : débannir restaure l'accès sans recréer de compte.
      final (unbanStatus, unbanBody) = await client.patch(
        '/api/admin/users/$daveId/disabled',
        json: {'disabled': false},
        token: _sharedAdminToken,
      );
      expect(unbanStatus, 200);
      expect(unbanBody['disabled'], false);

      final (loginAfterUnbanStatus, _) = await client.post(
        '/api/auth/login',
        json: {'email': 'dave@example.com', 'password': 'password1'},
      );
      expect(loginAfterUnbanStatus, 200);
    });

    test('password_hash jamais exposé via l\'API records (même à l\'admin)', () async {
      final (loginStatus, loginBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'alice@example.com', 'password': 'password1'},
      );
      expect(loginStatus, 200);
      final aliceId = loginBody['user']['id'] as String;
      final aliceToken = loginBody['accessToken'] as String;

      // Self-view : pas de hash.
      final (viewStatus, viewBody) = await client.get(
        '/api/collections/users/records/$aliceId',
        token: aliceToken,
      );
      expect(viewStatus, 200);
      expect(viewBody.containsKey('password_hash'), isFalse);
      expect(viewBody['email'], 'alice@example.com');

      // Admin list : pas de hash non plus.
      final (listStatus, listBody) = await client.get(
        '/api/collections/users/records',
        token: _sharedAdminToken,
      );
      expect(listStatus, 200);
      final items = listBody['items'] as List;
      expect(items, isNotEmpty);
      for (final item in items) {
        expect((item as Map).containsKey('password_hash'), isFalse);
      }
    });

    test('listRule users = self-only : bob ne liste pas alice', () async {
      final (aliceLogin, aliceBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'alice@example.com', 'password': 'password1'},
      );
      expect(aliceLogin, 200);
      final aliceId = aliceBody['user']['id'] as String;

      final (bobLogin, bobBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'bob@example.com', 'password': 'password1'},
      );
      expect(bobLogin, 200);
      final bobToken = bobBody['accessToken'] as String;
      final bobId = bobBody['user']['id'] as String;

      final (status, body) = await client.get('/api/collections/users/records', token: bobToken);
      expect(status, 200);
      final ids = (body['items'] as List).map((r) => r['id']).toList();
      expect(ids, contains(bobId));
      expect(ids, isNot(contains(aliceId)));
    });

    test('register/login normalisent la casse de l\'email', () async {
      final (regStatus, _) = await client.post(
        '/api/auth/register',
        json: {'email': 'Eve@Example.COM', 'password': 'password1'},
      );
      expect(regStatus, 201);

      final (dupStatus, _) = await client.post(
        '/api/auth/register',
        json: {'email': 'eve@example.com', 'password': 'autremdp1'},
      );
      expect(dupStatus, 400);

      final (loginStatus, loginBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'EVE@example.com', 'password': 'password1'},
      );
      expect(loginStatus, 200);
      expect(loginBody['user']['email'], 'eve@example.com');
    });

    test('impossible de renommer la collection users', () async {
      final (status, body) = await client.patch(
        '/api/admin/collections/users',
        json: {'name': 'membres'},
        token: _sharedAdminToken,
      );
      expect(status, 400);
      expect(body['error'].toString().toLowerCase(), contains('users'));
    });
  });

  group('5. Records + application réelle des règles owner', () {
    late String aliceToken;
    late String bobToken;
    late String aliceNoteId;

    setUpAll(() async {
      final (aliceStatus, aliceBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'alice@example.com', 'password': 'password1'},
      );
      expect(aliceStatus, 200);
      aliceToken = aliceBody['accessToken'] as String;

      final (bobStatus, bobBody) = await client.post(
        '/api/auth/login',
        json: {'email': 'bob@example.com', 'password': 'password1'},
      );
      expect(bobStatus, 200);
      bobToken = bobBody['accessToken'] as String;
    });

    test('un anonyme ne peut pas créer de record sur "notes" (createRule = auth requise)', () async {
      final (status, _) = await client.post('/api/collections/notes/records', json: {'title': 'anonyme'});
      expect(status, 403);
    });

    test('alice crée un record -> owner assigné automatiquement par le serveur', () async {
      final (status, body) = await client.post(
        '/api/collections/notes/records',
        json: {'title': 'Note d\'Alice'},
        token: aliceToken,
      );
      expect(status, 201);
      expect(body['title'], 'Note d\'Alice');
      expect(body['owner'], isNotEmpty);
      aliceNoteId = body['id'] as String;
    });

    test('un client ne peut pas usurper le champ owner à la création', () async {
      final (status, body) = await client.post(
        '/api/collections/notes/records',
        json: {'title': 'Tentative', 'owner': 'quelquun-dautre'},
        token: aliceToken,
      );
      expect(status, 201);
      // "owner" n'est pas un champ déclaré de la collection (auto field) :
      // records_service.create() ignore silencieusement les clés hors
      // schéma, seul auth.userId (côté serveur) alimente la colonne owner.
      expect(body['owner'], isNot('quelquun-dautre'));
    });

    test('bob ne voit pas la note d\'alice dans la liste (règle owner)', () async {
      final (status, body) = await client.get('/api/collections/notes/records', token: bobToken);
      expect(status, 200);
      final ids = (body['items'] as List).map((r) => r['id']);
      expect(ids, isNot(contains(aliceNoteId)));
    });

    test('bob ne peut ni voir, ni modifier, ni supprimer la note d\'alice', () async {
      final (viewStatus, _) = await client.get('/api/collections/notes/records/$aliceNoteId', token: bobToken);
      expect(viewStatus, 403);

      final (updateStatus, _) = await client.patch(
        '/api/collections/notes/records/$aliceNoteId',
        json: {'title': 'piraté'},
        token: bobToken,
      );
      expect(updateStatus, 403);

      final (deleteStatus, _) = await client.delete('/api/collections/notes/records/$aliceNoteId', token: bobToken);
      expect(deleteStatus, 403);
    });

    test('alice peut modifier et voir sa propre note', () async {
      final (status, body) = await client.patch(
        '/api/collections/notes/records/$aliceNoteId',
        json: {'title': 'Note modifiée'},
        token: aliceToken,
      );
      expect(status, 200);
      expect(body['title'], 'Note modifiée');
    });

    test('l\'admin outrepasse la règle owner (bypass total)', () async {
      final (status, body) = await client.get(
        '/api/collections/notes/records/$aliceNoteId',
        token: _sharedAdminToken,
      );
      expect(status, 200);
      expect(body['id'], aliceNoteId);
    });

    test('l\'admin peut supprimer la note d\'alice malgré la règle owner', () async {
      final (status, _) = await client.delete(
        '/api/collections/notes/records/$aliceNoteId',
        token: _sharedAdminToken,
      );
      expect(status, 200);

      final (getStatus, _) = await client.get(
        '/api/collections/notes/records/$aliceNoteId',
        token: _sharedAdminToken,
      );
      expect(getStatus, 404);
    });
  });

  group('7. Génération de code', () {
    test('codegen par collection renvoie modèle + repository + provider', () async {
      final (status, body) = await client.get('/api/admin/collections/notes/codegen', token: _sharedAdminToken);
      expect(status, 200);
      final files = (body['files'] as List).map((f) => f['path'] as String).toList();
      expect(files, contains('lib/models/notes.dart'));
      expect(files, contains('lib/repositories/notes_repository.dart'));
      expect(files, contains('lib/providers/notes_provider.dart'));
    });

    test('codegen Auth renvoie AppUser + AuthRepository + AuthProvider, et le contenu appelle bien /api/auth/me', () async {
      final (status, body) = await client.get('/api/admin/settings/codegen', token: _sharedAdminToken);
      expect(status, 200);
      final files = (body['files'] as List).map((f) => f as Map<String, dynamic>).toList();
      final paths = files.map((f) => f['path']).toList();
      expect(paths, contains('lib/models/app_user.dart'));
      expect(paths, contains('lib/repositories/auth_repository.dart'));
      expect(paths, contains('lib/providers/auth_provider.dart'));

      final repoContent = files.firstWhere((f) => f['path'] == 'lib/repositories/auth_repository.dart')['content'] as String;
      expect(repoContent, contains('/api/auth/me'));
    });

    test('codegen refuse sans jeton admin (protégé comme le reste de /api/admin)', () async {
      final (status, _) = await client.get('/api/admin/collections/notes/codegen');
      expect(status, 403);
    });

    test('codegen Auth n\'inclut PAS le login Discord tant qu\'il n\'est pas configuré', () async {
      final (status, body) = await client.get('/api/admin/settings/codegen', token: _sharedAdminToken);
      expect(status, 200);
      final files = (body['files'] as List).map((f) => f as Map<String, dynamic>).toList();
      final repoContent = files.firstWhere((f) => f['path'] == 'lib/repositories/auth_repository.dart')['content'] as String;
      final providerContent = files.firstWhere((f) => f['path'] == 'lib/providers/auth_provider.dart')['content'] as String;
      expect(repoContent, isNot(contains('discordAuthorizeUrl')));
      expect(providerContent, isNot(contains('handleDiscordCallback')));
    });

    test('codegen Auth inclut le login Discord une fois configuré (régression : générait tout, tout le temps)', () async {
      final (settingsStatus, _) = await client.patch(
        '/api/admin/settings',
        json: {'discordClientId': 'test-client-id', 'discordClientSecret': 'test-client-secret'},
        token: _sharedAdminToken,
      );
      expect(settingsStatus, 200);

      final (status, body) = await client.get('/api/admin/settings/codegen', token: _sharedAdminToken);
      expect(status, 200);
      final files = (body['files'] as List).map((f) => f as Map<String, dynamic>).toList();
      final repoContent = files.firstWhere((f) => f['path'] == 'lib/repositories/auth_repository.dart')['content'] as String;
      final providerContent = files.firstWhere((f) => f['path'] == 'lib/providers/auth_provider.dart')['content'] as String;
      expect(repoContent, contains('discordAuthorizeUrl'));
      expect(providerContent, contains('handleDiscordCallback'));

      // Remis à l'état initial pour ne pas affecter un test qui s'exécuterait après.
      final (disableStatus, _) = await client.patch(
        '/api/admin/settings',
        json: {'disableDiscord': true},
        token: _sharedAdminToken,
      );
      expect(disableStatus, 200);
    });
  });
}

// Partagé entre groupes (le jeton admin obtenu au groupe 1 sert à tous les
// suivants) — variable de niveau fichier plutôt qu'un paramètre thread à
// travers chaque groupe, plus simple pour un scénario séquentiel comme
// celui-ci.
late String _sharedAdminToken;
