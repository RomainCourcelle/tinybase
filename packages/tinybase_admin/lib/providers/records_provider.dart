import 'dart:async';

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
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

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

  /// Démarre l'abonnement SSE (idempotent).
  void startRealtime() {
    if (_realtimeSub != null) return;
    _realtimeSub = client.subscribeRecords(collectionName).listen(
      _onRealtimeEvent,
      onError: (_) {
        // Reconnexion soft : on ignore et on laisse l'utilisateur recharger.
      },
    );
  }

  void stopRealtime() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  void _onRealtimeEvent(Map<String, dynamic> event) {
    final action = event['action'] as String?;
    final recordId = event['recordId'] as String?;
    if (action == null || recordId == null) return;

    switch (action) {
      case 'create':
        final record = event['record'];
        if (record is Map) {
          final map = Map<String, dynamic>.from(record);
          // N'insère en tête que sur la première page.
          if (page == 1) {
            items = [map, ...items.where((r) => r['id'] != recordId)];
            if (items.length > perPage) items = items.take(perPage).toList();
          }
          totalItems += 1;
          notifyListeners();
        }
      case 'update':
        final record = event['record'];
        if (record is Map) {
          final map = Map<String, dynamic>.from(record);
          final idx = items.indexWhere((r) => r['id'] == recordId);
          if (idx >= 0) {
            items = [...items]..[idx] = map;
            notifyListeners();
          }
        }
      case 'delete':
        final before = items.length;
        items = items.where((r) => r['id'] != recordId).toList();
        if (items.length != before) {
          totalItems = (totalItems - 1).clamp(0, 1 << 30);
          notifyListeners();
        }
    }
  }

  Future<bool> create(
    Map<String, dynamic> data, {
    Map<String, ({String filename, List<int> bytes, String? contentType})>? files,
  }) async {
    errorMessage = null;
    try {
      await client.createRecord(collectionName, data, files: files);
      await load(page: 1);
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(
    String id,
    Map<String, dynamic> data, {
    Map<String, ({String filename, List<int> bytes, String? contentType})>? files,
  }) async {
    errorMessage = null;
    try {
      await client.updateRecord(collectionName, id, data, files: files);
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

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
