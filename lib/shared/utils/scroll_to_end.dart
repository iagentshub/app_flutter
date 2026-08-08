import 'package:flutter/material.dart';

/// Margen en el que se considera que el usuario "sigue el final": justo lo
/// que ocupa media burbuja, para que un arrastre mínimo no cuente como
/// haberse separado.
const _stickyThreshold = 48.0;

/// Si el usuario está pegado al final de [controller]. Sin clientes todavía
/// (primer frame) se considera que sí, para que el primer mensaje ancle abajo.
bool isAtEnd(ScrollController controller) {
  if (!controller.hasClients) return true;
  final position = controller.position;
  return position.maxScrollExtent - position.pixels <= _stickyThreshold;
}

/// Sigue el final solo si el usuario no se ha ido a leer hacia atrás. Es lo
/// que hay que llamar mientras llega una respuesta en streaming: arrastrar el
/// scroll arriba para releer no debe devolver la vista abajo en el siguiente
/// token.
void maybeScrollToEnd(ScrollController controller) {
  if (!isAtEnd(controller)) return;
  scrollToEnd(controller, animate: false);
}

/// Desplaza [controller] hasta el final tras el próximo frame — para listas
/// de chat que crecen mientras el usuario ya está mirando el final.
void scrollToEnd(ScrollController controller, {bool animate = true}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients) return;
    final target = controller.position.maxScrollExtent;
    if (animate) {
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      controller.jumpTo(target);
    }
  });
}
