import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/records_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_bits.dart';
import 'record_form_dialog.dart';

class RecordsScreen extends StatelessWidget {
  final CollectionDefinition collection;
  const RecordsScreen({super.key, required this.collection});

  bool get _isAuthCollection => collection.type == CollectionType.auth;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final columns = [...collection.autoFields, ...collection.fields.map((f) => f.name)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: collection.name,
          subtitle: provider.isLoading
              ? 'Chargement…'
              : '${provider.totalItems} record${provider.totalItems == 1 ? '' : 's'}',
          actions: [
            if (_isAuthCollection)
              const StatusPill(label: 'Auth — lecture / ban / suppression')
            else
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: RecordFormDialog(collection: collection),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Rafraîchir',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => provider.load(page: provider.page),
            ),
          ],
        ),
        if (provider.isLoading) const LinearProgressIndicator(minHeight: 2),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: provider.items.isEmpty && !provider.isLoading
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Aucun record',
                  subtitle: _isAuthCollection
                      ? 'Les comptes apparaissent ici après inscription via /api/auth.'
                      : 'Ajoute le premier enregistrement de cette collection.',
                  action: _isAuthCollection
                      ? null
                      : FilledButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: provider,
                              child: RecordFormDialog(collection: collection),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter'),
                        ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
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
                                  ...columns.map(
                                    (c) => DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          _displayValue(record[c]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!_isAuthCollection)
                                          IconButton(
                                            tooltip: 'Éditer',
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            onPressed: () => showDialog(
                                              context: context,
                                              builder: (_) => ChangeNotifierProvider.value(
                                                value: provider,
                                                child: RecordFormDialog(
                                                  collection: collection,
                                                  existing: record,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (_isAuthCollection)
                                          Builder(builder: (context) {
                                            final isDisabled = _isRecordDisabled(record);
                                            return IconButton(
                                              tooltip: isDisabled ? 'Réactiver' : 'Bannir',
                                              icon: Icon(
                                                isDisabled
                                                    ? Icons.lock_open_outlined
                                                    : Icons.block_outlined,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _confirmToggleBan(context, provider, record, isDisabled),
                                            );
                                          }),
                                        IconButton(
                                          tooltip: 'Supprimer',
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
                  ),
                ),
        ),
        if (provider.totalItems > RecordsProvider.perPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: provider.page > 1 ? () => provider.load(page: provider.page - 1) : null,
                ),
                Text(
                  'Page ${provider.page}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
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
    if (value == null) return '—';
    if (value is bool) return value ? 'vrai' : 'faux';
    final s = value.toString();
    return s.isEmpty ? '—' : s;
  }

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
    if (isCurrentlyDisabled) {
      await provider.setUserDisabled(record['id'] as String, false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bannir ce compte ?'),
        content: const Text(
          'Le compte ne pourra plus se connecter (jetons déjà émis révoqués), '
          'mais ses données sont conservées. Réversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
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
              ? 'Le compte sera définitivement supprimé. Action irréversible.'
              : 'Action irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
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
