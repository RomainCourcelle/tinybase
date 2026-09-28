import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../json_response.dart';

/// Connexion via Discord (OAuth2 "Authorization Code"). Contrairement à
/// NexusBase (qui enregistre côté Discord une redirect_uri différente par
/// app cliente, `target` compris dans la query), ici UNE seule redirect_uri
/// est à déclarer dans le portail Discord : `<url-du-serveur>/api/auth/
/// discord/callback`. Le `target` (deep link de retour vers l'app cliente,
/// ex. `fr.romainc.hub://login-callback`) voyage dans le paramètre `state`
/// — standard OAuth2, encodé en base64url, et Discord nous le renvoie tel
/// quel au callback. Plus simple à opérer : pas besoin de reconfigurer
/// Discord à chaque nouvelle app cliente.
///
/// Flow complet :
/// 1. L'app cliente ouvre `/api/auth/discord/authorize?target=<deep link>`
///    dans un navigateur (in-app browser / webview).
/// 2. On redirige (302) vers l'écran de consentement Discord.
/// 3. Discord redirige vers `/api/auth/discord/callback?code=...&state=...`.
/// 4. On échange `code` contre un token Discord, récupère le profil
///    (`/api/users/@me`), crée/relie/connecte le compte TinyBase
///    correspondant (voir AuthService.loginOrRegisterWithDiscord),
///    puis redirige vers le `target` avec `accessToken`/`refreshToken` en
///    query — l'app cliente les récupère depuis son deep link handler.
Router buildDiscordAuthRoutes(AuthService authService, SettingsService settingsService) {
  final router = Router();

  String _origin(Request request) {
    final uri = request.requestedUri;
    final port = uri.hasPort && !((uri.scheme == 'https' && uri.port == 443) || (uri.scheme == 'http' && uri.port == 80))
        ? ':${uri.port}'
        : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  router.get('/authorize', (Request request) async {
    try {
      final settings = await settingsService.get();
      if (!settings.discordEnabled) {
        return jsonResponse({'error': 'Connexion Discord désactivée ou non configurée'}, status: 400);
      }

      final target = request.url.queryParameters['target'];
      if (target == null || target.isEmpty) {
        return jsonResponse({'error': '"target" requis (deep link de retour vers ton app)'}, status: 400);
      }

      final state = base64Url.encode(utf8.encode(target));
      final redirectUri = '${_origin(request)}/api/auth/discord/callback';

      final authorizeUrl = Uri.https('discord.com', '/api/oauth2/authorize', {
        'client_id': settings.discordClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'identify email',
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
      if (!settings.discordEnabled) {
        return jsonResponse({'error': 'Connexion Discord désactivée ou non configurée'}, status: 400);
      }

      final code = request.url.queryParameters['code'];
      final state = request.url.queryParameters['state'];
      if (code == null || state == null) {
        return jsonResponse({'error': '"code"/"state" manquant dans le retour Discord'}, status: 400);
      }

      final String target;
      try {
        target = utf8.decode(base64Url.decode(state));
      } catch (_) {
        return jsonResponse({'error': '"state" invalide'}, status: 400);
      }

      final clientSecret = await settingsService.getDiscordClientSecret();
      if (clientSecret == null || clientSecret.isEmpty) {
        return jsonResponse({'error': 'Client secret Discord non configuré'}, status: 500);
      }

      final redirectUri = '${_origin(request)}/api/auth/discord/callback';

      final tokenResponse = await http.post(
        Uri.https('discord.com', '/api/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': settings.discordClientId!,
          'client_secret': clientSecret,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );
      if (tokenResponse.statusCode != 200) {
        return jsonResponse(
          {'error': 'Échange du code Discord échoué : ${tokenResponse.body}'},
          status: 400,
        );
      }
      final tokenJson = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final discordAccessToken = tokenJson['access_token'] as String;

      final profileResponse = await http.get(
        Uri.https('discord.com', '/api/users/@me'),
        headers: {'Authorization': 'Bearer $discordAccessToken'},
      );
      if (profileResponse.statusCode != 200) {
        return jsonResponse({'error': 'Impossible de récupérer le profil Discord'}, status: 400);
      }
      final profile = jsonDecode(profileResponse.body) as Map<String, dynamic>;
      final discordId = profile['id'] as String;
      final discordEmail = profile['email'] as String?;

      final session = await authService.loginOrRegisterWithDiscord(discordId: discordId, email: discordEmail);

      final separator = target.contains('?') ? '&' : '?';
      final redirectTarget = '$target$separator'
          'accessToken=${Uri.encodeQueryComponent(session.accessToken)}'
          '&refreshToken=${Uri.encodeQueryComponent(session.refreshToken)}';

      return Response.found(redirectTarget);
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
