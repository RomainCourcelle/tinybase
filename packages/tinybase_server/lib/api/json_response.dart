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
/// Toute autre exception remonte comme 500 avec juste `toString()` — pas
/// d'idée de masquer les erreurs en V1 (projet perso/petite équipe), mais à
/// muscler si TinyBase est un jour exposé plus largement.
Response errorResponse(Object error) {
  if (error is ForbiddenException) return jsonResponse({'error': error.message}, status: 403);
  if (error is NotFoundException) return jsonResponse({'error': error.message}, status: 404);
  if (error is AuthException) return jsonResponse({'error': error.message}, status: 400);
  if (error is AdminException) return jsonResponse({'error': error.message}, status: 400);
  if (error is SettingsException) return jsonResponse({'error': error.message}, status: 400);
  if (error is FormatException) return jsonResponse({'error': error.message}, status: 400);
  if (error is StateError) return jsonResponse({'error': error.message}, status: 400);
  return jsonResponse({'error': error.toString()}, status: 500);
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
