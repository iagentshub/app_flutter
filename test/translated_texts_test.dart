import 'dart:async';

import 'package:app_flutter/shared/i18n/translated_texts.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'descarta una carga obsoleta al cambiar de idioma rápidamente',
    () async {
      SharedPreferences.setMockInitialValues({});
      final locale = await LocaleController.bootstrap();
      final loads = <String, Completer<Map<String, dynamic>>>{};
      final texts = TranslatedTexts(
        localeController: locale,
        namespace: 'test',
        loader: ({required languageCode, required namespace}) {
          return (loads[languageCode] ??= Completer()).future;
        },
      );
      addTearDown(texts.dispose);

      await locale.setLanguage('en');
      loads['en']!.complete({'label': 'English'});
      await Future<void>.delayed(Duration.zero);
      expect(texts.text('label'), 'English');

      loads['es']!.complete({'label': 'Español obsoleto'});
      await Future<void>.delayed(Duration.zero);
      expect(texts.text('label'), 'English');
    },
  );

  test('no notifica cuando una carga termina después de dispose', () async {
    SharedPreferences.setMockInitialValues({});
    final locale = await LocaleController.bootstrap();
    final pending = Completer<Map<String, dynamic>>();
    final texts = TranslatedTexts(
      localeController: locale,
      namespace: 'test',
      loader: ({required languageCode, required namespace}) => pending.future,
    );
    var notifications = 0;
    texts.addListener(() => notifications++);

    texts.dispose();
    pending.complete({'label': 'Tarde'});
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 0);
  });
}
