import 'dart:io';

/// Configuration lue depuis les variables d'environnement, avec des valeurs
/// par défaut pratiques pour le dev local (à surcharger en prod, notamment
/// [jwtSecret] et [adminToken] — voir le README).
class Config {
  Config._();

  static String get dbPath => _env('DB_PATH') ?? 'tinybase.db';

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

  /// Secret utilisé pour signer les JWT (access + refresh). À définir
  /// absolument en prod via la variable d'env JWT_SECRET : la valeur par
  /// défaut n'est là que pour ne pas planter en dev local.
  static String get jwtSecret => _env('JWT_SECRET') ?? 'dev-insecure-secret-change-me';

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
