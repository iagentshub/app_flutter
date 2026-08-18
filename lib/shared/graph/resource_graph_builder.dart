import '../../models/agents/agent_models.dart';
import '../../models/connections/connection_models.dart';
import '../../models/explore/explore_models.dart';
import '../../models/knowledge/knowledge_models.dart';
import '../../models/prompts/prompt_models.dart';
import '../../models/skills/skill_models.dart';
import '../../models/tools/tool_models.dart';
import '../../models/workflows/workflow_models.dart';
import 'graph_models.dart';

/// Resultado de armar un grafo: los nodos, las aristas y cuál es la raíz.
///
/// Se devuelve como un objeto y no como una tupla suelta porque el `rootId`
/// viaja siempre con ellos: el widget lo necesita para saber qué nodo es el
/// centro, y separarlos es cómo se acababa pasando la raíz de otro grafo.
class GraphBuild {
  const GraphBuild({
    required this.nodes,
    required this.edges,
    required this.rootId,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String rootId;
}

/// Catálogo de etiquetas legibles por id de recurso.
///
/// Sin esto un grafo enseña el id crudo, que es exactamente lo que pasaba en
/// Workflows mientras Agentes mostraba nombres: la tarjeta de agentes recibía
/// siete mapas sueltos y la de workflows ninguno. Al vivir el catálogo aquí,
/// cualquier pantalla que arme un grafo obtiene los mismos nombres.
class ResourceNames {
  const ResourceNames({
    this.skills = const {},
    this.prompts = const {},
    this.tools = const {},
    this.knowledge = const {},
    this.packs = const {},
    this.connections = const {},
    this.packItems = const {},
  });

  final Map<String, String> skills;
  final Map<String, String> prompts;
  final Map<String, String> tools;
  final Map<String, String> knowledge;
  final Map<String, String> packs;
  final Map<String, String> connections;

  /// Ficheros de cada pack, indexados por id de pack. Permite colgar del pack
  /// su contenido real en vez de un nodo opaco.
  final Map<String, List<KnowledgeItem>> packItems;

  /// Arma el catálogo desde los listados que ya carga cada pantalla. Estaba
  /// escrito a mano en la página de Agentes y en ningún sitio más, que es
  /// justo por qué el grafo de Workflows enseñaba ids.
  factory ResourceNames.fromCatalogs({
    List<SkillItem> skills = const [],
    List<PromptItem> prompts = const [],
    List<ToolItem> tools = const [],
    List<KnowledgeItem> knowledge = const [],
    List<KnowledgePack> packs = const [],
    List<ConnectionItem> connections = const [],
  }) => ResourceNames(
    skills: {for (final item in skills) item.id: item.name},
    prompts: {for (final item in prompts) item.id: item.name},
    tools: {for (final item in tools) item.id: item.name},
    knowledge: {for (final item in knowledge) item.id: item.name},
    packs: {for (final item in packs) item.id: item.name},
    connections: {
      for (final item in connections)
        item.id: item.model.isNotEmpty ? item.model : item.name,
    },
    packItems: {
      for (final pack in packs)
        pack.id: knowledge.where((item) => item.packId == pack.id).toList(),
    },
  );

  String skill(String id) => skills[id] ?? id;
  String prompt(String id) => prompts[id] ?? id;
  String tool(String id) => tools[id] ?? id;
  String knowledgeName(String id) => knowledge[id] ?? id;
  String pack(String id) => packs[id] ?? id;
  String connection(String id) => connections[id] ?? id;
}

/// Acumulador con deduplicación incorporada.
///
/// Las cuatro implementaciones que esto sustituye repetían cada una su propio
/// `Map` de nodos y `Set` de claves de arista, y una de ellas reconstruía el
/// conjunto de ids ya vistos dentro del bucle. Un recurso compartido por dos
/// agentes tiene que aparecer una sola vez, enlazado desde ambos.
class _Accumulator {
  final Map<String, GraphNode> _nodes = {};
  final Map<String, GraphEdge> _edges = {};

  String node(
    String type,
    String id, {
    required String label,
    String description = '',
  }) {
    final nodeId = '$type:$id';
    _nodes[nodeId] = GraphNode(
      id: nodeId,
      label: label,
      type: type,
      description: description,
    );
    return nodeId;
  }

  /// Nodo con id explícito, para las raíces y para los pasos de una
  /// orquestación, cuyos ids vienen dados por la definición del workflow.
  String rawNode(
    String nodeId, {
    required String label,
    required String type,
    String description = '',
  }) {
    _nodes[nodeId] = GraphNode(
      id: nodeId,
      label: label,
      type: type,
      description: description,
    );
    return nodeId;
  }

  void edge(String sourceId, String targetId, {bool dashed = false}) {
    _edges['$sourceId->$targetId'] = GraphEdge(
      sourceId: sourceId,
      targetId: targetId,
      dashed: dashed,
    );
  }

  bool hasNode(String nodeId) => _nodes.containsKey(nodeId);

  GraphBuild build(String rootId) => GraphBuild(
    nodes: _nodes.values.toList(growable: false),
    edges: _edges.values.toList(growable: false),
    rootId: rootId,
  );
}

/// Cuelga de [parentId] todo lo que usa un agente.
///
/// Es la frase que estaba escrita cuatro veces —y en tres versiones distintas,
/// así que el mismo agente enseñaba cosas diferentes según desde qué pantalla
/// se abriera el grafo—. Aquí está una vez y completa.
void _agentSubgraph(
  _Accumulator acc,
  AgentItem agent, {
  required String parentId,
  required ResourceNames names,
  String connectionOverride = '',
}) {
  final connectionId = connectionOverride.isNotEmpty
      ? connectionOverride
      : agent.connectionId;
  if (connectionId.isNotEmpty) {
    acc.edge(
      parentId,
      acc.node(
        'connection',
        connectionId,
        label: names.connection(connectionId),
      ),
    );
  }
  for (final id in agent.skills) {
    acc.edge(parentId, acc.node('skill', id, label: names.skill(id)));
  }
  for (final id in agent.prompts) {
    acc.edge(parentId, acc.node('prompt', id, label: names.prompt(id)));
  }
  for (final id in agent.tools) {
    acc.edge(parentId, acc.node('tool', id, label: names.tool(id)));
  }
  for (final id in agent.knowledge) {
    acc.edge(
      parentId,
      acc.node('knowledge', id, label: names.knowledgeName(id)),
    );
  }
  for (final id in agent.knowledgePacks) {
    final packNodeId = acc.node('knowledge_pack', id, label: names.pack(id));
    acc.edge(parentId, packNodeId);
    _packTree(acc, packNodeId: packNodeId, items: names.packItems[id] ?? const []);
  }
  if (agent.useMemory) {
    final file = agent.memoryFile.isEmpty ? 'memory' : agent.memoryFile;
    acc.edge(parentId, acc.node('memory', file, label: file));
  }
}

/// Reconstruye la jerarquía real de un pack: carpetas y ficheros a partir de
/// la ruta relativa de cada miembro.
///
/// El backend inventaba nodos de carpeta y los mandaba ya montados; ahora
/// manda la ruta y el árbol se arma aquí, que es donde estaba escrito por
/// tercera vez.
void _packTree(
  _Accumulator acc, {
  required String packNodeId,
  required List<KnowledgeItem> items,
}) {
  for (final item in items) {
    final relativePath = item.packRelativePath.isEmpty
        ? item.name
        : item.packRelativePath;
    final parts = relativePath.split('/').where((p) => p.isNotEmpty).toList();
    var parentId = packNodeId;
    final directories = <String>[];
    for (final directory in parts.take(parts.length - 1)) {
      directories.add(directory);
      final directoryId = acc.node(
        'knowledge_directory',
        '$packNodeId/${directories.join('/')}',
        label: directory,
        description: directories.join('/'),
      );
      acc.edge(parentId, directoryId);
      parentId = directoryId;
    }
    final leafId = acc.node(
      'knowledge',
      item.id,
      label: parts.isEmpty ? relativePath : parts.last,
      description: item.preview,
    );
    acc.edge(parentId, leafId);
  }
}

/// Grafo de contenido de un agente: el agente en el centro y todo lo que usa.
GraphBuild agentGraph({
  required AgentItem agent,
  required ResourceNames names,
}) {
  final acc = _Accumulator();
  final rootId = acc.rawNode(
    'root',
    label: agent.name,
    type: 'agent',
    description: agent.description,
  );
  _agentSubgraph(acc, agent, parentId: rootId, names: names);
  return acc.build(rootId);
}

/// Grafo de una orquestación a tres niveles: la orquestación, sus pasos y,
/// bajo cada paso, lo que usa el agente que lo ejecuta.
GraphBuild workflowGraph({
  required WorkflowItem workflow,
  required Map<String, AgentItem> agentsById,
  required ResourceNames names,
}) {
  final acc = _Accumulator();
  final rootId = acc.rawNode(
    'root',
    label: workflow.name,
    type: 'workflow',
    description: workflow.description,
  );

  final stepIds = <String>{};
  for (final raw in workflow.nodes) {
    if (raw is! Map) continue;
    final stepId = raw['id']?.toString() ?? '';
    if (stepId.isEmpty) continue;
    stepIds.add(stepId);
    final agentId = raw['agent_id']?.toString() ?? '';
    final agent = agentsById[agentId];
    final label = (raw['label']?.toString().isNotEmpty ?? false)
        ? raw['label'].toString()
        : (agent?.name ?? (agentId.isEmpty ? stepId : agentId));
    acc.rawNode(
      stepId,
      label: label,
      type: raw['kind']?.toString() == 'evaluator' ? 'evaluator' : 'agent',
      description: agent?.description ?? '',
    );
    if (agent == null) continue;
    _agentSubgraph(
      acc,
      agent,
      parentId: stepId,
      names: names,
      // La conexión de la orquestación manda sobre la del agente: es la que
      // se usa de verdad al ejecutar el paso.
      connectionOverride: workflow.llmOrchestrationConnectionId,
    );
  }

  final withIncoming = <String>{};
  for (final raw in workflow.edges) {
    if (raw is! Map) continue;
    final source = raw['source']?.toString() ?? '';
    final target = raw['target']?.toString() ?? '';
    if (!acc.hasNode(source) || !acc.hasNode(target)) continue;
    withIncoming.add(target);
    acc.edge(source, target, dashed: raw['type']?.toString() == 'loop');
  }
  // Un paso sin predecesor cuelga de la raíz: si no, quedaría suelto en el
  // lienzo sin nada que lo una a la orquestación que lo contiene.
  for (final stepId in stepIds) {
    if (!withIncoming.contains(stepId)) acc.edge(rootId, stepId);
  }
  return acc.build(rootId);
}

/// Grafo de un recurso suelto de Knowledge (skill, prompt, tool, knowledge o
/// pack) con los agentes que lo usan alrededor.
GraphBuild resourceUsageGraph({
  required String resourceId,
  required String resourceName,
  required String resourceType,
  String resourceDescription = '',
  required List<AgentItem> usedBy,
}) {
  final acc = _Accumulator();
  final rootId = acc.rawNode(
    'root',
    label: resourceName,
    type: resourceType,
    description: resourceDescription,
  );
  for (final agent in usedBy) {
    acc.edge(
      rootId,
      acc.node(
        'agent',
        agent.id,
        label: agent.name,
        description: agent.description,
      ),
    );
  }
  return acc.build(rootId);
}

/// Grafo de un fichero de knowledge: su pack encima (si pertenece a uno) y
/// los agentes que lo usan.
GraphBuild knowledgeItemGraph({
  required KnowledgeItem item,
  KnowledgePack? pack,
  required List<AgentItem> usedBy,
}) {
  final acc = _Accumulator();
  final rootId = acc.rawNode(
    'root',
    label: item.name,
    type: 'knowledge',
    description: item.preview,
  );
  final packId = item.packId;
  if (packId != null && packId.isNotEmpty) {
    final packNodeId = acc.node(
      'knowledge_pack',
      packId,
      label: pack?.name ?? item.packRelativePath,
      description: pack?.description ?? '',
    );
    acc.edge(packNodeId, rootId);
  }
  for (final agent in usedBy) {
    acc.edge(
      rootId,
      acc.node(
        'agent',
        agent.id,
        label: agent.name,
        description: agent.description,
      ),
    );
  }
  return acc.build(rootId);
}

/// Grafo de un pack: su contenido real (carpetas y ficheros) y los agentes
/// que usan el pack entero o alguno de sus ficheros.
GraphBuild knowledgePackGraph({
  required KnowledgePack pack,
  required List<KnowledgeItem> items,
  required List<AgentItem> usedBy,
}) {
  final acc = _Accumulator();
  final rootId = acc.rawNode(
    'root',
    label: pack.name,
    type: 'knowledge_pack',
    description: pack.description,
  );
  _packTree(acc, packNodeId: rootId, items: items);
  for (final agent in usedBy) {
    final agentNodeId = 'agent:${agent.id}';
    if (agent.knowledgePacks.contains(pack.id)) {
      acc.node(
        'agent',
        agent.id,
        label: agent.name,
        description: agent.description,
      );
      acc.edge(rootId, agentNodeId);
    }
    for (final item in items.where((i) => agent.knowledge.contains(i.id))) {
      acc.node(
        'agent',
        agent.id,
        label: agent.name,
        description: agent.description,
      );
      acc.edge('knowledge:${item.id}', agentNodeId);
    }
  }
  return acc.build(rootId);
}

/// Grafo de un pack oficial: el repositorio de origen, sus componentes y las
/// dependencias entre ellos.
///
/// La tarjeta de Explorar y la página de detalle del pack armaban este mismo
/// grafo por separado —una en Python y otra en Dart— porque cada una tenía a
/// mano un modelo distinto. Ahora las dos pasan por aquí.
GraphBuild officialPackGraph({
  required String sourceId,
  required String sourceName,
  String sourceDescription = '',
  required List<ExploreOfficialPackComponent> components,
}) {
  final acc = _Accumulator();
  final rootId = acc.node(
    'official_source',
    sourceId,
    label: sourceName,
    description: sourceDescription,
  );
  final nodeIdByKey = <String, String>{};
  for (final component in components) {
    final nodeId = acc.node(
      component.resourceType,
      component.resourceId,
      label: component.name,
      description: component.description,
    );
    nodeIdByKey[component.componentKey] = nodeId;
    acc.edge(rootId, nodeId);
  }
  for (final component in components) {
    final sourceNodeId = nodeIdByKey[component.componentKey];
    if (sourceNodeId == null) continue;
    for (final dependency in component.dependencies) {
      final targetNodeId = nodeIdByKey[dependency];
      if (targetNodeId != null) acc.edge(sourceNodeId, targetNodeId);
    }
  }
  return acc.build(rootId);
}

/// Grafo armado a partir de las relaciones que devuelve el backend
/// (`/relations`).
///
/// El servidor solo aporta hechos —qué cuelga de qué, con qué nombre y con qué
/// relación— porque hay dos cosas que el cliente no puede resolver por su
/// cuenta: el filtro de dependencias públicas de un recurso publicado y los
/// recursos de otros usuarios en el panel de administración. La forma la pone
/// este fichero, igual que en los grafos que se arman del todo aquí: las
/// carpetas de un pack, por ejemplo, salen de la ruta de cada fichero y no
/// viajan por la red.
GraphBuild fromRelations(Map<String, dynamic> json) {
  final acc = _Accumulator();
  final root = (json['root'] as Map?)?.cast<String, dynamic>() ?? const {};
  final rootType = (root['type'] ?? '').toString();
  final rootRawId = (root['id'] ?? '').toString();
  final rootId = acc.node(
    rootType,
    rootRawId,
    label: (root['label'] ?? '').toString(),
    description: (root['description'] ?? '').toString(),
  );

  final directories = <String, String>{};
  for (final raw in (json['items'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final relation = (raw['relation'] ?? '').toString();
    final via = (raw['via'] as Map?)?.cast<String, dynamic>();
    final viaRawId = (via?['id'] ?? rootRawId).toString();
    var parentId = via == null
        ? rootId
        : '${(via['type'] ?? '').toString()}:$viaRawId';

    final parts = (raw['path'] ?? '')
        .toString()
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length > 1) {
      final accumulated = <String>[];
      for (final directory in parts.take(parts.length - 1)) {
        accumulated.add(directory);
        final key = '$viaRawId:${accumulated.join('/')}';
        parentId = directories.putIfAbsent(key, () {
          final directoryId = acc.node(
            'knowledge_directory',
            key,
            label: directory,
            description: accumulated.join('/'),
          );
          acc.edge(parentId, directoryId);
          return directoryId;
        });
      }
    }

    final targetId = acc.node(
      (raw['type'] ?? '').toString(),
      (raw['id'] ?? '').toString(),
      label: (raw['label'] ?? '').toString(),
      description: (raw['description'] ?? '').toString(),
    );
    // Un propietario, una fuente oficial o el agente que usa el recurso
    // apuntan hacia aquello de lo que cuelgan, no al revés.
    final inverse = raw['inverse'] == true;
    acc.edge(
      inverse ? targetId : parentId,
      inverse ? parentId : targetId,
      dashed: const {'flow_loop', 'shared', 'depends'}.contains(relation),
    );
  }
  return acc.build(rootId);
}
