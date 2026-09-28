import 'field_type.dart';

/// Définition d'un champ personnalisé d'une collection (en plus des champs
/// auto id/created/updated/owner gérés par [CollectionDefinition]).
class FieldDefinition {
  final String name;
  final FieldType type;
  final bool required;

  /// Pour [FieldType.select] : les options autorisées. Pour
  /// [FieldType.relation] : le nom de la collection cible (une seule entrée
  /// dans la liste, par convention, pour rester simple en V1 — pas encore de
  /// relations multiples).
  final List<String> options;

  const FieldDefinition({
    required this.name,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  FieldDefinition copyWith({String? name, FieldType? type, bool? required, List<String>? options}) {
    return FieldDefinition(
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
    );
  }

  factory FieldDefinition.fromJson(Map<String, dynamic> json) {
    return FieldDefinition(
      name: json['name'] as String,
      type: FieldType.fromName(json['type'] as String),
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'required': required,
        'options': options,
      };
}
