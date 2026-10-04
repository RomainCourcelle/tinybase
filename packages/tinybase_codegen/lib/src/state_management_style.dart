/// Style de state management produit par le codegen TinyBase.
enum StateManagementStyle {
  /// `ChangeNotifier` + package `provider` (défaut, historique).
  provider,

  /// Notifiers annotés `@riverpod` (nécessite `build_runner` côté app).
  riverpod;

  /// Parse le query param `style` (API) / choix admin. Défaut = [provider].
  static StateManagementStyle parse(String? raw) {
    final value = raw?.trim().toLowerCase();
    switch (value) {
      case null:
      case '':
      case 'provider':
        return StateManagementStyle.provider;
      case 'riverpod':
        return StateManagementStyle.riverpod;
      default:
        throw FormatException(
          'style codegen inconnu : "$raw" (attendu : provider | riverpod)',
        );
    }
  }

  String get apiValue => name;

  String get label => switch (this) {
        StateManagementStyle.provider => 'Provider (ChangeNotifier)',
        StateManagementStyle.riverpod => 'Riverpod (annotations)',
      };
}
