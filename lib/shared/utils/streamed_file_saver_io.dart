import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

enum StreamedFileSaveResult { saved, cancelled, checksumMismatch }

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

Future<StreamedFileSaveResult> saveStreamedFile({
  required Stream<List<int>> stream,
  required String fileName,
  required String dialogTitle,
  String? expectedSha256,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
    }
    final data = bytes.takeBytes();
    if (!_matchesChecksum(data, expectedSha256)) {
      return StreamedFileSaveResult.checksumMismatch;
    }
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: data,
    );
    return path == null
        ? StreamedFileSaveResult.cancelled
        : StreamedFileSaveResult.saved;
  }

  final path = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
  );
  if (path == null) {
    await stream.listen(null).cancel();
    return StreamedFileSaveResult.cancelled;
  }

  final target = File(path);
  final partial = File(
    '$path.iagents-part-${DateTime.now().microsecondsSinceEpoch}',
  );
  final output = partial.openWrite();
  final digestSink = _DigestSink();
  final digestInput = sha256.startChunkedConversion(digestSink);
  try {
    await for (final chunk in stream) {
      output.add(chunk);
      digestInput.add(chunk);
    }
    await output.flush();
    await output.close();
    digestInput.close();
    if (!_sameDigest(digestSink.value, expectedSha256)) {
      await partial.delete();
      return StreamedFileSaveResult.checksumMismatch;
    }
    if (await target.exists()) await target.delete();
    await partial.rename(path);
    return StreamedFileSaveResult.saved;
  } catch (_) {
    await output.close();
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
}

bool _matchesChecksum(Uint8List bytes, String? expected) =>
    _sameDigest(sha256.convert(bytes), expected);

bool _sameDigest(Digest? actual, String? expected) =>
    expected == null ||
    expected.isEmpty ||
    actual.toString().toLowerCase() == expected.toLowerCase();
