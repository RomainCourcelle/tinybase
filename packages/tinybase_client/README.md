# tinybase_client

Client Flutter/Dart pour le backend **[TinyBase](https://github.com/RomainCourcelle/tinybase)** (auth, JWT, CRUD, fichiers, realtime).

> Pas affilié à la bibliothèque JavaScript [TinyBase](https://tinybase.org/).

## Install

```bash
flutter pub add tinybase_client
```

## Usage

```dart
import 'package:tinybase_client/tinybase_client.dart';

final client = TinyBaseClient(baseUrl: 'https://your-api.example.com');

await client.auth.login(email: 'a@b.c', password: 'secret');
await client.auth.restore(); // au démarrage de l'app

final notes = client.collection('notes');
final page = await notes.list();
await notes.create({'title': 'Hello'});

// Fichier (champ FieldType.file)
await notes.create(
  {'title': 'Avec pièce jointe'},
  files: {
    'attachment': FileUpload(filename: 'doc.pdf', bytes: pdfBytes),
  },
);
final url = notes.fileUrl(recordId, 'attachment');

// Realtime
final sub = notes.subscribe().listen((change) {
  print('${change.action} ${change.recordId}');
});
// sub.cancel() pour fermer le SSE
```

## Features

- Auth email/password
- OAuth Discord / Microsoft (browser) et Google / Apple (idToken natif)
- Refresh JWT automatique après un `401`
- CRUD `/api/collections/<name>/records`
- Upload multipart pour les champs `file`
- Realtime SSE (`subscribe`)
- Persistance tokens via `SharedPreferences` (ou `InMemoryTokenStore` pour les tests)

## Backend

Ce package parle à une instance [tinybase_server](https://github.com/RomainCourcelle/tinybase/tree/main/packages/tinybase_server).  
En prod (Railway), pointe `DB_PATH` vers un volume persisté (`FILES_DIR` suit le même dossier par défaut).

## License

MIT
