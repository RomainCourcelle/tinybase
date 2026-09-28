import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import '../providers/collections_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/records_provider.dart';
import '../services/api_client.dart';
import 'codegen_dialog.dart';
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

/// Ce que la zone centrale affiche à un instant donné — les données
/// (records) et la fiche schéma (champs + règles) sont deux vues bien
/// distinctes (façon NexusBase), on ne peut être que dans l'une des trois.
enum _MainPane { empty, records, collectionForm }

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

  @override
  Widget build(BuildContext context) {
    final collectionsProvider = context.watch<CollectionsProvider>();
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Collections',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _CompactIconButton(
                        tooltip: 'Générer le code d\'authentification',
                        icon: Icons.vpn_key_outlined,
                        onPressed: () => _generateAuthCode(context, collectionsProvider),
                      ),
                      _CompactIconButton(
                        tooltip: 'Réglages',
                        icon: Icons.settings_outlined,
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => SettingsDialog(client: collectionsProvider.client),
                        ),
                      ),
                      _CompactIconButton(
                        tooltip: 'Nouvelle collection',
                        icon: Icons.add,
                        onPressed: _openCreateForm,
                      ),
                    ],
                  ),
                ),
                if (collectionsProvider.isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: collectionsProvider.errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            collectionsProvider.errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        )
                      : ListView.builder(
                          itemCount: collectionsProvider.collections.length,
                          itemBuilder: (context, index) {
                            final col = collectionsProvider.collections[index];
                            final isSelected = _pane != _MainPane.empty &&
                                (col.name == collectionsProvider.selectedName || col.name == _editingCollection?.name);
                            return ListTile(
                              selected: isSelected,
                              leading: Icon(col.type == CollectionType.auth ? Icons.lock_outline : Icons.table_chart_outlined),
                              title: Text(col.name),
                              subtitle: Text('${col.fields.length} champ(s)'),
                              onTap: () => _openRecords(collectionsProvider, col.name),
                              trailing: col.name == 'users'
                                  ? null
                                  : PopupMenuButton<String>(
                                      onSelected: (action) => _onCollectionAction(context, collectionsProvider, col, action),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Éditer le schéma')),
                                        PopupMenuItem(value: 'codegen', child: Text('Générer le code')),
                                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                      ],
                                    ),
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(connection.adminEmail ?? connection.baseUrl ?? '', overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Se déconnecter'),
                  onTap: () => connection.disconnect(),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildMainPane(collectionsProvider)),
        ],
      ),
    );
  }

  Widget _buildMainPane(CollectionsProvider collectionsProvider) {
    switch (_pane) {
      case _MainPane.empty:
        return const Center(child: Text('Sélectionne une collection à gauche'));
      case _MainPane.records:
        final selected = collectionsProvider.selected;
        if (selected == null) return const Center(child: Text('Sélectionne une collection à gauche'));
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
          onViewRecords: _editingCollection == null ? null : () => _openRecords(collectionsProvider, _editingCollection!.name),
        );
    }
  }

  /// Trio modèle/repository/provider Dart pour l'authentification — pas
  /// propre à une collection, contrairement à `codegen` sur chacune (voir
  /// tinybase_codegen/AuthCodegenService côté serveur).
  Future<void> _generateAuthCode(BuildContext context, CollectionsProvider provider) async {
    try {
      final files = await provider.client.authCodegen();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => CodegenDialog(title: 'Authentification', files: files),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      try {
        final files = await provider.client.codegen(col.name);
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => CodegenDialog(title: col.name, files: files),
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
          content: Text('"${col.name}" et TOUS ses records seront définitivement supprimés.'),
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

/// `IconButton` par défaut a une zone de tap minimum de 48x48 — 3 d'entre
/// eux à côté du titre "Collections" dans une sidebar de 260px, ça ne
/// rentre pas et le titre passe à la ligne (bug UI rapporté). Réduit la
/// zone de tap sans toucher à la taille de l'icône elle-même.
class _CompactIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  const _CompactIconButton({required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
