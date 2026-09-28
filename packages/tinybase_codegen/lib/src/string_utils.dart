/// Conversions de casse pour dériver des noms Dart depuis le nom d'une
/// collection ou d'un champ. Les noms de collection/champ sont déjà validés
/// côté serveur (voir `kValidIdentifier` dans tinybase_shared) donc on n'a
/// pas à gérer d'espaces/tirets exotiques — juste `snake_case`/`camelCase`.

String toPascalCase(String input) {
  final parts = input.split(RegExp(r'[_\-\s]+')).where((p) => p.isNotEmpty);
  return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String toCamelCase(String input) {
  final pascal = toPascalCase(input);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
}

String toSnakeCase(String input) {
  final withUnderscores = input.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  return withUnderscores.toLowerCase();
}
