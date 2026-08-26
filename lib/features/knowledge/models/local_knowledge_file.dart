import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import '../../../core/config/directory_import_policy.dart';

String _sha256ForBytes(Uint8List bytes) => sha256.convert(bytes).toString();

class LocalKnowledgeFile {
  const LocalKnowledgeFile({
    required this.relativePath,
    required this.bytes,
    this.originalSizeBytes,
    this.checksum = '',
    this.mimeType = '',
    this.modifiedAt,
    this.bytesLoader,
  });

  final String relativePath;
  final Uint8List bytes;
  final int? originalSizeBytes;
  final String checksum;
  final String mimeType;
  final int? modifiedAt;
  final Future<Uint8List> Function()? bytesLoader;

  String get name => relativePath.replaceAll(r'\', '/').split('/').last;
  int get sizeBytes => originalSizeBytes ?? bytes.length;
  bool get isDeferred => bytesLoader != null;
  Future<Uint8List> readBytes() async =>
      bytesLoader == null ? bytes : await bytesLoader!();
  String get resolvedChecksum {
    if (checksum.isNotEmpty) return checksum;
    if (isDeferred) {
      throw StateError('Load deferred bytes before calculating a checksum');
    }
    return sha256.convert(bytes).toString();
  }

  String get resolvedMimeType => mimeType.isNotEmpty
      ? mimeType
      : lookupMimeType(relativePath, headerBytes: bytes.take(16).toList()) ??
            'application/octet-stream';
}

LocalKnowledgeFile createDeferredLocalKnowledgeFile({
  required String relativePath,
  required Future<Uint8List> Function() readBytes,
  int? originalSizeBytes,
  String mimeType = '',
  int? modifiedAt,
}) => LocalKnowledgeFile(
  relativePath: relativePath,
  bytes: Uint8List(0),
  originalSizeBytes: originalSizeBytes,
  mimeType: mimeType,
  modifiedAt: modifiedAt,
  bytesLoader: readBytes,
);

Future<LocalKnowledgeFile> createLocalKnowledgeFile({
  required String relativePath,
  required Uint8List bytes,
  int? originalSizeBytes,
  String mimeType = '',
  int? modifiedAt,
  bool calculateChecksum = true,
}) async => LocalKnowledgeFile(
  relativePath: relativePath,
  bytes: bytes,
  originalSizeBytes: originalSizeBytes,
  checksum: calculateChecksum ? await compute(_sha256ForBytes, bytes) : '',
  mimeType: mimeType.isNotEmpty
      ? mimeType
      : lookupMimeType(relativePath, headerBytes: bytes.take(16).toList()) ??
            'application/octet-stream',
  modifiedAt: modifiedAt,
);

class KnowledgeDirectorySelection {
  const KnowledgeDirectorySelection({
    required this.files,
    required this.ignoredCount,
    this.skippedByReason = const {},
    this.onDispose,
  });

  final List<LocalKnowledgeFile> files;
  final int ignoredCount;
  final Map<DirectorySkipReason, int> skippedByReason;
  final Future<void> Function()? onDispose;

  Future<void> dispose() async {
    await onDispose?.call();
  }
}

class KnowledgeDirectoryProgress {
  const KnowledgeDirectoryProgress({
    required this.processed,
    required this.compatible,
    required this.ignored,
  });

  final int processed;
  final int compatible;
  final int ignored;
}

typedef KnowledgeDirectoryProgressCallback = void Function(
  KnowledgeDirectoryProgress progress,
);
