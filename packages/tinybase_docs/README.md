# tinybase_docs

Getting Started TinyBase (Flutter Web) — switch global Provider / Riverpod.

## Local

```bash
cd packages/tinybase_docs
flutter pub get
flutter run -d chrome
```

## Railway

- Build context : racine du monorepo
- Dockerfile Path : `packages/tinybase_docs/Dockerfile`
- Domaine dédié (ex. `docs.tonprojet.com`)

Le service docs est **séparé** de l’API TinyBase (static only, pas de SQLite).
