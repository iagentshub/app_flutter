import 'dart:async';
import '../../utils/i18n.dart';

import 'api_error.dart';

/// Separa líneas de un stream sin permitir que una línea sin terminador crezca
/// indefinidamente en memoria.
class BoundedLineTransformer extends StreamTransformerBase<String, String> {
  const BoundedLineTransformer({required this.maxLineChars});

  final int maxLineChars;

  @override
  Stream<String> bind(Stream<String> stream) async* {
    var pending = StringBuffer();
    var pendingLength = 0;
    await for (final chunk in stream) {
      var offset = 0;
      while (offset < chunk.length) {
        final newline = chunk.indexOf('\n', offset);
        final end = newline < 0 ? chunk.length : newline;
        final fragment = chunk.substring(offset, end);
        if (pendingLength + fragment.length > maxLineChars) {
          throw ApiError(
            statusCode: 502,
            code: 'stream_event_too_large',
            message: tr('common.event_too_large'),
          );
        }
        pending.write(fragment);
        pendingLength += fragment.length;
        if (newline < 0) break;
        final line = pending.toString();
        yield line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
        pending = StringBuffer();
        pendingLength = 0;
        offset = newline + 1;
      }
    }
    if (pendingLength > 0) yield pending.toString();
  }
}
