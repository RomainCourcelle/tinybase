import 'package:flutter/material.dart';

/// Choix Provider vs Riverpod avant de lancer le codegen.
Future<String?> showCodegenStyleDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Style de code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Provider'),
              subtitle: const Text('ChangeNotifier + package provider'),
              onTap: () => Navigator.pop(ctx, 'provider'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Riverpod'),
              subtitle: const Text('Annotations @riverpod + build_runner'),
              onTap: () => Navigator.pop(ctx, 'riverpod'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      );
    },
  );
}
