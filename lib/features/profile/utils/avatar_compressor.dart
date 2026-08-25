import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Recorte normalizado (0..1) sobre la imagen **ya rotada**. Va en fracciones
/// y no en píxeles porque quien lo calcula es la vista previa del diálogo, que
/// decodifica a resolución reducida para no meter un bitmap de 12 MP en el
/// hilo de UI: en píxeles, el recorte saldría desplazado respecto al original.
class AvatarCrop {
  const AvatarCrop({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

/// Entrada para [compressAvatarBytes]. Función top-level porque `compute()`
/// exige una función de nivel superior o estática, no un closure/método de
/// instancia, para poder ejecutarla en un isolate aparte.
class AvatarCompressionInput {
  const AvatarCompressionInput(
    this.bytes, {
    this.maxDimension = 512,
    this.quality = 85,
    this.quarterTurns = 0,
    this.crop,
  });

  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  /// Giros de 90° en sentido horario que el usuario aplicó en el diálogo.
  final int quarterTurns;

  /// Encuadre elegido. Sin él se sube la imagen entera, que es lo que hacía
  /// antes de existir el diálogo de ajuste.
  final AvatarCrop? crop;
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

/// Decodifica, endereza según EXIF, rota, recorta, redimensiona (lado mayor a
/// [AvatarCompressionInput.maxDimension] preservando el aspect ratio) y
/// recodifica siempre como JPEG. Diseñada para invocarse vía
/// `compute(compressAvatarBytes, input)` y correr en un isolate aparte sin
/// bloquear la UI.
AvatarCompressionResult compressAvatarBytes(AvatarCompressionInput input) {
  // `decodeImage` no siempre devuelve `null` ante basura: elige decodificador
  // por firma y el candidato equivocado revienta por su cuenta —unos bytes
  // cualesquiera acaban en el lector de PSD y saltan con un RangeError. Todo
  // sale por la misma excepción para que quien llame tenga un solo caso.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(input.bytes);
  } catch (error) {
    throw AvatarCompressionException('No se pudo decodificar la imagen: $error');
  }
  if (decoded == null) {
    throw AvatarCompressionException('No se pudo decodificar la imagen');
  }

  // El códec de Flutter que pinta la vista previa sí respeta la orientación
  // EXIF; `decodeImage` la deja en los metadatos. Sin hornearla aquí, una foto
  // hecha en vertical se subiría tumbada y el recorte caería en otro sitio.
  var image = img.bakeOrientation(decoded);

  final turns = input.quarterTurns % 4;
  if (turns != 0) {
    image = img.copyRotate(image, angle: turns * 90);
  }

  final crop = input.crop;
  if (crop != null) {
    final x = (crop.left * image.width).round().clamp(0, image.width - 1);
    final y = (crop.top * image.height).round().clamp(0, image.height - 1);
    final width = (crop.width * image.width).round().clamp(
      1,
      image.width - x,
    );
    final height = (crop.height * image.height).round().clamp(
      1,
      image.height - y,
    );
    image = img.copyCrop(image, x: x, y: y, width: width, height: height);
  }

  final longestSide = image.width > image.height ? image.width : image.height;
  final resized = longestSide > input.maxDimension
      ? img.copyResize(
          image,
          width: image.width >= image.height ? input.maxDimension : null,
          height: image.height > image.width ? input.maxDimension : null,
        )
      : image;

  final jpgBytes = img.encodeJpg(resized, quality: input.quality);
  return AvatarCompressionResult(Uint8List.fromList(jpgBytes), 'avatar.jpg');
}
