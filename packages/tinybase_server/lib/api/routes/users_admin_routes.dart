import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../json_response.dart';

/// Routes admin sur `users` — ban + patch des champs custom.
Router buildUsersAdminRoutes(AuthService authService) {
  final router = Router();

  /// Body attendu : { "disabled": true|false }
  router.patch('/<id>/disabled', (Request request, String id) async {
    try {
      final body = await request.readJson();
      final disabled = body['disabled'];
      if (disabled is! bool) {
        throw const FormatException('Le champ "disabled" (booléen) est requis');
      }
      final user = await authService.setDisabled(id, disabled);
      return jsonResponse(user);
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// PATCH champs custom d'un user (pas email/password/OAuth).
  router.patch('/<id>', (Request request, String id) async {
    try {
      final body = await request.readJson();
      final user = await authService.adminUpdateUserFields(id, body);
      return jsonResponse(user);
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
