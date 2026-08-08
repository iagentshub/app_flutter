import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/models/profile/profile_models.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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

  test('todos los acentos mantienen contraste AA en botones rellenos', () {
    for (final themeId in kThemeIds) {
      final theme = AppTheme.mode(themeId) == ThemeMode.light
          ? AppTheme.light(themeId)
          : AppTheme.dark(themeId);
      final scheme = theme.colorScheme;
      final contrast = _contrastRatio(scheme.primary, scheme.onPrimary);

      expect(
        contrast,
        greaterThanOrEqualTo(4.5),
        reason: '$themeId tiene contraste ${contrast.toStringAsFixed(2)}:1',
      );
      final surfaceContrast = _contrastRatio(scheme.primary, scheme.surface);
      expect(
        surfaceContrast,
        greaterThanOrEqualTo(4.5),
        reason:
            '$themeId usa primary como foreground con contraste '
            '${surfaceContrast.toStringAsFixed(2)}:1',
      );
      expect(
        theme.filledButtonTheme.style?.foregroundColor?.resolve(
          const <WidgetState>{},
        ),
        scheme.onPrimary,
        reason: '$themeId debe aplicar onPrimary también a FilledButton',
      );
    }
  });

  test(
    'statusColor garantiza AA de verdes/naranjas/rojos de Admin y Centinel',
    () {
      const statusColors = [
        Colors.red,
        Colors.orange,
        Colors.green,
        Colors.grey,
      ];
      final surfaces = [
        AppTheme.light().colorScheme.surface,
        AppTheme.dark().colorScheme.surface,
      ];

      for (final surface in surfaces) {
        for (final color in statusColors) {
          final safe = AppTheme.statusColor(color, surface);
          final contrast = _contrastRatio(safe, surface);
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason:
                '$color sobre $surface da ${contrast.toStringAsFixed(2)}:1 '
                'tras derivar $safe',
          );
        }
      }
    },
  );

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

double _contrastRatio(Color a, Color b) {
  final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}
