import 'package:tinybase_shared/tinybase_shared.dart';

import 'string_utils.dart';

/// Repository typé qui s'appuie sur [TinyBaseClient.collection] (refresh auto).
class RepositoryGenerator {
  static String generate(CollectionDefinition collection) {
    final className = toPascalCase(collection.name);
    final repoName = '${className}Repository';
    final collectionName = collection.name;
    final snake = toSnakeCase(collection.name);
    final hasFileFields = collection.fields.any((f) => f.type == FieldType.file);

    final filesParam = hasFileFields
        ? ', {\n    Map<String, FileUpload>? files,\n  }'
        : '';
    final filesArg = hasFileFields ? ', files: files' : '';

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

  Future<$className> create(Map<String, dynamic> data$filesParam) async {
    try {
      return $className.fromJson(await _col.create(data$filesArg));
    } on TinyBaseException catch (e) {
      throw ${repoName}Exception(e.statusCode, e.message);
    }
  }

  Future<$className> update(String id, Map<String, dynamic> data$filesParam) async {
    try {
      return $className.fromJson(await _col.update(id, data$filesArg));
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

  /// URL de téléchargement d'un champ fichier.
  String fileUrl(String recordId, String field) => _col.fileUrl(recordId, field);

  /// Abonnement SSE aux changements de la collection.
  Stream<RecordChange> subscribe() => _col.subscribe();
}
''';
  }
}
