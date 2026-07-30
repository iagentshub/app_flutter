import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los runners de escritorio fijan un mínimo de 720x600', () {
    final macosRunner = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final linuxRunner = File(
      'linux/runner/my_application.cc',
    ).readAsStringSync();
    final windowsRunner = File(
      'windows/runner/flutter_window.cpp',
    ).readAsStringSync();

    expect(macosRunner, contains('NSSize(width: 720, height: 600)'));
    expect(linuxRunner, contains('geometry.min_width = 720'));
    expect(linuxRunner, contains('geometry.min_height = 600'));
    expect(windowsRunner, contains('kMinimumWindowWidth = 720'));
    expect(windowsRunner, contains('kMinimumWindowHeight = 600'));
    expect(windowsRunner, contains('WM_GETMINMAXINFO'));
  });
}
