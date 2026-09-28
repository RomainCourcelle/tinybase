import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/collections_provider.dart';

/// Un champ en cours d'édition dans le formulaire. [originalName] est null
/// pour un champ tout juste ajouté (donc jamais vu par le serveur) ; sinon
/// il garde trace du nom au moment de l'ouverture de la page, pour qu'on
/// puisse envoyer la bonne entrée dans `renames` si le nom a changé — sans
/// ça, un renommage serait vu côté serveur comme "suppression du vieux
/// champ + ajout d'un nouveau", ce qui perdrait les données de la colonne
/// (voir collections_service.dart côté serveur).
class _EditableField {
  final String? originalName;
  final TextEditingController nameController;
  FieldType type;
  bool required;
  final TextEditingController optionsController;
  String? relationTarget;

  _EditableField({
    this.originalName,
    required String name,
    required this.type,
    this.required = false,
    String options = '',
    this.relationTarget,
  })  : nameController = TextEditingController(text: name),
        optionsController = TextEditingController(text: options);

  void dispose() {
    nameController.dispose();
    optionsController.dispose();
  }
}

/// Préremplit les 5 règles d'un coup avec un pattern courant — voir
/// rules_service.dart côté serveur pour la grammaire exacte supportée
/// (V1 volontairement restreinte : `""` = public, `null` = admin seulement,
/// `@request.auth.id != ""` = authentifié, `@request.auth.id = <champ>` =
/// propriétaire du record).
enum _RuleTemplate { ownerPrivate, publicRead, adminOnly }

/// Une des 5 règles d'accès d'une collection (list/view/create/update/
/// delete) — texte libre, sauf si [adminOnly] est coché auquel cas le texte
/// est ignoré et la règle envoyée au serveur vaut `null` (personne, sauf
/// jeton admin).
class _RuleState {
  final TextEditingController controller;
  bool adminOnly;
  _RuleState({String text = '', this.adminOnly = false}) : controller = TextEditingController(text: text);

  /// `null` si [adminOnly], sinon le texte tel quel (chaîne vide = public).
  String? get value => adminOnly ? null : controller.text.trim();

  void dispose() => controller.dispose();
}

/// Page complète de gestion d'une collection (champs + règles d'accès) —
/// remplace l'ancienne petite dialog par une vraie page dans la zone
/// centrale de l'admin, dans le même esprit que la page "collection" de
/// NexusBase. [existing] null = création ; sinon édition de cette
/// collection.
class CollectionFormScreen extends StatefulWidget {
  final CollectionDefinition? existing;
  final ValueChanged<String> onSaved;
  final VoidCallback onCancel;
  final VoidCallback? onViewRecords;

  const CollectionFormScreen({
    super.key,
    this.existing,
    required this.onSaved,
    required this.onCancel,
    this.onViewRecords,
  });

