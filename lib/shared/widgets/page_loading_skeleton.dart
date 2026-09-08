import 'package:flutter/material.dart';

import 'animated_iagents_mark.dart';

/// Stable placeholders while the deferred route downloads its code.
/// No shimmer: the brand indicator already communicates progress.
class PageLoadingSkeleton extends StatelessWidget {
  const PageLoadingSkeleton({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox.square(
                        dimension: 32,
                        child: IAgentsLoadingMark(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Placeholder(width: constraints.maxWidth * 0.4, height: 24),
                  const SizedBox(height: 16),
                  const _Placeholder(width: double.infinity, height: 48),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: List.generate(
                      columns * 2,
                      (_) => SizedBox(
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Placeholder(width: width * 0.45, height: 16),
                                const SizedBox(height: 24),
                                const _Placeholder(
                                  width: double.infinity,
                                  height: 12,
                                ),
                                const SizedBox(height: 8),
                                _Placeholder(width: width * 0.5, height: 12),
                                const SizedBox(height: 24),
                                _Placeholder(width: width * 0.3, height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}
