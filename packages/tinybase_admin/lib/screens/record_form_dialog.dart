import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/records_provider.dart';

/// Formulaire généré dynamiquement à partir du schéma de la collection —
/// un widget par [FieldType], pas de code spécifique à écrire par
/// collection (c'est tout l'intérêt d'un moteur générique).
class RecordFormDialog extends StatefulWidget {
  final CollectionDefinition collection;
  final Map<String, dynamic>? existing;
  const RecordFormDialog({super.key, required this.collection, this.existing});

  @override
  State<RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<RecordFormDialog> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, String?> _selectValues = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.collection.fields) {
      final current = widget.existing?[field.name];
      switch (field.type) {
        case FieldType.boolean:
          _boolValues[field.name] = current == 1 || current == true;
          break;
        case FieldType.select:
          _selectValues[field.name] = current?.toString();
          break;
        default:
          _textControllers[field.name] = TextEditingController(text: current?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String fieldName) async {
    final controller = _textControllers[fieldName]!;
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = picked.toIso8601String());
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{};
    for (final field in widget.collection.fields) {
      switch (field.type) {
        case FieldType.boolean:
          data[field.name] = _boolValues[field.name] ?? false;
          break;
        case FieldType.select:
          if (_selectValues[field.name] != null) data[field.name] = _selectValues[field.name];
          break;
        case FieldType.number:
          final raw = _textControllers[field.name]!.text.trim();
          if (raw.isNotEmpty) {
            final parsed = num.tryParse(raw);
            if (parsed == null) {
              setState(() {
                _saving = false;
                _error = 'Valeur numérique invalide pour "${field.name}"';
              });
              return;
            }
            data[field.name] = parsed;
          }
          break;
        default:
          final raw = _textControllers[field.name]!.text;
          if (raw.isNotEmpty) data[field.name] = raw;
      }
    }

    final provider = context.read<RecordsProvider>();
    final ok = widget.existing == null
        ? await provider.create(data)
        : await provider.update(widget.existing!['id'] as String, data);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = provider.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nouveau record — ${widget.collection.name}' : 'Éditer le record'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...widget.collection.fields.map(_buildField),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _buildField(FieldDefinition field) {
    final label = field.required ? '${field.name} *' : field.name;
    switch (field.type) {
      case FieldType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label),
            value: _boolValues[field.name] ?? false,
            onChanged: (v) => setState(() => _boolValues[field.name] = v ?? false),
          ),
        );
      case FieldType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: _selectValues[field.name],
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
            items: field.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => setState(() => _selectValues[field.name] = v),
          ),
        );
      case FieldType.date:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _textControllers[field.name],
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () => _pickDate(field.name),
          ),
        );
      case FieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _textControllers[field.name],
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          ),
        );
      case FieldType.json:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _textControllers[field.name],
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '$label (JSON brut)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );
      case FieldType.text:
      case FieldType.email:
      case FieldType.url:
      case FieldType.relation:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _textControllers[field.name],
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          ),
        );
    }
  }
}
