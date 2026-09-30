/// Parseur minimal pour le paramètre `?filter=` des listes de records.
///
/// Grammaire V1 (volontairement simple — un vrai parseur avec parenthèses
/// et précédence complète est repoussé en V2) :
///   condition  := champ operateur valeur
///   operateur  := "=" | "!=" | ">" | "<" | ">=" | "<=" | "~"  (~ = contient)
///   valeur     := "chaîne entre guillemets" | nombre | true | false | null
///   expression := condition (("&&" | "||") condition)*
///
/// Pas de parenthèses, pas de précédence && vs || (évalué strictement de
/// gauche à droite) : suffisant pour les filtres qu'on écrit à la main
/// depuis une app cliente, mais à garder en tête comme limite connue.
class FilterParser {
  static final RegExp _condition = RegExp(
    r'^\s*(\w+)\s*(!=|>=|<=|=|>|<|~)\s*(.+?)\s*$',
  );

  /// Retourne le SQL (avec `?` en placeholders) et la liste des paramètres
  /// dans l'ordre. Lève [FormatException] si un nom de champ n'est pas dans
  /// [allowedColumns] (protection anti-injection : les noms de colonnes ne
  /// peuvent jamais être paramétrés en SQL, donc on les valide nous-mêmes).
  static (String sql, List<Object?> params) parse(String filter, Set<String> allowedColumns) {
    if (filter.trim().isEmpty) return ('', const []);

    // Découpe au premier niveau sur && / || en respectant les guillemets.
    final tokens = _tokenizeTopLevel(filter);
    final buffer = StringBuffer();
    final params = <Object?>[];

    for (final token in tokens) {
      if (token == '&&') {
        buffer.write(' AND ');
        continue;
      }
      if (token == '||') {
        buffer.write(' OR ');
        continue;
      }
      final match = _condition.firstMatch(token);
      if (match == null) {
        throw FormatException('Condition de filtre invalide : "$token"');
      }
      final field = match.group(1)!;
      final op = match.group(2)!;
      final rawValue = match.group(3)!;

      if (!allowedColumns.contains(field)) {
        throw FormatException('Champ de filtre inconnu : "$field"');
      }

      if (op == '~') {
        buffer.write('"$field" LIKE ?');
        params.add('%${_unquote(rawValue)}%');
      } else {
        final value = _parseValue(rawValue);
        // En SQL, `= NULL` / `!= NULL` sont TOUJOURS faux — il faut
        // `IS NULL` / `IS NOT NULL`. On ne bind pas de paramètre dans ce cas.
        if (value == null && (op == '=' || op == '!=')) {
          buffer.write(op == '=' ? '"$field" IS NULL' : '"$field" IS NOT NULL');
        } else {
          buffer.write('"$field" $op ?');
          params.add(value);
        }
      }
    }

    return (buffer.toString(), params);
  }

  static List<String> _tokenizeTopLevel(String filter) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < filter.length) {
      final char = filter[i];
      if (char == '"') inQuotes = !inQuotes;

      if (!inQuotes && filter.startsWith('&&', i)) {
        _flush(buffer, tokens);
        tokens.add('&&');
        i += 2;
        continue;
      }
      if (!inQuotes && filter.startsWith('||', i)) {
        _flush(buffer, tokens);
        tokens.add('||');
        i += 2;
        continue;
      }
      buffer.write(char);
      i++;
    }
    _flush(buffer, tokens);
    return tokens;
  }

  static void _flush(StringBuffer buffer, List<String> tokens) {
    final value = buffer.toString().trim();
    if (value.isNotEmpty) tokens.add(value);
    buffer.clear();
  }

  static String _unquote(String raw) {
    if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  static Object? _parseValue(String raw) {
    if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
      return raw.substring(1, raw.length - 1);
    }
    if (raw == 'true') return 1;
    if (raw == 'false') return 0;
    if (raw == 'null') return null;
    final asNum = num.tryParse(raw);
    if (asNum != null) return asNum;
    return raw;
  }
}
