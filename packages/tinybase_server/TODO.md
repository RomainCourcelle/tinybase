# TinyBase — roadmap

## V1 (fait)
- [x] Moteur de collections dynamique (create/rename/edit fields/delete)
- [x] Migrations physiques : rename direct, add/drop column, reconstruction si changement de type
- [x] CRUD générique de records + filtre/tri/pagination
- [x] Auth email/password (bcrypt + JWT access/refresh)
- [x] Auth admin (table `_admins`, setup one-shot, plus de `X-Admin-Token`)
- [x] Règles d'accès basiques (public / authentifié / owner-based)
- [x] OAuth Discord (register/login + lien de compte)
- [x] Admin Flutter Web (collections + records + settings + users ban)
- [x] Génération de code Dart (modèle + repository + provider + auth)
- [x] Dockerfile prêt pour Railway
- [x] JWT_SECRET auto-persisté (`.jwt_secret` à côté de la DB)
- [x] Redaction `password_hash` + listRule users self-only
- [x] Schéma auth aligné (`disabled` / `discord_id`) + rename `users` interdit
- [x] Discord `target` allowlist + email Discord `verified` only
- [x] Setup admin atomique + filtre `IS NULL` + email normalisé

## V2
- [x] Stockage de fichiers (local d'abord, S3-compatible ensuite)
- [x] Temps réel (SSE sur les changements de collection)
- [x] Options `max:` / `mime:` par champ file
- [x] Collection `users` extensible (schéma + register + PATCH /me)
- [x] Docs Getting Started (tinybase_docs)
- [x] Hardening 0.3.x : SSE delete ACL + ping/reconnect, MIME wildcards, download Content-Type, multipart cap, CORS env, 500 génériques, OAuth fragment tokens, validation email/url/select
- [ ] Batch API (plusieurs opérations transactionnelles en un call)
- [ ] Backups automatiques programmés
- [ ] Logs/dashboard admin avancé
- [ ] Migrations versionnées du schéma (historique, rollback)
- [ ] Cron jobs / webhooks sortants
- [ ] Multi-admins / rôles
- [ ] Parseur de filtre avec parenthèses et précédence complète
- [ ] Expand / relations (FK) + validation select/email/url
- [ ] Rotation / révocation des refresh tokens
- [ ] Stockage S3-compatible (suite fichiers)
