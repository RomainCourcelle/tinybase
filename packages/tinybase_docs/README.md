# TinyBase Docs

Site de documentation Flutter Web (Getting Started, Exemple, Changelog).

## Local

```bash
cd packages/tinybase_docs
flutter pub get
flutter run -d chrome
```

## Railway

Service **statique séparé** de l’API.

1. Nouveau service → repo monorepo TinyBase  
2. **Dockerfile Path** : `packages/tinybase_docs/Dockerfile`  
3. Root Directory : laisser la racine du monorepo (build context)  
4. Domaine custom optionnel : `docs.tonprojet.com`

Aucune variable d’env obligatoire. Railway injecte `PORT`.

## Deep links

| Page | Hash |
|------|------|
| Home | `/#/` |
| Getting started | `/#/getting-started` |
| Exemple | `/#/example` |
| Changelog | `/#/changelog` |
