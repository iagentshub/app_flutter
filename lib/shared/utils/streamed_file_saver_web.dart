import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

enum StreamedFileSaveResult { saved, cancelled, checksumMismatch }

Future<StreamedFileSaveResult> saveStreamedFile({
  required Stream<List<int>> stream,
  required String fileName,
  required String dialogTitle,
  String? expectedSha256,
}) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    bytes.add(chunk);
  }
  final data = bytes.takeBytes();
  if (expectedSha256 != null &&
      expectedSha256.isNotEmpty &&
      sha256.convert(data).toString().toLowerCase() !=
          expectedSha256.toLowerCase()) {
    return StreamedFileSaveResult.checksumMismatch;
  }
  final path = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: Uint8List.fromList(data),
  );
  return path == null
      ? StreamedFileSaveResult.cancelled
      : StreamedFileSaveResult.saved;
}
