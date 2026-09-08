import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Agrupa ajustes breves sin estirar sus campos por toda la pantalla.
class WebFormSection extends StatelessWidget {
  const WebFormSection({
    required this.child,
    this.title,
    this.description,
    super.key,
  });
  final Widget child;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (title != null || description != null) const SizedBox(height: 24),
        child,
      ],
    );
    if (!kIsWeb) return content;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: content,
      ),
    );
  }
}
