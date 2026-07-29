import 'package:flutter/material.dart';

/// Transición simple de fundido entre vistas. Antes incluía un desplazamiento
/// (slide) y un barrido de scanline superpuestos, pero al combinarse con
/// contenido que aún está maquetándose (listas, cards) daba una sensación de
/// elementos "descuadrados" durante la animación. Un fundido puro no mueve
/// nada de sitio, así que no puede desalinear nada.
class TerminalViewTransition extends StatefulWidget {
  const TerminalViewTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 130),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<TerminalViewTransition> createState() => _TerminalViewTransitionState();
}

class _TerminalViewTransitionState extends State<TerminalViewTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: widget.child);
  }
}
