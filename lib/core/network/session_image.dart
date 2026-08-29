import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// Imagen que necesita la sesión para descargarse (los avatares).
///
/// `NetworkImage` no vale en web: el navegador solo manda la cookie sola en
/// peticiones **same-origin**. Con la aplicación en un puerto y el backend en
/// otro —`flutter run` contra el compose, sin ir más lejos— la descarga sale
/// sin credenciales, el backend responde 401 y la foto cae al respaldo de
/// iniciales. Sin error, sin hueco roto: exactamente igual que un usuario que
/// no tiene foto, que es lo que hace que nadie lo note.
///
/// Aquí la descarga la hace el cliente HTTP de la aplicación, que sí pide
/// credenciales (`withCredentials`), así que el origen deja de importar. Fuera
/// de web la cabecera `Cookie` sigue siendo necesaria y viaja en [headers].
@immutable
class SessionImage extends ImageProvider<SessionImage> {
  const SessionImage(
    this.url, {
    required this.client,
    this.headers,
    this.scale = 1.0,
  });

  final String url;
  final http.Client client;
  final Map<String, String>? headers;
  final double scale;

  @override
  Future<SessionImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<SessionImage>(this);

  @override
  ImageStreamCompleter loadImage(
    SessionImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _descargar(key, decode),
      scale: key.scale,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _descargar(
    SessionImage key,
    ImageDecoderCallback decode,
  ) async {
    final uri = Uri.parse(key.url);
    final response = await key.client.get(uri, headers: key.headers);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      // La excepción es la del framework a propósito: `errorBuilder` y el
      // respaldo de iniciales ya saben tratarla.
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is SessionImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'SessionImage("$url", scale: $scale)';
}
