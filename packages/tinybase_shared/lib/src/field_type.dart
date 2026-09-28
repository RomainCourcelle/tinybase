import 'dart:convert';

/// Types de champ supportés pour un [FieldDefinition]. Chaque type sait se
/// mapper vers un type de colonne SQLite (voir [FieldType.sqlColumnType]),
/// valider/normaliser une valeur JSON entrante (voir [FieldType.coerce]) et
/// s'afficher dans l'admin (voir l'extension [FieldTypeLabel]).
enum FieldType {
  text,
  number,
  boolean,
  date,
  email,
  url,
  select,
  relation,
  json;

  static FieldType fromName(String name) {
    return FieldType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => throw FormatException('Type de champ inconnu : $name'),
    );
  }

  /// Type de colonne SQLite utilisé pour stocker ce champ. SQLite a un
  /// typage dynamique (affinité de colonne, pas de contrainte stricte) donc
  /// ceci sert surtout de documentation + affinité de tri/comparaison.
  String get sqlColumnType {
    switch (this) {
      case FieldType.number:
        return 'REAL';
      case FieldType.boolean:
        return 'INTEGER';
      case FieldType.text:
      case FieldType.date:
      case FieldType.email:
      case FieldType.url:
      case FieldType.select:
      case FieldType.relation:
      case FieldType.json:
        return 'TEXT';
    }
  }

  /// Convertit une valeur JSON entrante (depuis le body d'une requête) vers
  /// la représentation Dart qu'on écrira réellement en base.
  Object? coerce(Object? value) {
    if (value == null) return null;
    switch (this) {
      case FieldType.number:
        if (value is num) return value.toDouble();
        return double.parse(value.toString());
      case FieldType.boolean:
        if (value is bool) return value ? 1 : 0;
        return (value == true || value == 1 || value == '1' || value == 'true') ? 1 : 0;
      case FieldType.json:
        // La colonne SQL est TEXT : un objet/liste JSON décodé depuis le
        // body de la requête (Map/List Dart) ne peut pas être bindé tel
        // quel comme paramètre SQL — sqlite_async ne sait binder que des
        // types primitifs. On le ré-encode donc systématiquement en
        // String ; une valeur déjà String (le client a envoyé du JSON
        // pré-encodé) passe telle quelle.
        return value is String ? value : jsonEncode(value);
      case FieldType.text:
      case FieldType.date:
      case FieldType.email:
      case FieldType.url:
      case FieldType.select:
      case FieldType.relation:
        return value.toString();
    }
  }
}

/// Libellé français affiché dans l'admin (menu déroulant de sélection du
/// type de champ). Vit ici (et pas seulement côté admin) pour que le type
/// reste la seule source de vérité, y compris pour son affichage.
extension FieldTypeLabel on FieldType {
  String get label {
    switch (this) {
      case FieldType.text:
        return 'Texte';
      case FieldType.number:
        return 'Nombre';
      case FieldType.boolean:
        return 'Booléen';
      case FieldType.date:
        return 'Date';
      case FieldType.email:
        return 'Email';
      case FieldType.url:
        return 'URL';
      case FieldType.select:
        return 'Select';
      case FieldType.relation:
        return 'Relation';
      case FieldType.json:
        return 'JSON';
    }
  }
}
