import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _markdownLink = RegExp(r'\[[^\]]+\]\(([^)]+)\)');

Iterable<File> _documentationFiles() sync* {
  yield File('README.md');
  yield* Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.md'));
}

void main() {
  test('local documentation links resolve', () {
    for (final document in _documentationFiles()) {
      final contents = document.readAsStringSync();
      for (final match in _markdownLink.allMatches(contents)) {
        final rawTarget = match.group(1)!.trim().replaceAll(RegExp(r'^<|>$'), '');
        if (rawTarget.startsWith('#') ||
            rawTarget.startsWith('http://') ||
            rawTarget.startsWith('https://') ||
            rawTarget.startsWith('mailto:')) {
          continue;
        }
        final relativeTarget = rawTarget.split('#').first;
        if (relativeTarget.isEmpty) continue;
        final target = File.fromUri(
          document.absolute.uri.resolve(Uri.decodeFull(relativeTarget)),
        );
        expect(
          target.existsSync() || Directory(target.path).existsSync(),
          isTrue,
          reason: '${document.path} links to missing $rawTarget',
        );
      }
    }
  });

  test('Spanish and English guides have the same pages', () {
    Set<String> names(String language) => Directory('docs/$language')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();

    expect(names('es'), names('en'));
  });

  test('documented Dart version follows pubspec', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('sdk: ^3.13.0'));
    for (final path in ['README.md', 'docs/es/build.md', 'docs/en/build.md']) {
      expect(File(path).readAsStringSync(), contains('Dart 3.13'));
    }
  });

  test('Tool guides state that local execution is pending', () {
    expect(
      File('docs/es/screens.md').readAsStringSync(),
      contains('La ejecución automática local todavía no está habilitada'),
    );
    expect(
      File('docs/en/screens.md').readAsStringSync(),
      contains('Automatic local execution is not enabled yet'),
    );
  });
}
