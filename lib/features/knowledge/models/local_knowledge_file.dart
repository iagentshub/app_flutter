import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

String _sha256ForBytes(Uint8List bytes) => sha256.convert(bytes).toString();

class LocalKnowledgeFile {
  const LocalKnowledgeFile({
    required this.relativePath,
    required this.bytes,
    this.originalSizeBytes,
    this.checksum = '',
    this.mimeType = '',
    this.modifiedAt,
  });

  final String relativePath;
  final Uint8List bytes;
  final int? originalSizeBytes;
  final String checksum;
  final String mimeType;
  final int? modifiedAt;

  String get name => relativePath.replaceAll(r'\', '/').split('/').last;
  int get sizeBytes => originalSizeBytes ?? bytes.length;
  String get resolvedChecksum =>
      checksum.isNotEmpty ? checksum : sha256.convert(bytes).toString();
  String get resolvedMimeType => mimeType.isNotEmpty
      ? mimeType
      : lookupMimeType(relativePath, headerBytes: bytes.take(16).toList()) ??
            'application/octet-stream';
}

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
  });

  final List<LocalKnowledgeFile> files;
  final int ignoredCount;
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
