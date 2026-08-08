import 'package:app_flutter/core/config/backend_url.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Tabla compartida con la extensión de VS Code ──────────────────────────────
// Los MISMOS casos están en vs_code/src/test/url.test.ts. Si los dos clientes
// discrepan, el mismo hub casero funciona en uno y no en el otro: eso pasaba
// con 192.168.x.x, que esta app aceptaba y la extensión rechazaba.
//
// _isLocalOrPrivateHost es privado, así que se comprueba por su efecto
// observable: sin esquema, un host local infiere http y uno público https.

const localos = <String>[
  'localhost',
  'hub.localhost',
  'hub.local',
  '127.0.0.1',
  '127.1.2.3',
  '10.0.0.5',
  '192.168.1.50',
  '172.16.0.1',
  '172.31.255.254',
  '169.254.10.1',
];

const publicos = <String>[
  'hub.ejemplo.com',
  'example.org',
  // El clásico: parece local pero el dominio es de otro.
  'localhost.evil.com',
  '192.168.1.50.evil.com',
  // Justo fuera de cada rango privado.
  '11.0.0.1',
  '172.15.0.1',
  '172.32.0.1',
  '192.169.1.1',
  '169.253.0.1',
  '8.8.8.8',
  // No son IPv4 válidas, así que se tratan como nombres públicos.
  '10.0.0',
  '10.0.0.256',
  '10.0.0.a',
];

void main() {
  group('BackendUrl.normalize — esquema inferido', () {
    for (final host in localos) {
      test('$host es red local → http', () {
        expect(BackendUrl.normalize(host), 'http://$host');
      });
    }

    for (final host in publicos) {
      test('$host no es red local → https', () {
        expect(BackendUrl.normalize(host), 'https://$host');
      });
    }
  });

  group('BackendUrl.normalize — esquema explícito', () {
    test('acepta http en cualquier host de red local', () {
      expect(
        BackendUrl.normalize('http://192.168.1.50:8765'),
        'http://192.168.1.50:8765',
      );
      expect(BackendUrl.normalize('http://hub.local:8765'), 'http://hub.local:8765');
    });

    test('rechaza http hacia internet', () {
      expect(BackendUrl.normalize('http://hub.ejemplo.com'), '');
      expect(BackendUrl.normalize('http://localhost.evil.com'), '');
      expect(BackendUrl.normalize('http://8.8.8.8'), '');
    });

    test('https vale para cualquier host', () {
      expect(
        BackendUrl.normalize('https://hub.ejemplo.com/'),
        'https://hub.ejemplo.com',
      );
    });

    test('rechaza esquemas que no son http(s)', () {
      expect(BackendUrl.normalize('ftp://hub.ejemplo.com'), '');
    });

    test('rechaza credenciales, query y fragmento en la URL del backend', () {
      expect(BackendUrl.normalize('https://user:pass@hub.ejemplo.com'), '');
      expect(BackendUrl.normalize('https://hub.ejemplo.com?a=1'), '');
      expect(BackendUrl.normalize('https://hub.ejemplo.com#x'), '');
    });

    test('no distingue mayúsculas', () {
      expect(BackendUrl.normalize('HTTP://LOCALHOST:8765'), 'http://localhost:8765');
    });

    test('la cadena vacía no es una URL', () {
      expect(BackendUrl.normalize('   '), '');
    });
  });
}
