import 'package:tinybase_shared/tinybase_shared.dart';

import 'model_generator.dart';
import 'provider_generator.dart';
import 'repository_generator.dart';
import 'string_utils.dart';

/// Un fichier généré, prêt à être écrit sur disque côté client (ou renvoyé
/// tel quel par la route API — voir codegen_routes.dart dans tinybase_server).
class GeneratedFile {
  final String path;
  final String content;
  const GeneratedFile({required this.path, required this.content});

  Map<String, dynamic> toJson() => {'path': path, 'content': content};
}

/// Point d'entrée du codegen : modèle + repository + provider pour une
/// collection donnée. `path:` volontairement calqué sur la convention
/// `lib/models/`, `lib/repositories/`, `lib/providers/` déjà utilisée dans
/// les projets Flutter de Romain.
class CodegenService {
  static List<GeneratedFile> generate(CollectionDefinition collection) {
    final snake = toSnakeCase(collection.name);
    return [
      GeneratedFile(path: 'lib/models/$snake.dart', content: ModelGenerator.generate(collection)),
      GeneratedFile(
        path: 'lib/repositories/${snake}_repository.dart',
        content: RepositoryGenerator.generate(collection),
      ),
      GeneratedFile(
        path: 'lib/providers/${snake}_provider.dart',
        content: ProviderGenerator.generate(collection),
      ),
    ];
  }
}

// Le codegen de la couche Auth (session/repository/provider, pas propre à
// une collection) vit dans AuthCodegenService (auth_codegen_service.dart),
// pas ici — évite d'avoir deux générateurs concurrents pour la même chose.
