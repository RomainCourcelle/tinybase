import 'package:tinybase_shared/tinybase_shared.dart';

import 'string_utils.dart';

/// Génère un notifier Riverpod annoté (`@riverpod`) pour une collection.
///
/// L'app cliente doit exposer `tinyBaseClientProvider` (généré par le codegen
/// Auth en style riverpod, ou à déclarer à la main) puis lancer :
/// `dart run build_runner build`.
class RiverpodGenerator {
  static String generate(CollectionDefinition collection) {
    final className = toPascalCase(collection.name);
    final repoName = '${className}Repository';
    final notifierName = '${className}Notifier';
    final stateName = '${className}State';
    final snake = toSnakeCase(collection.name);
    final repoException = '${repoName}Exception';

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (collection "${collection.name}").
//
// pubspec.yaml (app) :
//   flutter_riverpod: ^2.6.1
//   riverpod_annotation: ^2.6.1
//   tinybase_client: ...
// dev_dependencies:
//   riverpod_generator: ^2.6.1
//   build_runner: ^2.4.13
//
// Puis : dart run build_runner build
//
// Prérequis : un `tinyBaseClientProvider` (voir codegen Auth riverpod).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/$snake.dart';
import '../repositories/${snake}_repository.dart';
// Fournit tinyBaseClientProvider — génère aussi Auth en style riverpod.
import 'auth_provider.dart';

part '${snake}_provider.g.dart';

@riverpod
$repoName ${toCamelCase(collection.name)}Repository(Ref ref) {
  return $repoName(ref.watch(tinyBaseClientProvider));
}

@riverpod
class $notifierName extends _\$$notifierName {
  static const perPage = 30;

  $repoName get _repo => ref.read(${toCamelCase(collection.name)}RepositoryProvider);

  @override
  $stateName build() => const $stateName();

  Future<void> load({int page = 1, String sort = '', String filter = ''}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.list(
        page: page,
        perPage: perPage,
        sort: sort,
        filter: filter,
      );
      state = state.copyWith(
        items: result.items,
        totalItems: result.totalItems,
        page: result.page,
        isLoading: false,
      );
    } on $repoException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    state = state.copyWith(clearError: true);
    try {
      await _repo.create(data);
      await load(page: state.page);
      return true;
    } on $repoException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    state = state.copyWith(clearError: true);
    try {
      await _repo.update(id, data);
      await load(page: state.page);
      return true;
    } on $repoException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = state.copyWith(clearError: true);
    try {
      await _repo.delete(id);
      await load(page: state.page);
      return true;
    } on $repoException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }
}

class $stateName {
  final List<$className> items;
  final bool isLoading;
  final String? errorMessage;
  final int page;
  final int totalItems;

  const $stateName({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.page = 1,
    this.totalItems = 0,
  });

  $stateName copyWith({
    List<$className>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    int? page,
    int? totalItems,
  }) {
    return $stateName(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      page: page ?? this.page,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}
''';
  }
}
