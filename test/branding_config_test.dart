import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const appName = 'iAgents';
  const applicationId = 'com.iagentshub.app';

  test('todas las plataformas comparten nombre e identificador', () {
    final androidGradle = _read('android/app/build.gradle.kts');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final androidActivity = _read(
      'android/app/src/main/kotlin/com/iagentshub/app/MainActivity.kt',
    );
    final iosProject = _read('ios/Runner.xcodeproj/project.pbxproj');
    final iosInfo = _read('ios/Runner/Info.plist');
    final macosConfig = _read('macos/Runner/Configs/AppInfo.xcconfig');
    final linuxCmake = _read('linux/CMakeLists.txt');
    final linuxRunner = _read('linux/runner/my_application.cc');
    final windowsCmake = _read('windows/CMakeLists.txt');
    final windowsResources = _read('windows/runner/Runner.rc');
    final webManifest = _read('web/manifest.json');
    final webIndex = _read('web/index.html');

    expect(androidGradle, contains('namespace = "$applicationId"'));
    expect(androidGradle, contains('applicationId = "$applicationId"'));
    expect(androidManifest, contains('android:label="$appName"'));
    expect(androidActivity, contains('package $applicationId'));

    expect(iosProject, contains('PRODUCT_BUNDLE_IDENTIFIER = $applicationId;'));
    expect(iosInfo, contains('<string>$appName</string>'));

    expect(macosConfig, contains('PRODUCT_BUNDLE_IDENTIFIER = $applicationId'));
    expect(macosConfig, contains('PRODUCT_NAME = $appName'));
    expect(macosConfig, contains('EXECUTABLE_NAME = iagents'));

    expect(linuxCmake, contains('set(BINARY_NAME "iagents")'));
    expect(linuxCmake, contains('set(APPLICATION_ID "$applicationId")'));
    expect(linuxRunner, contains('"$appName"'));

    expect(windowsCmake, contains('set(BINARY_NAME "iagents")'));
    expect(windowsResources, contains('"ProductName", "$appName"'));
    expect(windowsResources, contains('"OriginalFilename", "iagents.exe"'));

    expect(webManifest, contains('"name": "$appName"'));
    expect(webManifest, contains('"short_name": "$appName"'));
    expect(webIndex, contains('<title>$appName</title>'));
  });

  test('no quedan identificadores nativos anteriores', () {
    const nativeConfigPaths = [
      'android/app/build.gradle.kts',
      'android/app/src/main/AndroidManifest.xml',
      'android/app/src/main/kotlin/com/iagentshub/app/MainActivity.kt',
      'ios/Runner.xcodeproj/project.pbxproj',
      'ios/Runner/Info.plist',
      'macos/Runner.xcodeproj/project.pbxproj',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'linux/CMakeLists.txt',
      'linux/runner/my_application.cc',
      'windows/CMakeLists.txt',
      'windows/runner/Runner.rc',
      'web/manifest.json',
      'web/index.html',
    ];
    const obsoleteValues = [
      'com.iagentshub.app_flutter',
      'com.iagentshub.appFlutter',
    ];

    for (final path in nativeConfigPaths) {
      final contents = _read(path);
      for (final obsolete in obsoleteValues) {
        expect(
          contents,
          isNot(contains(obsolete)),
          reason: '$path todavía contiene $obsolete',
        );
      }
    }
  });

  test('el producto se escribe «iAgents Hub», nunca pegado', () {
    // Tercera grafía en aparecer: la fase 2 unificó about/docs/seo y se dejó
    // «iAgentsHub» en pricing, legacy y la navegación. Sin esta comprobación
    // la cuarta llega sola, porque nadie lee los .json de locales enteros.
    //
    // Ojo: el nombre NATIVO de la app sí es «iAgents» a secas (ver el test de
    // arriba). Aquí solo se persigue el pegado sin espacio.
    final offenders = <String>[];
    for (final dir in ['lib', 'assets/locales']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') && !f.path.endsWith('.json')) continue;
        if (f.readAsStringSync().contains('iAgentsHub')) offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: 'Escríbelo «iAgents Hub», con espacio');
  });
}

String _read(String path) => File(path).readAsStringSync();
