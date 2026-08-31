import 'api_response.dart';
import 'cursor_pagination_exception.dart';

/// Contrato único de paginación para repositorios HTTP.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.hasMore,
    this.total,
    this.nextCursor,
    this.snapshotAt,
  });

  final List<T> items;
  final int? total;
  final String? nextCursor;
  final bool hasMore;
  final String? snapshotAt;

  factory PageResult.fromCursorV2Response(
    ApiResponse response,
    T Function(Map<String, dynamic>) decode,
  ) {
    final payload = response.body;
    if (payload is! Map<String, dynamic> ||
        payload['items'] is! List ||
        payload['page'] is! Map<String, dynamic>) {
      throw const CursorPaginationException.invalidResponse();
    }
    final rawItems = payload['items'] as List;
    final page = payload['page'] as Map<String, dynamic>;
    if (page['has_more'] is! bool ||
        rawItems.any((item) => item is! Map<String, dynamic>)) {
      throw const CursorPaginationException.invalidResponse();
    }
    final items = rawItems
        .cast<Map<String, dynamic>>()
        .map(decode)
        .toList(growable: false);
    final total = page['total'] is int ? page['total'] as int : null;
    final nextCursor = page['next_cursor']?.toString();
    final hasMore = page['has_more'] as bool;
    if (hasMore && (nextCursor == null || nextCursor.isEmpty)) {
      throw const CursorPaginationException.missingNextCursor();
    }
    return PageResult<T>(
      items: items,
      total: total,
      nextCursor: nextCursor,
      snapshotAt: page['snapshot_at']?.toString(),
      hasMore: hasMore,
    );
  }

  factory PageResult.fromLegacyResponse(
    ApiResponse response,
    T Function(Map<String, dynamic>) decode,
  ) {
    final payload = response.body;
    final rawItems = payload is List ? payload : const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(decode)
        .toList(growable: false);
    final nextCursor = response.headers['x-next-cursor'];
    final explicitHasMore = response.headers['x-has-more'];
    return PageResult<T>(
      items: items,
      total: int.tryParse(response.headers['x-total-count'] ?? ''),
      nextCursor: nextCursor,
      hasMore:
          explicitHasMore == 'true' ||
          (explicitHasMore == null && nextCursor != null),
    );
  }
}
