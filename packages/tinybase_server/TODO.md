# TinyBase — roadmap

## V1 (en cours dans ce commit)
- [x] Moteur de collections dynamique (create/rename/edit fields/delete)
- [x] Migrations physiques : rename direct, add/drop column, reconstruction si changement de type
- [x] CRUD générique de records + filtre/tri/pagination
- [x] Auth email/password (bcrypt + JWT access/refresh)
- [x] Règles d'accès basiques (public / authentifié / owner-based)
- [x] Dockerfile prêt pour Railway
- [ ] Admin Flutter Web (CRUD collections + records + users)
- [ ] Génération de code Dart (modèle + repository + provider) par collection, exposée via une route admin pour que Nexus Code Launcher puisse l'appeler directement pendant le scaffolding

## V2
- [ ] OAuth Discord (register/login)
- [ ] Stockage de fichiers (local d'abord, S3-compatible ensuite)
- [ ] Temps réel (SSE sur les changements de collection)
- [ ] Batch API (plusieurs opérations transactionnelles en un call)
- [ ] Backups automatiques programmés
- [ ] Logs/dashboard admin avancé
- [ ] Migrations versionnées du schéma (historique, rollback)
- [ ] Cron jobs / webhooks sortants
- [ ] Vraie auth admin (table d'admins + rôles) au lieu du jeton statique
- [ ] Parseur de filtre avec parenthèses et précédence complète
