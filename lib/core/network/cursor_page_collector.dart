import 'cursor_pagination_exception.dart';
import 'page_result.dart';

export 'cursor_pagination_exception.dart';

/// Recorre un listado cursor-only y valida el contrato en cada página.
Future<List<T>> collectCursorPages<T>(
  Future<PageResult<T>> Function(String? cursor) loadPage,
) async {
  final items = <T>[];
  final seenCursors = <String>{};
  String? cursor;
  while (true) {
    final page = await loadPage(cursor);
    items.addAll(page.items);
    if (!page.hasMore) return items;
    final nextCursor = page.nextCursor;
    if (nextCursor == null || nextCursor.isEmpty) {
      throw const CursorPaginationException.missingNextCursor();
    }
    if (!seenCursors.add(nextCursor)) {
      throw const CursorPaginationException.repeatedCursor();
    }
    cursor = nextCursor;
  }
}
