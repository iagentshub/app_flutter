import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../../core/config/directory_import_policy.dart';
import '../models/local_knowledge_file.dart';

Future<KnowledgeDirectorySelection?> pickKnowledgeDirectory({
  KnowledgeDirectoryProgressCallback? onProgress,
  bool calculateChecksums = true,
}) async {
  final completer = Completer<KnowledgeDirectorySelection?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..webkitdirectory = true;

  Future<void> readSelection() async {
    final selected = input.files;
    if (selected == null || selected.length == 0) {
      completer.complete(null);
      return;
    }
    final files = <LocalKnowledgeFile>[];
    var ignored = 0;
    var totalBytes = 0;
    for (var index = 0; index < selected.length; index++) {
      final file = selected.item(index);
      if (file == null) continue;
      var relative = file.webkitRelativePath.replaceAll(r'\', '/');
      if (relative.contains('/')) {
        relative = relative.split('/').skip(1).join('/');
      }
      relative = relative.isEmpty ? file.name : relative;
      final size = file.size;
      if (!DirectoryImportPolicy.supportsPath(
            DirectoryImportKind.knowledgePack,
            relative,
          ) ||
          DirectoryImportPolicy.exceedsUploadLimit(size) ||
          DirectoryImportPolicy.exceedsUploadLimit(totalBytes + size)) {
        ignored++;
      } else {
        final buffer = await file.arrayBuffer().toDart;
        files.add(
          await createLocalKnowledgeFile(
            relativePath: relative,
            bytes: Uint8List.view(buffer.toDart),
            originalSizeBytes: size,
            mimeType: file.type,
            modifiedAt: file.lastModified,
            calculateChecksum: calculateChecksums,
          ),
        );
        totalBytes += size;
      }
      onProgress?.call(
        KnowledgeDirectoryProgress(
          processed: index + 1,
          compatible: files.length,
          ignored: ignored,
        ),
      );
    }
    completer.complete(
      KnowledgeDirectorySelection(files: files, ignoredCount: ignored),
    );
  }

  void onChange(web.Event _) => unawaited(readSelection());

  input.addEventListener('change', onChange.toJS);
  input.addEventListener(
    'cancel',
    ((web.Event _) => completer.complete(null)).toJS,
  );
  input.click();
  return completer.future;
}
