import 'package:tinybase_shared/tinybase_shared.dart';

import 'field_mapping.dart';
import 'string_utils.dart';

/// Génère la classe modèle Dart (immuable, `fromJson`/`toJson`/`copyWith`)
/// d'une collection — un champ Dart par [FieldDefinition], plus les champs
/// auto (id/created/updated/owner) gérés par [CollectionDefinition].
class ModelGenerator {
  static String generate(CollectionDefinition collection) {
    final className = toPascalCase(collection.name);
    final hasOwner = collection.type == CollectionType.base;
    final usesJson = collection.fields.any((f) => f.type == FieldType.json);

    final buffer = StringBuffer();
    buffer.writeln('// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.');
    buffer.writeln('// Régénère depuis l\'admin TinyBase (collection "${collection.name}").');
    if (usesJson) buffer.writeln("import 'dart:convert';");
    buffer.writeln();
    buffer.writeln('class $className {');
    buffer.writeln('  final String id;');
    buffer.writeln('  final DateTime created;');
    buffer.writeln('  final DateTime updated;');
    if (hasOwner) buffer.writeln('  final String? owner;');
    for (final field in collection.fields) {
      final mapping = FieldMapping(field.type);
      buffer.writeln('  final ${mapping.dartType(required: field.required)} ${toCamelCase(field.name)};');
    }
    buffer.writeln();

    // Constructeur
    buffer.writeln('  const $className({');
    buffer.writeln('    required this.id,');
    buffer.writeln('    required this.created,');
    buffer.writeln('    required this.updated,');
    if (hasOwner) buffer.writeln('    this.owner,');
    for (final field in collection.fields) {
      final camel = toCamelCase(field.name);
      final isBoolOrJson = field.type == FieldType.boolean || field.type == FieldType.json;
      if (field.required && !isBoolOrJson) {
        buffer.writeln('    required this.$camel,');
      } else if (field.type == FieldType.boolean) {
        buffer.writeln('    this.$camel = false,');
      } else {
        buffer.writeln('    this.$camel,');
      }
    }
    buffer.writeln('  });');
    buffer.writeln();

    // fromJson
    buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return $className(');
    buffer.writeln("      id: json['id'] as String,");
    buffer.writeln("      created: DateTime.parse(json['created'] as String),");
    buffer.writeln("      updated: DateTime.parse(json['updated'] as String),");
    if (hasOwner) buffer.writeln("      owner: json['owner'] as String?,");
    for (final field in collection.fields) {
      final camel = toCamelCase(field.name);
      final mapping = FieldMapping(field.type);
      buffer.writeln('      $camel: ${mapping.fromJsonExpr(field.name, required: field.required)},');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // toJson — uniquement les champs éditables (id/created/updated/owner
    // sont gérés par le serveur, jamais envoyés dans le body create/update).
    buffer.writeln('  /// Body JSON pour un create/update — n\'inclut volontairement pas');
    buffer.writeln('  /// id/created/updated/owner, gérés côté serveur.');
    buffer.writeln('  Map<String, dynamic> toJson() => {');
    for (final field in collection.fields) {
      final camel = toCamelCase(field.name);
      final mapping = FieldMapping(field.type);
      buffer.writeln("        '${field.name}': ${mapping.toJsonExpr(camel)},");
    }
    buffer.writeln('      };');
    buffer.writeln();

    // copyWith
    buffer.writeln('  $className copyWith({');
    for (final field in collection.fields) {
      final camel = toCamelCase(field.name);
      final mapping = FieldMapping(field.type);
      buffer.writeln('    ${mapping.copyWithParamType} $camel,');
    }
    buffer.writeln('  }) {');
    buffer.writeln('    return $className(');
    buffer.writeln('      id: id,');
    buffer.writeln('      created: created,');
    buffer.writeln('      updated: updated,');
    if (hasOwner) buffer.writeln('      owner: owner,');
    for (final field in collection.fields) {
      final camel = toCamelCase(field.name);
      buffer.writeln('      $camel: $camel ?? this.$camel,');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln('}');
    return buffer.toString();
  }
}
