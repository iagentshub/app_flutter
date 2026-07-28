import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';

class ExploreRepository {
  ExploreRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<ExploreItem>> listResources(
    String token, {
    required String type,
    String query = '',
    String category = '',
    String label = '',
  }) async {
    final params = <String, String>{
      'type': type,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (category.trim().isNotEmpty) 'category': category.trim(),
      if (label.trim().isNotEmpty) 'label': label.trim(),
    };
    final uri = Uri(path: '/api/explore', queryParameters: params);
    final response = await apiClient.get(uri.toString(), gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ExploreItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getPreview(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/explore/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/preview',
      gaToken: token,
    );
    return response.json;
  }

  Future<int> star(String token, {required String resourceType, required String resourceId}) async {
    final response = await apiClient.post(
      '/api/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/star',
      gaToken: token,
    );
    apiClient.invalidateCache('/api/explore');
    final payload = response.json;
    final stars = payload['stars'];
    if (stars is int) return stars;
    if (stars is num) return stars.toInt();
    return 0;
  }

  Future<int> unstar(String token, {required String resourceType, required String resourceId}) async {
    final response = await apiClient.delete(
      '/api/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/star',
      gaToken: token,
    );
    apiClient.invalidateCache('/api/explore');
    final payload = response.json;
    final stars = payload['stars'];
    if (stars is int) return stars;
    if (stars is num) return stars.toInt();
    return 0;
  }

  Future<Map<String, dynamic>> linkResource(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    switch (resourceType) {
      case 'knowledge':
        return (await apiClient.post(
          '/api/knowledge/${Uri.encodeComponent(resourceId)}/link',
          gaToken: token,
        ))
            .json;
      case 'workflow':
        return (await apiClient.post(
          '/api/workflows/${Uri.encodeComponent(resourceId)}/link',
          gaToken: token,
        ))
            .json;
      case 'agent':
        return _linkWithScopeFallback(
          token,
          '/api/agents/public/${Uri.encodeComponent(resourceId)}/link',
          '/api/agents/private/${Uri.encodeComponent(resourceId)}/link',
        );
      case 'skill':
        return _linkWithScopeFallback(
          token,
          '/api/skills/public/${Uri.encodeComponent(resourceId)}/link',
          '/api/skills/private/${Uri.encodeComponent(resourceId)}/link',
        );
      default:
        throw ApiError(statusCode: 422, message: 'Tipo no soportado para link: $resourceType');
    }
  }

  Future<Map<String, dynamic>> _linkWithScopeFallback(
    String token,
    String primaryPath,
    String secondaryPath,
  ) async {
    try {
      final response = await apiClient.post(primaryPath, gaToken: token);
      return response.json;
    } on ApiError catch (_) {
      final response = await apiClient.post(secondaryPath, gaToken: token);
      return response.json;
    }
  }
}
