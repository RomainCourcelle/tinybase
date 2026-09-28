/// Contexte d'authentification attaché à une requête (voir
/// api/middleware/auth_middleware.dart). `userId` est null pour une requête
/// anonyme. `isAdmin` est vrai quand un jeton admin valide (compte
/// email/mot de passe — voir AdminService) est présent en
/// `Authorization: Bearer` — un admin outrepasse TOUTES les règles
/// d'accès, y compris sur les records (pas seulement sur le schéma) : c'est
/// ce qui permet à l'admin Flutter Web de parcourir toutes les données peu
/// importe les règles owner-based définies par collection.
class AuthContext {
  final String? userId;
  final bool isAdmin;
  const AuthContext({this.userId, this.isAdmin = false});
  const AuthContext.anonymous() : userId = null, isAdmin = false;
  bool get isAuthenticated => userId != null;
}

/// Résultat de l'évaluation d'une règle pour une action de LECTURE (list) :
/// soit refusé, soit autorisé avec éventuellement un prédicat SQL
/// supplémentaire à appliquer (ex. `owner = ?`).
class RuleDecision {
  final bool allowed;
  final String? sqlPredicate; // ex. `"owner" = ?`
  final List<Object?> params;
  const RuleDecision.deny() : allowed = false, sqlPredicate = null, params = const [];
  const RuleDecision.allow({this.sqlPredicate, this.params = const []}) : allowed = true;
}

/// Évaluateur de règles d'accès V1 — grammaire volontairement restreinte à
/// ce que NexusBase utilisait déjà (accès public ou "owner-based"), mais
/// évalué proprement au niveau SQL (donc pagination/tri corrects) plutôt
/// que par un filtrage a posteriori en Dart. Les patterns non reconnus sont
/// refusés plutôt qu'ignorés silencieusement — mieux vaut un 403 qu'une
/// règle qui ne fait rien sans prévenir.
///
/// Grammaire supportée :
///   - `""` (chaîne vide)              -> accès public
///   - `null` (absent)                 -> personne (réservé à l'admin, V2)
///   - `@request.auth.id != ""`        -> tout utilisateur authentifié
///   - `@request.auth.id = <champ>`    -> uniquement le propriétaire du
///                                        record (compare `<champ>` == uid)
class RulesService {
  const RulesService();

  static final RegExp _ownerPattern = RegExp(r'^@request\.auth\.id\s*=\s*(\w+)$');
  static final RegExp _authOnlyPattern = RegExp(r'^@request\.auth\.id\s*!=\s*""$');

  /// Pour list/view : calcule si la requête est autorisée et, si besoin, le
  /// prédicat SQL à ajouter au WHERE.
  RuleDecision forRead(String? rule, AuthContext auth) {
    if (auth.isAdmin) return const RuleDecision.allow();
    if (rule == null) return const RuleDecision.deny();
    final trimmed = rule.trim();
    if (trimmed.isEmpty) return const RuleDecision.allow();

    if (_authOnlyPattern.hasMatch(trimmed)) {
      return auth.isAuthenticated ? const RuleDecision.allow() : const RuleDecision.deny();
    }

    final ownerMatch = _ownerPattern.firstMatch(trimmed);
    if (ownerMatch != null) {
      if (!auth.isAuthenticated) return const RuleDecision.deny();
      final field = ownerMatch.group(1)!;
      return RuleDecision.allow(sqlPredicate: '"$field" = ?', params: [auth.userId]);
    }

    // Règle non reconnue par ce parseur minimal -> on refuse plutôt que de
    // laisser passer une règle qu'on n'a pas su interpréter correctement.
    return const RuleDecision.deny();
  }

  /// Pour create : l'`owner` est de toute façon assigné côté serveur (voir
  /// records_service.dart), donc on ne vérifie que la condition
  /// d'authentification de la règle, pas l'égalité de champ.
  bool forCreate(String? rule, AuthContext auth) {
    if (auth.isAdmin) return true;
    if (rule == null) return false;
    final trimmed = rule.trim();
    if (trimmed.isEmpty) return true;
    if (_authOnlyPattern.hasMatch(trimmed)) return auth.isAuthenticated;
    if (_ownerPattern.hasMatch(trimmed)) return auth.isAuthenticated;
    return false;
  }

  /// Pour update/delete : on a déjà le record en main (récupéré avant
  /// mutation), donc on peut évaluer la comparaison de propriétaire pour de
  /// vrai contre sa valeur actuelle.
  bool forRecordAction(String? rule, AuthContext auth, Map<String, dynamic> record) {
    if (auth.isAdmin) return true;
    if (rule == null) return false;
    final trimmed = rule.trim();
    if (trimmed.isEmpty) return true;
    if (_authOnlyPattern.hasMatch(trimmed)) return auth.isAuthenticated;

    final ownerMatch = _ownerPattern.firstMatch(trimmed);
    if (ownerMatch != null) {
      if (!auth.isAuthenticated) return false;
      final field = ownerMatch.group(1)!;
      return record[field] == auth.userId;
    }
    return false;
  }
}
