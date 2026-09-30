import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import 'settings_service.dart';

const _uuid = Uuid();

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthSession {
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  AuthSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'user': {'id': userId, 'email': email},
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// Inscription / connexion / rafraîchissement de session sur la collection
/// `users`. Mots de passe hashés en bcrypt, sessions en JWT (access court +
/// refresh long), même idée que NexusBase. La connexion Discord (OAuth2)
/// vit ici aussi — [loginOrRegisterWithDiscord] — puisqu'elle aboutit au
/// même résultat qu'un login classique : une [AuthSession].
class AuthService {
  final SqliteDatabase db;
  final SettingsService settings;
  AuthService(this.db, this.settings);

  Future<AuthSession> register(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    final appSettings = await settings.get();
    if (!appSettings.registrationsOpen) {
      throw AuthException('Les inscriptions sont actuellement fermées');
    }
    if (password.length < 8) {
      throw AuthException('Le mot de passe doit faire au moins 8 caractères');
    }
    final existing = await db.getOptional('SELECT id FROM users WHERE email = ?', [normalizedEmail]);
    if (existing != null) {
      throw AuthException('Un compte existe déjà avec cet email');
    }

    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());

    await db.execute(
      'INSERT INTO users (id, email, password_hash, created, updated) VALUES (?, ?, ?, ?, ?)',
      [id, normalizedEmail, hash, now, now],
    );

    return await _issueSession(id, normalizedEmail);
  }

  Future<AuthSession> login(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    final row = await db.getOptional('SELECT * FROM users WHERE email = ?', [normalizedEmail]);
    if (row == null) throw AuthException('Email ou mot de passe incorrect');

    final hash = row['password_hash'] as String;
    if (!BCrypt.checkpw(password, hash)) {
      throw AuthException('Email ou mot de passe incorrect');
    }
    if ((row['disabled'] as int? ?? 0) == 1) {
      throw AuthException('Ce compte a été désactivé');
    }

    return await _issueSession(row['id'] as String, row['email'] as String);
  }

  /// Connexion / liaison OAuth générique (discord, google, apple, microsoft).
  /// [providerColumn] = nom de colonne SQLite (`discord_id`, `google_id`, …).
  Future<AuthSession> loginOrRegisterWithOAuth({
    required String providerColumn,
    required String providerUserId,
    String? email,
  }) async {
    final allowed = {'discord_id', 'google_id', 'apple_id', 'microsoft_id'};
    if (!allowed.contains(providerColumn)) {
      throw AuthException('Provider OAuth inconnu');
    }

    final existingByProvider =
        await db.getOptional('SELECT * FROM users WHERE "$providerColumn" = ?', [providerUserId]);
    if (existingByProvider != null) {
      if ((existingByProvider['disabled'] as int? ?? 0) == 1) {
        throw AuthException('Ce compte a été désactivé');
      }
      return await _issueSession(existingByProvider['id'] as String, existingByProvider['email'] as String);
    }

    final effectiveEmail = (email != null && email.isNotEmpty)
        ? _normalizeEmail(email)
        : '$providerUserId@${providerColumn.replaceAll('_id', '')}.local';

    final existingByEmail =
        await db.getOptional('SELECT id, email, disabled FROM users WHERE email = ?', [effectiveEmail]);
    if (existingByEmail != null) {
      if ((existingByEmail['disabled'] as int? ?? 0) == 1) {
        throw AuthException('Ce compte a été désactivé');
      }
      await db.execute('UPDATE users SET "$providerColumn" = ? WHERE id = ?', [
        providerUserId,
        existingByEmail['id'],
      ]);
      return await _issueSession(existingByEmail['id'] as String, existingByEmail['email'] as String);
    }

    final appSettings = await settings.get();
    if (!appSettings.registrationsOpen) {
      throw AuthException('Les inscriptions sont actuellement fermées');
    }

    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final placeholderHash = BCrypt.hashpw(_uuid.v4(), BCrypt.gensalt());

    await db.execute(
      'INSERT INTO users (id, email, password_hash, "$providerColumn", created, updated) VALUES (?, ?, ?, ?, ?, ?)',
      [id, effectiveEmail, placeholderHash, providerUserId, now, now],
    );

    return await _issueSession(id, effectiveEmail);
  }

  Future<AuthSession> loginOrRegisterWithDiscord({required String discordId, String? email}) {
    return loginOrRegisterWithOAuth(providerColumn: 'discord_id', providerUserId: discordId, email: email);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final Map<String, dynamic> payload;
    try {
      final jwt = JWT.verify(refreshToken, SecretKey(Config.jwtSecret));
      payload = Map<String, dynamic>.from(jwt.payload as Map);
    } catch (_) {
      throw AuthException('Refresh token invalide ou expiré');
    }
    if (payload['type'] != 'refresh') {
      throw AuthException('Ce n\'est pas un refresh token');
    }

    final userId = payload['sub'] as String;
    final row = await db.getOptional('SELECT * FROM users WHERE id = ?', [userId]);
    if (row == null) throw AuthException('Utilisateur introuvable');
    if ((row['disabled'] as int? ?? 0) == 1) {
      throw AuthException('Ce compte a été désactivé');
    }

    return await _issueSession(row['id'] as String, row['email'] as String);
  }

  /// Utilisé par `GET /api/auth/me` (voir auth_routes.dart) — le code
  /// généré côté client (AuthCodegenService) attend `{id, email}`, pas
  /// juste l'id du jeton.
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final row = await db.getOptional('SELECT id, email FROM users WHERE id = ?', [userId]);
    if (row == null) return null;
    return {'id': row['id'], 'email': row['email']};
  }

  /// Vérifie un access token et renvoie l'id utilisateur, ou null s'il est
  /// absent/invalide/expiré (requête traitée comme anonyme). Vérifie aussi
  /// `disabled` en base à CHAQUE requête (pas seulement au login) : un ban
  /// doit couper l'accès immédiatement, sans attendre l'expiration du jeton
  /// d'accès déjà émis (généralement de courte durée, mais pas nul) — voir
  /// auth_middleware.dart qui appelle ceci de façon asynchrone.
  Future<String?> verifyAccessToken(String token) async {
    final String userId;
    try {
      final jwt = JWT.verify(token, SecretKey(Config.jwtSecret));
      final payload = Map<String, dynamic>.from(jwt.payload as Map);
      if (payload['type'] != 'access') return null;
      final sub = payload['sub'] as String?;
      if (sub == null) return null;
      userId = sub;
    } catch (_) {
      return null;
    }
    final row = await db.getOptional('SELECT disabled FROM users WHERE id = ?', [userId]);
    if (row == null) return null;
    if ((row['disabled'] as int? ?? 0) == 1) return null;
    return userId;
  }

  /// Active/désactive un compte ("ban") sans supprimer ses données — un
  /// compte désactivé ne peut plus se connecter (login/refresh/Discord) et
  /// perd l'accès immédiatement même avec un jeton d'accès déjà émis (voir
  /// [verifyAccessToken]). Réversible, contrairement à la suppression (voir
  /// RecordsService.delete pour cette dernière).
  Future<Map<String, dynamic>> setDisabled(String userId, bool disabled) async {
    final row = await db.getOptional('SELECT id, email FROM users WHERE id = ?', [userId]);
    if (row == null) throw AuthException('Utilisateur introuvable');
    await db.execute('UPDATE users SET disabled = ?, updated = ? WHERE id = ?', [
      disabled ? 1 : 0,
      DateTime.now().toUtc().toIso8601String(),
      userId,
    ]);
    return {'id': row['id'], 'email': row['email'], 'disabled': disabled};
  }

  Future<AuthSession> _issueSession(String userId, String email) async {
    final appSettings = await settings.get();
    final access = JWT({'sub': userId, 'type': 'access'})
        .sign(SecretKey(Config.jwtSecret), expiresIn: appSettings.accessTokenTtl);
    final refresh = JWT({'sub': userId, 'type': 'refresh'})
        .sign(SecretKey(Config.jwtSecret), expiresIn: appSettings.refreshTokenTtl);
    return AuthSession(userId: userId, email: email, accessToken: access, refreshToken: refresh);
  }

  /// Trim + lowercase : `Alice@X.com` et `alice@x.com` = même compte.
  static String _normalizeEmail(String email) => email.trim().toLowerCase();
}
