import '../../../core/network/api_repository.dart';
import '../../../core/network/page_result.dart';
import '../../../models/logs/log_models.dart';

class LogsRepository extends ApiRepository {
  LogsRepository({required super.apiClient});

  static const _basePath = '/api/admin/logs';
  static const _listPath = '/api/v2/admin/logs';

  Future<LogsPage> list(
    String token, {
    String? dateFrom,
    String? dateTo,
    String? ip,
    String? username,
    String? level,
    String? source,
    String? category,
    String? action,
    String? resourceType,
    String? resourceId,
    String? outcome,
    String? query,
    String? cursor,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'limit': '$pageSize',
      'include_total': 'true',
      'cursor': ?cursor,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (ip != null && ip.isNotEmpty) 'ip': ip,
      if (username != null && username.isNotEmpty) 'username': username,
      if (level != null && level.isNotEmpty) 'level': level,
      if (source != null && source.isNotEmpty) 'source': source,
      if (category != null && category.isNotEmpty) 'category': category,
      if (action != null && action.isNotEmpty) 'action': action,
      if (resourceType != null && resourceType.isNotEmpty)
        'resource_type': resourceType,
      if (resourceId != null && resourceId.isNotEmpty)
        'resource_id': resourceId,
      if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final path = Uri(path: _listPath, queryParameters: params).toString();
    final response = await apiClient.get(path, gaToken: token);
    final page = PageResult<LogEntry>.fromCursorV2Response(
      response,
      (item) => LogEntry(raw: item),
    );
    return LogsPage(result: page, page: pageNumber, pageSize: pageSize);
  }

  Future<List<LogsSummaryDay>> summary(String token) async {
    final response = await apiClient.get(
      '$_basePath/summary',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => LogsSummaryDay(raw: item))
        .toList();
  }

  Future<String> exportCsv(
    String token, {
    String? dateFrom,
    String? dateTo,
    String? ip,
    String? username,
    String? level,
    String? source,
    String? category,
    String? action,
    String? resourceType,
    String? resourceId,
    String? outcome,
    String? query,
  }) async {
    final params = <String, String>{
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (ip != null && ip.isNotEmpty) 'ip': ip,
      if (username != null && username.isNotEmpty) 'username': username,
      if (level != null && level.isNotEmpty) 'level': level,
      if (source != null && source.isNotEmpty) 'source': source,
      if (category != null && category.isNotEmpty) 'category': category,
      if (action != null && action.isNotEmpty) 'action': action,
      if (resourceType != null && resourceType.isNotEmpty)
        'resource_type': resourceType,
      if (resourceId != null && resourceId.isNotEmpty)
        'resource_id': resourceId,
      if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final path = Uri(
      path: '$_basePath/export',
      queryParameters: params,
    ).toString();
    final response = await apiClient.get(path, gaToken: token);
    final body = response.body;
    return body is String ? body : '';
  }
}
