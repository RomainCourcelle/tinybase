import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';

const _uuid = Uuid();

class AdminException implements Exception {
  final String message;
  AdminException(this.message);
}

class AdminSession {
  final String adminId;
  final String email;
  final String accessToken;
  AdminSession({required this.adminId, required this.email, required this.accessToken});

  Map<String, dynamic> toJson() => {
        'admin': {'id': adminId, 'email': email},
        'accessToken': accessToken,
      };
}

/// Comptes administrateur (email/mot de passe) — remplace le jeton statique
/// `X-Admin-Token` de la V1. Bien SÉPARÉ de `AuthService`/la collection
/// `users` : un admin gère l'instance (schéma, réglages), un `user` est un
/// compte client d'une app qui consomme TinyBase — les deux ne doivent
/// jamais se confondre, même s'ils partagent bcrypt/JWT sous le capot.
///
/// Sécurité volontairement V1 : `/api/admin/auth/setup` (voir
/// admin_auth_routes.dart) n'est ouverte QUE tant que [hasAnyAdmin] est
/// faux — une fois le premier compte créé, elle refuse tout le monde pour
/// toujours (pas de "deuxième admin" en V1 : un seul compte à ce stade).
class AdminService {
  final SqliteDatabase db;
  AdminService(this.db);

  Future<bool> hasAnyAdmin() async {
    final row = await db.getOptional('SELECT id FROM _admins LIMIT 1');
    return row != null;
  }

  Future<AdminSession> createFirstAdmin(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (password.length < 8) {
      throw AdminException('Le mot de passe doit faire au moins 8 caractères');
    }

    // Check + INSERT dans la même writeTransaction : deux setup concurrents
    // ne peuvent plus créer deux admins (la V1 promet un seul compte).
    final session = await db.writeTransaction((tx) async {
      final existing = await tx.getOptional('SELECT id FROM _admins LIMIT 1');
      if (existing != null) {
        throw AdminException('Un compte administrateur existe déjà');
      }

      final id = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final hash = BCrypt.hashpw(password, BCrypt.gensalt());

      await tx.execute(
        'INSERT INTO _admins (id, email, password_hash, created, updated) VALUES (?, ?, ?, ?, ?)',
        [id, normalizedEmail, hash, now, now],
      );

      return _issueSession(id, normalizedEmail);
    });

    return session;
  }

  Future<AdminSession> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final row = await db.getOptional('SELECT * FROM _admins WHERE email = ?', [normalizedEmail]);
    if (row == null) throw AdminException('Email ou mot de passe incorrect');

    final hash = row['password_hash'] as String;
    if (!BCrypt.checkpw(password, hash)) {
      throw AdminException('Email ou mot de passe incorrect');
    }

    return _issueSession(row['id'] as String, row['email'] as String);
  }

  /// Vérifie un jeton admin et renvoie l'id de l'admin, ou `null` s'il est
  /// absent/invalide/expiré/pas du bon type (ex. un jeton utilisateur
  /// classique présenté ici) — voir auth_middleware.dart.
  String? verifyAdminToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(Config.jwtSecret));
      final payload = Map<String, dynamic>.from(jwt.payload as Map);
      if (payload['type'] != 'admin') return null;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  AdminSession _issueSession(String adminId, String email) {
    final token = JWT({'sub': adminId, 'type': 'admin'}).sign(SecretKey(Config.jwtSecret), expiresIn: Config.adminTokenTtl);
    return AdminSession(adminId: adminId, email: email, accessToken: token);
  }
}
