import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arranca con el último tema efectivo y sincroniza cambios', () async {
    SharedPreferences.setMockInitialValues({
      ThemeController.storageKey: 'light-blue',
    });
    final controller = await ThemeController.bootstrap();
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.themeId, 'light-blue');
    await controller.syncFromBackend('dark-purple');

    expect(controller.themeId, 'dark-purple');
    expect(notifications, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeController.storageKey), 'dark-purple');
  });

  test('no notifica cuando el backend devuelve el mismo tema', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await ThemeController.bootstrap();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.syncFromBackend(ThemeController.defaultTheme);

    expect(notifications, 0);
  });
}
