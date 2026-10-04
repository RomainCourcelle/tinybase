# Publier `tinybase_client` 0.1.0

À faire **une fois** depuis ta machine (compte pub.dev requis).

```bash
cd packages/tinybase_client
dart pub login
dart pub publish --dry-run
dart pub publish
```

Puis tagger le monorepo :

```bash
cd ../..
git tag v0.1.0
git push origin v0.1.0
```

Vérifier : https://pub.dev/packages/tinybase_client
