import 'client.dart';

class RecordPage {
  final List<Map<String, dynamic>> items;
  final int totalItems;
  final int page;
  final int perPage;
  const RecordPage({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.perPage,
  });
}

/// CRUD générique `/api/collections/<name>/records` avec refresh auto via le client.
class TinyBaseCollection {
  final TinyBaseClient client;
  final String name;
  TinyBaseCollection(this.client, this.name);

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

  Future<Map<String, dynamic>> getOne(String id) async {
    final json = await client.requestJson('GET', '/api/collections/$name/records/$id');
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final json = await client.requestJson('POST', '/api/collections/$name/records', body: data);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final json = await client.requestJson('PATCH', '/api/collections/$name/records/$id', body: data);
    return Map<String, dynamic>.from(json as Map);
  }

  Future<void> delete(String id) async {
    await client.requestJson('DELETE', '/api/collections/$name/records/$id');
  }
}
