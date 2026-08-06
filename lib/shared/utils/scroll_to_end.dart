import 'package:flutter/material.dart';

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
