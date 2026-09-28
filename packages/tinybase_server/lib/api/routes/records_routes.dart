import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/records_service.dart';
import '../json_response.dart';
import '../middleware/auth_middleware.dart';

/// Routes REST génériques, montées une seule fois sous `/api/collections`
/// (voir app.dart) avec le nom de la collection en paramètre d'URL — pas de
/// route à ajouter par collection, contrairement à une API où chaque
/// ressource aurait son propre routeur : comme les collections sont créées
/// dynamiquement à l'exécution via l'admin, il n'y a de toute façon pas de
/// liste de noms connue au démarrage du serveur pour les monter une par
/// une.
///
/// Équivalent de l'API auto-générée de PocketBase :
///   GET    /api/collections/<name>/records
///   GET    /api/collections/<name>/records/<id>
///   POST   /api/collections/<name>/records
///   PATCH  /api/collections/<name>/records/<id>
///   DELETE /api/collections/<name>/records/<id>
Router buildRecordsRoutes(RecordsService recordsService) {
  final router = Router();

  router.get('/<name>/records', (Request request, String name) async {
    try {
      final params = request.url.queryParameters;
      final result = await recordsService.list(
        name,
        auth: request.auth,
        filter: params['filter'] ?? '',
        sort: params['sort'] ?? '',
        page: int.tryParse(params['page'] ?? '') ?? 1,
        perPage: int.tryParse(params['perPage'] ?? '') ?? 30,
      );
      return jsonResponse({
        'page': result.page,
        'perPage': result.perPage,
        'totalItems': result.totalItems,
        'items': result.items,
      });
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/<name>/records/<id>', (Request request, String name, String id) async {
    try {
      final record = await recordsService.view(name, id, auth: request.auth);
      return jsonResponse(record);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/<name>/records', (Request request, String name) async {
    try {
      final body = await request.readJson();
      final record = await recordsService.create(name, body, auth: request.auth);
      return jsonResponse(record, status: 201);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.patch('/<name>/records/<id>', (Request request, String name, String id) async {
    try {
      final body = await request.readJson();
      final record = await recordsService.update(name, id, body, auth: request.auth);
      return jsonResponse(record);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.delete('/<name>/records/<id>', (Request request, String name, String id) async {
    try {
      await recordsService.delete(name, id, auth: request.auth);
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
