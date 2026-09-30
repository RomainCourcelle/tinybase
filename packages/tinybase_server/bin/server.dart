import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:tinybase/api/app.dart';
import 'package:tinybase/core/config.dart';
import 'package:tinybase/db/database.dart';

Future<void> main() async {
  await Config.init();
  await Database.init();

  final handler = buildApp();
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, Config.port);

  // ignore: avoid_print
  print('TinyBase démarré sur http://${server.address.host}:${server.port}');
  // ignore: avoid_print
  print('DB : ${Config.dbPath}');
}
