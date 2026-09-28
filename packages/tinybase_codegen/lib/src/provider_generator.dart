import 'package:tinybase_shared/tinybase_shared.dart';

import 'string_utils.dart';

/// Génère un `ChangeNotifier` (pattern Provider) qui expose la liste des
/// records de la collection avec pagination, plus create/update/delete —
/// même forme que RecordsProvider dans tinybase_admin, pour que ça reste
/// familier une fois branché dans une vraie app.
class ProviderGenerator {
  static String generate(CollectionDefinition collection) {
    final className = toPascalCase(collection.name);
    final repoName = '${className}Repository';
    final providerName = '${className}Provider';
    final snake = toSnakeCase(collection.name);

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (collection "${collection.name}").
import 'package:flutter/foundation.dart';

import '../models/$snake.dart';
import '../repositories/${snake}_repository.dart';

class $providerName extends ChangeNotifier {
  final $repoName repository;
  static const perPage = 30;

  $providerName(this.repository);

  List<$className> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _page = 1;
  int _totalItems = 0;

  List<$className> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get page => _page;
  int get totalItems => _totalItems;

  Future<void> load({int page = 1, String sort = '', String filter = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await repository.list(page: page, perPage: perPage, sort: sort, filter: filter);
      _items = result.items;
      _totalItems = result.totalItems;
      _page = result.page;
    } on ${repoName}Exception catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      await repository.create(data);
      await load(page: _page);
      return true;
    } on ${repoName}Exception catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      await repository.update(id, data);
      await load(page: _page);
      return true;
    } on ${repoName}Exception catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    _errorMessage = null;
    try {
      await repository.delete(id);
      await load(page: _page);
      return true;
    } on ${repoName}Exception catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}
''';
  }
}
