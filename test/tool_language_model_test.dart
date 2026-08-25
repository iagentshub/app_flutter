import 'package:app_flutter/core/config/tool_runtimes.dart';
import 'package:app_flutter/models/tools/tool_execution.dart';
import 'package:app_flutter/models/tools/tool_models.dart';
import 'package:app_flutter/shared/utils/file_size_formatter.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

void main() {
  test('el catálogo contiene contrato, presentación y reglas canónicas', () {
    expect(ToolRuntimeCatalog.supported.map((language) => language.apiValue), [
      'python',
      'shell',
      'cpp',
    ]);
    expect(ToolLanguage.python.icon, Icons.code);
    expect(ToolRuntimeCatalog.scriptExtension(ToolLanguage.python), 'py');
    expect(ToolLanguage.shell.icon, Icons.terminal);
    expect(ToolRuntimeCatalog.scriptExtension(ToolLanguage.shell), 'sh');
    expect(ToolLanguage.cpp.icon, Icons.memory);
    expect(ToolRuntimeCatalog.scriptExtension(ToolLanguage.cpp), isNull);
    expect(ToolLanguage.cpp.requiresBinary, isTrue);
    expect(ToolLanguage.python.requiresBinary, isFalse);
  });

  test('convierte valores de API e infiere extensiones conocidas', () {
    expect(ToolLanguage.fromApi('python'), ToolLanguage.python);
    expect(ToolLanguage.tryParseSupported('shell'), ToolLanguage.shell);
    expect(ToolLanguage.tryParseSupported('ruby'), isNull);
    expect(
      ToolRuntimeCatalog.fromSourcePath('tools/runner.PY'),
      ToolLanguage.python,
    );
    expect(
      ToolRuntimeCatalog.fromSourcePath('tools/runner.sh'),
      ToolLanguage.shell,
    );
    expect(
      ToolRuntimeCatalog.fromSourcePath('tools/runner.cpp'),
      ToolLanguage.cpp,
    );
    expect(ToolRuntimeCatalog.fromSourcePath('tools/runner.js'), isNull);
  });

  test('el catálogo no arrastra valores de otro backend', () {
    ToolRuntimeCatalog.updateFromPlatform({
      'tool_runtimes': [
        {
          'api_value': 'python',
          'extensions': ['.pyx'],
        },
      ],
    });
    expect(ToolRuntimeCatalog.supported, [ToolLanguage.python]);
    expect(
      ToolRuntimeCatalog.fromSourcePath('tools/compiled.pyx'),
      ToolLanguage.python,
    );
    expect(ToolRuntimeCatalog.fromSourcePath('tools/legacy.py'), isNull);

    ToolRuntimeCatalog.updateFromPlatform(const {});
    expect(ToolRuntimeCatalog.supported, const [
      ToolLanguage.python,
      ToolLanguage.shell,
      ToolLanguage.cpp,
    ]);
  });

  test('conserva un valor futuro con etiqueta e icono defensivos', () {
    final unknown = ToolLanguage.fromApi('ruby');

    expect(unknown.apiValue, 'ruby');
    expect(unknown.isSupported, isFalse);
    expect(unknown.icon, Icons.build_outlined);
    expect(unknown.label((_) => 'no debe usarse', fallback: 'ruby'), 'ruby');
  });

  test('ToolItem expone el lenguaje tipado sin alterar el valor de API', () {
    const known = ToolItem(raw: {'language': 'cpp'});
    const future = ToolItem(raw: {'language': 'rust'});

    expect(known.language, ToolLanguage.cpp);
    expect(known.language.apiValue, 'cpp');
    expect(future.language.apiValue, 'rust');
    expect(future.languageValue, 'rust');
  });

  test('resuelve las claves reales en español e inglés', () {
    cargarTraduccionesDePrueba(idioma: 'es');
    expect(ToolLanguage.python.label(tr), 'Python');
    expect(ToolLanguage.cpp.label(tr), 'C++');

    cargarTraduccionesDePrueba(idioma: 'en');
    expect(ToolLanguage.shell.label(tr), 'Shell');
    expect(ToolLanguage.cpp.label(tr), 'C++');
  });

  test('formatea bytes, KB, MB y cero sin cambiar la presentación', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(1024), '1.0 KB');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(1024 * 1024), '1.0 MB');
  });

  test('solo declara ejecutable una Tool compatible con el dispositivo', () {
    const linux = ToolDeviceCapabilities(
      platform: 'linux',
      architecture: 'x64',
      secureLocalExecution: true,
      availableRuntimes: {'python'},
    );
    const python = ToolItem(
      raw: {
        'id': 'python-1',
        'language': 'python',
        'content': 'print(1)',
        'ready': true,
      },
    );
    const native = ToolItem(
      raw: {
        'id': 'native-1',
        'language': 'cpp',
        'binary_filename': 'tool',
        'target_os': 'linux',
        'target_arch': 'arm64',
        'ready': true,
      },
    );

    expect(python.availabilityOn(linux), ToolExecutionAvailability.executable);
    expect(
      native.availabilityOn(linux),
      ToolExecutionAvailability.instructionOnly,
    );
    expect(
      python.availabilityOn(
        const ToolDeviceCapabilities(
          platform: 'linux',
          architecture: 'x64',
          secureLocalExecution: false,
          availableRuntimes: {'python'},
        ),
      ),
      ToolExecutionAvailability.instructionOnly,
    );
  });
}
