import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/diagnostics/app_diagnostics.dart';
import '../../shared/i18n/translated_texts.dart';
import '../../shared/state/app_services_scope.dart';
import '../../shared/widgets/async_state_panel.dart';

/// `prefijo.loadLibrary` de una importación `deferred as`.
typedef DeferredLibraryLoader = Future<void> Function();

/// Envuelve la página de una ruta cuyo código viaja en una parte diferida
/// (`import '…' deferred as …`) en vez de en el bundle principal.
///
/// En web, todo el código alcanzable desde `main()` se descarga antes de que
/// el usuario vea la pantalla de login. Admin —Centinel incluido—, el editor
/// visual de workflows y el checkout de Stripe son las áreas más pesadas y las
/// usa una fracción pequeña de la gente, así que se piden cuando se entra en
/// ellas y no antes. Ver docs/adr/005-carga-diferida-en-flutter-web.md.
///
/// Fuera de web `loadLibrary()` resuelve sin descargar nada, así que el móvil y
/// el escritorio pagan a lo sumo un frame de más.
///
/// Lo que este widget añade sobre un `FutureBuilder` suelto:
///
/// - **Recuerda lo ya cargado.** Volver a Admin no vuelve a mostrar el
///   indicador de carga: `loadLibrary()` está cacheado, pero el `FutureBuilder`
///   seguiría pintando un frame de espera en cada entrada.
/// - **Deja salir del error.** Pedir la parte es una petición de red que puede
///   fallar a mitad; sin reintento la sección se queda muerta hasta recargar la
///   pestaña entera.
class DeferredPage extends StatefulWidget {
  const DeferredPage({
    required this.name,
    required this.loader,
    required this.builder,
    super.key,
  });

  /// Identifica la parte diferida para el registro de [_loaded] y para los
  /// diagnósticos. Coincide con el nombre del prefijo del `deferred as`.
  final String name;

  final DeferredLibraryLoader loader;

  /// Construye la página. Solo se llama cuando la parte ya está cargada: es
  /// el único punto donde se pueden tocar los símbolos del prefijo diferido.
  final WidgetBuilder builder;

  static final Set<String> _loaded = <String>{};

  /// Si la parte ya se descargó en esta sesión, la página se monta en el mismo
  /// frame y sin indicador de carga.
  static bool isLoaded(String name) => _loaded.contains(name);

  @visibleForTesting
  static void forgetLoadedForTest() => _loaded.clear();

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final TranslatedTexts _t;
  late bool _loading;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: AppServicesScope.of(context).localeController,
      namespace: 'common',
    );
    _loading = !DeferredPage.isLoaded(widget.name);
    if (_loading) unawaited(_load());
  }

  @override
  void didUpdateWidget(DeferredPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name == widget.name) return;

    // Las rutas diferidas viven al mismo nivel del Navigator y Flutter puede
    // reutilizar este State al pasar, por ejemplo, de Admin a Centinel. El
    // estado anterior no demuestra que la nueva biblioteca esté cargada: si
    // se construye su símbolo antes de llamar a loadLibrary, dart2js deja la
    // aplicación en blanco con un DeferredLoadingError.
    _loading = !DeferredPage.isLoaded(widget.name);
    _failed = false;
    if (_loading) unawaited(_load());
  }

  Future<void> _load() async {
    final name = widget.name;
    final loader = widget.loader;
    try {
      await loader();
      DeferredPage._loaded.add(name);
      if (!mounted || widget.name != name) return;
      setState(() => _loading = false);
    } catch (error, stackTrace) {
      // La carga de una parte diferida es una petición HTTP: cualquier fallo
      // de red o de despliegue (parte que ya no existe tras un deploy nuevo)
      // llega aquí, y todos se resuelven igual — reintentar.
      AppDiagnostics.report('deferred.$name', error, stackTrace);
      if (!mounted || widget.name != name) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_failed) {
      return ListenableBuilder(
        listenable: _t,
        builder: (context, _) => AsyncStatePanel.error(
          message: _t.text('deferred.error'),
          retryLabel: _t.text('deferred.retry'),
          onRetry: _retry,
        ),
      );
    }
    return widget.builder(context);
  }
}
