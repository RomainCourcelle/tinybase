import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tinybase_codegen/tinybase_codegen.dart';

import '../../services/settings_service.dart';
import '../json_response.dart';

/// Réglages globaux de l'instance — protégées par [adminOnlyMiddleware]
/// (voir app.dart), comme le reste de `/api/admin/*`.
Router buildSettingsRoutes(SettingsService settingsService) {
  final router = Router();

  router.get('/', (Request request) async {
    try {
      final settings = await settingsService.get();
      return jsonResponse(settings.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Body attendu (tous les champs optionnels) :
  /// {
  ///   "registrationsOpen": true|false,
  ///   "discordClientId": "..."?,       // "" pour effacer explicitement
  ///   "discordClientSecret": "..."?,   // laisser vide = ne pas changer
  ///   "disableDiscord": true?          // efface id ET secret d'un coup
  /// }
  router.patch('/', (Request request) async {
    try {
      final body = await request.readJson();
      final disable = body['disableDiscord'] == true;

      final settings = await settingsService.update(
        registrationsOpen: body['registrationsOpen'] as bool?,
        discordClientId: body['discordClientId'] as String?,
        discordClientSecret: body['discordClientSecret'] as String?,
        disableDiscord: disable,
      );
      return jsonResponse(settings.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Code d'authentification (modèle + repository + provider) pour une app
  /// cliente qui ne passe pas par nexus_code_launcher — voir
  /// AuthCodegenService. `includeDiscord` suit AppSettings.discordEnabled :
  /// pas d'intérêt à générer des méthodes qui appelleraient des routes
  /// Discord désactivées côté serveur (voir discord_auth_routes.dart).
  router.get('/codegen', (Request request) async {
    try {
      final appSettings = await settingsService.get();
      final files = AuthCodegenService.generate(includeDiscord: appSettings.discordEnabled)
          .map((f) => f.toJson())
          .toList();
      return jsonResponse({'files': files});
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
