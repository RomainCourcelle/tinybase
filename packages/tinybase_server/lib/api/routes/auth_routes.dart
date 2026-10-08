import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../json_response.dart';
import '../middleware/auth_middleware.dart';

Router buildAuthRoutes(AuthService authService) {
  final router = Router();

  router.post('/register', (Request request) async {
    try {
      final body = await request.readJson();
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        return jsonResponse({'error': 'email et password requis'}, status: 400);
      }
      final extras = Map<String, dynamic>.from(body)
        ..remove('email')
        ..remove('password');
      final session = await authService.register(email, password, extras: extras);
      return jsonResponse(session.toJson(), status: 201);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/login', (Request request) async {
    try {
      final body = await request.readJson();
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        return jsonResponse({'error': 'email et password requis'}, status: 400);
      }
      final session = await authService.login(email, password);
      return jsonResponse(session.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/refresh', (Request request) async {
    try {
      final body = await request.readJson();
      final refreshToken = body['refreshToken'] as String?;
      if (refreshToken == null) {
        return jsonResponse({'error': 'refreshToken requis'}, status: 400);
      }
      final session = await authService.refresh(refreshToken);
      return jsonResponse(session.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/me', (Request request) async {
    final auth = request.auth;
    if (!auth.isAuthenticated) {
      return jsonResponse({'error': 'Non authentifié'}, status: 401);
    }
    final user = await authService.getUserById(auth.userId!);
    if (user == null) return jsonResponse({'error': 'Utilisateur introuvable'}, status: 404);
    return jsonResponse(user);
  });

  router.patch('/me', (Request request) async {
    try {
      final auth = request.auth;
      if (!auth.isAuthenticated) {
        return jsonResponse({'error': 'Non authentifié'}, status: 401);
      }
      final body = await request.readJson();
      final user = await authService.updateMe(auth.userId!, body);
      return jsonResponse(user);
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
