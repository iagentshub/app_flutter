import 'package:flutter/material.dart';

/// Duraciones del movimiento de la app y la consulta de movimiento reducido.
///
/// Están aquí y no en cada llamada porque una transición que dura distinto
/// según la pantalla se nota como una app inconsistente, y porque el ajuste
/// de accesibilidad hay que consultarlo en todas: `StatusDot`, `LaunchSplash`
/// y el grafo ya lo hacían cada uno por su cuenta.
abstract final class AppMotion {
  /// Cambio de sección dentro del shell. Corta a propósito: es la transición
  /// que el usuario ve más veces al día y cualquier cosa por encima de ~250 ms
  /// se percibe como que la app tarda en responder al clic del menú.
  static const Duration section = Duration(milliseconds: 220);

  /// Apertura de una página completa sobre otra (formularios, editores).
  /// Puede permitirse ser más larga: ocurre una vez por tarea, no por clic.
  static const Duration page = Duration(milliseconds: 300);

  /// Diálogos. Material sube el escalado en 150 ms y lo baja en 75: la salida
  /// más rápida que la entrada evita que el diálogo "se resista" al cerrarse.
  static const Duration modal = Duration(milliseconds: 150);

  /// Salida de un diálogo. Ver [modal].
  static const Duration modalReverse = Duration(milliseconds: 75);

  /// `true` cuando el sistema pide movimiento reducido (iOS «Reducir
  /// movimiento», Android «Quitar animaciones», `prefers-reduced-motion` en
  /// web). No es una preferencia estética: para quien tiene sensibilidad
  /// vestibular, una transición con escalado puede provocar mareo.
  ///
  /// Quien lo consulta debe **quitar** la animación, no acortarla. El
  /// framework ya acelera los `AnimationController` ×20 en este modo, y ese
  /// resto —un parpadeo de 15 ms— es justo lo que molesta.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}
