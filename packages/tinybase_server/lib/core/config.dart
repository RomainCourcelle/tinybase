import 'dart:io';
import 'dart:math';

/// Configuration lue depuis les variables d'environnement, avec des valeurs
/// par défaut pratiques pour le dev local.
///
/// [jwtSecret] est résolu au démarrage via [init] :
/// 1. variable d'env `JWT_SECRET` si définie ;
/// 2. sinon fichier `.jwt_secret` à côté de la DB (généré automatiquement
///    au premier démarrage) — comme PocketBase stocke ses clés dans
///    `pb_data`, pas besoin d'y penser en local / sur un volume unique.
class Config {
  Config._();

  static String get dbPath => _env('DB_PATH') ?? 'tinybase.db';

  /// Chemin DB effectivement utilisé (après [init]) — les tests passent un
  /// path temporaire ; [filesDir] doit suivre ce même dossier.
  static String? _resolvedDbPath;

  /// Dossier de stockage des fichiers uploadés (`FieldType.file`).
  /// Par défaut : `<dir(DB)>/files` pour suivre le volume persisté.
  static String get filesDir {
    final fromEnv = _env('FILES_DIR');
    if (fromEnv != null) return fromEnv;
    final dbFile = File(_resolvedDbPath ?? dbPath);
    final dir = (dbFile.parent.path == '.' || dbFile.parent.path.isEmpty)
        ? Directory.current.path
        : dbFile.parent.path;
    return '$dir${Platform.pathSeparator}files';
  }

  /// Nom d'affichage de l'instance (admin). Prioritaire sur la dérivation
  /// depuis le domaine. Ex. `APP_NAME=Cerebrum Base` sur Railway.
  static String? get appName => _env('APP_NAME');

  /// Taille max d'un fichier uploadé (octets). Défaut 10 Mo.
  static int get maxFileSize {
    final raw = _env('MAX_FILE_SIZE');
    if (raw == null) return 10 * 1024 * 1024;
    return int.tryParse(raw) ?? 10 * 1024 * 1024;
  }

  /// Plafond corps multipart entier (octets). Défaut = 2 × [maxFileSize] + 1 Mo.
  static int get maxMultipartBodySize {
    final raw = _env('MAX_MULTIPART_BODY_SIZE');
    if (raw != null) {
      return int.tryParse(raw) ?? (maxFileSize * 2 + 1024 * 1024);
    }
    return maxFileSize * 2 + 1024 * 1024;
  }

  /// Origine CORS autorisée (`*` par défaut). Ex. `https://admin.example.com`.
  static String get corsAllowOrigin => _env('CORS_ALLOW_ORIGIN') ?? '*';

  /// Si true, `POST /api/auth/forgot-password` renvoie aussi `resetToken`
  /// (tests / staging sans SMTP). Ne jamais activer en prod publique.
  static bool? _returnPasswordResetTokenOverride;
  static bool get returnPasswordResetToken {
    if (_returnPasswordResetTokenOverride != null) {
      return _returnPasswordResetTokenOverride!;
    }
    final raw = _env('RETURN_PASSWORD_RESET_TOKEN');
    return raw == '1' || raw?.toLowerCase() == 'true';
  }

