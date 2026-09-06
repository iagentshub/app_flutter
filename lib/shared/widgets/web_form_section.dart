import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Agrupa ajustes breves sin estirar sus campos por toda la pantalla.
class WebFormSection extends StatelessWidget {
  const WebFormSection({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}
