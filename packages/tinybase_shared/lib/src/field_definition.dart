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

  // --- FieldType.file : options encodées en `max:<octets>` / `mime:<type>` ---

  /// Taille max (octets) pour un champ fichier, ou null si non spécifiée.
  int? get fileMaxSizeBytes {
    for (final o in options) {
      if (o.startsWith('max:')) return int.tryParse(o.substring(4));
    }
    return null;
  }

  /// Types MIME autorisés pour un champ fichier (liste vide = tous).
  List<String> get fileMimeAllowlist {
    return options.where((o) => o.startsWith('mime:')).map((o) => o.substring(5)).where((s) => s.isNotEmpty).toList();
  }

  /// Encode les options fichier dans [FieldDefinition.options].
  static List<String> encodeFileOptions({int? maxBytes, List<String> mimes = const []}) {
    return [
      if (maxBytes != null && maxBytes > 0) 'max:$maxBytes',
      ...mimes.map((m) => m.trim()).where((m) => m.isNotEmpty).map((m) => 'mime:$m'),
    ];
  }

  /// Valide une valeur déjà coercée (email / url / select). No-op si null.
  void validate(Object? value) {
    if (value == null) return;
    final s = value.toString();
    switch (type) {
      case FieldType.email:
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
          throw FormatException('Email invalide pour "$name"');
        }
      case FieldType.url:
        final uri = Uri.tryParse(s);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          throw FormatException('URL invalide pour "$name"');
        }
      case FieldType.select:
        if (options.isNotEmpty && !options.contains(s)) {
          throw FormatException(
            'Valeur "$s" non autorisée pour "$name". Options : ${options.join(', ')}',
          );
        }
      default:
        break;
    }
  }

  /// Match MIME exact ou wildcard (`image/*`).
  static bool mimeMatches(String? contentType, List<String> allowlist) {
    if (allowlist.isEmpty) return true;
    if (contentType == null || contentType.isEmpty) return false;
    final ct = contentType.split(';').first.trim().toLowerCase();
    for (final raw in allowlist) {
      final a = raw.trim().toLowerCase();
      if (a.isEmpty) continue;
      if (a.endsWith('/*')) {
        final prefix = a.substring(0, a.length - 1); // "image/"
        if (ct.startsWith(prefix)) return true;
      } else if (a == ct) {
        return true;
      }
    }
    return false;
  }
}
