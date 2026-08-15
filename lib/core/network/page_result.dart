import 'api_response.dart';

/// Contrato único de paginación para repositorios HTTP.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.hasMore,
    this.total,
    this.nextCursor,
  });

  final List<T> items;
  final int? total;
  final String? nextCursor;
  final bool hasMore;

  factory PageResult.fromResponse(
    ApiResponse response,
    T Function(Map<String, dynamic>) decode,
  ) {
    final payload = response.body;
    final items = payload is List
        ? payload
              .whereType<Map<String, dynamic>>()
              .map(decode)
              .toList(growable: false)
        : <T>[];
    final total = int.tryParse(response.headers['x-total-count'] ?? '');
    final nextCursor = response.headers['x-next-cursor'];
    final explicitHasMore = response.headers['x-has-more'];
    return PageResult<T>(
      items: items,
      total: total,
      nextCursor: nextCursor,
      hasMore:
          explicitHasMore == 'true' ||
          (explicitHasMore == null && nextCursor != null),
    );
  }
}
