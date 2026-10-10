import 'package:sqlite_async/sqlite_async.dart';

import '../core/config.dart';

/// Point d'accès unique à la base SQLite. `sqlite_async` fait tourner les
/// requêtes sur un isolate dédié (non-bloquant pour le serveur HTTP) et
/// active le mode WAL par défaut, ce qui permet des lectures concurrentes
/// pendant qu'une écriture est en cours — voir la discussion sur le choix
/// de sqlite_async vs drift/sqlite3 brut dans le README.
class Database {
  Database._();

  static late final SqliteDatabase instance;
  static bool _initialized = false;

  /// [path] permet à la suite de tests (voir test/api_test.dart) de pointer
  /// vers un fichier temporaire isolé plutôt que la vraie base de dev — sans
  /// ce paramètre, comportement inchangé (toujours [Config.dbPath]).
  static Future<void> init({String? path, bool? returnPasswordResetToken}) async {
    if (_initialized) return;
    // JWT avant tout service auth. On passe [path] pour que le fichier
    // `.jwt_secret` (si pas d'env) vive à côté de la DB de test / prod.
    await Config.init(
      dbPathForSecret: path ?? Config.dbPath,
      returnPasswordResetToken: returnPasswordResetToken,
    );
    instance = SqliteDatabase(path: path ?? Config.dbPath);
    await instance.initialize();

    // Filet de sécurité en plus du WAL : si deux écritures se percutent,
    // on retente pendant 5s avant d'abandonner plutôt que d'échouer tout de
    // suite avec "database is locked".
    await instance.execute('PRAGMA busy_timeout = 5000;');
    await instance.execute('PRAGMA foreign_keys = ON;');

    await _bootstrapMetaTable();
    await _bootstrapUsersCollection();
    await _migrateUsersDiscordId();
    await _migrateUsersDisabled();
    await _migrateUsersListRule();
    await _bootstrapSettingsTable();
    await _migrateSettingsAuthTtl();
    await _migrateSettingsOAuthProviders();
    await _migrateSettingsSmtp();
    await _migrateUsersOAuthIds();
    await _bootstrapAdminsTable();
    await _bootstrapRefreshTokensTable();
    await _bootstrapPasswordResetsTable();
    await _bootstrapAccountDeletionsTable();

    _initialized = true;
  }

  /// Table meta décrivant toutes les collections (base + auth), y compris
  /// `users` elle-même. C'est la source de vérité pour l'admin, le moteur
  /// de records, et la génération de code Dart côté client.
  static Future<void> _bootstrapMetaTable() async {
    await instance.execute('''
      CREATE TABLE IF NOT EXISTS _collections (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        fields TEXT NOT NULL DEFAULT '[]',
        list_rule TEXT,
        view_rule TEXT,
        create_rule TEXT,
        update_rule TEXT,
        delete_rule TEXT,
        created TEXT NOT NULL,
        updated TEXT NOT NULL
      );
    ''');
  }

