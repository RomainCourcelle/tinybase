import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

import 'package:tinybase_shared/tinybase_shared.dart';
import 'collections_service.dart';
import 'filter_parser.dart';
import 'rules_service.dart';

const _uuid = Uuid();

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException([this.message = 'Accès refusé']);
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'Introuvable']);
}

/// CRUD générique sur la table physique d'une collection, avec application
/// des règles d'accès (RulesService) et du filtre/tri/pagination de la
/// requête. C'est l'équivalent de l'API REST auto-générée de PocketBase.
class RecordsService {
  final SqliteDatabase db;
  final CollectionsService collections;
  final RulesService rules;

  RecordsService(this.db, this.collections, {this.rules = const RulesService()});

  Future<CollectionDefinition> _requireWritableCollection(String name) async {
    final col = await collections.getOrThrow(name);
    if (col.type == CollectionType.auth) {
      throw ForbiddenException(
        'La collection "$name" est une collection auth : passe par /api/auth/*, pas par /api/collections/*',
      );
    }
    return col;
  }

  Future<({List<Map<String, dynamic>> items, int totalItems, int page, int perPage})> list(
    String collectionName, {
    required AuthContext auth,
    String filter = '',
    String sort = '',
    int page = 1,
    int perPage = 30,
  }) async {
    final col = await collections.getOrThrow(collectionName);
    final decision = rules.forRead(col.listRule, auth);
    if (!decision.allowed) throw ForbiddenException();

    final allowedColumns = {...col.autoFields, ...col.fields.map((f) => f.name)};
    final (filterSql, filterParams) = FilterParser.parse(filter, allowedColumns);

    final whereClauses = <String>[
      if (decision.sqlPredicate != null) decision.sqlPredicate!,
      if (filterSql.isNotEmpty) filterSql,
    ];
    final whereSql = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final params = [...decision.params, ...filterParams];

    final orderSql = _buildOrderBy(sort, allowedColumns);
    final safePerPage = perPage.clamp(1, 200);
    final offset = (page.clamp(1, 1 << 30) - 1) * safePerPage;

    final countRow = await db.get(
      'SELECT COUNT(*) as c FROM "$collectionName" $whereSql',
      params,
    );
    final totalItems = countRow['c'] as int;

    final rows = await db.getAll(
      'SELECT * FROM "$collectionName" $whereSql $orderSql LIMIT ? OFFSET ?',
      [...params, safePerPage, offset],
    );

    return (
      items: rows.map((r) => _publicRecord(col, Map<String, dynamic>.from(r))).toList(),
      totalItems: totalItems,
      page: page,
      perPage: safePerPage,
    );
  }

  Future<Map<String, dynamic>> view(String collectionName, String id, {required AuthContext auth}) async {
    final col = await collections.getOrThrow(collectionName);
    final row = await db.getOptional('SELECT * FROM "$collectionName" WHERE id = ?', [id]);
    if (row == null) throw NotFoundException();

    final record = Map<String, dynamic>.from(row);
    if (!rules.forRecordAction(col.viewRule, auth, record)) throw ForbiddenException();
    return _publicRecord(col, record);
  }

  Future<Map<String, dynamic>> create(
    String collectionName,
    Map<String, dynamic> data, {
    required AuthContext auth,
  }) async {
    final col = await _requireWritableCollection(collectionName);
    if (!rules.forCreate(col.createRule, auth)) throw ForbiddenException();

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    final columns = <String>['id', 'created', 'updated', 'owner'];
    final values = <Object?>[id, now, now, auth.userId];

    for (final field in col.fields) {
      if (!data.containsKey(field.name)) {
        if (field.required) {
          throw FormatException('Champ requis manquant : "${field.name}"');
        }
        continue;
      }
      final coerced = field.type.coerce(data[field.name]);
      if (field.required && coerced == null) {
        throw FormatException('Champ requis manquant : "${field.name}"');
      }
      columns.add(field.name);
      values.add(coerced);
    }

    final placeholders = List.filled(columns.length, '?').join(', ');
    final quotedColumns = columns.map((c) => '"$c"').join(', ');
    await db.execute(
      'INSERT INTO "$collectionName" ($quotedColumns) VALUES ($placeholders)',
      values,
    );

    return view(collectionName, id, auth: auth);
  }

