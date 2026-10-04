import 'package:tinybase_shared/tinybase_shared.dart';

import 'model_generator.dart';
import 'provider_generator.dart';
import 'repository_generator.dart';
import 'riverpod_generator.dart';
import 'state_management_style.dart';
import 'string_utils.dart';

/// Un fichier généré, prêt à être écrit sur disque côté client (ou renvoyé
/// tel quel par la route API — voir codegen_routes.dart dans tinybase_server).
class GeneratedFile {
  final String path;
  final String content;
  const GeneratedFile({required this.path, required this.content});

  Map<String, dynamic> toJson() => {'path': path, 'content': content};
}

/// Point d'entrée du codegen : modèle + repository + couche state
/// ([StateManagementStyle.provider] ou [StateManagementStyle.riverpod]).
class CodegenService {
  static List<GeneratedFile> generate(
    CollectionDefinition collection, {
    StateManagementStyle style = StateManagementStyle.provider,
  }) {
    final snake = toSnakeCase(collection.name);
    final stateContent = switch (style) {
      StateManagementStyle.provider => ProviderGenerator.generate(collection),
      StateManagementStyle.riverpod => RiverpodGenerator.generate(collection),
    };
    return [
      GeneratedFile(path: 'lib/models/$snake.dart', content: ModelGenerator.generate(collection)),
      GeneratedFile(
        path: 'lib/repositories/${snake}_repository.dart',
        content: RepositoryGenerator.generate(collection),
      ),
      GeneratedFile(
        path: 'lib/providers/${snake}_provider.dart',
        content: stateContent,
      ),
    ];
  }
}

// Le codegen de la couche Auth (session/provider, pas propre à une collection)
// vit dans AuthCodegenService (auth_codegen_service.dart).
