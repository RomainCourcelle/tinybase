import 'client.dart';

/// Paginated list of raw JSON records.
class RecordPage {
  /// Records for the current page.
  final List<Map<String, dynamic>> items;

  /// Total number of matching records.
  final int totalItems;

  /// Current 1-based page index.
  final int page;

  /// Page size used for this response.
  final int perPage;

  /// Creates a page result.
  const RecordPage({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.perPage,
  });
}

/// Generic CRUD helper for `/api/collections/<name>/records`.
class TinyBaseCollection {
  /// Parent client (handles auth + refresh).
  final TinyBaseClient client;

  /// Collection name as defined in TinyBase admin.
  final String name;

  /// Creates a collection accessor.
  TinyBaseCollection(this.client, this.name);

  /// Lists records with optional pagination, sort and filter.
  Future<RecordPage> list({
    int page = 1,
    int perPage = 30,
    String sort = '',
    String filter = '',
  }) async {
    final json = await client.requestJson(
      'GET',
      '/api/collections/$name/records',
      query: {
        'page': page,
        'perPage': perPage,
        if (sort.isNotEmpty) 'sort': sort,
        if (filter.isNotEmpty) 'filter': filter,
      },
    ) as Map<String, dynamic>;
    return RecordPage(
      items: (json['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      totalItems: json['totalItems'] as int,
      page: json['page'] as int,
      perPage: json['perPage'] as int,
    );
  }

  /// Fetches a single record by [id].
  Future<Map<String, dynamic>> getOne(String id) async {
    final json = await client.requestJson('GET', '/api/collections/$name/records/$id');
    return Map<String, dynamic>.from(json as Map);
  }

  /// Creates a record from [data].
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final json = await client.requestJson('POST', '/api/collections/$name/records', body: data);
    return Map<String, dynamic>.from(json as Map);
  }

  /// Updates record [id] with [data] (PATCH).
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final json = await client.requestJson('PATCH', '/api/collections/$name/records/$id', body: data);
    return Map<String, dynamic>.from(json as Map);
  }

  /// Deletes record [id].
  Future<void> delete(String id) async {
    await client.requestJson('DELETE', '/api/collections/$name/records/$id');
  }
}
