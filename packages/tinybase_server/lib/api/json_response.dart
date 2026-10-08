import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/records_service.dart';
import '../services/settings_service.dart';

Response jsonResponse(Object? data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );
}

/// Traduit les exceptions métier connues en réponses HTTP appropriées.
Response errorResponse(Object error) {
  if (error is ForbiddenException) return jsonResponse({'error': error.message}, status: 403);
  if (error is NotFoundException) return jsonResponse({'error': error.message}, status: 404);
  if (error is AuthException) return jsonResponse({'error': error.message}, status: 400);
  if (error is AdminException) return jsonResponse({'error': error.message}, status: 400);
  if (error is SettingsException) return jsonResponse({'error': error.message}, status: 400);
  if (error is FormatException) return jsonResponse({'error': error.message}, status: 400);
  if (error is StateError) return jsonResponse({'error': error.message}, status: 400);
  // Ne pas exposer les internals (stack / types) au client.
  // ignore: avoid_print
  print('Unhandled error: $error');
  return jsonResponse({'error': 'Erreur interne du serveur'}, status: 500);
}

extension RequestBody on Request {
  Future<Map<String, dynamic>> readJson() async {
    final body = await readAsString();
    if (body.isEmpty) return {};
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Le corps de la requête doit être un objet JSON');
    }
    return decoded;
  }
}
