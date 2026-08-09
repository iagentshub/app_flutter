import 'package:app_flutter/features/public/utils/public_profile_resource_filter.dart';
import 'package:app_flutter/models/explore/explore_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resources = [
    ExploreItem(
      raw: {
        'resource_type': 'agent',
        'name': 'Asistente financiero',
        'description': 'Analiza balances',
        'category': 'Finance',
        'tags': ['contabilidad'],
        'labels': ['public', 'lang_es'],
      },
    ),
    ExploreItem(
      raw: {
        'resource_type': 'workflow',
        'name': 'Research pipeline',
        'description': 'Busca y resume artículos',
        'category': 'Research',
        'tags': ['papers'],
        'labels': ['public', 'lang_en'],
      },
    ),
  ];

  test('busca por palabras en todos los campos visibles', () {
    expect(
      filterPublicProfileResources(
        resources,
        query: 'CONTABILIDAD',
        selectedTypes: const {},
      ).single.name,
      'Asistente financiero',
    );
    expect(
      filterPublicProfileResources(
        resources,
        query: 'artículos',
        selectedTypes: const {},
      ).single.resourceType,
      'workflow',
    );
  });

  test('combina búsqueda y filtro de tipo', () {
    final result = filterPublicProfileResources(
      resources,
      query: 'public',
      selectedTypes: const {'agent'},
    );

    expect(result.map((item) => item.resourceType), ['agent']);
  });
}
