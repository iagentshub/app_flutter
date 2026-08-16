import 'package:flutter/widgets.dart';

import 'app_services_scope.dart';
import 'resource_events.dart';

/// Recarga la vista cuando cambia un recurso que enseña, lo haya cambiado esta
/// pantalla u otra.
///
/// La convención que sustituye a «recargo yo después de mutar»: el que muta no
/// avisa a nadie —lo hace el cliente HTTP— y el que pinta declara qué mira. Así
/// dos vistas del mismo recurso no pueden desincronizarse, que es de donde
/// salían las regresiones en la pantalla que nadie tocó.
///
/// ```dart
/// class _MiPageState extends State<MiPage> with WatchesResourceChanges {
///   @override
///   Set<String> get watchedResources => const {'agents', 'skills'};
///
///   @override
///   Future<void> onResourcesChanged(Set<String> changed) => _load();
/// }
/// ```
///
/// Los nombres son la raíz de la ruta: `/api/agents/...` → `agents`.
mixin WatchesResourceChanges<T extends StatefulWidget> on State<T> {
  ResourceEvents? _events;

  /// Tipos de recurso que esta vista enseña.
  Set<String> get watchedResources;

  /// Qué hacer cuando alguno cambia. Normalmente, recargar.
  ///
  /// Recibe los tipos tocados —siempre un subconjunto de [watchedResources]—
  /// para que una pantalla con varias secciones recargue solo la que
  /// corresponde en vez de todas.
  Future<void> onResourcesChanged(Set<String> changed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final events = AppServicesScope.of(context).apiClient.resourceEvents;
    if (identical(events, _events)) return;
    _events?.removeListener(_handleChange);
    _events = events..addListener(_handleChange);
  }

  @override
  void dispose() {
    _events?.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    if (!mounted) return;
    final touched =
        (_events?.pending ?? const <String>{}).intersection(watchedResources);
    if (touched.isEmpty) return;
    onResourcesChanged(touched);
  }
}