  @override
  State<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends State<CollectionFormScreen> {
  late final TextEditingController _nameController;
  late final List<_EditableField> _fields;

  late final _RuleState _listRule;
  late final _RuleState _viewRule;
  late final _RuleState _createRule;
  late final _RuleState _updateRule;
  late final _RuleState _deleteRule;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _fields = (existing?.fields ?? const <FieldDefinition>[])
        .map((f) => _EditableField(
              originalName: f.name,
              name: f.name,
              type: f.type,
              required: f.required,
              options: f.type == FieldType.select ? f.options.join(', ') : '',
              relationTarget: f.type == FieldType.relation && f.options.isNotEmpty ? f.options.first : null,
            ))
        .toList();

    _listRule = _RuleState(text: existing?.listRule ?? '', adminOnly: existing != null && existing.listRule == null);
    _viewRule = _RuleState(text: existing?.viewRule ?? '', adminOnly: existing != null && existing.viewRule == null);
    _createRule = _RuleState(
      text: existing?.createRule ?? (existing == null ? '@request.auth.id != ""' : ''),
      adminOnly: existing != null && existing.createRule == null,
    );
    _updateRule = _RuleState(text: existing?.updateRule ?? '', adminOnly: existing != null && existing.updateRule == null);
    _deleteRule = _RuleState(text: existing?.deleteRule ?? '', adminOnly: existing != null && existing.deleteRule == null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    _listRule.dispose();
    _viewRule.dispose();
    _createRule.dispose();
    _updateRule.dispose();
    _deleteRule.dispose();
    super.dispose();
  }

  void _addField() {
    setState(() {
      _fields.add(_EditableField(name: '', type: FieldType.text));
    });
  }

  void _removeField(_EditableField field) {
    setState(() {
      field.dispose();
      _fields.remove(field);
    });
  }

  void _applyTemplate(_RuleTemplate template) {
    setState(() {
      switch (template) {
        case _RuleTemplate.ownerPrivate:
          for (final r in [_listRule, _viewRule, _createRule, _updateRule, _deleteRule]) {
            r.adminOnly = false;
          }
          _listRule.controller.text = '@request.auth.id = owner';
          _viewRule.controller.text = '@request.auth.id = owner';
          _createRule.controller.text = '@request.auth.id != ""';
          _updateRule.controller.text = '@request.auth.id = owner';
          _deleteRule.controller.text = '@request.auth.id = owner';
          break;
        case _RuleTemplate.publicRead:
          for (final r in [_listRule, _viewRule, _createRule, _updateRule, _deleteRule]) {
            r.adminOnly = false;
          }
          _listRule.controller.text = '';
          _viewRule.controller.text = '';
          _createRule.controller.text = '@request.auth.id != ""';
          _updateRule.controller.text = '@request.auth.id = owner';
          _deleteRule.controller.text = '@request.auth.id = owner';
          break;
        case _RuleTemplate.adminOnly:
          for (final r in [_listRule, _viewRule, _createRule, _updateRule, _deleteRule]) {
            r.adminOnly = true;
          }
          break;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom de la collection est requis');
      return;
    }
    for (final f in _fields) {
      if (f.nameController.text.trim().isEmpty) {
        setState(() => _error = 'Tous les champs doivent avoir un nom');
        return;
      }
      if (f.type == FieldType.relation && (f.relationTarget == null || f.relationTarget!.isEmpty)) {
        setState(() => _error = 'Choisis la collection cible du champ relation "${f.nameController.text.trim()}"');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final newFields = _fields
        .map((f) => FieldDefinition(
              name: f.nameController.text.trim(),
              type: f.type,
              required: f.required,
              options: switch (f.type) {
                FieldType.select =>
                  f.optionsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                FieldType.relation => [f.relationTarget!],
                _ => const [],
              },
            ))
        .toList();

    final provider = context.read<CollectionsProvider>();
    bool ok;
    if (_isEditing) {
      final renames = <String, String>{
        for (final f in _fields)
          if (f.originalName != null && f.originalName != f.nameController.text.trim())
            f.originalName!: f.nameController.text.trim(),
      };
      ok = await provider.update(
        widget.existing!.name,
        newName: name != widget.existing!.name ? name : null,
        fields: newFields,
        renames: renames,
        listRule: _listRule.value,
        viewRule: _viewRule.value,
        createRule: _createRule.value,
        updateRule: _updateRule.value,
        deleteRule: _deleteRule.value,
      );
    } else {
      ok = await provider.create(
        name: name,
        fields: newFields,
        listRule: _listRule.value,
        viewRule: _viewRule.value,
        createRule: _createRule.value,
        updateRule: _updateRule.value,
        deleteRule: _deleteRule.value,
      );
    }

    if (!mounted) return;
    if (ok) {
      widget.onSaved(name);
    } else {
      setState(() {
        _saving = false;
        _error = provider.errorMessage;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final provider = context.read<CollectionsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la collection ?'),
        content: Text('"${widget.existing!.name}" et TOUS ses records seront définitivement supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await provider.delete(widget.existing!.name);
      if (ok) widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _saving ? null : widget.onCancel,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Collections'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? widget.existing!.name : 'Nouvelle collection',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_isEditing && widget.onViewRecords != null) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: widget.onViewRecords,
                      icon: const Icon(Icons.table_rows_outlined, size: 18),
                      label: const Text('Voir / éditer les données'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (!_isEditing) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom de la collection', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
              ],
              _sectionCard(
                title: 'Champs',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_fields.isNotEmpty) ..._fields.map(_buildFieldRow),
                    if (_fields.isNotEmpty) const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(onPressed: _addField, icon: const Icon(Icons.add), label: const Text('Ajouter un champ')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionCard(
                title: 'Règles d\'accès',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vide = accès public, même sans connexion. Coche « admin seulement » pour réserver '
                      'l\'action aux administrateurs. Sinon, écris une expression, par exemple :',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'owner = @request.auth.id',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _templateChip('Modèle : données privées par utilisateur', _RuleTemplate.ownerPrivate),
                        _templateChip('Modèle : lecture publique', _RuleTemplate.publicRead),
                        _templateChip('Modèle : admin seulement', _RuleTemplate.adminOnly),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ruleField('list (lecture liste)', _listRule),
                    _ruleField('view (lecture détail)', _viewRule),
                    _ruleField('create', _createRule),
                    _ruleField('update', _updateRule),
                    _ruleField('delete', _deleteRule, showDivider: false),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Enregistrer' : 'Créer la collection'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: _saving ? null : widget.onCancel, child: const Text('Annuler')),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 32),
                _sectionCard(
                  title: 'Supprimer la collection',
                  titleColor: theme.colorScheme.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cette action est définitive : la collection et tous ses records seront perdus.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _saving ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                        child: const Text('Supprimer définitivement'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child, Color? titleColor}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: titleColor),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _templateChip(String label, _RuleTemplate template) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyTemplate(template),
    );
  }

  Widget _ruleField(String label, _RuleState rule, {bool showDivider = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          TextField(
            controller: rule.controller,
            enabled: !rule.adminOnly,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          Row(
            children: [
              Checkbox(
                value: rule.adminOnly,
                onChanged: (v) => setState(() => rule.adminOnly = v ?? false),
              ),
              const Text('admin seulement (ignore le champ ci-dessus)', style: TextStyle(fontSize: 12)),
            ],
          ),
          if (showDivider) const Divider(height: 8),
        ],
      ),
    );
  }

  Widget _buildFieldRow(_EditableField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: field.nameController,
                  decoration: const InputDecoration(labelText: 'Nom', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<FieldType>(
                  value: field.type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true, border: OutlineInputBorder()),
                  items: FieldType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                  onChanged: (t) => setState(() => field.type = t!),
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(value: field.required, onChanged: (v) => setState(() => field.required = v ?? false)),
              const Text('requis', style: TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer ce champ',
                onPressed: () => _removeField(field),
              ),
            ],
          ),
          if (field.type == FieldType.select) ...[
            const SizedBox(height: 8),
            TextField(
              controller: field.optionsController,
              decoration: const InputDecoration(labelText: 'Options (séparées par des virgules)', isDense: true, border: OutlineInputBorder()),
            ),
          ],
          if (field.type == FieldType.relation) ...[
            const SizedBox(height: 8),
            _RelationTargetPicker(
              value: field.relationTarget,
              onChanged: (name) => setState(() => field.relationTarget = name),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sélecteur de la collection cible d'un champ [FieldType.relation] — lit la
/// liste depuis [CollectionsProvider] déjà chargée (pas de requête réseau
/// supplémentaire), en excluant `users` (collection spéciale) uniquement si
/// on veut éviter les relations vers elle — ici on l'autorise, une relation
/// vers l'utilisateur propriétaire étant un cas d'usage courant.
class _RelationTargetPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _RelationTargetPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final names = context.watch<CollectionsProvider>().collections.map((c) => c.name).toList();
    return DropdownButtonFormField<String>(
      value: names.contains(value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Collection cible', isDense: true, border: OutlineInputBorder()),
      items: names.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
      onChanged: onChanged,
      hint: const Text('Choisir une collection'),
    );
  }
}
