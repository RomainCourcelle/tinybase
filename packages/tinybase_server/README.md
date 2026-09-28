# TinyBase

BaaS auto-hébergé en Dart, façon PocketBase — moteur de collections
dynamique (shelf + sqlite_async), compilé en binaire unique via
`dart compile exe`. Admin en Flutter Web à venir (pas encore dans ce repo).

## Démarrage

```bash
# 1. Récupérer les dépendances (pas de versions figées dans pubspec.yaml
#    volontairement — pub résout les dernières compatibles) :
dart pub add shelf shelf_router sqlite_async dart_jsonwebtoken bcrypt uuid
dart pub get

# 2. Variables d'env (voir lib/core/config.dart pour les valeurs par défaut
#    de dev — À CHANGER en prod, surtout JWT_SECRET et ADMIN_TOKEN) :
set PORT=8090
set JWT_SECRET=change-moi
set ADMIN_TOKEN=change-moi-aussi
set DB_PATH=tinybase.db

# 3. Lancer :
dart run bin/server.dart
```

Healthcheck : `GET http://localhost:8090/health`

## API

### Auth (`/api/auth`)
- `POST /register` `{email, password}` → session (access + refresh JWT)
- `POST /login` `{email, password}` → session
- `POST /refresh` `{refreshToken}` → nouvelle session
- `GET /me` (Bearer token) → `{id}`

### Admin schéma (`/api/admin/collections`, header `X-Admin-Token`)
- `GET /` → liste des collections
- `GET /<name>` → détail
- `POST /` `{name, type, fields, listRule, viewRule, createRule, updateRule, deleteRule}` → crée
- `PATCH /<name>` `{name?, fields?, renames?, listRule?, ...}` → renomme / édite les champs (rename direct, ajout/suppression de colonne, reconstruction de table si changement de type) / met à jour les règles
- `DELETE /<name>` → supprime

### Records (`/api/collections/<name>/records`, Bearer token optionnel selon les règles)
- `GET /` (`?filter=&sort=&page=&perPage=`) → liste paginée
- `GET /<id>` → un record
- `POST /` → crée (`owner` assigné automatiquement au user authentifié)
- `PATCH /<id>` → met à jour
- `DELETE /<id>` → supprime

### Règles d'accès (V1)
Grammaire volontairement restreinte :
- `""` → public
- `null` (absent) → personne (réservé à l'admin en V2)
- `@request.auth.id != ""` → utilisateur authentifié, n'importe lequel
- `@request.auth.id = <champ>` → uniquement le propriétaire (compare `<champ>` à l'id de l'utilisateur)

## Déploiement (Railway)

Voir le Dockerfile à la racine. Points importants :
- Railway injecte `PORT` — déjà géré par `Config.port`.
- **Attacher un Volume Railway** monté sur le dossier contenant `tinybase.db` (`DB_PATH`), sinon la base repart de zéro à chaque redeploy (filesystem éphémère par défaut).
- Définir `JWT_SECRET` et `ADMIN_TOKEN` dans les variables d'env Railway (jamais les valeurs par défaut de dev).

## Limites connues V1 (voir TODO.md pour le détail du plan)

- Pas de stockage de fichiers (prévu V2)
- Pas de temps réel (SSE/websocket, prévu V2)
- Parseur de filtre sans parenthèses, précédence `&&`/`||` gauche-à-droite stricte
- Un seul provider OAuth prévu (Discord), pas encore branché
- Pas encore d'admin Flutter Web (à faire dans un projet séparé qui consomme cette API)
- Pas encore de génération de code Dart (modèle + repository + provider) à partir du schéma
