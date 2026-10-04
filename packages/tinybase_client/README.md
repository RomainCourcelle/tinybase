# tinybase_client

Client Flutter/Dart pour le backend **[TinyBase](https://github.com/RomainCourcelle/tinybase)** (auth, JWT, CRUD collections).

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

final page = await client.collection('notes').list();
await client.collection('notes').create({'title': 'Hello'});
```

## Features

- Auth email/password
- OAuth Discord / Microsoft (browser) et Google / Apple (idToken natif)
- Refresh JWT automatique après un `401`
- CRUD `/api/collections/<name>/records`
- Persistance tokens via `SharedPreferences` (ou `InMemoryTokenStore` pour les tests)

## Backend

Ce package parle à une instance [tinybase_server](https://github.com/RomainCourcelle/tinybase/tree/main/packages/tinybase_server).  
En prod (Railway), pointe `DB_PATH` vers un volume persisté.

## License

MIT
