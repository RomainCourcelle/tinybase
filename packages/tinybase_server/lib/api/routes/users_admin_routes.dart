import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../json_response.dart';

/// Active/désactive ("ban") un compte de la collection `users` — protégée
/// par [adminOnlyMiddleware] (voir app.dart), comme le reste de
/// `/api/admin/*`. Vit à part de `/api/collections/users/*` (RecordsService)
/// parce que `users` est une collection `auth` : create/update y restent
/// bloqués même pour l'admin (voir records_service.dart), donc un simple
/// PATCH générique ne peut pas servir à ça — celui-ci ne touche QUE la
/// colonne `disabled`, jamais `email`/`password_hash`.
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

  return router;
}
