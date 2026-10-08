import 'dart:convert';

import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

import 'package:tinybase_shared/tinybase_shared.dart';

import 'records_service.dart' show NotFoundException;

const _uuid = Uuid();

/// Sentinel pour [CollectionsService.updateRules] : distingue "ce paramètre
/// n'a pas été fourni donc on ne touche pas à la règle actuelle" d'un
/// `null` explicitement fourni (qui doit lui être écrit tel quel — mettre
/// une règle à `null` = accès réservé aux administrateurs, voir
/// rules_service.dart). Un simple `String?` ne peut pas représenter ces 3
/// états à lui seul (fourni-non-null / fourni-null / non-fourni).
const Object kRuleUnset = Object();

/// CRUD des collections + migrations physiques des tables SQLite associées.
/// C'est le morceau que NexusBase n'a pas : renommer une collection ou un
/// champ, ajouter/retirer un champ, ou changer son type, après coup et sans
/// perdre les données existantes.
class CollectionsService {
  final SqliteDatabase db;
  CollectionsService(this.db);

  Future<List<CollectionDefinition>> list() async {
    final rows = await db.getAll('SELECT * FROM _collections ORDER BY name');
    return rows.map((r) => CollectionDefinition.fromRow(r)).toList();
  }

  Future<CollectionDefinition?> get(String name) async {
    final row = await db.getOptional('SELECT * FROM _collections WHERE name = ?', [name]);
    return row == null ? null : CollectionDefinition.fromRow(row);
  }

  /// `NotFoundException` (pas `StateError`) : régression trouvée en lançant
  /// la batterie de tests — le `errorResponse` de json_response.dart mappe
  /// `StateError` en 400, alors qu'une collection introuvable doit renvoyer
  /// 404 (comme le fait déjà RecordsService pour un record introuvable).
  Future<CollectionDefinition> getOrThrow(String name) async {
    final col = await get(name);
    if (col == null) throw NotFoundException('Collection "$name" introuvable');
    return col;
  }

