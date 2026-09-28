import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

/// Records de la collection actuellement sélectionnée. Un nouveau provider
/// est recréé (voir main.dart) à chaque changement de collection plutôt que
/// de gérer plusieurs collections en mémoire — plus simple, et l'admin
/// n'affiche de toute façon qu'une collection à la fois.
class RecordsProvider extends ChangeNotifier {
  final ApiClient client;
  final String collectionName;
  RecordsProvider(this.client, this.collectionName);

  List<Map<String, dynamic>> items = [];
  int totalItems = 0;
  int page = 1;
  static const perPage = 50;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({int page = 1}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await client.listRecords(collectionName, page: page, perPage: perPage);
      items = result.items;
      totalItems = result.totalItems;
      this.page = result.page;
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    errorMessage = null;
    try {
      await client.createRecord(collectionName, data);
      await load(page: 1);
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    errorMessage = null;
    try {
      await client.updateRecord(collectionName, id, data);
      await load(page: page);
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    errorMessage = null;
    try {
      await client.deleteRecord(collectionName, id);
      await load(page: page);
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Ban/réactivation d'un compte `users` (voir ApiClient.setUserDisabled) —
  /// n'a de sens que sur la collection `users`, appelé uniquement depuis
  /// RecordsScreen quand `_isAuthCollection` est vrai.
  Future<bool> setUserDisabled(String id, bool disabled) async {
    errorMessage = null;
    try {
      await client.setUserDisabled(id, disabled);
      await load(page: page);
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}
