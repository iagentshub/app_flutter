import 'package:flutter/material.dart';

import '../state/async_section.dart';
import 'async_state_panel.dart';

/// Pinta una [AsyncSection] con la presentación que ya usaba cada página.
///
/// La parte visual no cambia: sigue delegando en [AsyncStatePanel]. Lo que
/// desaparece es el `if (_loading) ... if (_error != null) ...` repetido en
/// cada vista, con sus decisiones tomadas de forma distinta en cada copia.
class AsyncSectionBuilder<T> extends StatelessWidget {
  const AsyncSectionBuilder({
    required this.section,
    required this.retryLabel,
    required this.builder,
    super.key,
  });

  final AsyncSection<T> section;
  final String retryLabel;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: section,
      builder: (context, _) {
        final data = section.data;

        // Con datos ya cargados se siguen mostrando aunque una recarga falle
        // o esté en curso: vaciar la vista por un error de red es peor que
        // enseñar lo último bueno que se tenía.
        if (data != null) return builder(context, data);
        if (section.loading) return const AsyncStatePanel.loading();

        final error = section.error;
        if (error != null) {
          return AsyncStatePanel.error(
            message: error,
            retryLabel: retryLabel,
            onRetry: section.load,
          );
        }
        return const AsyncStatePanel.loading();
      },
    );
  }
}
