import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/codegen_download/codegen_download.dart';

/// Affiche le code généré (modèle + repository + provider) pour une
/// collection, avec copie presse-papiers et téléchargement. L'admin tourne
/// en Flutter Web (voir pubspec.yaml, plateforme unique) donc le
/// téléchargement utilise `dart:html` en pratique — mais via un import
/// CONDITIONNEL (voir services/codegen_download/), pas direct ici : un
/// import direct de `dart:html` empêche `flutter test`/`dart test` de
/// compiler (la VM Dart des tests n'a pas cette librairie), même si le
/// widget testé n'appelle jamais le téléchargement.
class CodegenDialog extends StatefulWidget {
  final String title;
  final List<GeneratedFile> files;
  const CodegenDialog({super.key, required this.title, required this.files});

  @override
  State<CodegenDialog> createState() => _CodegenDialogState();
}

class _CodegenDialogState extends State<CodegenDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.files.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copy(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copié dans le presse-papiers')));
  }

  void _download(GeneratedFile file) {
    downloadFile(file.path.split('/').last, file.content);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 760,
        height: 640,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Code généré — ${widget.title}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      for (final f in widget.files) {
                        _download(f);
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Tout télécharger'),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: widget.files.map((f) => Tab(text: f.path.split('/').last)).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: widget.files.map(_buildFileView).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileView(GeneratedFile file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(file.path, style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: () => _copy(file.content),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier'),
              ),
              TextButton.icon(
                onPressed: () => _download(file),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Télécharger'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  file.content,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
