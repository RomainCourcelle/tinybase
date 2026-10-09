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

Doc : [`packages/tinybase_docs`](packages/tinybase_docs) — Flutter Web (Getting Started + Exemple).  
Déploie sur Railway avec **Dockerfile Path** = `packages/tinybase_docs/Dockerfile` (service séparé de l’API).

## Railway (prod)

Variables importantes :

- `DB_PATH` → chemin **sur le volume** (ex. `/data/tinybase.db`)
- Volume monté sur le même préfixe (ex. `/data`) — couvre aussi `files/` et `.jwt_secret`
- `PORT` injecté par Railway
- `JWT_SECRET` recommandé si plusieurs instances (sinon fichier `.jwt_secret` à côté de la DB)
- `APP_NAME` (optionnel) → nom affiché dans l'admin (sinon dérivé du domaine)
- `FILES_DIR` / `MAX_FILE_SIZE` (optionnels) → stockage fichiers

Sans `DB_PATH` sur volume, la base est perdue à chaque redeploy.

## License

MIT
