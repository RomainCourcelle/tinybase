import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/config.dart';
import '../json_response.dart';

/// Métadonnées publiques de l'instance (branding admin, etc.).
Router buildMetaRoutes() {
  final router = Router();

  router.get('/', (Request request) {
    return jsonResponse({
      'appName': Config.appName,
    });
  });

  return router;
}
