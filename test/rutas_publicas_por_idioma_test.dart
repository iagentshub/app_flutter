import 'package:app_flutter/app/router/external_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las rutas públicas se declaraban con una constante por idioma y página
/// —`docs` y `docsEn`, diez en total— y una lista a mano en el router. Ahora se
/// derivan del catálogo de idiomas. Este test congela el resultado: si la
/// derivación cambia, una ruta pública deja de recogerse y quien llegue a
/// `/app/en/docs` ve el 404 de Flutter en vez de ir al sitio real, que es un
/// fallo que nadie reporta.
void main() {
  test('las rutas públicas derivadas son las que se declaraban a mano', () {
    expect(publicPathsPorIdioma(), [
      '/about',
      '/docs',
      '/support',
      '/pricing',
      '/en',
      '/en/about',
      '/en/docs',
      '/en/support',
      '/en/pricing',
    ]);
  });
}
