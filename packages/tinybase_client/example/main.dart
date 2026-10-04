import 'package:tinybase_client/tinybase_client.dart';

/// Minimal usage of [TinyBaseClient].
///
/// Replace [baseUrl] with your TinyBase server URL.
Future<void> main() async {
  final client = TinyBaseClient(
    baseUrl: 'https://your-api.example.com',
    tokenStore: InMemoryTokenStore(),
  );

  // await client.auth.login(email: 'a@b.c', password: 'secret');
  // await client.auth.restore();

  // final page = await client.collection('notes').list();
  // print(page.totalItems);

  print('TinyBase client ready for ${client.baseUrl}');
}
