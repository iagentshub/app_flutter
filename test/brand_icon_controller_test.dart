import 'package:app_flutter/shared/services/native_app_icon_service.dart';
import 'package:app_flutter/shared/state/brand_icon_controller.dart';
import 'package:app_flutter/shared/widgets/brand_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(NativeAppIconService.channelName),
          (_) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(NativeAppIconService.channelName),
          null,
        );
  });

  test('usa iA blanco sobre rojo de forma predeterminada', () async {
    final controller = await BrandIconController.bootstrap();

    expect(controller.selected, BrandIconVariant.iaInterWhiteOnRed);
    expect(controller.assetPath, 'assets/icons/ia/ia_inter_white_on_red.png');
  });

  test('persiste y recupera el icono seleccionado', () async {
    final controller = await BrandIconController.bootstrap();
    await controller.select(BrandIconVariant.iaInterRedOnBlack);

    final restored = await BrandIconController.bootstrap();

    expect(restored.selected, BrandIconVariant.iaInterRedOnBlack);
    expect(restored.assetPath, 'assets/icons/ia/ia_inter_red_on_black.png');
  });

  test('envía la variante seleccionada al canal del icono nativo', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(NativeAppIconService.channelName),
          (call) async {
            calls.add(call);
            return null;
          },
        );
    final controller = await BrandIconController.bootstrap();

    await controller.select(BrandIconVariant.agentCoordinator);
    await controller.select(BrandIconController.defaultVariant);

    expect(calls, hasLength(2));
    expect(calls.first.method, 'setIcon');
    expect(calls.first.arguments, containsPair('name', 'agentCoordinator'));
    expect(calls.last.arguments, containsPair('name', null));
  });

  test('todas las variantes apuntan a un recurso PNG único', () {
    final paths = BrandIconVariant.values
        .map((variant) => variant.assetPath)
        .toSet();

    expect(paths, hasLength(BrandIconVariant.values.length));
    expect(paths.every((path) => path.endsWith('.png')), isTrue);
  });

  test('ignora de forma segura una preferencia desconocida', () async {
    SharedPreferences.setMockInitialValues({
      BrandIconController.storageKey: 'obsolete_icon',
    });

    final controller = await BrandIconController.bootstrap();

    expect(controller.selected, BrandIconVariant.iaInterWhiteOnRed);
  });

  testWidgets('BrandIcon se actualiza al cambiar la preferencia', (
    tester,
  ) async {
    final controller = await BrandIconController.bootstrap();
    await tester.pumpWidget(
      BrandIconScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: BrandIcon())),
      ),
    );

    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        BrandIconController.defaultVariant.assetPath,
      ),
    );

    for (final variant in BrandIconVariant.values) {
      await controller.select(variant);
      await tester.pump();

      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<AssetImage>().having(
          (image) => image.assetName,
          'assetName',
          variant.assetPath,
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
