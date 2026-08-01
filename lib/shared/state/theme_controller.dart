import 'package:flutter/material.dart';

import '../../core/storage/local_store.dart';

const kThemeIds = [
  'dark-red',
  'dark-blue',
  'dark-orange',
  'dark-purple',
  'light-red',
  'light-blue',
  'light-orange',
  'light-purple',
  'noir',
  'marble',
  'ember',
  'ocean',
  'forest',
  'dusk',
];

/// Tema efectivo de la aplicación. El backend decide si procede de la
/// preferencia del usuario o del valor forzado por administración.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._themeId);

  static const storageKey = 'effective_theme';
  static const defaultTheme = 'dark-red';

  String _themeId;
  String get themeId => _themeId;

  static Future<ThemeController> bootstrap() async {
    final prefs = await LocalStore.instance();
    return ThemeController._(prefs.getString(storageKey) ?? defaultTheme);
  }

  Future<void> syncFromBackend(String? themeId) async {
    if (themeId == null || themeId.isEmpty || themeId == _themeId) return;
    _themeId = themeId;
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(storageKey, themeId);
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    required ThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context, {bool listen = true}) {
    final ThemeControllerScope? scope;
    if (listen) {
      scope = context
          .dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    } else {
      scope =
          context
                  .getElementForInheritedWidgetOfExactType<
                    ThemeControllerScope
                  >()
                  ?.widget
              as ThemeControllerScope?;
    }
    assert(scope != null, 'ThemeControllerScope no encontrado');
    return scope!.notifier!;
  }
}