  Future<Map<String, dynamic>> update(
    String collectionName,
    String id,
    Map<String, dynamic> data, {
    required AuthContext auth,
  }) async {
    final col = await _requireWritableCollection(collectionName);
    final existingRow = await db.getOptional('SELECT * FROM "$collectionName" WHERE id = ?', [id]);
    if (existingRow == null) throw NotFoundException();
    final existing = Map<String, dynamic>.from(existingRow);

    if (!rules.forRecordAction(col.updateRule, auth, existing)) throw ForbiddenException();

    final setClauses = <String>['"updated" = ?'];
    final values = <Object?>[DateTime.now().toUtc().toIso8601String()];

    for (final field in col.fields) {
      if (!data.containsKey(field.name)) continue;
      final coerced = field.type.coerce(data[field.name]);
      if (field.required && coerced == null) {
        throw FormatException('Champ requis manquant : "${field.name}"');
      }
      setClauses.add('"${field.name}" = ?');
      values.add(coerced);
    }

    values.add(id);
    await db.execute(
      'UPDATE "$collectionName" SET ${setClauses.join(', ')} WHERE id = ?',
      values,
    );

    return view(collectionName, id, auth: auth);
  }

  /// Contrairement à `create`/`update` (qui passent par
  /// [_requireWritableCollection] et refusent TOUJOURS une collection
  /// `auth`, même pour l'admin — modifier `password_hash` à la main via
  /// l'API records générique n'a pas de sens), la suppression n'a aucune
  /// invariant à préserver : un admin doit pouvoir virer un compte
  /// utilisateur (ban/suppression RGPD...) sans passer par `/api/auth/*`,
  /// qui n'expose aucune route pour ça côté utilisateur lui-même.
  Future<void> delete(String collectionName, String id, {required AuthContext auth}) async {
    final col = await collections.getOrThrow(collectionName);
    if (col.type == CollectionType.auth && !auth.isAdmin) {
      throw ForbiddenException(
        'La collection "$collectionName" est une collection auth : seul un admin peut y supprimer un record directement.',
      );
    }
    final existingRow = await db.getOptional('SELECT * FROM "$collectionName" WHERE id = ?', [id]);
    if (existingRow == null) throw NotFoundException();
    final existing = Map<String, dynamic>.from(existingRow);

    if (!rules.forRecordAction(col.deleteRule, auth, existing)) throw ForbiddenException();

    await db.execute('DELETE FROM "$collectionName" WHERE id = ?', [id]);
  }

  String _buildOrderBy(String sort, Set<String> allowedColumns) {
    if (sort.trim().isEmpty) return 'ORDER BY "created" DESC';
    final parts = sort.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    final clauses = <String>[];
    for (final part in parts) {
      final desc = part.startsWith('-');
      final field = desc ? part.substring(1) : part;
      if (!allowedColumns.contains(field)) {
        throw FormatException('Champ de tri inconnu : "$field"');
      }
      clauses.add('"$field" ${desc ? 'DESC' : 'ASC'}');
    }
    return clauses.isEmpty ? '' : 'ORDER BY ${clauses.join(', ')}';
  }

  /// Retire les secrets (`password_hash`, …) avant sérialisation API —
  /// même pour l'admin : un hash bcrypt n'a rien à faire dans une réponse
  /// REST (PocketBase fait pareil).
  Map<String, dynamic> _publicRecord(CollectionDefinition col, Map<String, dynamic> record) {
    if (col.type != CollectionType.auth) return record;
    final cleaned = Map<String, dynamic>.from(record);
    for (final secret in kAuthSecretFields) {
      cleaned.remove(secret);
    }
    return cleaned;
  }
}
