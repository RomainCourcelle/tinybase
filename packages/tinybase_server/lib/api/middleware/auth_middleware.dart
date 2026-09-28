import 'package:shelf/shelf.dart';

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/rules_service.dart';

const authContextKey = 'tinybase.auth';

extension RequestAuth on Request {
  AuthContext get auth => context[authContextKey] as AuthContext? ?? const AuthContext.anonymous();
}

/// Lit le header `Authorization: Bearer <token>` s'il est présent et
/// détermine ce qu'il représente : soit un jeton admin (voir AdminService —
/// donne `isAdmin = true`, qui outrepasse TOUTES les règles d'accès, y
/// compris sur les records, pas seulement /api/admin/*), soit un jeton
/// utilisateur classique (voir AuthService — donne `userId`). Un jeton ne
/// peut être valide que pour l'un OU l'autre (le claim `type` du JWT les
/// distingue), jamais les deux. Ne bloque JAMAIS la requête elle-même — un
/// jeton absent/invalide/expiré devient simplement anonyme ; c'est aux
/// règles d'accès (RulesService, appliqué dans records_service) de décider
/// si l'action est autorisée pour un anonyme.
Middleware authMiddleware(AuthService authService, AdminService adminService) {
  return (Handler innerHandler) {
    return (Request request) async {
      final header = request.headers['authorization'];
      String? userId;
      bool isAdmin = false;
      if (header != null && header.startsWith('Bearer ')) {
        final token = header.substring('Bearer '.length);
        final adminId = adminService.verifyAdminToken(token);
        if (adminId != null) {
          isAdmin = true;
        } else {
          userId = await authService.verifyAccessToken(token);
        }
      }

      final auth = AuthContext(userId: userId, isAdmin: isAdmin);
      final updated = request.change(context: {authContextKey: auth});
      return innerHandler(updated);
    };
  };
}

/// Protège les routes d'administration (schéma des collections, réglages,
/// codegen) — un jeton admin valide (voir AdminService), transmis en
/// `Authorization: Bearer <jwt>`. Remplace le jeton statique `X-Admin-Token`
/// de la V1.
Middleware adminOnlyMiddleware(AdminService adminService) {
  return (Handler innerHandler) {
    return (Request request) {
      final header = request.headers['authorization'];
      final token = (header != null && header.startsWith('Bearer ')) ? header.substring('Bearer '.length) : null;
      final adminId = token == null ? null : adminService.verifyAdminToken(token);
      if (adminId == null) {
        return Response(403, body: '{"error":"Authentification admin invalide ou manquante"}',
            headers: {'content-type': 'application/json'});
      }
      return innerHandler(request);
    };
  };
}
