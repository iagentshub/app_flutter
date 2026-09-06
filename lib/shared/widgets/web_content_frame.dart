import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Mantiene un mismo eje de contenido en la cabecera y las páginas web.
/// Las páginas conservan sus 16 px interiores; el marco añade aire en web.
class WebContentFrame extends StatelessWidget {
  const WebContentFrame({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.compactPadding = EdgeInsets.zero,
    super.key,
  });

  static const maxWidth = 1600.0;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry compactPadding;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: constraints.maxWidth >= 900 ? padding : compactPadding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Durante la animación del sidebar se recorta, pero no se comprime el menú.
class WebSidebarViewport extends StatelessWidget {
  const WebSidebarViewport({
    required this.width,
    required this.child,
    super.key,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return OverflowBox(
      alignment: AlignmentDirectional.topStart,
      minWidth: width,
      maxWidth: width,
      child: child,
    );
  }
}
