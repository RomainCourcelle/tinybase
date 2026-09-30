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

## API

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

### Records (`/api/collections/<name>/records`, Bearer optionnel selon règles)
- `GET /` (`?filter=&sort=&page=&perPage=`) → liste paginée
- `GET /<id>` → un record
- `POST /` → crée (`owner` = user authentifié)
- `PATCH /<id>` → met à jour
- `DELETE /<id>` → supprime

Sur une collection `auth` (`users`) : create/update refusés via cette API ;
`password_hash` n'est **jamais** renvoyé.

### Règles d'accès (V1)
- `""` → public
- `null` → admin seulement
- `@request.auth.id != ""` → utilisateur authentifié
- `@request.auth.id = <champ>` → propriétaire (compare `<champ>` à l'uid)

## Déploiement (Railway)

Voir le Dockerfile à la racine.
- Attacher un **Volume** sur le dossier de `DB_PATH` (sinon DB + `.jwt_secret` repartent à zéro).
- Optionnel : fixer `JWT_SECRET` si plusieurs replicas.

## Limites connues V1 (voir TODO.md)

- Pas de stockage de fichiers / temps réel (V2)
- Parseur de filtre sans parenthèses
- Un seul compte admin
- `target` Discord : deep-link custom ou `localhost` uniquement
