import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../state/async_section.dart';
import 'async_state_panel.dart';
import 'motion/app_motion.dart';

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
      builder: (context, _) => _conTransicion(context, _estado(context)),
    );
  }

  /// El estado visible y su identidad. La clave es el estado, **no** los
  /// datos: con contenido en pantalla una recarga que trae otros elementos no
  /// debe fundir la vista entera, solo repintarla.
  ({String clave, Widget vista}) _estado(BuildContext context) {
    final data = section.data;

    // Con datos ya cargados se siguen mostrando aunque una recarga falle
    // o esté en curso: vaciar la vista por un error de red es peor que
    // enseñar lo último bueno que se tenía.
    if (data != null) {
      return (clave: 'data', vista: builder(context, data));
    }
    if (section.loading) {
      return (clave: 'loading', vista: const AsyncStatePanel.loading());
    }

    final error = section.error;
    if (error != null) {
      return (
        clave: 'error',
        vista: AsyncStatePanel.error(
          message: error,
          retryLabel: retryLabel,
          onRetry: section.load,
        ),
      );
    }
    return (clave: 'loading', vista: const AsyncStatePanel.loading());
  }

  /// Funde el indicador de carga con lo que llega detrás. Sin esto, el
  /// contenido sustituye al spinner en un fotograma y el salto se lee como un
  /// parpadeo, sobre todo cuando la respuesta llega rápido.
  Widget _conTransicion(
    BuildContext context,
    ({String clave, Widget vista}) e,
  ) {
    final keyed = KeyedSubtree(key: ValueKey<String>(e.clave), child: e.vista);
    if (AppMotion.reduced(context)) return keyed;
    return PageTransitionSwitcher(
      duration: AppMotion.section,
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
          FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            fillColor: Colors.transparent,
            child: child,
          ),
      child: keyed,
    );
  }
}
