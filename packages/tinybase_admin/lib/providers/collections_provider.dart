import 'package:flutter/foundation.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../services/api_client.dart';

class CollectionsProvider extends ChangeNotifier {
  final ApiClient client;
  CollectionsProvider(this.client);

  List<CollectionDefinition> _collections = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedName;

  List<CollectionDefinition> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedName => _selectedName;
  CollectionDefinition? get selected =>
      _collections.where((c) => c.name == _selectedName).cast<CollectionDefinition?>().firstOrNull;

  void select(String? name) {
    _selectedName = name;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _collections = await client.listCollections();
      _collections.sort((a, b) => a.name.compareTo(b.name));
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    required String name,
    required List<FieldDefinition> fields,
    String? listRule = '',
    String? viewRule = '',
    String? createRule = '',
    String? updateRule = '',
    String? deleteRule = '',
  }) async {
    _errorMessage = null;
    try {
      final col = await client.createCollection(
        name: name,
        type: CollectionType.base,
        fields: fields,
        listRule: listRule,
        viewRule: viewRule,
        createRule: createRule,
        updateRule: updateRule,
        deleteRule: deleteRule,
      );
      await load();
      _selectedName = col.name;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(
    String currentName, {
    String? newName,
    List<FieldDefinition>? fields,
    Map<String, String>? renames,
    required String? listRule,
    required String? viewRule,
    required String? createRule,
    required String? updateRule,
    required String? deleteRule,
  }) async {
    _errorMessage = null;
    try {
      final col = await client.updateCollection(
        currentName,
        newName: newName,
        fields: fields,
        renames: renames,
        listRule: listRule,
        viewRule: viewRule,
        createRule: createRule,
        updateRule: updateRule,
        deleteRule: deleteRule,
      );
      await load();
      _selectedName = col.name;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String name) async {
    _errorMessage = null;
    try {
      await client.deleteCollection(name);
      if (_selectedName == name) _selectedName = null;
      await load();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
