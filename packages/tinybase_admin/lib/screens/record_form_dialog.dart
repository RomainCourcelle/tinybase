import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/connection_provider.dart';
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
  final Map<String, String?> _existingFileNames = {};
  final Map<String, ({String name, List<int> bytes})> _pickedFiles = {};
  final Set<String> _clearFiles = {};
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
        case FieldType.select:
          _selectValues[field.name] = current?.toString();
        case FieldType.file:
          _existingFileNames[field.name] = current?.toString();
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

  Future<void> _pickFile(String fieldName) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final file = files.first;
    try {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFiles[fieldName] = (name: file.name, bytes: bytes);
        _clearFiles.remove(fieldName);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Impossible de lire le fichier : $e');
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{};
    final files = <String, ({String filename, List<int> bytes, String? contentType})>{};

    for (final field in widget.collection.fields) {
      switch (field.type) {
        case FieldType.boolean:
          data[field.name] = _boolValues[field.name] ?? false;
        case FieldType.select:
          if (_selectValues[field.name] != null) data[field.name] = _selectValues[field.name];
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
        case FieldType.file:
          final picked = _pickedFiles[field.name];
          if (picked != null) {
            files[field.name] = (
              filename: picked.name,
              bytes: picked.bytes,
              contentType: null,
            );
          } else if (_clearFiles.contains(field.name)) {
            data[field.name] = null;
          }
        default:
          final raw = _textControllers[field.name]!.text;
          if (raw.isNotEmpty) data[field.name] = raw;
      }
    }

    final provider = context.read<RecordsProvider>();
    final ok = widget.existing == null
        ? await provider.create(data, files: files.isEmpty ? null : files)
        : await provider.update(widget.existing!['id'] as String, data, files: files.isEmpty ? null : files);

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
      case FieldType.file:
        final picked = _pickedFiles[field.name];
        final existing = _existingFileNames[field.name];
        final cleared = _clearFiles.contains(field.name);
        final recordId = widget.existing?['id'] as String?;
        final connection = context.read<ConnectionProvider>();
        final downloadUrl = (recordId != null && existing != null && existing.isNotEmpty && !cleared)
            ? connection.client.fileUrl(widget.collection.name, recordId, field.name)
            : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    picked != null
                        ? picked.name
                        : (cleared || existing == null || existing.isEmpty)
                            ? 'Aucun fichier'
                            : existing,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (downloadUrl != null)
                  IconButton(
                    tooltip: 'Ouvrir',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () {
                      // Sur web, l'admin ouvre l'URL (Bearer non transmis —
                      // l'admin a souvent des règles publiques ou on
                      // s'appuie sur le token en session navigateur non
                      // applicable ici). On affiche l'URL pour copier.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(downloadUrl)),
                      );
                    },
                  ),
                TextButton(onPressed: () => _pickFile(field.name), child: const Text('Choisir')),
                if ((existing != null && existing.isNotEmpty && !cleared) || picked != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _pickedFiles.remove(field.name);
                      _clearFiles.add(field.name);
                    }),
                    child: const Text('Retirer'),
                  ),
              ],
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
