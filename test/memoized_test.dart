import 'package:app_flutter/shared/utils/memoized.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las listas filtradas eran getters que hacían `.where(...).toList()` sobre
/// la colección completa y se leían dentro de `build`: se recorrían y copiaban
/// enteras en cada `setState` —al escribir en el buscador, al cambiar de
/// pestaña, al abrir un menú, al llegar una traducción—.
void main() {
  test('no recalcula mientras las entradas no cambien', () {
    final memo = Memoized<List<int>>();
    var calculos = 0;
    final datos = [1, 2, 3, 4];

    List<int> filtrar(String filtro) => memo.of([datos, filtro], () {
      calculos += 1;
      return datos.where((n) => filtro == 'pares' ? n.isEven : true).toList();
    });

    expect(filtrar('pares'), [2, 4]);
    expect(calculos, 1);

    // Tres repintados más con el mismo filtro: ni un recálculo.
    filtrar('pares');
    filtrar('pares');
    expect(filtrar('pares'), [2, 4]);
    expect(calculos, 1);

    // Cambiar el filtro sí recalcula.
    expect(filtrar('todos'), [1, 2, 3, 4]);
    expect(calculos, 2);

    // Y volver al anterior también: se cachea un único resultado, el último.
    expect(filtrar('pares'), [2, 4]);
    expect(calculos, 3);
  });

  test('recalcula cuando se reemplaza la colección de origen', () {
    final memo = Memoized<int>();
    var calculos = 0;
    var datos = [1, 2, 3];

    int contar() => memo.of([datos], () {
      calculos += 1;
      return datos.length;
    });

    expect(contar(), 3);
    expect(contar(), 3);
    expect(calculos, 1);

    // Las páginas reemplazan la lista al recargar (`_agents = [...]`), que es
    // justo lo que esta caché detecta: la dependencia se compara por
    // identidad.
    datos = [1, 2, 3, 4];
    expect(contar(), 4);
    expect(calculos, 2);
  });

  test('un resultado nulo también se cachea', () {
    final memo = Memoized<String?>();
    var calculos = 0;

    String? valor() => memo.of(['clave'], () {
      calculos += 1;
      return null;
    });

    expect(valor(), isNull);
    expect(valor(), isNull);
    expect(calculos, 1);
  });
}
