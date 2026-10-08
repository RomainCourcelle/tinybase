import 'package:shelf/shelf.dart';

import '../../core/config.dart';

/// CORS — origine configurable via `CORS_ALLOW_ORIGIN` (défaut `*`).
Middleware corsMiddleware() {
  final origin = Config.corsAllowOrigin;
  final headers = {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    if (origin != '*') 'Vary': 'Origin',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}
