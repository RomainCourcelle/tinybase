# TinyBase

Backend léger (SQLite) + admin Flutter Web + client Dart/Flutter + codegen.

## Packages

| Package | Rôle |
|---------|------|
| [`tinybase_server`](packages/tinybase_server) | API HTTP (auth, collections, admin) |
| [`tinybase_client`](packages/tinybase_client) | SDK Flutter publié sur [pub.dev](https://pub.dev/packages/tinybase_client) |
| [`tinybase_admin`](packages/tinybase_admin) | Panel d’admin (Flutter Web) |
| [`tinybase_docs`](packages/tinybase_docs) | Getting Started (Flutter Web, hébergeable sur Railway) |
| [`tinybase_codegen`](packages/tinybase_codegen) | Génération modèles / Provider / Riverpod |
| [`tinybase_shared`](packages/tinybase_shared) | Types partagés |

**Docs en ligne :** [https://tinybase-documentation.up.railway.app/](https://tinybase-documentation.up.railway.app/)  
Source : [`packages/tinybase_docs`](packages/tinybase_docs) — Dockerfile Path = `packages/tinybase_docs/Dockerfile` (service Railway séparé de l’API).

## Railway (prod)

Variables importantes :

- `DB_PATH` → chemin **sur le volume** (ex. `/data/tinybase.db`)
- Volume monté sur le même préfixe (ex. `/data`) — couvre aussi `files/` et `.jwt_secret`
- `PORT` injecté par Railway
- `JWT_SECRET` recommandé si plusieurs instances (sinon fichier `.jwt_secret` à côté de la DB)
- `APP_NAME` (optionnel) → nom affiché dans l'admin (sinon dérivé du domaine)
- `FILES_DIR` / `MAX_FILE_SIZE` (optionnels) → stockage fichiers
- `PUBLIC_BASE_URL` → URL publique de l'API (liens email, meta `deleteAccountUrl`)
- SMTP (reset password) → **Admin → Réglages → Email / SMTP** (pas besoin d’env)
- Fallback legacy optionnel : `SMTP_*` si rien n’est configuré dans l’admin
- Pages stores : `/delete-account`, `/reset-password`

Sans `DB_PATH` sur volume, la base est perdue à chaque redeploy.

## License

MIT
