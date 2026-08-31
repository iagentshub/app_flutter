import '../../utils/i18n.dart';

/// Error local con código estable para incumplimientos del contrato cursor.
class CursorPaginationException implements Exception {
  const CursorPaginationException._(this.code);

  const CursorPaginationException.invalidResponse()
    : this._('pagination_invalid_response');

  const CursorPaginationException.missingNextCursor()
    : this._('pagination_missing_next_cursor');

  const CursorPaginationException.repeatedCursor()
    : this._('pagination_repeated_cursor');

  final String code;

  String get message => trErrorOr(code, code);

  @override
  String toString() => message;
}
