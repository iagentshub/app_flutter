import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Notifica sin marcar sucio un widget que el framework ya está construyendo.
///
/// El tema y el idioma llegan del backend también desde un `initState`: la
/// caché de arranque (`BootPlatformCache`) resuelve sin `await`, así que el
/// login los aplica en mitad del build del árbol. Notificar ahí ensucia el
/// `InheritedNotifier` que se está construyendo —«setState() or
/// markNeedsBuild() called during build»—, la excepción se lleva el frame y el
/// valor no llega a aplicarse.
///
/// La guarda vive en el notificador y no en cada llamador porque estos dos los
/// comparte toda la aplicación: hay ocho sitios que sincronizan tema o idioma y
/// el noveno no tiene por qué acordarse.
mixin NotificacionDiferida on ChangeNotifier {
  bool _desechado = false;

  /// `notifyListeners()` ahora, o justo después del frame si estamos dentro de
  /// uno.
  void notificarFueraDelBuild() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_desechado) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
