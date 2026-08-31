import 'package:app_flutter/features/workflows/cards/workflow_card.dart';
import 'package:app_flutter/models/workflows/workflow_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 800, child: child)),
  ),
);

WorkflowCard _card({required WorkflowItem item, required VoidCallback onRun}) {
  return WorkflowCard(
    item: item,
    agentsById: const {},
    stepsLabel: 'pasos',
    connectionsLabel: 'conexiones',
    ownerLabel: 'Propio',
    linkedLabel: 'Enlace',
    forkLabel: 'Fork',
    labelText: (label) => label,
    runLabel: 'Ejecutar',
    editTooltip: 'Editar',
    deleteTooltip: 'Eliminar',
    graphTooltip: 'Ver grafo',
    graphCloseLabel: 'Cerrar',
    graphEmptyLabel: 'Vacío',
    graphSearchHint: 'Buscar',
    graphSortTooltip: 'Ordenar',
    graphSortHierarchyVerticalLabel: 'Vertical',
    graphSortHierarchyHorizontalLabel: 'Horizontal',
    graphSortGalaxyLabel: 'Galaxia',
    graphShowLabelsTooltip: 'Mostrar etiquetas',
    graphHideLabelsTooltip: 'Ocultar etiquetas',
    graphQuickViewDescriptionLabel: 'Descripción',
    graphQuickViewNoDescriptionLabel: 'Sin descripción',
    graphQuickViewConnectionsLabel: 'Conexiones',
    graphQuickViewNoConnectionsLabel: 'Sin conexiones',
    inProgressLabel: 'En curso',
    inactiveLabel: 'Desactivado',
    activateTooltip: 'Activar',
    deactivateTooltip: 'Desactivar',
    onRun: onRun,
    onEdit: () {},
    onDelete: () {},
    onToggleActive: () {},
  );
}

void main() {
  testWidgets('workflow desactivado conserva reactivación pero no se ejecuta', (
    tester,
  ) async {
    var ran = false;
    const item = WorkflowItem(
      raw: {
        'id': 'workflow-inactive',
        'name': 'Workflow desactivado',
        'definition': {'nodes': [], 'edges': []},
        'is_active': false,
      },
    );

    await tester.pumpWidget(_host(_card(item: item, onRun: () => ran = true)));

    final runButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ejecutar'),
    );
    expect(runButton.onPressed, isNull);
    expect(find.text('Desactivado'), findsOneWidget);
    expect(find.byTooltip('Activar'), findsOneWidget);
    expect(ran, isFalse);
  });
}
