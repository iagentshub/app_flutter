import 'package:desktop_drop/desktop_drop.dart';

import '../../../core/config/directory_import_policy.dart';
import '../models/local_knowledge_file.dart';

/// Recolecta un árbol arrastrado aplicando una única política para Knowledge y
/// Agents. Evita que ambos flujos diverjan en exclusiones, límites y conteos.
Future<KnowledgeDirectorySelection> collectDroppedDirectory(
  List<DropItem> entries, {
  required DirectoryImportKind kind,
  bool calculateChecksums = true,
  KnowledgeDirectoryProgressCallback? onProgress,
}) async {
  final files = <LocalKnowledgeFile>[];
  final skipped = <DirectorySkipReason, int>{};
  var processed = 0;
  var totalBytes = 0;

  void registerSkip(DirectorySkipReason reason) {
    skipped.update(reason, (count) => count + 1, ifAbsent: () => 1);
  }

  int descendantFileCount(DropItemDirectory directory) => directory.children
      .map(
        (entry) => entry is DropItemDirectory ? descendantFileCount(entry) : 1,
      )
      .fold(0, (total, count) => total + count);

  void report() => onProgress?.call(
    KnowledgeDirectoryProgress(
      processed: processed,
      compatible: files.length,
      ignored: skipped.values.fold(0, (total, count) => total + count),
    ),
  );

  Future<void> scan(List<DropItem> children, String prefix) async {
    for (final entry in children) {
      final relative = prefix.isEmpty ? entry.name : '$prefix/${entry.name}';
      if (entry is DropItemDirectory) {
        if (DirectoryImportPolicy.ignoresDirectory(kind, entry.name)) {
          final count = descendantFileCount(entry);
          processed += count;
          for (var index = 0; index < count; index++) {
            registerSkip(DirectorySkipReason.ignoredDirectory);
          }
          report();
        } else {
          await scan(entry.children, relative);
        }
        continue;
      }

      processed++;
      final policyReason = DirectoryImportPolicy.skipReason(kind, relative);
      if (policyReason != null) {
        registerSkip(policyReason);
        report();
        continue;
      }
      if (kind == DirectoryImportKind.agent) {
        files.add(
          createDeferredLocalKnowledgeFile(
            relativePath: relative,
            readBytes: entry.readAsBytes,
          ),
        );
        report();
        continue;
      }
      try {
        final bytes = await entry.readAsBytes();
        if (DirectoryImportPolicy.exceedsUploadLimit(bytes.length) ||
            DirectoryImportPolicy.exceedsUploadLimit(
              totalBytes + bytes.length,
            )) {
          registerSkip(DirectorySkipReason.uploadLimit);
        } else {
          files.add(
            await createLocalKnowledgeFile(
              relativePath: relative,
              bytes: bytes,
              calculateChecksum: calculateChecksums,
            ),
          );
          totalBytes += bytes.length;
        }
      } catch (_) {
        registerSkip(DirectorySkipReason.readFailure);
      }
      report();
    }
  }

  await scan(entries, '');
  return KnowledgeDirectorySelection(
    files: files,
    ignoredCount: skipped.values.fold(0, (total, count) => total + count),
    skippedByReason: Map.unmodifiable(skipped),
  );
}
