import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Entrada para [compressAvatarBytes]. Función top-level porque `compute()`
/// exige una función de nivel superior o estática, no un closure/método de
/// instancia, para poder ejecutarla en un isolate aparte.
class AvatarCompressionInput {
  const AvatarCompressionInput(
    this.bytes, {
    this.maxDimension = 512,
    this.quality = 85,
  });

  final Uint8List bytes;
  final int maxDimension;
  final int quality;
}

class AvatarCompressionResult {
  const AvatarCompressionResult(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;
}

class AvatarCompressionException implements Exception {
  AvatarCompressionException(this.message);

  final String message;
}

/// Decodifica, redimensiona (lado mayor a [AvatarCompressionInput.maxDimension]
/// preservando el aspect ratio) y recodifica siempre como JPEG. Diseñada para
/// invocarse vía `compute(compressAvatarBytes, input)` y correr en un isolate
/// aparte sin bloquear la UI.
AvatarCompressionResult compressAvatarBytes(AvatarCompressionInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) {
    throw AvatarCompressionException('No se pudo decodificar la imagen');
  }

  final longestSide = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longestSide > input.maxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? input.maxDimension : null,
          height: decoded.height > decoded.width ? input.maxDimension : null,
        )
      : decoded;

  final jpgBytes = img.encodeJpg(resized, quality: input.quality);
  return AvatarCompressionResult(Uint8List.fromList(jpgBytes), 'avatar.jpg');
}
