import 'package:shelf/shelf.dart';

/// CORS permissif — nécessaire pour que l'admin Flutter Web (servi depuis
/// une autre origine en dev) puisse appeler l'API. À restreindre à une
/// origine précise en prod si besoin (voir Config).
Middleware corsMiddleware() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Token',
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
