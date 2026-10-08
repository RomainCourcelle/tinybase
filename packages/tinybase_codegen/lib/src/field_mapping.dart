import 'package:tinybase_shared/tinybase_shared.dart';

/// Mappe un [FieldType] vers son type Dart et sait générer les expressions
/// de (dé)sérialisation JSON correspondantes pour le générateur de modèle.
///
/// Choix délibérés pour rester robuste face à ce que renvoie vraiment
/// l'API TinyBase (voir records_service.dart côté serveur, qui ne
/// post-traite pas les lignes SQLite brutes) :
/// - [FieldType.boolean] est stocké en SQLite comme INTEGER (0/1) — jamais
///   nullable côté modèle Dart généré (défaut `false`), pour éviter un
///   type `bool?` à trois états qui ne correspond à rien côté serveur.
/// - [FieldType.date] est stocké en TEXT ISO 8601.
/// - [FieldType.json] est stocké en TEXT (une chaîne JSON déjà encodée) —
///   le modèle généré le décode en `dynamic` à la lecture et le renvoie
///   brut à l'écriture (le serveur se charge de le ré-encoder si besoin,
///   voir `FieldType.coerce`).
class FieldMapping {
  final FieldType type;
  const FieldMapping(this.type);

  /// Type Dart de base, sans le `?` de nullabilité.
  String get _baseType {
    switch (type) {
      case FieldType.number:
        return 'double';
      case FieldType.boolean:
        return 'bool';
      case FieldType.date:
        return 'DateTime';
      case FieldType.json:
        return 'dynamic';
      case FieldType.text:
      case FieldType.email:
      case FieldType.url:
      case FieldType.select:
      case FieldType.relation:
      case FieldType.file:
        return 'String';
    }
  }

  /// Type Dart tel qu'il apparaît dans le modèle généré. `required`
  /// détermine la nullabilité (sauf pour boolean/json, cf. doc de classe).
  String dartType({required bool required}) {
    if (type == FieldType.json) return 'dynamic';
    if (type == FieldType.boolean) return 'bool';
    return required ? _baseType : '$_baseType?';
  }

  /// Type Dart utilisé pour le paramètre optionnel d'un `copyWith` —
  /// toujours nullable (y compris pour boolean, dont le champ du modèle
  /// lui-même ne l'est pas) puisque `null` y signifie "ne pas changer cette
  /// valeur", pas "mettre à null".
  String get copyWithParamType => type == FieldType.json ? 'dynamic' : '$_baseType?';

  /// Expression Dart lisant `json['<name>']` vers le type du modèle.
  String fromJsonExpr(String jsonKey, {required bool required}) {
    switch (type) {
      case FieldType.number:
        return required ? "(json['$jsonKey'] as num).toDouble()" : "(json['$jsonKey'] as num?)?.toDouble()";
      case FieldType.boolean:
        return "(json['$jsonKey'] == 1 || json['$jsonKey'] == true)";
      case FieldType.date:
        return required
            ? "DateTime.parse(json['$jsonKey'] as String)"
            : "json['$jsonKey'] != null ? DateTime.parse(json['$jsonKey'] as String) : null";
      case FieldType.json:
        return "json['$jsonKey'] is String ? jsonDecode(json['$jsonKey'] as String) : json['$jsonKey']";
      case FieldType.text:
      case FieldType.email:
      case FieldType.url:
      case FieldType.select:
      case FieldType.relation:
      case FieldType.file:
        return required ? "json['$jsonKey'] as String" : "json['$jsonKey'] as String?";
    }
  }

  /// Expression Dart sérialisant le champ du modèle (nommé [fieldName])
  /// pour le body JSON envoyé au serveur (create/update).
  String toJsonExpr(String fieldName, {required bool required}) {
    switch (type) {
      case FieldType.date:
        return required
            ? '$fieldName.toIso8601String()'
            : '$fieldName?.toIso8601String()';
      case FieldType.number:
      case FieldType.boolean:
      case FieldType.json:
      case FieldType.text:
      case FieldType.email:
      case FieldType.url:
      case FieldType.select:
      case FieldType.relation:
      case FieldType.file:
        return fieldName;
    }
  }
}