  /// URL publique de l'instance (sans slash final). Ex. `https://api.example.com`.
  /// Utilisée pour les liens reset / delete-account dans les emails et `/api/meta`.
  static String? get publicBaseUrl {
    final raw = _env('PUBLIC_BASE_URL');
    if (raw == null) return null;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Template de lien reset. `{token}` est remplacé.
  /// Défaut : `$publicBaseUrl/reset-password?token={token}`.
  static String? passwordResetLink(String token) {
    final tpl = _env('PASSWORD_RESET_URL_TEMPLATE');
    if (tpl != null && tpl.contains('{token}')) {
      return tpl.replaceAll('{token}', Uri.encodeComponent(token));
    }
    final base = publicBaseUrl;
    if (base == null) return null;
    return '$base/reset-password?token=${Uri.encodeComponent(token)}';
  }

  /// Fallback legacy : préférer Admin → Réglages → Email / SMTP.
  /// Si `_settings` n'a pas de SMTP, ces env restent utilisées.
  static String? get smtpHost => _env('SMTP_HOST');
  static int get smtpPort {
    final raw = _env('SMTP_PORT');
    return int.tryParse(raw ?? '') ?? 587;
  }

  static String? get smtpUser => _env('SMTP_USER');
  static String? get smtpPassword => _env('SMTP_PASSWORD');
  static String? get smtpFrom => _env('SMTP_FROM');
  static bool get smtpSsl {
    final raw = _env('SMTP_SSL');
    return raw == '1' || raw?.toLowerCase() == 'true';
  }

  static bool get smtpConfigured =>
      smtpHost != null &&
      smtpHost!.isNotEmpty &&
      smtpFrom != null &&
      smtpFrom!.isNotEmpty;

  /// Max tentatives login/register/forgot par IP sur [authRateLimitWindow].
  static int get authRateLimitMax {
    final raw = _env('AUTH_RATE_LIMIT_MAX');
    return int.tryParse(raw ?? '') ?? 20;
  }

  static Duration get authRateLimitWindow {
    final raw = _env('AUTH_RATE_LIMIT_WINDOW_SECONDS');
    final seconds = int.tryParse(raw ?? '') ?? 60;
    return Duration(seconds: seconds.clamp(1, 3600));
  }

  /// Dossier contenant le build Flutter Web de tinybase_admin (fichiers
  /// statiques `index.html` + `assets/` + `main.dart.js`), servi tel quel
  /// pour tout ce qui n'est pas une route `/api/*` — voir [buildApp] dans
  /// app.dart. En dev local ce dossier n'existe pas forcément (l'admin
  /// tourne alors via `flutter run -d chrome` séparément) ; en prod
  /// (Docker/Railway) il est copié à côté du binaire par le Dockerfile.
  static String get adminWebDir => _env('ADMIN_WEB_DIR') ?? 'public';

  /// Railway (et la plupart des PaaS) injectent le port à écouter via la
  /// variable d'env PORT : ne JAMAIS coder un port en dur ici.
  static int get port {
    final raw = _env('PORT');
    if (raw == null) return 8090;
    return int.tryParse(raw) ?? 8090;
  }

  /// Secret utilisé pour signer les JWT (access + refresh + admin).
  /// Doit être initialisé via [init] avant tout usage.
  static late final String jwtSecret;

  static bool _initialized = false;

  /// Résout [jwtSecret] (env, override de test, ou fichier auto-généré).
  /// Idempotent. [dbPathForSecret] permet aux tests d'aligner le fichier
  /// secret sur leur DB temporaire (sinon on utiliserait le cwd du process).
  static Future<void> init({
    String? dbPathForSecret,
    String? jwtSecretOverride,
    bool? returnPasswordResetToken,
  }) async {
    if (_initialized) return;
    if (returnPasswordResetToken != null) {
      _returnPasswordResetTokenOverride = returnPasswordResetToken;
    }
    _resolvedDbPath = dbPathForSecret ?? dbPath;

    if (jwtSecretOverride != null) {
      if (jwtSecretOverride.length < 16) {
        throw StateError('jwtSecretOverride trop court (minimum 16 caractères)');
      }
      jwtSecret = jwtSecretOverride;
      _initialized = true;
      return;
    }

    final fromEnv = _env('JWT_SECRET');
    if (fromEnv != null) {
      if (fromEnv.length < 16) {
        throw StateError(
          'JWT_SECRET trop court (${fromEnv.length} caractères, minimum 16). '
          'Génère-en un plus long, ex. : openssl rand -hex 32',
        );
      }
      jwtSecret = fromEnv;
      _initialized = true;
      return;
    }

    final secretFile = _jwtSecretFile(dbPathForSecret ?? dbPath);
    if (await secretFile.exists()) {
      final stored = (await secretFile.readAsString()).trim();
      if (stored.length < 16) {
        throw StateError(
          'Fichier ${secretFile.path} contient un secret trop court. '
          'Supprime-le pour en régénérer un, ou définis JWT_SECRET.',
        );
      }
      jwtSecret = stored;
      _initialized = true;
      return;
    }

    final generated = _generateSecret();
    await secretFile.parent.create(recursive: true);
    await secretFile.writeAsString('$generated\n');
    // ignore: avoid_print
    print(
      'JWT_SECRET non défini — secret généré et persisté dans ${secretFile.path}\n'
      '  (pour plusieurs instances derrière un load-balancer, définis plutôt '
      'JWT_SECRET dans l\'environnement pour qu\'elles partagent la même clé)',
    );
    jwtSecret = generated;
    _initialized = true;
  }

  /// Fichier `.jwt_secret` dans le même dossier que la base SQLite — suit
  /// donc le volume persisté en prod (Railway etc.) sans config supplémentaire.
  static File _jwtSecretFile(String path) {
    final dbFile = File(path);
    final dir = (dbFile.parent.path == '.' || dbFile.parent.path.isEmpty)
        ? Directory.current
        : dbFile.parent;
    return File('${dir.path}${Platform.pathSeparator}.jwt_secret');
  }

  static String _generateSecret() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Fallbacks historiques — les TTL utilisateurs viennent de `_settings`
  /// (éditables dans l'admin). Seul [adminTokenTtl] reste ici.
  static Duration get accessTokenTtl => const Duration(hours: 2);
  static Duration get refreshTokenTtl => const Duration(days: 30);

  /// Durée de vie du jeton des comptes admin (email/mot de passe — voir
  /// AdminService). Plus long que le token utilisateur : c'est un panel
  /// d'administration qu'on rouvre régulièrement, pas une session grand
  /// public, et il n'y a pas de refresh token dédié en V1 (se reconnecter
  /// simplement une fois expiré).
  static Duration get adminTokenTtl => const Duration(days: 14);

  static String? _env(String key) {
    final value = Platform.environment[key];
    return (value == null || value.isEmpty) ? null : value;
  }
}
