import 'package:app_flutter/shared/state/upload_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => UploadLimits.updateFromPlatform({'max_request_bytes': 0}));

  test('sin límite configurado no rechaza nada', () {
    // El fallo que motiva el test: comparar `bytes > 0` a pelo convierte
    // «sin límite» en «no cabe nada», que es exactamente lo contrario.
    expect(UploadLimits.unlimited, isTrue);
    expect(UploadLimits.exceeds(500 * 1024 * 1024), isFalse);
  });

  test('con límite rechaza solo lo que no cabe', () {
    UploadLimits.updateFromPlatform({'max_request_bytes': 1024});
    expect(UploadLimits.exceeds(1024), isFalse);
    expect(UploadLimits.exceeds(1025), isTrue);
  });

  test('un valor ausente o de otro tipo deja el límite como estaba', () {
    UploadLimits.updateFromPlatform({'max_request_bytes': 2048});
    UploadLimits.updateFromPlatform({});
    UploadLimits.updateFromPlatform({'max_request_bytes': 'diez megas'});
    expect(UploadLimits.maxRequestBytes, 2048);
  });

  test('el texto del límite es el que sale en los mensajes de error', () {
    UploadLimits.updateFromPlatform({'max_request_bytes': 10 * 1024 * 1024});
    expect(UploadLimits.formatted, '10 MB');
    UploadLimits.updateFromPlatform({'max_request_bytes': 1536 * 1024});
    expect(UploadLimits.formatted, '1.5 MB');
    UploadLimits.updateFromPlatform({'max_request_bytes': 4096});
    expect(UploadLimits.formatted, '4 KB');
  });
}
