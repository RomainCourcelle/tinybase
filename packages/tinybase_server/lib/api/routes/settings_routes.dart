import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tinybase_codegen/tinybase_codegen.dart';

import '../../services/settings_service.dart';
import '../json_response.dart';

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

  router.patch('/', (Request request) async {
    try {
      final body = await request.readJson();

      final settings = await settingsService.update(
        registrationsOpen: body['registrationsOpen'] as bool?,
        accessTokenTtlHours: (body['accessTokenTtlHours'] as num?)?.toInt(),
        refreshTokenTtlDays: (body['refreshTokenTtlDays'] as num?)?.toInt(),
        discordClientId: body['discordClientId'] as String?,
        discordClientSecret: body['discordClientSecret'] as String?,
        disableDiscord: body['disableDiscord'] == true,
        googleClientId: body['googleClientId'] as String?,
        googleClientSecret: body['googleClientSecret'] as String?,
        disableGoogle: body['disableGoogle'] == true,
        microsoftClientId: body['microsoftClientId'] as String?,
        microsoftClientSecret: body['microsoftClientSecret'] as String?,
        disableMicrosoft: body['disableMicrosoft'] == true,
        appleClientId: body['appleClientId'] as String?,
        appleTeamId: body['appleTeamId'] as String?,
        appleKeyId: body['appleKeyId'] as String?,
        applePrivateKey: body['applePrivateKey'] as String?,
        disableApple: body['disableApple'] == true,
      );
      return jsonResponse(settings.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/codegen', (Request request) async {
    try {
      final appSettings = await settingsService.get();
      final style = StateManagementStyle.parse(request.url.queryParameters['style']);
      final files = AuthCodegenService.generate(
        includeDiscord: appSettings.discord.enabled,
        includeGoogle: appSettings.google.enabled,
        includeApple: appSettings.apple.enabled,
        includeMicrosoft: appSettings.microsoft.enabled,
        style: style,
      ).map((f) => f.toJson()).toList();
      return jsonResponse({'files': files, 'style': style.apiValue});
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
