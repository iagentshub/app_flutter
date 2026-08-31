import '../../../core/network/api_repository.dart';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

class MetadataTable {
  const MetadataTable({required this.raw});

  final Map<String, dynamic> raw;

  String get name => raw['name'] as String? ?? '';

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
    final value = raw['items'];
    if (value is! List) return const [];
    return value.map((row) {
      if (row is! List) return <String?>[];
      return row.map((cell) => cell?.toString()).toList();
    }).toList();
  }

  Map<String, dynamic> get _page => raw['page'] is Map<String, dynamic>
      ? raw['page'] as Map<String, dynamic>
      : const {};

  int? get total =>
      _page['total'] is num ? (_page['total'] as num).toInt() : null;
  bool get hasMore => _page['has_more'] == true;
  String? get nextCursor => _page['next_cursor']?.toString();
}

class MetadataRepository extends ApiRepository {
  MetadataRepository({required super.apiClient});

  Future<List<MetadataTable>> listTables(String token) async {
    final response = await apiClient.get(
      '/api/admin/metadata/tables',
      gaToken: token,
      cache: true,
    );
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
    int pageSize = 50,
    String query = '',
    String? cursor,
  }) async {
    final params = <String, String>{
      'limit': '$pageSize',
      'include_total': 'true',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final path = Uri(
      path:
          '/api/v2/admin/metadata/tables/${Uri.encodeComponent(tableName)}/data',
      queryParameters: params,
    ).toString();
    final response = await apiClient.get(path, gaToken: token);
    return MetadataPageData(raw: response.json);
  }
}
