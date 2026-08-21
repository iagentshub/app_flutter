import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/shared/i18n/locale_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// El desplegable de países del checkout y el `map()` que lo alimenta.
///
/// La lista es dato traducido, no copia de interfaz, y de ella depende que un
/// cliente pueda declarar dónde se le factura: un país que falte es un cliente
/// que no puede pagar, y un código que solo esté en un idioma es un
/// desplegable vacío para media base de usuarios.

/// Los 27 Estados miembros. Es la misma lista que
/// `backend/app/services/billing_tax.py:EU_COUNTRIES`, que decide en qué
/// países se puede registrar un NIF-IVA: si aquí falta uno, esa empresa no
/// puede elegir su país y paga IVA que no le corresponde.
const _ue27 = {
  'AT',
  'BE',
  'BG',
  'CY',
  'CZ',
  'DE',
  'DK',
  'EE',
  'ES',
  'FI',
  'FR',
  'GR',
  'HR',
  'HU',
  'IE',
  'IT',
  'LT',
  'LU',
  'LV',
  'MT',
  'NL',
  'PL',
  'PT',
  'RO',
  'SE',
  'SI',
  'SK',
};

Map<String, String> _paises(String lang) {
  final raw = File('assets/locales/$lang/pricing.json').readAsStringSync();
  return LocaleLoader.map(
    jsonDecode(raw) as Map<String, dynamic>,
    'checkout.countries',
  );
}

void main() {
  test('map() saca un diccionario de un nodo anidado', () {
    final bundle = <String, dynamic>{
      'checkout': {
        'countries': {'ES': 'España', 'FR': 'Francia'},
      },
    };
    expect(LocaleLoader.map(bundle, 'checkout.countries'), {
      'ES': 'España',
      'FR': 'Francia',
    });
  });

  test('map() de una ruta que no existe o no es un mapa devuelve vacío', () {
    final bundle = <String, dynamic>{
      'checkout': {'title': 'Pagar'},
    };
    expect(LocaleLoader.map(bundle, 'checkout.countries'), isEmpty);
    expect(LocaleLoader.map(bundle, 'checkout.title'), isEmpty);
    expect(LocaleLoader.map(bundle, 'nada'), isEmpty);
  });

  test('map() descarta los valores que no son cadenas', () {
    final bundle = <String, dynamic>{
      'countries': {'ES': 'España', 'XX': 42, 'YY': null},
    };
    expect(LocaleLoader.map(bundle, 'countries'), {'ES': 'España'});
  });

  test('los dos idiomas ofrecen exactamente los mismos países', () {
    final es = _paises('es');
    final en = _paises('en');
    expect(es, isNotEmpty);
    expect(es.keys.toSet(), en.keys.toSet());
  });

  test('están los 27 de la UE, que son los que pueden declarar NIF-IVA', () {
    final codigos = _paises('es').keys.toSet();
    expect(_ue27.difference(codigos), isEmpty);
  });

  test('los códigos son ISO 3166-1 alfa-2, que es lo que espera Stripe', () {
    final iso = RegExp(r'^[A-Z]{2}$');
    for (final lang in ['es', 'en']) {
      for (final entrada in _paises(lang).entries) {
        expect(
          iso.hasMatch(entrada.key),
          isTrue,
          reason: '$lang: ${entrada.key}',
        );
        expect(
          entrada.value.trim(),
          isNotEmpty,
          reason: '$lang: ${entrada.key}',
        );
      }
    }
  });
}
