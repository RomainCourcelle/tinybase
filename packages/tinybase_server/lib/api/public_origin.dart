import 'package:shelf/shelf.dart';

import '../core/config.dart';

/// Origine publique de l'API pour les redirect_uri OAuth et liens email.
///
/// Prefère [Config.publicBaseUrl] (Railway) — derrière un proxy,
/// [Request.requestedUri] peut être en `http` ou un host interne, ce qui
/// casse l'échange Discord/Microsoft (`redirect_uri` mismatch).
String publicOrigin(Request request) {
  final base = Config.publicBaseUrl;
  if (base != null && base.isNotEmpty) return base;

  final uri = request.requestedUri;
  final port = uri.hasPort &&
          !((uri.scheme == 'https' && uri.port == 443) ||
              (uri.scheme == 'http' && uri.port == 80))
      ? ':${uri.port}'
      : '';
  return '${uri.scheme}://${uri.host}$port';
}
