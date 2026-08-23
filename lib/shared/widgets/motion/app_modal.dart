import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Abre un diálogo con la transición *fade through* de Material Motion: el
/// diálogo entra escalando desde el 80 % mientras el fondo se atenúa, y sale
/// en la mitad de tiempo del que tarda en entrar.
///
/// Es el reemplazo de `showDialog` en toda la app —hay setenta y cuatro
/// llamadas— y mantiene su firma a propósito, para que migrar sea cambiar el
/// nombre y para que la diferencia no se note al leer el código.
///
/// Lo que aporta sobre `showDialog`, además del movimiento:
///
/// - **Respeta el movimiento reducido.** Con el ajuste activo cae al
///   `showDialog` de siempre, sin escalado: el escalado es justo el gesto que
///   molesta a quien tiene sensibilidad vestibular.
/// - **La etiqueta de la barrera sigue traducida.** `showModal` la toma de
///   `MaterialLocalizations`, igual que `showDialog`, así que el lector de
///   pantalla sigue anunciando en el idioma de la app cómo se cierra.
///
/// [fullscreenSurface] marca el contenido que ya ocupa la pantalla entera y no
/// puede escalar: la capa transformada que añade el *fade through* deja, en
/// web, la cabecera del diálogo sin pintar aunque sus controles sigan
/// recibiendo eventos. Esos casos toman la misma ruta que el movimiento
/// reducido —`showDialog` a secas—, que es exactamente lo que necesitan.
/// Escrito aquí y no como excepción del guard de
/// `test/feature_architecture_test.dart`: una excepción por ruta invita a la
/// siguiente y no explica nada al que abra el fichero.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool fullscreenSurface = false,
  RouteSettings? routeSettings,
}) {
  if (fullscreenSurface || AppMotion.reduced(context)) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      routeSettings: routeSettings,
    );
  }
  return showModal<T>(
    context: context,
    configuration: _AppModalConfiguration(
      barrierDismissible: barrierDismissible,
    ),
    builder: builder,
    routeSettings: routeSettings,
  );
}

/// `FadeScaleTransitionConfiguration` con las duraciones de la app y con
/// `barrierDismissible` abierto: la del paquete lo fija en el constructor
/// como constante y aquí hay cinco diálogos que lo cierran a mano.
class _AppModalConfiguration extends FadeScaleTransitionConfiguration {
  const _AppModalConfiguration({required super.barrierDismissible})
    : super(
        transitionDuration: AppMotion.modal,
        reverseTransitionDuration: AppMotion.modalReverse,
      );
}
