import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:tinybase_shared/tinybase_shared.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import 'collections_service.dart';
import 'files_service.dart';
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

/// Result of [AuthService.forgotPassword] (token only when Config allows).
class ForgotPasswordResult {
  final bool ok;
  final String? resetToken;
  const ForgotPasswordResult({required this.ok, this.resetToken});

  Map<String, dynamic> toJson() => {
        'ok': ok,
        if (resetToken != null) 'resetToken': resetToken,
      };
}

/// Inscription / connexion / rafraîchissement de session sur la collection
/// `users`. Mots de passe hashés en bcrypt, sessions en JWT (access court +
/// refresh long) avec table `_refresh_tokens` pour révocation.
class AuthService {
  final SqliteDatabase db;
  final SettingsService settings;
  final CollectionsService collections;
  final FilesService files;

  /// Records `owner = userId` dans les collections base. Branché depuis
  /// [buildApp] vers [RecordsService.deleteOwnedBy].
  Future<void> Function(String userId)? purgeOwnedRecords;

  AuthService(
    this.db,
    this.settings,
    this.collections, {
    FilesService? files,
  }) : files = files ?? FilesService();

  Future<AuthSession> register(
    String email,
    String password, {
    Map<String, dynamic> extras = const {},
  }) async {
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

    final custom = await _coerceCustomFields(extras, forCreate: true);

    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());

    final columns = <String>['id', 'email', 'password_hash', 'created', 'updated'];
    final values = <Object?>[id, normalizedEmail, hash, now, now];
    for (final entry in custom.entries) {
      columns.add(entry.key);
      values.add(entry.value);
    }

    final placeholders = List.filled(columns.length, '?').join(', ');
    final quoted = columns.map((c) => '"$c"').join(', ');
    await db.execute('INSERT INTO users ($quoted) VALUES ($placeholders)', values);

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
  Future<AuthSession> loginOrRegisterWithOAuth({
    required String providerColumn,
    required String providerUserId,
    String? email,
    Map<String, dynamic> fields = const {},
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
      return await _issueSession(
        existingByProvider['id'] as String,
        existingByProvider['email'] as String,
      );
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

    final custom = await _coerceCustomFields(fields, forCreate: false);

    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final placeholderHash = BCrypt.hashpw(_uuid.v4(), BCrypt.gensalt());

    final columns = <String>['id', 'email', 'password_hash', providerColumn, 'created', 'updated'];
    final values = <Object?>[id, effectiveEmail, placeholderHash, providerUserId, now, now];
    for (final entry in custom.entries) {
      columns.add(entry.key);
      values.add(entry.value);
    }

    final placeholders = List.filled(columns.length, '?').join(', ');
    final quoted = columns.map((c) => '"$c"').join(', ');
    await db.execute(
      'INSERT INTO users ($quoted) VALUES ($placeholders)',
      values,
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
    final jti = payload['jti'] as String?;
    final hash = _hashToken(refreshToken);

    final stored = await db.getOptional(
      'SELECT id, user_id, expires_at FROM _refresh_tokens WHERE token_hash = ?',
      [hash],
    );
    if (stored == null) {
      throw AuthException('Refresh token révoqué ou inconnu');
    }
    if (jti != null && stored['id'] != jti) {
      throw AuthException('Refresh token invalide');
    }
    if (stored['user_id'] != userId) {
      throw AuthException('Refresh token invalide');
    }
    final expiresAt = DateTime.tryParse(stored['expires_at'] as String);
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      await db.execute('DELETE FROM _refresh_tokens WHERE id = ?', [stored['id']]);
      throw AuthException('Refresh token expiré');
    }

    // Rotation : invalide l'ancien avant d'émettre le nouveau.
    await db.execute('DELETE FROM _refresh_tokens WHERE id = ?', [stored['id']]);

    final row = await db.getOptional('SELECT * FROM users WHERE id = ?', [userId]);
    if (row == null) throw AuthException('Utilisateur introuvable');
    if ((row['disabled'] as int? ?? 0) == 1) {
      throw AuthException('Ce compte a été désactivé');
    }

    return await _issueSession(row['id'] as String, row['email'] as String);
  }

  /// Révoque un refresh token (logout) et/ou tous les tokens du user.
  Future<void> logout({String? userId, String? refreshToken}) async {
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await db.execute(
        'DELETE FROM _refresh_tokens WHERE token_hash = ?',
        [_hashToken(refreshToken)],
      );
    }
    if (userId != null) {
      await db.execute('DELETE FROM _refresh_tokens WHERE user_id = ?', [userId]);
    }
  }

