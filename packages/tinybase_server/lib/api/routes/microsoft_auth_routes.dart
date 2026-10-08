import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../json_response.dart';
import 'discord_auth_routes.dart' show isAllowedOAuthTarget;

/// OAuth2 Microsoft (Azure AD v2) — même pattern que Discord :
/// 1 redirect_uri serveur + `target` dans `state`.
Router buildMicrosoftAuthRoutes(AuthService authService, SettingsService settingsService) {
  final router = Router();

  String _origin(Request request) {
    final uri = request.requestedUri;
    final port = uri.hasPort &&
            !((uri.scheme == 'https' && uri.port == 443) || (uri.scheme == 'http' && uri.port == 80))
        ? ':${uri.port}'
        : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  router.get('/authorize', (Request request) async {
    try {
      final settings = await settingsService.get();
      if (!settings.microsoft.enabled) {
        return jsonResponse({'error': 'Connexion Microsoft désactivée ou non configurée'}, status: 400);
      }

      final target = request.url.queryParameters['target'];
      if (target == null || target.isEmpty) {
        return jsonResponse({'error': '"target" requis (deep link de retour vers ton app)'}, status: 400);
      }
      if (!isAllowedOAuthTarget(target)) {
        return jsonResponse({'error': '"target" non autorisé'}, status: 400);
      }

      final state = base64Url.encode(utf8.encode(target));
      final redirectUri = '${_origin(request)}/api/auth/microsoft/callback';

      final authorizeUrl = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize', {
        'client_id': settings.microsoft.clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid profile email User.Read',
        'state': state,
      });

      return Response.found(authorizeUrl.toString());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/callback', (Request request) async {
    try {
      final settings = await settingsService.get();
      if (!settings.microsoft.enabled) {
        return jsonResponse({'error': 'Connexion Microsoft désactivée ou non configurée'}, status: 400);
      }

      final code = request.url.queryParameters['code'];
      final state = request.url.queryParameters['state'];
      if (code == null || state == null) {
        return jsonResponse({'error': '"code"/"state" manquant'}, status: 400);
      }

      final String target;
      try {
        target = utf8.decode(base64Url.decode(state));
      } catch (_) {
        return jsonResponse({'error': '"state" invalide'}, status: 400);
      }
      if (!isAllowedOAuthTarget(target)) {
        return jsonResponse({'error': '"target" non autorisé'}, status: 400);
      }

      final clientSecret = await settingsService.getMicrosoftClientSecret();
      if (clientSecret == null || clientSecret.isEmpty) {
        return jsonResponse({'error': 'Client secret Microsoft non configuré'}, status: 500);
      }

      final redirectUri = '${_origin(request)}/api/auth/microsoft/callback';

      final tokenResponse = await http.post(
        Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': settings.microsoft.clientId!,
          'client_secret': clientSecret,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );
      if (tokenResponse.statusCode != 200) {
        return jsonResponse(
          {'error': 'Échange du code Microsoft échoué : ${tokenResponse.body}'},
          status: 400,
        );
      }
      final tokenJson = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final access = tokenJson['access_token'] as String;

      final profileResponse = await http.get(
        Uri.https('graph.microsoft.com', '/v1.0/me'),
        headers: {'Authorization': 'Bearer $access'},
      );
      if (profileResponse.statusCode != 200) {
        return jsonResponse({'error': 'Impossible de récupérer le profil Microsoft'}, status: 400);
      }
      final profile = jsonDecode(profileResponse.body) as Map<String, dynamic>;
      final msId = profile['id'] as String;
      final msEmail = (profile['mail'] as String?) ?? (profile['userPrincipalName'] as String?);

      final session = await authService.loginOrRegisterWithOAuth(
        providerColumn: 'microsoft_id',
        providerUserId: msId,
        email: msEmail,
      );

      // Fragment (#) : tokens hors query string (moins de logs / Referer).
      final redirectTarget = '$target'
          '#accessToken=${Uri.encodeQueryComponent(session.accessToken)}'
          '&refreshToken=${Uri.encodeQueryComponent(session.refreshToken)}';

      return Response.found(redirectTarget);
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
