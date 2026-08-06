import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

enum StatusDotState { ok, error, pending, unknown }

/// Punto de estado (verde/rojo/gris, o naranja parpadeante mientras hay una
/// operación en curso) — mismo indicador visual en toda la app: salud de
/// backend en Configurar backend y estado de comparticion por grupo.
class StatusDot extends StatefulWidget {
  const StatusDot({required this.state, this.size = 8, super.key});

  final StatusDotState state;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncController();
  }

  void _syncController() {
    if (widget.state == StatusDotState.pending) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.state) {
    StatusDotState.ok => FncColors.materialGreen800,
    StatusDotState.error => FncColors.materialRed800,
    StatusDotState.pending => FncColors.materialOrange800,
    StatusDotState.unknown => FncColors.materialGrey,
  };

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
    final controller = _controller;
    if (controller == null) return dot;
    return FadeTransition(
      opacity: Tween(
        begin: 0.35,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}