  /// Suppression de compte (Play Store / RGPD) : records dont il est
  /// `owner` (et leurs fichiers), sessions, tokens de reset, puis la ligne user.
  Future<void> deleteAccount(String userId) async {
    final row = await db.getOptional('SELECT id FROM users WHERE id = ?', [userId]);
    if (row == null) throw AuthException('Utilisateur introuvable');
    final purge = purgeOwnedRecords;
    if (purge != null) await purge(userId);
    await db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM _refresh_tokens WHERE user_id = ?', [userId]);
      await tx.execute('DELETE FROM _password_resets WHERE user_id = ?', [userId]);
      await tx.execute('DELETE FROM users WHERE id = ?', [userId]);
    });
    await files.deleteRecordFiles('users', userId);
  }

  /// Demande de reset — réponse toujours ok (pas d'énumération d'emails).
  Future<ForgotPasswordResult> forgotPassword(String email) async {
    final normalized = _normalizeEmail(email);
    final row = await db.getOptional('SELECT id FROM users WHERE email = ?', [normalized]);
    if (row == null) {
      return const ForgotPasswordResult(ok: true);
    }

    final userId = row['id'] as String;
    await db.execute('DELETE FROM _password_resets WHERE user_id = ?', [userId]);

    final rawToken = _uuid.v4() + _uuid.v4();
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final expires = now.add(const Duration(hours: 1));
    await db.execute(
      'INSERT INTO _password_resets (id, user_id, token_hash, expires_at, created) VALUES (?, ?, ?, ?, ?)',
      [id, userId, _hashToken(rawToken), expires.toIso8601String(), now.toIso8601String()],
    );

    // Sans SMTP en V0.4 : token renvoyé seulement si env de test/staging.
    return ForgotPasswordResult(
      ok: true,
      resetToken: Config.returnPasswordResetToken ? rawToken : null,
    );
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    if (newPassword.length < 8) {
      throw AuthException('Le mot de passe doit faire au moins 8 caractères');
    }
    final hash = _hashToken(token);
    final row = await db.getOptional(
      'SELECT id, user_id, expires_at FROM _password_resets WHERE token_hash = ?',
      [hash],
    );
    if (row == null) throw AuthException('Lien de réinitialisation invalide ou expiré');
    final expiresAt = DateTime.tryParse(row['expires_at'] as String);
    if (expiresAt == null || expiresAt.isBefore(DateTime.now().toUtc())) {
      await db.execute('DELETE FROM _password_resets WHERE id = ?', [row['id']]);
      throw AuthException('Lien de réinitialisation invalide ou expiré');
    }

    final userId = row['user_id'] as String;
    final passwordHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await db.execute(
      'UPDATE users SET password_hash = ?, updated = ? WHERE id = ?',
      [passwordHash, DateTime.now().toUtc().toIso8601String(), userId],
    );
    await db.execute('DELETE FROM _password_resets WHERE user_id = ?', [userId]);
    await db.execute('DELETE FROM _refresh_tokens WHERE user_id = ?', [userId]);
  }

  /// Profil public : id, email, disabled + champs custom (sans secrets).
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final row = await db.getOptional('SELECT * FROM users WHERE id = ?', [userId]);
    if (row == null) return null;
    return _publicUser(Map<String, dynamic>.from(row));
  }

  /// Met à jour les champs custom du user authentifié.
  Future<Map<String, dynamic>> updateMe(String userId, Map<String, dynamic> data) async {
    final existing = await db.getOptional('SELECT id FROM users WHERE id = ?', [userId]);
    if (existing == null) throw AuthException('Utilisateur introuvable');

    final custom = await _coerceCustomFields(data, forCreate: false);
    if (custom.isEmpty) {
      return (await getUserById(userId))!;
    }

    final sets = <String>['"updated" = ?'];
    final values = <Object?>[DateTime.now().toUtc().toIso8601String()];
    for (final entry in custom.entries) {
      sets.add('"${entry.key}" = ?');
      values.add(entry.value);
    }
    values.add(userId);
    await db.execute('UPDATE users SET ${sets.join(', ')} WHERE id = ?', values);
    return (await getUserById(userId))!;
  }

  /// Admin : met à jour les champs custom d'un user (pas email/password/OAuth).
  Future<Map<String, dynamic>> adminUpdateUserFields(String userId, Map<String, dynamic> data) async {
    return updateMe(userId, data);
  }

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

  Future<Map<String, dynamic>> setDisabled(String userId, bool disabled) async {
    final row = await db.getOptional('SELECT * FROM users WHERE id = ?', [userId]);
    if (row == null) throw AuthException('Utilisateur introuvable');
    await db.execute('UPDATE users SET disabled = ?, updated = ? WHERE id = ?', [
      disabled ? 1 : 0,
      DateTime.now().toUtc().toIso8601String(),
      userId,
    ]);
    if (disabled) {
      await db.execute('DELETE FROM _refresh_tokens WHERE user_id = ?', [userId]);
    }
    final public = _publicUser(Map<String, dynamic>.from(row));
    public['disabled'] = disabled;
    return public;
  }

  Future<Map<String, Object?>> _coerceCustomFields(
    Map<String, dynamic> data, {
    required bool forCreate,
  }) async {
    final col = await collections.getOrThrow('users');
    final byName = {for (final f in col.fields) f.name: f};
    final out = <String, Object?>{};

    for (final entry in data.entries) {
      final key = entry.key;
      if (key == 'email' || key == 'password' || key == 'password_hash') continue;
      if (kAuthProtectedFieldNames.contains(key)) {
        throw FormatException('Champ système non modifiable : "$key"');
      }
      final field = byName[key];
      if (field == null) {
        throw FormatException('Champ inconnu : "$key"');
      }
      if (field.type == FieldType.file) {
        throw FormatException('Les champs fichier ne sont pas supportés via /api/auth (utilise une collection séparée)');
      }
      final coerced = field.type.coerce(entry.value);
      if (field.required && coerced == null) {
        throw FormatException('Champ requis manquant : "$key"');
      }
      field.validate(coerced);
      out[key] = coerced;
    }

    if (forCreate) {
      for (final field in col.fields) {
        if (!field.required) continue;
        if (out.containsKey(field.name)) continue;
        throw FormatException('Champ requis manquant : "${field.name}"');
      }
    }

    return out;
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> row) {
    final cleaned = Map<String, dynamic>.from(row);
    for (final secret in kAuthSecretFields) {
      cleaned.remove(secret);
    }
    return cleaned;
  }

  Future<AuthSession> _issueSession(String userId, String email) async {
    final appSettings = await settings.get();
    final jti = _uuid.v4();
    final access = JWT({'sub': userId, 'type': 'access'})
        .sign(SecretKey(Config.jwtSecret), expiresIn: appSettings.accessTokenTtl);
    final refresh = JWT({'sub': userId, 'type': 'refresh', 'jti': jti})
        .sign(SecretKey(Config.jwtSecret), expiresIn: appSettings.refreshTokenTtl);

    final now = DateTime.now().toUtc();
    final expires = now.add(appSettings.refreshTokenTtl);
    await db.execute(
      'INSERT INTO _refresh_tokens (id, user_id, token_hash, expires_at, created) VALUES (?, ?, ?, ?, ?)',
      [jti, userId, _hashToken(refresh), expires.toIso8601String(), now.toIso8601String()],
    );

    return AuthSession(userId: userId, email: email, accessToken: access, refreshToken: refresh);
  }

  static String _hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

  static String _normalizeEmail(String email) => email.trim().toLowerCase();
}
