import 'package:flutter/material.dart';

class TerminalViewTransition extends StatefulWidget {
  const TerminalViewTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 150),
    this.scanline = true,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final bool scanline;

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
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.022),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final dimOpacity = (1 - _controller.value) * 0.14;
        final scanOpacity = widget.scanline ? (1 - _controller.value) * 0.35 : 0.0;
        final scanY = -1 + (_controller.value * 2);

        return Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(position: _slide, child: child),
            ),
            if (dimOpacity > 0.001)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: dimOpacity),
                ),
              ),
            if (scanOpacity > 0.001)
              IgnorePointer(
                child: Align(
                  alignment: Alignment(0, scanY),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 2,
                    color: const Color(0xFFD90429).withValues(alpha: scanOpacity),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
