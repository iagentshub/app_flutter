import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Transición de las páginas que se abren sobre otra con `Navigator.push`
/// —formularios de agente, editor de workflows, editor de orquestaciones,
/// revisión de fuentes oficiales, chat—, con el patrón *shared axis Z* de
/// Material Motion: la saliente se aleja mientras la entrante llega desde el
/// fondo, que es lo que comunica «esto se abre encima», no «esto es otro sitio».
///
/// Va en el tema y no en cada `push` por dos razones. La primera es que hay
/// catorce llamadas repartidas por cinco ficheros y una nueva no tendría por
/// qué acordarse de nada. La segunda, más importante: sustituir el
/// `MaterialPageRoute` por una ruta propia habría dejado fuera el gesto de
/// retroceso de iOS, que lo aporta `MaterialRouteTransitionMixin` a través de
/// este mismo tema.
///
/// Por eso mismo **iOS conserva su transición nativa**: ahí el deslizamiento
/// lateral no es decoración, es el gesto con el que se vuelve atrás, y
/// cambiarlo por un escalado deja al usuario sin la señal de qué está
/// arrastrando.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _shared = SharedAxisPageTransitionsBuilder(
    transitionType: SharedAxisTransitionType.scaled,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    return _shared.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Tema de transiciones de página de la app.
///
/// En nativo, iOS y macOS quedan fuera a propósito —ver
/// [AppPageTransitionsBuilder]—: son las dos plataformas donde volver atrás es
/// un deslizamiento y la transición es la que lo hace legible.
///
/// En web no hay tal gesto, y `defaultTargetPlatform` ahí es el del sistema
/// que abre el navegador: sin esta distinción, la misma aplicación se
/// comportaría distinto según se abriera desde un Mac o desde un PC. Web usa
/// la transición de la app en todas.
PageTransitionsTheme get appPageTransitionsTheme {
  const propia = AppPageTransitionsBuilder();
  if (kIsWeb) {
    return const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: propia,
        TargetPlatform.fuchsia: propia,
        TargetPlatform.linux: propia,
        TargetPlatform.windows: propia,
        TargetPlatform.iOS: propia,
        TargetPlatform.macOS: propia,
      },
    );
  }
  return const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: propia,
      TargetPlatform.fuchsia: propia,
      TargetPlatform.linux: propia,
      TargetPlatform.windows: propia,
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
