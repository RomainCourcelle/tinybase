import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tinybase_codegen/tinybase_codegen.dart';

import '../../services/collections_service.dart';
import 'package:tinybase_shared/tinybase_shared.dart';
import '../json_response.dart';

/// Routes d'administration du schéma — protégées par [adminOnlyMiddleware]
/// (voir app.dart). Permet : lister/créer/renommer/éditer les
/// champs/supprimer une collection. C'est la partie "édition complète des
/// collections/fields" que NexusBase n'avait pas.
Router buildCollectionsRoutes(CollectionsService collectionsService) {
  final router = Router();

  router.get('/', (Request request) async {
    try {
      final list = await collectionsService.list();
      return jsonResponse(list.map((c) => c.toJson()).toList());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/<name>', (Request request, String name) async {
    try {
      final col = await collectionsService.getOrThrow(name);
      return jsonResponse(col.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/', (Request request) async {
    try {
      final body = await request.readJson();
      final name = body['name'] as String?;
      if (name == null) return jsonResponse({'error': '"name" requis'}, status: 400);

      final typeStr = body['type'] as String? ?? 'base';
      final type = CollectionType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => throw FormatException('type invalide : $typeStr'),
      );

      final fields = ((body['fields'] as List?) ?? [])
          .map((f) => FieldDefinition.fromJson(f as Map<String, dynamic>))
          .toList();

      // `containsKey` (et pas juste `body['listRule'] as String?`) pour
      // distinguer "champ absent du body -> défaut public" d'un `null`
      // explicite ("admin seulement" coché côté admin, voir rules_service.dart).
      final col = await collectionsService.create(
        name: name,
        type: type,
        fields: fields,
        listRule: body.containsKey('listRule') ? body['listRule'] as String? : '',
        viewRule: body.containsKey('viewRule') ? body['viewRule'] as String? : '',
        createRule: body.containsKey('createRule') ? body['createRule'] as String? : '',
        updateRule: body.containsKey('updateRule') ? body['updateRule'] as String? : '',
        deleteRule: body.containsKey('deleteRule') ? body['deleteRule'] as String? : '',
      );
      return jsonResponse(col.toJson(), status: 201);
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Body attendu :
  /// {
  ///   "name": "nouveauNom"?,           // renommage de la collection
  ///   "fields": [...]?,                // liste FINALE désirée des champs
  ///   "renames": {"ancien": "nouveau"}?, // champs renommés (sinon vus comme suppr+ajout)
  ///   "listRule"/"viewRule"/"createRule"/"updateRule"/"deleteRule": "..."?
  /// }
  router.patch('/<name>', (Request request, String name) async {
    try {
      final body = await request.readJson();
      var current = name;

      if (body['fields'] != null) {
        final newFields = (body['fields'] as List)
            .map((f) => FieldDefinition.fromJson(f as Map<String, dynamic>))
            .toList();
        final renames = (body['renames'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ?? {};
        await collectionsService.updateFields(current, newFields, renames: renames);
      }

      if (body['name'] != null && body['name'] != current) {
        await collectionsService.rename(current, body['name'] as String);
        current = body['name'] as String;
      }

      if (body.containsKey('listRule') ||
          body.containsKey('viewRule') ||
          body.containsKey('createRule') ||
          body.containsKey('updateRule') ||
          body.containsKey('deleteRule')) {
        // Par champ : absent du body -> kRuleUnset (ne pas toucher) ; présent
        // (même avec la valeur JSON `null`) -> écrit tel quel, `null` inclus
        // ("admin seulement", voir rules_service.dart).
        await collectionsService.updateRules(
          current,
          listRule: body.containsKey('listRule') ? body['listRule'] as String? : kRuleUnset,
          viewRule: body.containsKey('viewRule') ? body['viewRule'] as String? : kRuleUnset,
          createRule: body.containsKey('createRule') ? body['createRule'] as String? : kRuleUnset,
          updateRule: body.containsKey('updateRule') ? body['updateRule'] as String? : kRuleUnset,
          deleteRule: body.containsKey('deleteRule') ? body['deleteRule'] as String? : kRuleUnset,
        );
      }

      final result = await collectionsService.getOrThrow(current);
      return jsonResponse(result.toJson());
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.delete('/<name>', (Request request, String name) async {
    try {
      await collectionsService.delete(name);
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  /// Génère modèle + repository + provider Dart pour la collection (voir
  /// tinybase_codegen) — utilisé par nexus_code_launcher pendant le
  /// scaffolding d'un projet, pour éviter d'écrire ce code à la main pour
  /// chaque appli qui consomme une instance TinyBase. Route à deux
  /// segments (`/<name>/codegen`), donc pas de conflit avec `/<name>`
  /// ci-dessus (shelf_router ne fait matcher chaque segment qu'une fois).
  router.get('/<name>/codegen', (Request request, String name) async {
    try {
      final collection = await collectionsService.getOrThrow(name);
      final files = CodegenService.generate(collection).map((f) => f.toJson()).toList();
      return jsonResponse({'files': files});
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
