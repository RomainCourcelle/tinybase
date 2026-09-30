import 'dart:convert';

import 'field_definition.dart';

enum CollectionType { base, auth }

/// Noms de colonnes gérés automatiquement par TinyBase — toujours présents,
/// jamais dans [CollectionDefinition.fields]. Une collection `auth` n'a pas
/// de colonne `owner` (elle EST la table des utilisateurs) mais a
/// `email`/`password_hash`/`discord_id`/`disabled` en plus.
const List<String> kBaseAutoFields = ['id', 'created', 'updated', 'owner'];
const List<String> kAuthAutoFields = [
  'id',
  'email',
  'password_hash',
  'discord_id',
  'disabled',
  'created',
  'updated',
];

/// Champs jamais exposés par l'API records (même à l'admin) — secrets de
/// stockage, pas des données métier. Voir RecordsService._publicRecord.
const Set<String> kAuthSecretFields = {'password_hash'};

/// Noms réservés : tables système + collection auth bootstrap. Interdits à
/// la création / au renommage.
const Set<String> kReservedCollectionNames = {
  'users',
  '_collections',
  '_admins',
  '_settings',
};

/// Un nom de collection ou de champ ne peut contenir que lettres/chiffres/
/// underscore, et ne peut pas commencer par un chiffre — sécurité (ce sont
/// des identifiants SQL interpolés directement dans le SQL généré, jamais
/// passés en paramètre) et compat multi-plateforme.
final RegExp kValidIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

void assertValidIdentifier(String name, {required String kind}) {
  if (!kValidIdentifier.hasMatch(name)) {
    throw FormatException(
      'Nom de $kind invalide : "$name" (lettres/chiffres/underscore uniquement, '
      'ne doit pas commencer par un chiffre)',
    );
  }
}

/// Définition complète d'une collection telle que stockée dans la table
/// meta `_collections` côté serveur (lib/db/database.dart) et telle
/// qu'échangée sur le fil via l'API d'administration (consommée par
/// l'admin Flutter Web).
class CollectionDefinition {
  final String id;
  final String name;
  final CollectionType type;
  final List<FieldDefinition> fields;

  /// Règles d'accès par action — chaîne vide = public, null = personne
  /// (accessible seulement via le jeton admin). Voir rules_service.dart
  /// (côté serveur) pour la grammaire supportée en V1.
  final String? listRule;
  final String? viewRule;
  final String? createRule;
  final String? updateRule;
  final String? deleteRule;

  final DateTime created;
  final DateTime updated;

  const CollectionDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.fields,
    required this.created,
    required this.updated,
    this.listRule,
    this.viewRule,
    this.createRule,
    this.updateRule,
    this.deleteRule,
  });

  List<String> get autoFields => type == CollectionType.auth ? kAuthAutoFields : kBaseAutoFields;

  CollectionDefinition copyWith({
    String? name,
    List<FieldDefinition>? fields,
    String? listRule,
    String? viewRule,
    String? createRule,
    String? updateRule,
    String? deleteRule,
    DateTime? updated,
  }) {
    return CollectionDefinition(
      id: id,
      name: name ?? this.name,
      type: type,
      fields: fields ?? this.fields,
      created: created,
      updated: updated ?? this.updated,
      listRule: listRule ?? this.listRule,
      viewRule: viewRule ?? this.viewRule,
      createRule: createRule ?? this.createRule,
      updateRule: updateRule ?? this.updateRule,
      deleteRule: deleteRule ?? this.deleteRule,
    );
  }

  /// Construit depuis une ligne de la table meta `_collections` (colonnes
  /// snake_case, `fields` stocké en JSON brut). Côté serveur uniquement.
  factory CollectionDefinition.fromRow(Map<String, dynamic> row) {
    final fieldsJson = row['fields'] as String;
    final decoded = (fieldsJson.isEmpty) ? const [] : jsonDecode(fieldsJson) as List<dynamic>;
    return CollectionDefinition(
      id: row['id'] as String,
      name: row['name'] as String,
      type: CollectionType.values.firstWhere((t) => t.name == row['type']),
      fields: decoded.map((e) => FieldDefinition.fromJson(e as Map<String, dynamic>)).toList(),
      listRule: row['list_rule'] as String?,
      viewRule: row['view_rule'] as String?,
      createRule: row['create_rule'] as String?,
      updateRule: row['update_rule'] as String?,
      deleteRule: row['delete_rule'] as String?,
      created: DateTime.parse(row['created'] as String),
      updated: DateTime.parse(row['updated'] as String),
    );
  }

  /// Construit depuis la réponse JSON de l'API (camelCase — voir [toJson]).
  /// Utilisé côté admin (et réutilisable côté serveur si besoin un jour).
  factory CollectionDefinition.fromJson(Map<String, dynamic> json) {
    return CollectionDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      type: CollectionType.values.firstWhere((t) => t.name == json['type']),
      fields: (json['fields'] as List).map((f) => FieldDefinition.fromJson(f as Map<String, dynamic>)).toList(),
      listRule: json['listRule'] as String?,
      viewRule: json['viewRule'] as String?,
      createRule: json['createRule'] as String?,
      updateRule: json['updateRule'] as String?,
      deleteRule: json['deleteRule'] as String?,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'fields': fields.map((f) => f.toJson()).toList(),
        'listRule': listRule,
        'viewRule': viewRule,
        'createRule': createRule,
        'updateRule': updateRule,
        'deleteRule': deleteRule,
        'created': created.toIso8601String(),
        'updated': updated.toIso8601String(),
      };
}
