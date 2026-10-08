# TinyBase

BaaS auto-hébergé en Dart, façon PocketBase — moteur de collections
dynamique (shelf + sqlite_async), admin Flutter Web, codegen Dart,
compilé en binaire unique via `dart compile exe`.

## Démarrage

```bash
# Depuis packages/tinybase_server :
dart pub get

# Optionnel — sinon un secret est auto-généré dans `.jwt_secret` à côté de la DB :
#   set JWT_SECRET=<openssl rand -hex 32>
set PORT=8090
set DB_PATH=tinybase.db

# Optionnel branding admin + fichiers :
# set APP_NAME=Cerebrum Base
# set FILES_DIR=C:\data\files
# set MAX_FILE_SIZE=10485760

dart run bin/server.dart
```

Healthcheck : `GET http://localhost:8090/health`

### JWT_SECRET — pas besoin d'y penser en local

Au démarrage :
1. Si `JWT_SECRET` est défini dans l'environnement → on l'utilise (min. 16 caractères).
2. Sinon → lecture / création automatique de `.jwt_secret` **à côté de la DB**.

Ça suit le volume persisté (Railway etc.). Définis `JWT_SECRET` explicitement
seulement si tu as **plusieurs instances** derrière un load-balancer (elles
doivent partager la même clé).

### Fichiers & branding

| Variable | Défaut | Rôle |
|----------|--------|------|
| `FILES_DIR` | `<dir(DB_PATH)>/files` | Stockage des uploads (`FieldType.file`) |
| `MAX_FILE_SIZE` | `10485760` (10 Mo) | Taille max par fichier |
| `MAX_MULTIPART_BODY_SIZE` | ~2× `MAX_FILE_SIZE` + 1 Mo | Plafond corps multipart |
| `CORS_ALLOW_ORIGIN` | `*` | Origine CORS autorisée |
| `APP_NAME` | _(vide)_ | Nom affiché dans l'admin ; sinon dérivé du domaine (`flown.com` → `Flown Base`) |

## API

### Meta (`/api/meta`)
- `GET /` → `{ appName }` (public)

### Auth (`/api/auth`)
- `POST /register` `{email, password}` → session (access + refresh JWT)
- `POST /login` `{email, password}` → session
- `POST /refresh` `{refreshToken}` → nouvelle session
- `GET /me` (Bearer token) → `{id, email}`
- Discord OAuth : `/api/auth/discord/authorize?target=<deep-link>` (si configuré)

### Admin auth (`/api/admin/auth`)
- `GET /status` → `{hasAdmin}`
- `POST /setup` `{email, password}` → crée le **premier** admin (ensuite fermé)
- `POST /login` `{email, password}` → `{admin, accessToken}`

### Admin schéma (`/api/admin/collections`, Bearer admin)
- `GET /` → liste des collections
- `GET /<name>` → détail
- `POST /` `{name, type, fields, listRule, ...}` → crée
- `PATCH /<name>` → renomme / édite champs / règles
- `DELETE /<name>` → supprime (pas `users`)
- `GET /<name>/codegen` → fichiers Dart générés

### Auth profil (v0.3)
- `POST /register` accepte aussi les champs custom du schéma `users`
- `GET /me` → profil public (id, email, custom fields, sans `password_hash`)
- `PATCH /me` → met à jour les champs custom
- Admin : `PATCH /api/admin/users/<id>` → champs custom ; `PATCH .../disabled` → ban

### Records (`/api/collections/<name>/records`, Bearer optionnel selon règles)
- `GET /` (`?filter=&sort=&page=&perPage=`) → liste paginée
- `GET /<id>` → un record
- `POST /` → crée (`owner` = user authentifié) — JSON ou `multipart/form-data` (`data` JSON + fichiers nommés comme les champs `file`)
- `PATCH /<id>` → met à jour (idem multipart)
- `DELETE /<id>` → supprime
- `GET /<id>/files/<field>` → télécharge le fichier d'un champ `file`
- `GET /realtime` → SSE (`event: record`, payload `{action, recordId, record?}`)

Champ `file` : options `max:<octets>` et `mime:<type>` dans le schéma.
Sur une collection `auth` (`users`) : create/update refusés via cette API ;
`password_hash` n'est **jamais** renvoyé.

### Règles d'accès (V1)
- `""` → public
- `null` → admin seulement
- `@request.auth.id != ""` → utilisateur authentifié
- `@request.auth.id = <champ>` → propriétaire (compare `<champ>` à l'uid)

## Déploiement (Railway)

Voir le Dockerfile à la racine.
- Attacher un **Volume** sur le dossier de `DB_PATH` (sinon DB + `.jwt_secret` + `files/` repartent à zéro).
- Optionnel : `APP_NAME`, `JWT_SECRET` si plusieurs replicas.

## Limites connues (voir TODO.md)

- Fichiers : stockage local seulement (S3 plus tard)
- Parseur de filtre sans parenthèses
- Un seul compte admin
- `target` Discord : deep-link custom ou `localhost` uniquement
