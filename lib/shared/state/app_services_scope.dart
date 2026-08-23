import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';
import '../../features/executions/controllers/resource_executions_controller.dart';
import '../../features/workflows/controllers/workflow_runs_controller.dart';
import 'locale_controller.dart';
import 'session_controller.dart';

/// Servicios que necesita cualquier página autenticada.
///
/// `internal_router.dart` mencionaba `apiClient`, `sessionController` y
/// `localeController` 51 veces: los tres se pasaban a mano por constructor a
/// cada una de las 17 páginas internas, así que añadir una página —o dar a una
/// existente acceso a un servicio más— obligaba a editar el router, el
/// `ShellRoute` y la firma del widget.
///
/// El patrón alternativo ya existía y funcionaba en este mismo código:
/// `ThemeControllerScope` y `BrandIconScope` viajan por `InheritedWidget` y
/// ninguna página los recibe por constructor. Esto lo extiende a los tres
/// servicios globales, sin ninguna librería de inyección.
///
/// Lo que **no** cambia: `BackendController` y los repositorios de arranque
/// (`AuthRepository`, `DashboardRepository`) siguen viniendo por parámetro,
/// porque los usa el propio router en `redirect` y `refreshListenable`.
class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    this.workflowRunsController,
    this.resourceExecutionsController,
    required super.child,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final WorkflowRunsController? workflowRunsController;
  final ResourceExecutionsController? resourceExecutionsController;

  /// Los servicios se crean una vez al arrancar y no se sustituyen, así que
  /// leerlos no crea dependencia: se puede llamar desde `initState`.
  static AppServicesScope of(BuildContext context) {
    final scope =
        context
                .getElementForInheritedWidgetOfExactType<AppServicesScope>()
                ?.widget
            as AppServicesScope?;
    assert(scope != null, 'Falta un AppServicesScope sobre esta ruta');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      apiClient != oldWidget.apiClient ||
      sessionController != oldWidget.sessionController ||
      localeController != oldWidget.localeController ||
      workflowRunsController != oldWidget.workflowRunsController ||
      resourceExecutionsController != oldWidget.resourceExecutionsController;
}
