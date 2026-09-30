import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../../services/oauth_native_verifier.dart';
import '../../services/settings_service.dart';
import '../json_response.dart';

/// `POST /api/auth/google/native` et `POST /api/auth/apple/native`
/// body: `{ "idToken": "..." }` — échange un token SDK natif contre une session.
Router buildNativeOAuthRoutes({
  required String provider, // google | apple
  required AuthService authService,
  required SettingsService settingsService,
}) {
  final router = Router();

  router.post('/native', (Request request) async {
    try {
      final body = await request.readJson();
      final idToken = body['idToken'] as String?;
      if (idToken == null || idToken.isEmpty) {
        return jsonResponse({'error': '"idToken" requis'}, status: 400);
      }

      final settings = await settingsService.get();
      late final String providerColumn;
      late final String sub;
      String? email;

      if (provider == 'google') {
        if (!settings.google.enabled) {
          return jsonResponse({'error': 'Connexion Google désactivée ou non configurée'}, status: 400);
        }
        final verified = await OAuthNativeVerifier.verifyGoogleIdToken(
          idToken,
          audience: settings.google.clientId,
        );
        sub = verified.sub;
        email = verified.email;
        providerColumn = 'google_id';
      } else if (provider == 'apple') {
        if (!settings.apple.enabled || settings.apple.clientId == null) {
          return jsonResponse({'error': 'Connexion Apple désactivée ou non configurée'}, status: 400);
        }
        final verified = await OAuthNativeVerifier.verifyAppleIdToken(
          idToken,
          clientId: settings.apple.clientId!,
        );
        sub = verified.sub;
        email = verified.email;
        providerColumn = 'apple_id';
      } else {
        return jsonResponse({'error': 'Provider inconnu'}, status: 400);
      }

      final session = await authService.loginOrRegisterWithOAuth(
        providerColumn: providerColumn,
        providerUserId: sub,
        email: email,
      );
      return jsonResponse(session.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
