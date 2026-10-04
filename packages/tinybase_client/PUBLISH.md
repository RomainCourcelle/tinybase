# Publier `tinybase_client`

```bash
cd packages/tinybase_client
dart pub publish --dry-run
dart pub publish
```

Puis tagger :

```bash
cd ../..
git tag v0.1.1
git push origin v0.1.1
```

Vérifier : https://pub.dev/packages/tinybase_client
