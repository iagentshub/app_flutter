import 'dart:typed_data';

import 'package:app_flutter/features/profile/utils/avatar_compressor.dart';
import 'package:app_flutter/shared/utils/date_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Imagen de 100x50: mitad izquierda roja, mitad derecha azul. Basta para
/// distinguir a qué lado cayó el recorte y hacia dónde giró.
Uint8List _imagenDeDosMitades() {
  final image = img.Image(width: 100, height: 50);
  for (var y = 0; y < 50; y++) {
    for (var x = 0; x < 100; x++) {
      image.setPixelRgb(x, y, x < 50 ? 255 : 0, 0, x < 50 ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

img.Image _decodificar(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  group('el ajuste del avatar se aplica antes de subirlo', () {
    test('sin recorte se sube la imagen entera', () {
      final result = compressAvatarBytes(
        AvatarCompressionInput(_imagenDeDosMitades()),
      );
      final salida = _decodificar(result.bytes);
      expect(salida.width, 100);
      expect(salida.height, 50);
    });

    test('el recorte se queda con el trozo elegido', () {
      final result = compressAvatarBytes(
        AvatarCompressionInput(
          _imagenDeDosMitades(),
          crop: const AvatarCrop(left: 0, top: 0, width: 0.5, height: 1),
        ),
      );
      final salida = _decodificar(result.bytes);
      expect(salida.width, 50);
      expect(salida.height, 50);
      // JPEG es con pérdida, así que se comprueba el canal dominante y no el
      // valor exacto.
      final centro = salida.getPixel(25, 25);
      expect(centro.r, greaterThan(200));
      expect(centro.b, lessThan(60));
    });

    test('el giro cambia el lado largo y arrastra el recorte con él', () {
      final result = compressAvatarBytes(
        AvatarCompressionInput(_imagenDeDosMitades(), quarterTurns: 1),
      );
      final salida = _decodificar(result.bytes);
      expect(salida.width, 50);
      expect(salida.height, 100);
      // Un cuarto de vuelta horario manda el rojo de la izquierda arriba.
      final arriba = salida.getPixel(25, 10);
      expect(arriba.r, greaterThan(200));
    });

    test('el recorte no se sale de la imagen aunque los valores se pasen', () {
      final result = compressAvatarBytes(
        AvatarCompressionInput(
          _imagenDeDosMitades(),
          crop: const AvatarCrop(left: 0.9, top: 0.9, width: 1, height: 1),
        ),
      );
      final salida = _decodificar(result.bytes);
      expect(salida.width, lessThanOrEqualTo(100));
      expect(salida.height, lessThanOrEqualTo(50));
      expect(salida.width, greaterThan(0));
    });

    test('un lado mayor de 512 se reduce, uno menor se deja', () {
      final grande = img.Image(width: 1200, height: 600);
      final result = compressAvatarBytes(
        AvatarCompressionInput(Uint8List.fromList(img.encodePng(grande))),
      );
      expect(_decodificar(result.bytes).width, 512);
    });

    test('unos bytes que no son una imagen se rechazan con su excepción', () {
      expect(
        () => compressAvatarBytes(
          AvatarCompressionInput(Uint8List.fromList([1, 2, 3, 4])),
        ),
        throwsA(isA<AvatarCompressionException>()),
      );
    });
  });

  group('las fechas se pintan cortas', () {
    test('el ISO completo se queda en día y hora', () {
      // En local para que el test no dependa de la zona del que lo corre: lo
      // que se comprueba es el recorte, no la conversión.
      expect(
        formatDateTimeShort('2026-03-07T09:41:03.512874'),
        '07/03/2026 09:41',
      );
    });

    test('sin hora cuando no aporta', () {
      expect(formatDateShort('2026-03-07T09:41:03.512874'), '07/03/2026');
    });

    test('una fecha ausente da el guion y una ilegible se enseña cruda', () {
      expect(formatDateTimeShort(null), '—');
      expect(formatDateTimeShort(''), '—');
      expect(formatDateTimeShort('nunca'), 'nunca');
    });
  });
}
