import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Qué punteros pueden arrastrar una lista.
///
/// Flutter deja fuera el ratón a propósito —en una web con texto normal,
/// arrastrar selecciona—, y aquí eso dejaba media aplicación muerta en
/// escritorio y en web sin que nada fallara:
///
/// * las tiras horizontales (el selector de icono de marca del perfil, las
///   tablas de Admin, el picker de recursos de un agente) no se movían; con
///   el ratón encima la rueda tampoco es obvia, así que parecían recortadas.
/// * los trece `RefreshIndicator` de la aplicación son el único modo de
///   recargar esas pantallas, y tirar hacia abajo con el ratón no hacía nada.
///
/// El `trackpad` va aparte del ratón: un gesto de dos dedos en un portátil no
/// es un `PointerDeviceKind.mouse`.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.mouse,
  };
}
