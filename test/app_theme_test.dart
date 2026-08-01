import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/models/profile/profile_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selecciona correctamente el modo claro u oscuro', () {
    expect(AppTheme.mode('dark-blue'), ThemeMode.dark);
    expect(AppTheme.mode('light-purple'), ThemeMode.light);
    expect(AppTheme.mode('marble'), ThemeMode.light);
  });

  test('cada familia de color modifica el color principal', () {
    final red = AppTheme.dark('dark-red').colorScheme.primary;
    final blue = AppTheme.dark('dark-blue').colorScheme.primary;
    final orange = AppTheme.light('light-orange').colorScheme.primary;
    final purple = AppTheme.light('light-purple').colorScheme.primary;

    expect({red, blue, orange, purple}.length, 4);
    expect(AppTheme.dark('dark-blue').brightness, Brightness.dark);
    expect(AppTheme.light('light-blue').brightness, Brightness.light);
  });

  test('mantiene los nombres legacy con una apariencia válida', () {
    expect(AppTheme.dark('forest').colorScheme.primary, isNot(Colors.red));
    expect(AppTheme.mode('dusk'), ThemeMode.dark);
  });

  test('interpreta la política de tema devuelta por el backend', () {
    final settings = ProfileSettings.fromJson({
      'theme': 'light-purple',
      'language': 'es',
      'theme_configurable': false,
      'default_theme': 'light-purple',
    });

    expect(settings.theme, 'light-purple');
    expect(settings.themeConfigurable, isFalse);
    expect(settings.defaultTheme, 'light-purple');
  });
}
