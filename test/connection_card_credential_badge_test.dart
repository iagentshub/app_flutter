import 'package:app_flutter/features/connections/cards/connection_card.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

Widget _card(ConnectionItem item) => MaterialApp(
  home: Scaffold(
    body: ConnectionCard(
      item: item,
      tx: tr,
      providerLabel: 'OpenAI',
      onTest: () {},
      onShare: () {},
      onEdit: () {},
      onDelete: () {},
    ),
  ),
);

void main() {
  setUp(cargarTraduccionesDePrueba);

  testWidgets('una credencial ilegible se avisa en la tarjeta', (tester) async {
    await tester.pumpWidget(
      _card(
        const ConnectionItem(
          raw: {
            'id': 'c1',
            'name': 'OpenAI',
            'model': 'gpt-4o',
            'is_active': true,
            'credentials_unreadable': true,
            'unreadable_fields': ['api_key'],
          },
        ),
      ),
    );

    expect(find.text('Requiere atención'), findsOneWidget);
  });

  testWidgets('una conexión sana no muestra el aviso', (tester) async {
    await tester.pumpWidget(
      _card(
        const ConnectionItem(
          raw: {
            'id': 'c1',
            'name': 'OpenAI',
            'model': 'gpt-4o',
            'is_active': true,
          },
        ),
      ),
    );

    expect(find.text('Requiere atención'), findsNothing);
  });
}
