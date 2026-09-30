import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import '../core/config.dart';
import '../db/database.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/collections_service.dart';
import '../services/records_service.dart';
import '../services/settings_service.dart';
import 'middleware/auth_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'routes/admin_auth_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/collections_routes.dart';
import 'routes/discord_auth_routes.dart';
import 'routes/microsoft_auth_routes.dart';
import 'routes/native_oauth_routes.dart';
import 'routes/records_routes.dart';
import 'routes/settings_routes.dart';
import 'routes/users_admin_routes.dart';

Handler buildApp() {
  final settingsService = SettingsService(Database.instance);
  final authService = AuthService(Database.instance, settingsService);
  final adminService = AdminService(Database.instance);
  final collectionsService = CollectionsService(Database.instance);
  final recordsService = RecordsService(Database.instance, collectionsService);

  final root = Router();

  // Mounts OAuth les plus spécifiques AVANT `/api/auth`.
  root.mount('/api/auth/discord', buildDiscordAuthRoutes(authService, settingsService).call);
  root.mount('/api/auth/microsoft', buildMicrosoftAuthRoutes(authService, settingsService).call);
  root.mount(
    '/api/auth/google',
    buildNativeOAuthRoutes(provider: 'google', authService: authService, settingsService: settingsService).call,
  );
  root.mount(
    '/api/auth/apple',
    buildNativeOAuthRoutes(provider: 'apple', authService: authService, settingsService: settingsService).call,
  );
  root.mount('/api/auth', buildAuthRoutes(authService).call);

  // PUBLIQUE (pas de adminPipeline) — voir admin_auth_routes.dart : c'est
  // elle qui délivre le jeton que adminOnlyMiddleware vérifiera ensuite.
  root.mount('/api/admin/auth', buildAdminAuthRoutes(adminService).call);

  // Routes d'administration (schéma + réglages) — protégées par jeton admin
  // (comptes email/mot de passe, voir AdminService). Remplace le jeton
  // statique `X-Admin-Token` de la V1.
  final adminPipeline = const Pipeline().addMiddleware(adminOnlyMiddleware(adminService));
  root.mount('/api/admin/collections', adminPipeline.addHandler(buildCollectionsRoutes(collectionsService).call));
  // Le codegen de la couche Auth vit sous /api/admin/settings/codegen (voir
  // settings_routes.dart) — pas de mount séparé, un seul générateur Auth.
  root.mount('/api/admin/settings', adminPipeline.addHandler(buildSettingsRoutes(settingsService).call));
  // Ban/réactivation d'un compte `users` — distinct de /api/collections/users
  // (RecordsService bloque create/update sur une collection auth même pour
  // l'admin, voir records_service.dart), donc une route admin dédiée.
  root.mount('/api/admin/users', adminPipeline.addHandler(buildUsersAdminRoutes(authService).call));

  root.mount('/api/collections', buildRecordsRoutes(recordsService).call);

  root.get('/health', (Request request) => Response.ok('{"ok":true}', headers: {'content-type': 'application/json'}));

  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(authMiddleware(authService, adminService));

  final apiHandler = pipeline.addHandler(root.call);

  // Sert l'admin (build Flutter Web de tinybase_admin) comme fallback pour
  // tout ce qui n'est pas une route `/api/*` ou `/health` — c'est ce qui
  // permet un déploiement en un seul service (un seul binaire, un seul
  // port). Le dossier n'existe pas forcément en dev local (l'admin tourne
  // alors séparément via `flutter run -d chrome`) : dans ce cas on ne
  // branche que l'API, pas de 500 au démarrage.
  final adminDir = Directory(Config.adminWebDir);
  if (adminDir.existsSync()) {
    final staticHandler = createStaticHandler(adminDir.path, defaultDocument: 'index.html');
    return Cascade().add(apiHandler).add(staticHandler).handler;
  }
  return apiHandler;
}
