import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/records_provider.dart';
import 'record_form_dialog.dart';

class RecordsScreen extends StatelessWidget {
  final CollectionDefinition collection;
  const RecordsScreen({super.key, required this.collection});

  /// Une collection `auth` (ex. `users`) ne peut pas être créée/éditée via
  /// cet écran — inscription et changement de mot de passe passent par
  /// `/api/auth/*`, jamais par l'API records générique, même pour l'admin
  /// (voir records_service.dart). La suppression reste possible : c'est ce
  /// qui permet à l'admin de virer un compte (ban/RGPD) sans route dédiée.
  bool get _isAuthCollection => collection.type == CollectionType.auth;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final columns = [...collection.autoFields, ...collection.fields.map((f) => f.name)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Text(collection.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 12),
              Text('${provider.totalItems} record(s)', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              if (_isAuthCollection)
                const Chip(label: Text('Inscription via l\'app uniquement — suppression possible ici'))
              else
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: RecordFormDialog(collection: collection),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Rafraîchir',
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.load(page: provider.page),
              ),
            ],
          ),
        ),
        if (provider.isLoading) const LinearProgressIndicator(),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(provider.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: provider.items.isEmpty && !provider.isLoading
              ? const Center(child: Text('Aucun record'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: [
                        ...columns.map((c) => DataColumn(label: Text(c))),
                        const DataColumn(label: Text('')),
                      ],
                      rows: provider.items.map((record) {
                        return DataRow(
                          cells: [
                            ...columns.map((c) => DataCell(Text(_displayValue(record[c])))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isAuthCollection)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => ChangeNotifierProvider.value(
                                          value: provider,
                                          child: RecordFormDialog(collection: collection, existing: record),
                                        ),
                                      ),
                                    ),
                                  if (_isAuthCollection)
                                    Builder(builder: (context) {
                                      final isDisabled = _isRecordDisabled(record);
                                      return IconButton(
                                        tooltip: isDisabled ? 'Réactiver ce compte' : 'Bannir ce compte',
                                        icon: Icon(isDisabled ? Icons.lock_open_outlined : Icons.block_outlined, size: 18),
                                        onPressed: () => _confirmToggleBan(context, provider, record, isDisabled),
                                      );
                                    }),
                                  IconButton(
                                    tooltip: _isAuthCollection ? 'Supprimer ce compte' : null,
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => _confirmDelete(context, provider, record),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        if (provider.totalItems > RecordsProvider.perPage)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: provider.page > 1 ? () => provider.load(page: provider.page - 1) : null,
                ),
                Text('Page ${provider.page}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: provider.items.length == RecordsProvider.perPage
                      ? () => provider.load(page: provider.page + 1)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _displayValue(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'vrai' : 'faux';
    return value.toString();
  }

  /// `disabled` vient de SQLite en INTEGER (0/1) sérialisé tel quel en JSON
  /// — jamais un vrai booléen côté client, contrairement aux champs
  /// `FieldType.boolean` définis par l'utilisateur.
  bool _isRecordDisabled(Map<String, dynamic> record) {
    final value = record['disabled'];
    if (value is bool) return value;
    return value == 1;
  }

  Future<void> _confirmToggleBan(
    BuildContext context,
    RecordsProvider provider,
    Map<String, dynamic> record,
    bool isCurrentlyDisabled,
  ) async {
    // Réactiver ne nécessite pas de confirmation (action anodine et
    // réversible en un clic) — seul le bannissement, qui coupe l'accès de
    // quelqu'un, en demande une.
    if (isCurrentlyDisabled) {
      await provider.setUserDisabled(record['id'] as String, false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bannir ce compte ?'),
        content: const Text(
          'Le compte ne pourra plus se connecter (les jetons déjà émis sont aussi révoqués immédiatement), '
          'mais ses données sont conservées. Réversible à tout moment.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bannir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.setUserDisabled(record['id'] as String, true);
    }
  }

  Future<void> _confirmDelete(BuildContext context, RecordsProvider provider, Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isAuthCollection ? 'Supprimer ce compte ?' : 'Supprimer ce record ?'),
        content: Text(
          _isAuthCollection
              ? 'Le compte sera définitivement supprimé et ne pourra plus se connecter. Action irréversible.'
              : 'Action irréversible.',
        ),
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
      await provider.delete(record['id'] as String);
    }
  }
}