  /// La collection `users` (type `auth`) doit toujours exister — c'est elle
  /// qui porte l'authentification. Créée automatiquement au premier
  /// démarrage si absente.
  static Future<void> _bootstrapUsersCollection() async {
    final existing = await instance.getOptional(
      'SELECT id FROM _collections WHERE name = ?',
      ['users'],
    );
    if (existing != null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    // listRule = self-only (`id`) : un user connecté ne doit PAS lister
    // tous les comptes (fuite d'emails / metadonnées). L'admin outrepasse
    // via RulesService. view/update : soi-même. create/delete : admin only
    // (chaîne vide côté create est volontairement fermée via l'API records
    // qui refuse toute écriture auth — voir RecordsService).
    await instance.execute(
      '''
      INSERT INTO _collections (id, name, type, fields, list_rule, view_rule, create_rule, update_rule, delete_rule, created, updated)
      VALUES (?, 'users', 'auth', '[]', '@request.auth.id = id', '@request.auth.id = id', null, '@request.auth.id = id', null, ?, ?)
      ''',
      ['_col_users', now, now],
    );

    await instance.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        discord_id TEXT,
        disabled INTEGER NOT NULL DEFAULT 0,
        created TEXT NOT NULL,
        updated TEXT NOT NULL
      );
    ''');
  }

  /// Migration pour une base créée AVANT l'ajout du "ban" (désactivation
  /// d'un compte sans supprimer ses données) : `users` existe déjà sans la
  /// colonne `disabled`. Même schéma de migration idempotente que
  /// `_migrateUsersDiscordId` ci-dessous.
  static Future<void> _migrateUsersDisabled() async {
    final columns = await instance.getAll('PRAGMA table_info(users)');
    final hasDisabled = columns.any((c) => c['name'] == 'disabled');
    if (!hasDisabled) {
      await instance.execute('ALTER TABLE users ADD COLUMN disabled INTEGER NOT NULL DEFAULT 0;');
    }
  }

  /// Bases créées avec l'ancien `listRule` trop permissif
  /// (`@request.auth.id != ""` = tout user authentifié voit tous les users).
  /// On resserre UNIQUEMENT si la règle est encore exactement cette valeur
  /// bootstrap — une règle custom volontairement posée par l'admin est
  /// laissée intacte.
  static Future<void> _migrateUsersListRule() async {
    final row = await instance.getOptional(
      "SELECT list_rule FROM _collections WHERE name = 'users'",
    );
    if (row == null) return;
    if (row['list_rule'] == '@request.auth.id != ""') {
      await instance.execute(
        "UPDATE _collections SET list_rule = '@request.auth.id = id' WHERE name = 'users'",
      );
    }
  }

  /// Migration pour une base créée AVANT l'ajout de la connexion Discord :
  /// `users` existe déjà sans la colonne `discord_id`. `ADD COLUMN` seul
  /// (nullable, pas de rebuild de table nécessaire ici contrairement à un
  /// changement de type — voir collections_service.dart pour ce cas-là).
  /// Idempotent : si la colonne existe déjà (nouvelle install, table créée
  /// directement avec elle ci-dessus), ne fait rien.
  static Future<void> _migrateUsersDiscordId() async {
    final columns = await instance.getAll('PRAGMA table_info(users)');
    final hasDiscordId = columns.any((c) => c['name'] == 'discord_id');
    if (!hasDiscordId) {
      await instance.execute('ALTER TABLE users ADD COLUMN discord_id TEXT;');
    }
    // Index unique séparé (pas inline dans le ADD COLUMN) : les valeurs
    // NULL (comptes email/mot de passe classiques) ne sont pas comparées
    // entre elles par un index UNIQUE SQLite, donc ça n'empêche pas
    // plusieurs comptes sans Discord de coexister.
    await instance.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_discord_id ON users(discord_id);');
  }

  /// Réglages globaux de l'instance (inscriptions ouvertes, config
  /// Discord, TTL JWT) — voir settings_service.dart. Une seule ligne, id fixe.
  static Future<void> _bootstrapSettingsTable() async {
    await instance.execute('''
      CREATE TABLE IF NOT EXISTS _settings (
        id TEXT PRIMARY KEY,
        registrations_open INTEGER NOT NULL DEFAULT 1,
        discord_client_id TEXT,
        discord_client_secret TEXT,
        google_client_id TEXT,
        google_client_secret TEXT,
        microsoft_client_id TEXT,
        microsoft_client_secret TEXT,
        apple_client_id TEXT,
        apple_team_id TEXT,
        apple_key_id TEXT,
        apple_private_key TEXT,
        auth_access_ttl_hours INTEGER NOT NULL DEFAULT 2,
        auth_refresh_ttl_days INTEGER NOT NULL DEFAULT 30,
        updated TEXT NOT NULL
      );
    ''');
    final existing = await instance.getOptional("SELECT id FROM _settings WHERE id = 'settings'");
    if (existing == null) {
      final now = DateTime.now().toUtc().toIso8601String();
      await instance.execute(
        "INSERT INTO _settings (id, registrations_open, updated) VALUES ('settings', 1, ?)",
        [now],
      );
    }
  }

  /// Bases créées avant les colonnes de durée JWT : valeurs = anciens
  /// défauts Config (2h access / 30j refresh).
  static Future<void> _migrateSettingsAuthTtl() async {
    final columns = await instance.getAll('PRAGMA table_info(_settings)');
    final names = columns.map((c) => c['name'] as String).toSet();
    if (!names.contains('auth_access_ttl_hours')) {
      await instance.execute(
        'ALTER TABLE _settings ADD COLUMN auth_access_ttl_hours INTEGER NOT NULL DEFAULT 2;',
      );
    }
    if (!names.contains('auth_refresh_ttl_days')) {
      await instance.execute(
        'ALTER TABLE _settings ADD COLUMN auth_refresh_ttl_days INTEGER NOT NULL DEFAULT 30;',
      );
    }
  }

  static Future<void> _migrateSettingsOAuthProviders() async {
    final columns = await instance.getAll('PRAGMA table_info(_settings)');
    final names = columns.map((c) => c['name'] as String).toSet();
    const extras = [
      'google_client_id TEXT',
      'google_client_secret TEXT',
      'microsoft_client_id TEXT',
      'microsoft_client_secret TEXT',
      'apple_client_id TEXT',
      'apple_team_id TEXT',
      'apple_key_id TEXT',
      'apple_private_key TEXT',
    ];
    for (final def in extras) {
      final name = def.split(' ').first;
      if (!names.contains(name)) {
        await instance.execute('ALTER TABLE _settings ADD COLUMN $def;');
      }
    }
  }

  /// SMTP (reset password) — configuré via admin, comme les secrets OAuth.
  static Future<void> _migrateSettingsSmtp() async {
    final columns = await instance.getAll('PRAGMA table_info(_settings)');
    final names = columns.map((c) => c['name'] as String).toSet();
    const extras = [
      'smtp_host TEXT',
      'smtp_port INTEGER',
      'smtp_user TEXT',
      'smtp_password TEXT',
      'smtp_from TEXT',
      'smtp_ssl INTEGER',
    ];
    for (final def in extras) {
      final name = def.split(' ').first;
      if (!names.contains(name)) {
        await instance.execute('ALTER TABLE _settings ADD COLUMN $def;');
      }
    }
  }

  static Future<void> _migrateUsersOAuthIds() async {
    final columns = await instance.getAll('PRAGMA table_info(users)');
    final names = columns.map((c) => c['name'] as String).toSet();
    for (final col in ['google_id', 'apple_id', 'microsoft_id']) {
      if (!names.contains(col)) {
        await instance.execute('ALTER TABLE users ADD COLUMN $col TEXT;');
      }
      await instance.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_$col ON users($col);',
      );
    }
  }

  /// Comptes administrateur (email/mot de passe) — remplace le jeton
  /// statique `X-Admin-Token` de la V1 (voir AdminService). AUCUNE ligne
  /// insérée par défaut ici, volontairement : une table vide EST le signal
  /// "aucun admin encore créé", utilisé par `/api/admin/auth/status` pour
  /// proposer l'écran de création du premier compte plutôt qu'un login.
  static Future<void> _bootstrapAdminsTable() async {
    await instance.execute('''
      CREATE TABLE IF NOT EXISTS _admins (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created TEXT NOT NULL,
        updated TEXT NOT NULL
      );
    ''');
  }

  /// Refresh tokens côté serveur (révocation / rotation).
  static Future<void> _bootstrapRefreshTokensTable() async {
    await instance.execute('''
      CREATE TABLE IF NOT EXISTS _refresh_tokens (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        created TEXT NOT NULL
      );
    ''');
    await instance.execute(
      'CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON _refresh_tokens(user_id);',
    );
  }

  /// Tokens one-shot pour reset password.
  static Future<void> _bootstrapPasswordResetsTable() async {
    await instance.execute('''
      CREATE TABLE IF NOT EXISTS _password_resets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        created TEXT NOT NULL
      );
    ''');
    await instance.execute(
      'CREATE INDEX IF NOT EXISTS idx_password_resets_user ON _password_resets(user_id);',
    );
  }

  /// Tokens one-shot pour suppression de compte (page web / OAuth sans password).
  static Future<void> _bootstrapAccountDeletionsTable() async {
    await instance.execute('''
      CREATE TABLE IF NOT EXISTS _account_deletions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        created TEXT NOT NULL
      );
    ''');
    await instance.execute(
      'CREATE INDEX IF NOT EXISTS idx_account_deletions_user ON _account_deletions(user_id);',
    );
  }
}
