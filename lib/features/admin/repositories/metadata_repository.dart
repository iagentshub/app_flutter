import '../../../core/network/api_client.dart';

class MetadataTable {
  const MetadataTable({required this.raw});

  final Map<String, dynamic> raw;

  String get name => raw['name'] as String? ?? '';

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get rows => _asInt(raw['rows']);
  int get colCount => _asInt(raw['col_count']);
  int get sizeBytes => _asInt(raw['size_bytes']);
}

class MetadataPageData {
  const MetadataPageData({required this.raw});

  final Map<String, dynamic> raw;

  List<String> get columns {
    final value = raw['columns'];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  List<List<String?>> get rows {
    final value = raw['rows'];
    if (value is! List) return const [];
    return value.map((row) {
      if (row is! List) return <String?>[];
      return row.map((cell) => cell?.toString()).toList();
    }).toList();
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get total => _asInt(raw['total']);
  int get page => _asInt(raw['page']);
  int get pageSize => _asInt(raw['page_size']);
  int get pages => _asInt(raw['pages']);
}

class MetadataRepository {
  MetadataRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<MetadataTable>> listTables(String token) async {
    final response = await apiClient.get('/api/admin/metadata/tables', gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => MetadataTable(raw: item))
        .toList();
  }

  Future<MetadataPageData> tableData(
    String token, {
    required String tableName,
    required int page,
    int pageSize = 50,
    String query = '',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final path = Uri(
      path: '/api/admin/metadata/tables/${Uri.encodeComponent(tableName)}/data',
      queryParameters: params,
    ).toString();
    final response = await apiClient.get(path, gaToken: token);
    return MetadataPageData(raw: response.json);
  }
}
