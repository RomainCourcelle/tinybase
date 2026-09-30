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
- [ ] Stockage de fichiers (local d'abord, S3-compatible ensuite)
- [ ] Temps réel (SSE sur les changements de collection)
- [ ] Batch API (plusieurs opérations transactionnelles en un call)
- [ ] Backups automatiques programmés
- [ ] Logs/dashboard admin avancé
- [ ] Migrations versionnées du schéma (historique, rollback)
- [ ] Cron jobs / webhooks sortants
- [ ] Multi-admins / rôles
- [ ] Parseur de filtre avec parenthèses et précédence complète
- [ ] Expand / relations (FK) + validation select/email/url
- [ ] Rotation / révocation des refresh tokens
