import 'package:tinybase_shared/tinybase_shared.dart';

import 'string_utils.dart';

/// Repository typé qui s'appuie sur [TinyBaseClient.collection] (refresh auto).
class RepositoryGenerator {
  static String generate(CollectionDefinition collection) {
    final className = toPascalCase(collection.name);
    final repoName = '${className}Repository';
    final collectionName = collection.name;
    final snake = toSnakeCase(collection.name);

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (collection "$collectionName").
//
// Nécessite tinybase_client dans le pubspec.
import 'package:tinybase_client/tinybase_client.dart';

import '../models/$snake.dart';

class ${repoName}Exception implements Exception {
  final int statusCode;
  final String message;
  ${repoName}Exception(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Accès CRUD à la collection "$collectionName" via [TinyBaseClient].
class $repoName {
  final TinyBaseClient client;
  $repoName(this.client);

  TinyBaseCollection get _col => client.collection('$collectionName');

  Future<({List<$className> items, int totalItems, int page, int perPage})> list({
    int page = 1,
    int perPage = 30,
    String sort = '',
    String filter = '',
  }) async {
    try {
      final result = await _col.list(page: page, perPage: perPage, sort: sort, filter: filter);
      return (
        items: result.items.map($className.fromJson).toList(),
        totalItems: result.totalItems,
        page: result.page,
        perPage: result.perPage,
      );
    } on TinyBaseException catch (e) {
      throw ${repoName}Exception(e.statusCode, e.message);
    }
  }

  Future<$className> getOne(String id) async {
    try {
      return $className.fromJson(await _col.getOne(id));
    } on TinyBaseException catch (e) {
      throw ${repoName}Exception(e.statusCode, e.message);
    }
  }

  Future<$className> create(Map<String, dynamic> data) async {
    try {
      return $className.fromJson(await _col.create(data));
    } on TinyBaseException catch (e) {
      throw ${repoName}Exception(e.statusCode, e.message);
    }
  }

  Future<$className> update(String id, Map<String, dynamic> data) async {
    try {
      return $className.fromJson(await _col.update(id, data));
    } on TinyBaseException catch (e) {
      throw ${repoName}Exception(e.statusCode, e.message);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _col.delete(id);
    } on TinyBaseException catch (e) {
      throw ${repoName}Exception(e.statusCode, e.message);
    }
  }
}
''';
  }
}
