import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_motion.dart';

/// Página de go_router con transición *fade through* entre rutas hermanas.
///
/// Es lo que usan tanto las secciones internas (`internal_router.dart`) como
/// las pantallas de fuera de la sesión —login, registro, recuperar contraseña,
/// verificación, configuración del backend—: todas son hermanas entre sí, se va
/// de una a otra y no se entra en ninguna.
///
/// **La transición de las secciones vive aquí y no en el shell.** Envolver el
/// `child` del ShellRoute la ponía sobre el Navigator del shell, que lleva
/// `GlobalKey`, y un switcher lo mantenía en dos ramas del árbol a la vez: en
/// release eso no lanza nada, simplemente deja la pantalla sin pintar hasta que
/// otro evento programa un frame.
///
/// Antes cada una se envolvía en un fundido propio que arrancaba al montarse.
/// Eso solo animaba la entrante: la saliente se quitaba del árbol en el mismo
/// fotograma, así que ir de login a registro era un corte seco seguido de un
/// fundido, y volver, lo mismo. Aquí las dos rutas están vivas durante la
/// transición y el paso es continuo en ambos sentidos.
///
/// La `key` tiene que ser la `pageKey` del estado de go_router: es lo que le
/// dice al Navigator que son páginas distintas y no la misma reconstruida.
CustomTransitionPage<T> fadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: AppMotion.section,
    reverseTransitionDuration: AppMotion.section,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.reduced(context)) return child;
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        // El relleno por defecto es `canvasColor`, y en el tema claro ese es
        // blanco puro mientras el fondo real de las páginas es el
        // `scaffoldBackgroundColor`, un gris casi blanco: la diferencia se veía
        // como un fogonazo blanco a mitad de transición, en los dos sentidos.
        // Tiene que ser opaco: son pantallas completas y detrás no hay nada
        // que enseñar mientras cruzan.
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    },
  );
}