  Future<CollectionDefinition> create({
    required String name,
    required CollectionType type,
    required List<FieldDefinition> fields,
    String? listRule = '',
    String? viewRule = '',
    String? createRule = '',
    String? updateRule = '',
    String? deleteRule = '',
  }) async {
    assertValidIdentifier(name, kind: 'collection');
    if (kReservedCollectionNames.contains(name) || name.startsWith('_')) {
      throw FormatException('Nom de collection réservé : "$name"');
    }
    for (final f in fields) {
      assertValidIdentifier(f.name, kind: 'champ');
    }
    final autoFields = type == CollectionType.auth ? kAuthAutoFields : kBaseAutoFields;
    for (final f in fields) {
      if (autoFields.contains(f.name)) {
        throw FormatException('"${f.name}" est un champ automatique, choisis un autre nom');
      }
    }

    final existing = await get(name);
    if (existing != null) {
      throw StateError('Une collection "$name" existe déjà');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'col_${_uuid.v4()}';

    await db.writeTransaction((tx) async {
      await tx.execute(
        '''
        INSERT INTO _collections (id, name, type, fields, list_rule, view_rule, create_rule, update_rule, delete_rule, created, updated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          id,
          name,
          type.name,
          jsonEncode(fields.map((f) => f.toJson()).toList()),
          listRule,
          viewRule,
          createRule,
          updateRule,
          deleteRule,
          now,
          now,
        ],
      );

      final columns = StringBuffer();
      if (type == CollectionType.auth) {
        columns.write(_authAutoColumnsSql);
      } else {
        columns.write('id TEXT PRIMARY KEY, created TEXT NOT NULL, updated TEXT NOT NULL, owner TEXT');
      }
      for (final f in fields) {
        columns.write(', "${f.name}" ${f.type.sqlColumnType}');
      }
      await tx.execute('CREATE TABLE "$name" ($columns);');
      if (type == CollectionType.auth) {
        await tx.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS "idx_${name}_discord_id" ON "$name"(discord_id);',
        );
      }
    });

    return (await get(name))!;
  }

  Future<CollectionDefinition> rename(String oldName, String newName) async {
    assertValidIdentifier(newName, kind: 'collection');
    if (oldName == 'users') {
      throw StateError('Impossible de renommer la collection "users" (AuthService y est lié)');
    }
    if (kReservedCollectionNames.contains(newName) || newName.startsWith('_')) {
      throw FormatException('Nom de collection réservé : "$newName"');
    }
    final col = await getOrThrow(oldName);
    if (await get(newName) != null) {
      throw StateError('Une collection "$newName" existe déjà');
    }

    await db.writeTransaction((tx) async {
      await tx.execute('ALTER TABLE "$oldName" RENAME TO "$newName";');
      await tx.execute(
        'UPDATE _collections SET name = ?, updated = ? WHERE id = ?',
        [newName, DateTime.now().toUtc().toIso8601String(), col.id],
      );
    });

    return (await get(newName))!;
  }

  /// Met à jour la liste des champs d'une collection. [newFields] doit
  /// contenir la liste FINALE désirée (avec les nouveaux noms). [renames]
  /// mappe explicitement ancien nom -> nouveau nom pour les champs
  /// renommés (sans quoi un renommage serait vu comme "suppression + ajout"
  /// et perdrait les données de la colonne).
  ///
  /// Stratégie : les renommages purs passent par `RENAME COLUMN` (aucune
  /// perte). Un ajout de champ passe par `ADD COLUMN`. Si un champ
  /// existant change de TYPE, SQLite ne sait pas faire `ALTER COLUMN` :
  /// on reconstruit alors la table entière (table temporaire + copie +
  /// swap), en une seule fois pour tous les champs concernés.
  Future<CollectionDefinition> updateFields(
    String name,
    List<FieldDefinition> newFields, {
    Map<String, String> renames = const {},
  }) async {
    final col = await getOrThrow(name);
    for (final f in newFields) {
      assertValidIdentifier(f.name, kind: 'champ');
      if (col.autoFields.contains(f.name) || kAuthProtectedFieldNames.contains(f.name)) {
        throw FormatException('"${f.name}" est un champ automatique / système, choisis un autre nom');
      }
    }

    // Champs existants après application des renommages (ancien nom -> def).
    final oldByFinalName = <String, FieldDefinition>{};
    for (final f in col.fields) {
      final finalName = renames[f.name] ?? f.name;
      oldByFinalName[finalName] = f;
    }
    final newByName = {for (final f in newFields) f.name: f};

    final needsRebuild = newByName.entries.any((entry) {
      final old = oldByFinalName[entry.key];
      return old != null && old.type != entry.value.type;
    });

    await db.writeTransaction((tx) async {
      if (renames.isNotEmpty) {
        for (final entry in renames.entries) {
          if (entry.key == entry.value) continue;
          await tx.execute('ALTER TABLE "$name" RENAME COLUMN "${entry.key}" TO "${entry.value}";');
        }
      }

      if (needsRebuild) {
        await _rebuildTable(tx, name: name, type: col.type, newFields: newFields);
      } else {
        // Colonnes à ajouter : dans newFields mais pas dans l'ancien schéma
        // (après renommage).
        for (final f in newFields) {
          if (!oldByFinalName.containsKey(f.name)) {
            await tx.execute('ALTER TABLE "$name" ADD COLUMN "${f.name}" ${f.type.sqlColumnType};');
          }
        }
        // Colonnes à retirer : présentes avant (après renommage) mais plus
        // dans newFields.
        for (final finalName in oldByFinalName.keys) {
          if (!newByName.containsKey(finalName)) {
            await tx.execute('ALTER TABLE "$name" DROP COLUMN "$finalName";');
          }
        }
      }

      await tx.execute(
        'UPDATE _collections SET fields = ?, updated = ? WHERE id = ?',
        [
          jsonEncode(newFields.map((f) => f.toJson()).toList()),
          DateTime.now().toUtc().toIso8601String(),
          col.id,
        ],
      );
    });

    return (await get(name))!;
  }

  Future<void> _rebuildTable(
    SqliteWriteContext tx, {
    required String name,
    required CollectionType type,
    required List<FieldDefinition> newFields,
  }) async {
    final tempName = '${name}_rebuild_tmp';
    await tx.execute('DROP TABLE IF EXISTS "$tempName";');

    final autoCols = type == CollectionType.auth
        ? _authAutoColumnsSql
        : 'id TEXT PRIMARY KEY, created TEXT NOT NULL, updated TEXT NOT NULL, owner TEXT';
    final customCols = newFields.map((f) => '"${f.name}" ${f.type.sqlColumnType}').join(', ');
    final allCols = customCols.isEmpty ? autoCols : '$autoCols, $customCols';
    await tx.execute('CREATE TABLE "$tempName" ($allCols);');

    // On copie colonne par colonne (via un SELECT nommé) plutôt qu'un
    // `SELECT *` pour que les champs absents de l'ancienne table (nouveaux
    // champs) deviennent bien NULL au lieu de faire planter la requête.
    final existingCols = (await tx.getAll('PRAGMA table_info("$name")'))
        .map((r) => r['name'] as String)
        .toSet();

    final autoNames = type == CollectionType.auth ? kAuthAutoFields : kBaseAutoFields;
    final selectCols = <String>[
      for (final c in autoNames) _selectAutoColumn(c, existingCols),
      for (final f in newFields)
        existingCols.contains(f.name) ? '"${f.name}"' : 'NULL AS "${f.name}"',
    ];

    await tx.execute(
      'INSERT INTO "$tempName" SELECT ${selectCols.join(', ')} FROM "$name";',
    );
    await tx.execute('DROP TABLE "$name";');
    await tx.execute('ALTER TABLE "$tempName" RENAME TO "$name";');
    if (type == CollectionType.auth) {
      await tx.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS "idx_${name}_discord_id" ON "$name"(discord_id);',
      );
    }
  }

  /// DDL des colonnes auto d'une collection auth — DOIT rester aligné avec
  /// [kAuthAutoFields] et le bootstrap `users` de database.dart.
  static const String _authAutoColumnsSql =
      'id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, '
      'discord_id TEXT, google_id TEXT, apple_id TEXT, microsoft_id TEXT, '
      'disabled INTEGER NOT NULL DEFAULT 0, '
      'created TEXT NOT NULL, updated TEXT NOT NULL';

  /// Expression SELECT pour une colonne auto : si absente de l'ancienne
  /// table (ex. `disabled`/`discord_id` ajoutés après coup), on fournit
  /// une valeur par défaut plutôt que de planter le rebuild.
  static String _selectAutoColumn(String column, Set<String> existingCols) {
    if (existingCols.contains(column)) return '"$column"';
    if (column == 'disabled') return '0 AS "disabled"';
    return 'NULL AS "$column"';
  }

  /// Met à jour uniquement les règles d'accès (aucun impact sur le schéma
  /// physique de la table). Laisser un paramètre à sa valeur par défaut
  /// ([kRuleUnset]) laisse la règle actuelle inchangée ; passer explicitement
  /// `null` la met à `null` (accès réservé aux administrateurs — voir
  /// rules_service.dart). Passer une chaîne (éventuellement vide) l'écrit
  /// telle quelle.
  Future<CollectionDefinition> updateRules(
    String name, {
    Object? listRule = kRuleUnset,
    Object? viewRule = kRuleUnset,
    Object? createRule = kRuleUnset,
    Object? updateRule = kRuleUnset,
    Object? deleteRule = kRuleUnset,
  }) async {
    final col = await getOrThrow(name);
    String? resolve(Object? provided, String? current) =>
        identical(provided, kRuleUnset) ? current : provided as String?;
    await db.execute(
      '''
      UPDATE _collections
      SET list_rule = ?, view_rule = ?, create_rule = ?, update_rule = ?, delete_rule = ?, updated = ?
      WHERE id = ?
      ''',
      [
        resolve(listRule, col.listRule),
        resolve(viewRule, col.viewRule),
        resolve(createRule, col.createRule),
        resolve(updateRule, col.updateRule),
        resolve(deleteRule, col.deleteRule),
        DateTime.now().toUtc().toIso8601String(),
        col.id,
      ],
    );
    return (await get(name))!;
  }

  Future<void> delete(String name) async {
    final col = await getOrThrow(name);
    if (name == 'users') {
      throw StateError('Impossible de supprimer la collection "users"');
    }
    await db.writeTransaction((tx) async {
      await tx.execute('DROP TABLE IF EXISTS "$name";');
      await tx.execute('DELETE FROM _collections WHERE id = ?', [col.id]);
    });
  }
}
