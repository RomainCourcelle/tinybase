import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/admin_service.dart';
import '../json_response.dart';

/// Routes PUBLIQUES (pas de [adminOnlyMiddleware] ici — normal, c'est elles
/// qui délivrent le jeton que ce middleware vérifiera ensuite) pour la
/// connexion/le tout premier lancement de l'admin. Voir AdminService pour
/// la logique.
Router buildAdminAuthRoutes(AdminService adminService) {
  final router = Router();

  /// Utilisé par l'admin Flutter au moment de se connecter à une instance :
  /// affiche l'écran "créer le compte admin" si `hasAdmin` est faux, sinon
  /// l'écran de connexion classique.
  router.get('/status', (Request request) async {
    try {
      final hasAdmin = await adminService.hasAnyAdmin();
      return jsonResponse({'hasAdmin': hasAdmin});
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/setup', (Request request) async {
    try {
      final body = await request.readJson();
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        return jsonResponse({'error': 'email et password requis'}, status: 400);
      }
      final session = await adminService.createFirstAdmin(email, password);
      return jsonResponse(session.toJson(), status: 201);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/login', (Request request) async {
    try {
      final body = await request.readJson();
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        return jsonResponse({'error': 'email et password requis'}, status: 400);
      }
      final session = await adminService.login(email, password);
      return jsonResponse(session.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
