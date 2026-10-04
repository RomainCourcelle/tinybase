import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/collections_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/records_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_bits.dart';
import 'codegen_dialog.dart';
import 'codegen_style_dialog.dart';
import 'collection_form_screen.dart';
import 'records_screen.dart';
import 'settings_dialog.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = context.read<ConnectionProvider>();
    return ChangeNotifierProvider(
      create: (_) => CollectionsProvider(connection.client)..load(),
      child: const _HomeShellBody(),
    );
  }
}

enum _MainPane { empty, records, collectionForm, settings }

class _HomeShellBody extends StatefulWidget {
  const _HomeShellBody();

  @override
  State<_HomeShellBody> createState() => _HomeShellBodyState();
}

class _HomeShellBodyState extends State<_HomeShellBody> {
  _MainPane _pane = _MainPane.empty;
  CollectionDefinition? _editingCollection;

  void _openRecords(CollectionsProvider provider, String name) {
    provider.select(name);
    setState(() {
      _pane = _MainPane.records;
      _editingCollection = null;
    });
  }

  void _openCreateForm() {
    setState(() {
      _editingCollection = null;
      _pane = _MainPane.collectionForm;
    });
  }

  void _openEditForm(CollectionDefinition col) {
    setState(() {
      _editingCollection = col;
      _pane = _MainPane.collectionForm;
    });
  }

  void _openSettings() {
    setState(() {
      _pane = _MainPane.settings;
      _editingCollection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionsProvider = context.watch<CollectionsProvider>();
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            collectionsProvider: collectionsProvider,
            connection: connection,
            pane: _pane,
            editingName: _editingCollection?.name,
            onOpenRecords: (name) => _openRecords(collectionsProvider, name),
            onCreate: _openCreateForm,
            onSettings: _openSettings,
            onCollectionAction: (col, action) =>
                _onCollectionAction(context, collectionsProvider, col, action),
          ),
          Container(width: 1, color: AppColors.borderSubtle),
          Expanded(child: _buildMainPane(collectionsProvider)),
        ],
      ),
    );
  }

  Widget _buildMainPane(CollectionsProvider collectionsProvider) {
    switch (_pane) {
      case _MainPane.empty:
        return EmptyState(
          icon: Icons.table_chart_outlined,
          title: collectionsProvider.collections.isEmpty
              ? 'Aucune collection'
              : 'Sélectionne une collection',
          subtitle: collectionsProvider.collections.isEmpty
              ? 'Crée ta première collection pour commencer à stocker des données.'
              : 'Choisis une collection dans la barre latérale pour voir ses records.',
          action: collectionsProvider.collections.isEmpty
              ? FilledButton.icon(
                  onPressed: _openCreateForm,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle collection'),
                )
              : null,
        );
      case _MainPane.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          client: collectionsProvider.client,
        );
      case _MainPane.records:
        final selected = collectionsProvider.selected;
        if (selected == null) {
          return const EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'Sélectionne une collection',
          );
        }
        return ChangeNotifierProvider<RecordsProvider>(
          key: ValueKey('records-${selected.name}'),
          create: (_) => RecordsProvider(collectionsProvider.client, selected.name)..load(),
          child: RecordsScreen(collection: selected),
        );
      case _MainPane.collectionForm:
        return CollectionFormScreen(
          key: ValueKey('form-${_editingCollection?.name ?? '__new__'}'),
          existing: _editingCollection,
          onCancel: () => setState(() {
            _pane = _MainPane.empty;
            _editingCollection = null;
          }),
          onSaved: (name) => _openRecords(collectionsProvider, name),
          onViewRecords: _editingCollection == null
              ? null
              : () => _openRecords(collectionsProvider, _editingCollection!.name),
        );
    }
  }

  Future<void> _onCollectionAction(
    BuildContext context,
    CollectionsProvider provider,
    CollectionDefinition col,
    String action,
  ) async {
    if (action == 'edit') {
      _openEditForm(col);
      return;
    }
    if (action == 'codegen') {
      final style = await showCodegenStyleDialog(context);
      if (style == null || !context.mounted) return;
      try {
        final files = await provider.client.codegen(col.name, style: style);
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => CodegenDialog(title: '${col.name} ($style)', files: files),
        );
      } on ApiException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supprimer la collection ?'),
          content: Text('"${col.name}" et tous ses records seront définitivement supprimés.'),
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
        final ok = await provider.delete(col.name);
        if (ok && mounted && _editingCollection?.name == col.name) {
          setState(() {
            _pane = _MainPane.empty;
            _editingCollection = null;
          });
        }
      }
    }
  }
}

class _Sidebar extends StatelessWidget {
  final CollectionsProvider collectionsProvider;
  final ConnectionProvider connection;
  final _MainPane pane;
  final String? editingName;
  final ValueChanged<String> onOpenRecords;
  final VoidCallback onCreate;
  final VoidCallback onSettings;
  final void Function(CollectionDefinition col, String action) onCollectionAction;

  const _Sidebar({
    required this.collectionsProvider,
    required this.connection,
    required this.pane,
    required this.editingName,
    required this.onOpenRecords,
    required this.onCreate,
    required this.onSettings,
    required this.onCollectionAction,
  });

  @override
  Widget build(BuildContext context) {
    // Material (pas ColoredBox/Container.color) : sinon ListTile ne peut pas
    // peindre son ink splash / selectedTileColor (warning Flutter).
    return Material(
      color: AppColors.bgElevated,
      child: SizedBox(
        width: 268,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.hub_outlined, size: 15, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'TinyBase',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Nouvelle collection',
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: onCreate,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.text,
                    backgroundColor: AppColors.surfaceHover,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Text(
              'COLLECTIONS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textFaint,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (collectionsProvider.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(
            child: collectionsProvider.errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      collectionsProvider.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  )
                : collectionsProvider.collections.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Aucune collection pour l\'instant.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: collectionsProvider.collections.length,
                        itemBuilder: (context, index) {
                          final col = collectionsProvider.collections[index];
                          final isSelected = pane != _MainPane.empty &&
                              pane != _MainPane.settings &&
                              (col.name == collectionsProvider.selectedName || col.name == editingName);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: ListTile(
                              dense: true,
                              selected: isSelected,
                              leading: Icon(
                                col.type == CollectionType.auth
                                    ? Icons.lock_outline
                                    : Icons.table_chart_outlined,
                                size: 18,
                              ),
                              title: Text(col.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                col.type == CollectionType.auth
                                    ? 'auth'
                                    : '${col.fields.length} champ${col.fields.length == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => onOpenRecords(col.name),
                              trailing: col.name == 'users'
                                  ? null
                                  : PopupMenuButton<String>(
                                      tooltip: 'Actions',
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_horiz, size: 18),
                                      onSelected: (action) => onCollectionAction(col, action),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Éditer le schéma')),
                                        PopupMenuItem(value: 'codegen', child: Text('Générer le code')),
                                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
          ),
          Container(height: 1, color: AppColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: ListTile(
              dense: true,
              selected: pane == _MainPane.settings,
              leading: const Icon(Icons.settings_outlined, size: 18),
              title: const Text('Réglages'),
              onTap: onSettings,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.logout, size: 18),
              title: Text(
                connection.adminEmail ?? 'Admin',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: const Text('Se déconnecter', style: TextStyle(fontSize: 11)),
              onTap: () => connection.disconnect(),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
