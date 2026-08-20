import 'package:flutter/foundation.dart';

import '../../utils/i18n.dart';
import '../state/locale_controller.dart';
import 'locale_loader.dart';

typedef TranslationBundleLoader =
    Future<Map<String, dynamic>> Function({
      required String languageCode,
      required String namespace,
    });

/// Carga y mantiene actualizado un namespace i18n para una página, sin
/// repetir el boilerplate de AppShell (_loadTexts en initState + listener
/// de cambio de idioma) en cada vista nueva.
class TranslatedTexts extends ChangeNotifier {
  TranslatedTexts({
    required this.localeController,
    required this.namespace,
    this.loader = LocaleLoader.load,
  }) {
    localeController.addListener(_onLocaleChanged);
    ready = _load();
  }

  final LocaleController localeController;
  final String namespace;
  final TranslationBundleLoader loader;
  late final Future<void> ready;
  Map<String, dynamic> _bundle = const {};
  int _generation = 0;
  bool _disposed = false;

  void _onLocaleChanged() => _load();

  Future<void> _load() async {
    final generation = ++_generation;
    final languageCode = localeController.languageCode;
    final bundle = await loader(
      languageCode: languageCode,
      namespace: namespace,
    );
    if (_disposed || generation != _generation) return;
    _bundle = bundle;
    // Lo comparte con `tr()`: a partir de aquí cualquier widget puede traducir
    // una clave de este namespace sin que se le pase el bundle.
    I18n.registrar(namespace, bundle);
    notifyListeners();
  }

  /// Traducción de [path] en el idioma activo, o el identificador si falta.
  String text(String path) => LocaleLoader.text(_bundle, path);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }
}
