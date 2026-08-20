import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/knowledge/knowledge_models.dart';
import 'package:app_flutter/models/workflows/workflow_models.dart';
import 'package:app_flutter/shared/graph/resource_graph_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _agent = AgentItem(
  raw: {
    'id': 'ag-1',
    'name': 'Redactor',
    'description': 'Escribe',
    'connection_id': 'conn-1',
    'skills': ['sk-1'],
    'prompts': ['pr-1'],
    'tools': ['to-1'],
    'knowledge': ['kn-1'],
    'knowledge_packs': ['kp-1'],
    'use_memory': true,
    'memory_file': 'notas.md',
  },
);

const _names = ResourceNames(
  skills: {'sk-1': 'Resumir'},
  prompts: {'pr-1': 'Tono formal'},
  tools: {'to-1': 'Buscar'},
  knowledge: {'kn-1': 'Manual'},
  packs: {'kp-1': 'Guía'},
  connections: {'conn-1': 'gpt-4o'},
  packItems: {
    'kp-1': [
      KnowledgeItem(
        raw: {
          'id': 'kn-9',
          'name': 'tono.md',
          'pack_id': 'kp-1',
          'pack_relative_path': 'estilo/tono.md',
        },
      ),
    ],
  },
);

Set<String> _labels(GraphBuild graph) =>
    graph.nodes.map((node) => node.label).toSet();

void main() {
  test('el grafo de un agente incluye todo lo que usa, con nombres', () {
    final graph = agentGraph(agent: _agent, names: _names);

    expect(
      _labels(graph),
      containsAll(<String>[
        'Redactor',
        'gpt-4o',
        'Resumir',
        'Tono formal',
        'Buscar',
        'Manual',
        'Guía',
        'notas.md',
      ]),
      reason: 'ningún nodo debe quedarse con el id crudo',
    );
  });

  test('un pack cuelga su jerarquía real de carpetas y ficheros', () {
    final graph = agentGraph(agent: _agent, names: _names);
    final porTipo = {for (final node in graph.nodes) node.label: node.type};

    expect(porTipo['estilo'], 'knowledge_directory');
    expect(porTipo['tono.md'], 'knowledge');
    final packId = graph.nodes.firstWhere((n) => n.label == 'Guía').id;
    final carpetaId = graph.nodes.firstWhere((n) => n.label == 'estilo').id;
    expect(
      graph.edges.any((e) => e.sourceId == packId && e.targetId == carpetaId),
      isTrue,
    );
  });

  test(
    'el mismo agente da el mismo subgrafo desde Agentes y desde Workflows',
    () {
      // Es la regresión que motivó unificar: el grafo del agente enseñaba
      // menos cosas —y con ids en vez de nombres— si se abría desde la
      // orquestación que lo ejecuta.
      final desdeAgentes = agentGraph(agent: _agent, names: _names);
      final desdeWorkflow = workflowGraph(
        workflow: const WorkflowItem(
          raw: {
            'id': 'wf-1',
            'name': 'Cadena',
            'definition': {
              'nodes': [
                {'id': 'paso-1', 'agent_id': 'ag-1'},
              ],
              'edges': [],
            },
          },
        ),
        agentsById: const {'ag-1': _agent},
        names: _names,
      );

      final hijosEnAgentes = _labels(desdeAgentes)..remove('Redactor');
      final hijosEnWorkflow = _labels(desdeWorkflow)
        ..removeAll({'Cadena', 'Redactor'});
      expect(hijosEnWorkflow, hijosEnAgentes);
    },
  );

  test('un recurso usado por dos agentes aparece una sola vez', () {
    const otro = AgentItem(
      raw: {
        'id': 'ag-2',
        'name': 'Revisor',
        'skills': ['sk-1'],
      },
    );
    final graph = workflowGraph(
      workflow: const WorkflowItem(
        raw: {
          'id': 'wf-1',
          'name': 'Cadena',
          'definition': {
            'nodes': [
              {'id': 'p1', 'agent_id': 'ag-1'},
              {'id': 'p2', 'agent_id': 'ag-2'},
            ],
            'edges': [
              {'source': 'p1', 'target': 'p2'},
            ],
          },
        },
      ),
      agentsById: const {'ag-1': _agent, 'ag-2': otro},
      names: _names,
    );

    expect(graph.nodes.where((node) => node.label == 'Resumir'), hasLength(1));
    final skillId = graph.nodes.firstWhere((n) => n.label == 'Resumir').id;
    expect(
      graph.edges.where((e) => e.targetId == skillId).map((e) => e.sourceId),
      containsAll(<String>['p1', 'p2']),
      reason: 'la skill compartida se enlaza desde los dos pasos',
    );
  });

  test('un paso sin predecesor cuelga de la raíz', () {
    final graph = workflowGraph(
      workflow: const WorkflowItem(
        raw: {
          'id': 'wf-1',
          'name': 'Cadena',
          'definition': {
            'nodes': [
              {'id': 'p1'},
              {'id': 'p2'},
            ],
            'edges': [
              {'source': 'p1', 'target': 'p2', 'type': 'loop'},
            ],
          },
        },
      ),
      agentsById: const {},
      names: const ResourceNames(),
    );

    expect(
      graph.edges.any((e) => e.sourceId == graph.rootId && e.targetId == 'p1'),
      isTrue,
    );
    expect(
      graph.edges.any((e) => e.sourceId == graph.rootId && e.targetId == 'p2'),
      isFalse,
    );
    expect(graph.edges.singleWhere((e) => e.targetId == 'p2').dashed, isTrue);
  });

  test('las relaciones del backend se arman aquí, no allí', () {
    final graph = fromRelations(const {
      'root': {'type': 'agent', 'id': 'ag-1', 'label': 'Redactor'},
      'items': [
        {
          'type': 'skill',
          'id': 'sk-1',
          'label': 'Resumir',
          'relation': 'uses',
          'via': null,
        },
        {
          'type': 'user',
          'id': 'u-1',
          'label': 'ana',
          'relation': 'owns',
          'via': null,
          'inverse': true,
        },
      ],
    });

    expect(graph.rootId, 'agent:ag-1');
    expect(graph.nodes, hasLength(3));
    // El propietario apunta hacia el recurso, no al revés.
    final propiedad = graph.edges.singleWhere(
      (edge) => edge.sourceId == 'user:u-1',
    );
    expect(propiedad.targetId, 'agent:ag-1');
  });

  test('el árbol de carpetas de un pack se construye desde la ruta', () {
    // El backend manda `path`; los nodos de carpeta no viajan por la red.
    final graph = fromRelations(const {
      'root': {'type': 'knowledge_pack', 'id': 'kp-1', 'label': 'Guía'},
      'items': [
        {
          'type': 'knowledge',
          'id': 'kn-1',
          'label': 'tono.md',
          'relation': 'contains',
          'via': {'type': 'knowledge_pack', 'id': 'kp-1'},
          'path': 'estilo/voz/tono.md',
        },
      ],
    });

    final porTipo = {for (final node in graph.nodes) node.label: node.type};
    expect(porTipo['estilo'], 'knowledge_directory');
    expect(porTipo['voz'], 'knowledge_directory');
    expect(porTipo['tono.md'], 'knowledge');
    expect(graph.edges, hasLength(3));
  });
}
