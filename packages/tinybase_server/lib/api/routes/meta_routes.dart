import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/config.dart';
import '../../services/settings_service.dart';
import '../json_response.dart';

/// Métadonnées publiques de l'instance (branding admin, etc.).
Router buildMetaRoutes(SettingsService settingsService) {
  final router = Router();

  router.get('/', (Request request) async {
    final base = Config.publicBaseUrl;
    final smtpConfigured = await settingsService.isSmtpConfigured();
    return jsonResponse({
      'appName': Config.appName,
      'smtpConfigured': smtpConfigured,
      'deleteAccountUrl': base == null ? '/delete-account' : '$base/delete-account',
      'resetPasswordPath': '/reset-password',
    });
  });

  return router;
}
