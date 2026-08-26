import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../core/config/directory_import_policy.dart';
import '../../../utils/i18n.dart';
import '../models/local_knowledge_file.dart';

Future<KnowledgeDirectorySelection?> pickKnowledgeDirectory({
  KnowledgeDirectoryProgressCallback? onProgress,
  bool calculateChecksums = true,
}) async {
  final selected = Platform.isIOS
      ? await const MethodChannel('com.iagentshub.app/knowledge_directory')
            .invokeMethod<String>('pickDirectory')
      : await FilePicker.getDirectoryPath(
          dialogTitle: tr('knowledge.pick_directory'),
        );
  if (selected == null || selected.isEmpty) return null;
  final root = Directory(selected);
  final files = <LocalKnowledgeFile>[];
  var processed = 0;
  var ignored = 0;
  var totalBytes = 0;

  Future<void> scan(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .lastOrNull
            ?.toLowerCase();
        if (name != null &&
            DirectoryImportPolicy.ignoresDirectory(
              DirectoryImportKind.knowledgePack,
              name,
            )) {
          continue;
        }
        await scan(entity);
        continue;
      }
      if (entity is! File) continue;
      final relative = entity.path
          .substring(root.path.length)
          .replaceFirst(RegExp(r'^[\\/]'), '')
          .replaceAll(r'\', '/');
      processed++;
      if (!DirectoryImportPolicy.supportsPath(
        DirectoryImportKind.knowledgePack,
        relative,
      )) {
        ignored++;
      } else {
        try {
          final size = await entity.length();
          if (DirectoryImportPolicy.exceedsUploadLimit(size) ||
              DirectoryImportPolicy.exceedsUploadLimit(totalBytes + size)) {
            ignored++;
          } else {
            final stat = await entity.stat();
            files.add(
              await createLocalKnowledgeFile(
                relativePath: relative,
                bytes: Uint8List.fromList(await entity.readAsBytes()),
                originalSizeBytes: size,
                modifiedAt: stat.modified.millisecondsSinceEpoch,
                calculateChecksum: calculateChecksums,
              ),
            );
            totalBytes += size;
          }
        } on FileSystemException {
          ignored++;
        }
      }
      onProgress?.call(
        KnowledgeDirectoryProgress(
          processed: processed,
          compatible: files.length,
          ignored: ignored,
        ),
      );
    }
  }

  try {
    await scan(root);
    return KnowledgeDirectorySelection(files: files, ignoredCount: ignored);
  } finally {
    final temporaryCopy = root.parent;
    if (Platform.isIOS &&
        temporaryCopy.path.startsWith(Directory.systemTemp.path) &&
        temporaryCopy.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .lastOrNull
                ?.startsWith('knowledge-directory-') ==
            true) {
      try {
        await temporaryCopy.delete(recursive: true);
      } on FileSystemException {
        // iOS limpiará igualmente su directorio temporal.
      }
    }
  }
}
