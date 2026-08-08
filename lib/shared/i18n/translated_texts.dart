import 'package:flutter/foundation.dart';

import '../state/locale_controller.dart';
import 'locale_loader.dart';

/// Carga y mantiene actualizado un namespace i18n para una página, sin
/// repetir el boilerplate de AppShell (_loadTexts en initState + listener
/// de cambio de idioma) en cada vista nueva.
class TranslatedTexts extends ChangeNotifier {
  TranslatedTexts({required this.localeController, required this.namespace}) {
    localeController.addListener(_onLocaleChanged);
    _load();
  }

  final LocaleController localeController;
  final String namespace;
  Map<String, dynamic> _bundle = const {};

  void _onLocaleChanged() => _load();

  Future<void> _load() async {
    _bundle = await LocaleLoader.load(
      languageCode: localeController.languageCode,
      namespace: namespace,
    );
    notifyListeners();
  }

  String text(String path, {String fallback = ''}) =>
      LocaleLoader.text(_bundle, path, fallback: fallback);

  @override
  void dispose() {
    localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }
}
