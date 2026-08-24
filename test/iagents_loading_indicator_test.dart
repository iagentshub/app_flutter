import 'dart:async';
import 'dart:math';

import 'package:app_flutter/shared/i18n/locale_loader.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/widgets/animated_iagents_mark.dart';
import 'package:app_flutter/shared/widgets/iagents_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocaleController> localeFor(String languageCode) async {
  SharedPreferences.setMockInitialValues({'app_language': languageCode});
  return LocaleController.bootstrap();
}

Future<void> loadTexts(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  testWidgets('muestra el mensaje precargado desde el primer fotograma', (
    tester,
  ) async {
    final localeController = await localeFor('es');
    await LocaleLoader.load(languageCode: 'es', namespace: 'common');
    final pendingBundle = Completer<Map<String, dynamic>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IAgentsLoadingIndicator(
            localeController: localeController,
            translationLoader: ({required languageCode, required namespace}) =>
                pendingBundle.future,
          ),
        ),
      ),
    );

    expect(find.text('Cargando…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
  });

  testWidgets('muestra el logo y elige al azar el siguiente mensaje', (
    tester,
  ) async {
    final localeController = await localeFor('es');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IAgentsLoadingIndicator(
            localeController: localeController,
            messageInterval: const Duration(milliseconds: 500),
            random: const _FixedRandom(2),
          ),
        ),
      ),
    );
    await loadTexts(tester);

    expect(find.byType(IAgentsLoadingMark), findsOneWidget);
    expect(find.byKey(const Key('iagents-loading-mark-morph')), findsOneWidget);
    expect(find.text('Cargando…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mejorando la experiencia de usuario…'), findsOneWidget);
    expect(find.text('Procesando…'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
  });

  testWidgets('usa los mensajes del idioma seleccionado', (tester) async {
    final localeController = await localeFor('en');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IAgentsLoadingIndicator(localeController: localeController),
        ),
      ),
    );
    await loadTexts(tester);

    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Cargando…'), findsNothing);
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
  });

  testWidgets('mantiene mensaje y logo estáticos con movimiento reducido', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final localeController = await localeFor('es');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IAgentsLoadingIndicator(
            localeController: localeController,
            messageInterval: const Duration(milliseconds: 300),
          ),
        ),
      ),
    );
    await loadTexts(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Cargando…'), findsOneWidget);
    expect(find.text('Procesando…'), findsNothing);
    expect(
      find.byKey(const Key('iagents-mark-animated-entrance')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
  });

  testWidgets('el overlay conserva y bloquea el contenido bajo el desenfoque', (
    tester,
  ) async {
    final localeController = await localeFor('es');
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IAgentsLoadingOverlay(
            loading: true,
            localeController: localeController,
            child: Center(
              child: TextButton(
                onPressed: () => taps += 1,
                child: const Text('Contenido existente'),
              ),
            ),
          ),
        ),
      ),
    );
    await loadTexts(tester);

    expect(find.text('Contenido existente'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(IAgentsLoadingIndicator), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('iagents-loading-content')),
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.text('Contenido existente'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
  });

  testWidgets('evita destellos y mantiene visible una carga ya mostrada', (
    tester,
  ) async {
    final localeController = await localeFor('es');
    final loading = ValueNotifier(true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (context, value, _) => IAgentsLoadingOverlay(
              loading: value,
              localeController: localeController,
              child: const Text('Contenido'),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('iagents-loading-overlay')), findsNothing);

    loading.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('iagents-loading-overlay')), findsNothing);

    loading.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 121));
    expect(find.byKey(const Key('iagents-loading-overlay')), findsOneWidget);

    loading.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('iagents-loading-overlay')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('iagents-loading-overlay')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    loading.dispose();
    localeController.dispose();
  });
}
