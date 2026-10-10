import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/auth_service.dart';
import '../json_response.dart';
import '../middleware/auth_middleware.dart';
import '../middleware/rate_limit_middleware.dart';

Router buildAuthRoutes(AuthService authService) {
  final router = Router();

  router.post('/register', (Request request) async {
    try {
      final limited = rejectIfRateLimited(request, 'register');
      if (limited != null) return limited;
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
      final limited = rejectIfRateLimited(request, 'login');
      if (limited != null) return limited;
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

  router.post('/logout', (Request request) async {
    try {
      final body = await request.readJson();
      final refreshToken = body['refreshToken'] as String?;
      final auth = request.auth;
      await authService.logout(
        userId: auth.isAuthenticated ? auth.userId : null,
        refreshToken: refreshToken,
      );
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/forgot-password', (Request request) async {
    try {
      final limited = rejectIfRateLimited(request, 'forgot');
      if (limited != null) return limited;
      final body = await request.readJson();
      final email = body['email'] as String?;
      if (email == null || email.isEmpty) {
        return jsonResponse({'error': 'email requis'}, status: 400);
      }
      final result = await authService.forgotPassword(email);
      return jsonResponse(result.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/reset-password', (Request request) async {
    try {
      final limited = rejectIfRateLimited(request, 'reset');
      if (limited != null) return limited;
      final body = await request.readJson();
      final token = body['token'] as String?;
      final password = body['password'] as String?;
      if (token == null || password == null) {
        return jsonResponse({'error': 'token et password requis'}, status: 400);
      }
      await authService.resetPassword(token: token, newPassword: password);
      return jsonResponse({'ok': true});
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

  router.delete('/me', (Request request) async {
    try {
      final auth = request.auth;
      if (!auth.isAuthenticated) {
        return jsonResponse({'error': 'Non authentifié'}, status: 401);
      }
      await authService.deleteAccount(auth.userId!);
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Play Store / web : email + password → suppression (sans Bearer).
  router.post('/delete-account', (Request request) async {
    try {
      final limited = rejectIfRateLimited(request, 'delete-account');
      if (limited != null) return limited;
      final body = await request.readJson();
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        return jsonResponse({'error': 'email et password requis'}, status: 400);
      }
      await authService.deleteAccountWithPassword(email: email, password: password);
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Play Store / OAuth : envoi d'un lien de confirmation par email.
  router.post('/request-delete-account', (Request request) async {
    try {
      final limited = rejectIfRateLimited(request, 'request-delete-account');
      if (limited != null) return limited;
      final body = await request.readJson();
      final email = body['email'] as String?;
      if (email == null || email.isEmpty) {
        return jsonResponse({'error': 'email requis'}, status: 400);
      }
      final result = await authService.requestAccountDeletion(email);
      return jsonResponse({
        'ok': true,
        if (result.resetToken != null) 'deleteToken': result.resetToken,
      });
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Confirme la suppression via le token du lien email.
  router.post('/confirm-delete-account', (Request request) async {
    try {
      final limited = rejectIfRateLimited(request, 'confirm-delete-account');
      if (limited != null) return limited;
      final body = await request.readJson();
      final token = body['token'] as String?;
      if (token == null || token.isEmpty) {
        return jsonResponse({'error': 'token requis'}, status: 400);
      }
      await authService.confirmAccountDeletion(token);
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
