import 'dart:collection';

import 'package:shelf/shelf.dart';

import '../../core/config.dart';
import '../json_response.dart';

/// Rate-limit in-memory simple (1 process). Suffisant pour une instance Railway.
class AuthRateLimiter {
  AuthRateLimiter({int? maxAttempts, Duration? window})
      : maxAttempts = maxAttempts ?? Config.authRateLimitMax,
        window = window ?? Config.authRateLimitWindow;

  final int maxAttempts;
  final Duration window;
  final Map<String, Queue<DateTime>> _hits = {};

  bool allow(String key) {
    final now = DateTime.now().toUtc();
    final q = _hits.putIfAbsent(key, Queue<DateTime>.new);
    while (q.isNotEmpty && now.difference(q.first) > window) {
      q.removeFirst();
    }
    if (q.length >= maxAttempts) return false;
    q.addLast(now);
    return true;
  }

  void clear() => _hits.clear();
}

final authRateLimiter = AuthRateLimiter();

String clientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  return request.headers['x-real-ip'] ?? 'local';
}

/// Middleware optionnel sur un sous-router — ou helper à appeler dans les routes.
Response? rejectIfRateLimited(Request request, String bucket) {
  final key = '$bucket:${clientIp(request)}';
  if (authRateLimiter.allow(key)) return null;
  return jsonResponse(
    {'error': 'Trop de tentatives, réessaie dans une minute'},
    status: 429,
  );
}
