import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/config.dart';
import '../json_response.dart';

/// Métadonnées publiques de l'instance (branding admin, etc.).
Router buildMetaRoutes() {
  final router = Router();

  router.get('/', (Request request) {
    final base = Config.publicBaseUrl;
    return jsonResponse({
      'appName': Config.appName,
      'smtpConfigured': Config.smtpConfigured,
      'deleteAccountUrl': base == null ? '/delete-account' : '$base/delete-account',
      'resetPasswordPath': '/reset-password',
    });
  });

  return router;
}
