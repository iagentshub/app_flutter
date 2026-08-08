import 'package:app_flutter/features/agents/cards/agent_card.dart';
import 'package:app_flutter/features/connections/cards/connection_card.dart';
import 'package:app_flutter/features/memory/cards/memory_file_card.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/models/memory/memory_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La fila de acciones de `AgentCard` llegó a tener ocho elementos y a 328 px
/// —el ancho que da la rejilla en un móvil de 360— Flutter lanzaba
/// «A RenderFlex overflowed by 70 pixels on the right». En release el aviso a
/// rayas no se ve: los botones de la derecha, incluido eliminar, quedaban
/// recortados fuera de la tarjeta y no se podían pulsar.
///
/// Ninguna prueba montaba las tarjetas a ancho de móvil, así que el problema
/// pasó inadvertido. Estas sí, para que no vuelva al añadir la próxima acción.
const _mobileCardWidth = 328.0;

String _tx(String path, String fallback) => fallback;

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: _mobileCardWidth, child: child)),
    ),
  );
}

const _agent = AgentItem(
  raw: {
    'id': 'agent-1',
    'name': 'Agente de soporte',
    'agent_type': 'generic',
    'model': 'gpt-4o',
    'connection_id': 'connection-1',
    'description': 'Responde dudas de clientes sobre pedidos y devoluciones.',
    'labels': ['produccion'],
    'is_active': true,
  },
);

void main() {
  setUp(() {
    // Móvil de 360x800, el caso que reportaba el desbordamiento.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('AgentCard cabe a ancho de móvil con todas sus acciones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        AgentCard(
          item: _agent,
          tx: _tx,
          onChat: () {},
          onExport: (_) {},
          onShare: () {},
          onHistory: () {},
          onEdit: () {},
          onDelete: () {},
          onToggleActive: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('las acciones del menú de AgentCard siguen siendo alcanzables', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var deleted = false;
    String? exported;
    await tester.pumpWidget(
      _host(
        AgentCard(
          item: _agent,
          tx: _tx,
          onChat: () {},
          onExport: (format) => exported = format,
          onShare: () {},
          onHistory: () {},
          onEdit: () {},
          onDelete: () => deleted = true,
          onToggleActive: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);

    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar · OpenAI'));
    await tester.pumpAndSettle();
    expect(exported, 'openai');
  });

  testWidgets('ConnectionCard cabe a ancho de móvil, también con sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const item = ConnectionItem(
      raw: {
        'id': 'connection-1',
        'name': 'OpenAI producción',
        'type': 'openai',
        'model': 'gpt-4o',
        'is_active': true,
      },
    );

    await tester.pumpWidget(
      _host(
        ConnectionCard(
          item: item,
          tx: _tx,
          providerLabel: 'OpenAI',
          onTest: () {},
          onShare: () {},
          onEdit: () {},
          onDelete: () {},
          onToggleActive: () {},
          onSyncHub: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('MemoryFileCard cabe a ancho de móvil', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const file = MemoryFileItem(
      raw: {'filename': 'notas-de-cliente.md', 'size': 2048},
    );

    await tester.pumpWidget(
      _host(
        MemoryFileCard(
          file: file,
          sizeLabel: 'Tamaño',
          editTooltip: 'Editar',
          deleteTooltip: 'Eliminar',
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
