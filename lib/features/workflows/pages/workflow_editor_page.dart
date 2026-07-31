import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../models/workflow_step_draft.dart';
import '../widgets/workflow_visual_canvas.dart';

part '../cards/workflow_step_editor_card.dart';

class WorkflowEditorPage extends StatefulWidget {
  const WorkflowEditorPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    this.initial,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final Map<String, dynamic>? initial;

  @override
  State<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

class _WorkflowEditorPageState extends State<WorkflowEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _labelsController;
  late final TranslatedTexts _t;
  late List<WorkflowStepDraft> _steps;
  String? _selectedStepId;
  int _stepCounter = 0;

  List<AgentItem> _agents = const [];
  bool _loadingAgents = true;
  String? _error;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);
  void _refresh(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    final labels = (initial?['labels'] is List)
        ? (initial?['labels'] as List).map((item) => item.toString()).join(', ')
        : 'private';
    _labelsController = TextEditingController(text: labels);

    final definition = initial?['definition'];
    _steps = definition is Map<String, dynamic>
        ? _stepsFromDefinition(definition)
        : [_newStep()];
    _selectedStepId = _steps.first.id;
    _loadAgents();
  }

  void _onTextsChanged() {
    if (mounted) _refresh(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadAgents() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _refresh(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loadingAgents = false;
      });
      return;
    }
    try {
      final agents = await AgentsRepository(
        apiClient: widget.apiClient,
      ).listAgents(token);
      if (!mounted) return;
      _refresh(() {
        _agents = agents;
        _loadingAgents = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
        _error = _tx(
          'workflow_editor.error_load_agents',
          'No se pudieron cargar los agentes disponibles',
        );
        _loadingAgents = false;
      });
    }
  }

  WorkflowStepDraft _newStep() {
    _stepCounter += 1;
    return WorkflowStepDraft(
      id: 'step-${DateTime.now().millisecondsSinceEpoch}-$_stepCounter',
    );
  }

  List<WorkflowStepDraft> _stepsFromDefinition(
    Map<String, dynamic> definition,
  ) {
    final nodes = (definition['nodes'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final edges = (definition['edges'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (nodes.isEmpty) return [_newStep()];

    final sequenceEdges = edges
        .where((e) => (e['type'] ?? 'sequence') == 'sequence')
        .toList();
    final loopEdges = edges.where((e) => e['type'] == 'loop').toList();

    return nodes.map((n) {
      final id = n['id'].toString();
      final loop = loopEdges
          .where((e) => e['source']?.toString() == id)
          .toList();
      final evaluator = n['evaluator'] as Map<String, dynamic>?;
      final nextIds = sequenceEdges
          .where((e) => e['source']?.toString() == id)
          .map((e) => e['target'].toString())
          .toList();
      return WorkflowStepDraft(
        id: id,
        agentId: n['agent_id']?.toString() ?? '',
        label: n['label']?.toString() ?? '',
        instruction: n['instruction']?.toString() ?? '',
        kind: n['kind']?.toString() ?? 'agent',
        evaluatorCondition: evaluator?['condition']?.toString() ?? '',
        evaluatorMaxIterations:
            (evaluator?['max_iterations'] as num?)?.toInt() ?? 5,
        loopTargetId: loop.isEmpty ? null : loop.first['target']?.toString(),
        loopIterations: loop.isEmpty
            ? 2
            : ((loop.first['iterations'] as num?)?.toInt() ?? 2),
        positionX: ((n['position'] as Map?)?['x'] as num?)?.toDouble(),
        positionY: ((n['position'] as Map?)?['y'] as num?)?.toDouble(),
        nextStepIds: nextIds,
      );
    }).toList();
  }

  Map<String, dynamic> _buildDefinition() {
    final nodes = _steps.map((step) {
      final node = <String, dynamic>{
        'id': step.id,
        'agent_id': step.agentId,
        'label': step.label,
        'instruction': step.instruction,
        'kind': step.kind,
        if (step.positionX != null && step.positionY != null)
          'position': {'x': step.positionX, 'y': step.positionY},
      };
      if (step.kind == 'evaluator') {
        node['evaluator'] = {
          'condition': step.evaluatorCondition,
          'max_iterations': step.evaluatorMaxIterations,
        };
      }
      return node;
    }).toList();

    final edges = <Map<String, dynamic>>[];
    for (final step in _steps) {
      for (final nextId in step.nextStepIds) {
        edges.add({'source': step.id, 'target': nextId, 'type': 'sequence'});
      }
    }
    for (final step in _steps) {
      if (step.loopTargetId == null) continue;
      final edge = <String, dynamic>{
        'source': step.id,
        'target': step.loopTargetId,
        'type': 'loop',
        'mode': step.kind == 'evaluator' ? 'condition' : 'fixed',
      };
      if (step.kind != 'evaluator') edge['iterations'] = step.loopIterations;
      edges.add(edge);
    }

    return {'nodes': nodes, 'edges': edges};
  }

  String? _validate() {
    if (_steps.isEmpty) {
      return _tx(
        'workflow_editor.validate_no_steps',
        'La orquestación necesita al menos un paso',
      );
    }
    for (var i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      if (step.agentId.isEmpty) {
        return _tx(
          'workflow_editor.validate_select_agent',
          'Selecciona un agente para el paso {{step}}',
        ).replaceAll('{{step}}', '${i + 1}');
      }
      if (step.kind == 'evaluator') {
        if (step.evaluatorCondition.trim().isEmpty) {
          return _tx(
            'workflow_editor.validate_evaluator_condition',
            'El paso {{step}} es un evaluador y necesita una condición',
          ).replaceAll('{{step}}', '${i + 1}');
        }
        if (step.loopTargetId == null) {
          return _tx(
            'workflow_editor.validate_evaluator_loop',
            'El paso {{step}} es un evaluador y debe volver a un paso anterior',
          ).replaceAll('{{step}}', '${i + 1}');
        }
      }
    }
    if (_steps.length > 1 && _steps.every((s) => s.nextStepIds.isEmpty)) {
      return _tx(
        'workflow_editor.validate_connect_steps',
        'Conecta los pasos entre sí ("Continúa hacia") para formar el flujo',
      );
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final labels = _labelsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'labels': labels.isEmpty ? ['private'] : labels,
      'definition': _buildDefinition(),
    };
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    Navigator.of(context).pop(payload);
  }

  void _addStep() {
    final newStep = _newStep();
    _refresh(() {
      // Si el último paso todavía no continúa hacia ningún sitio, lo
      // enlazamos automáticamente al nuevo — mantiene el caso lineal
      // (el más común) tan simple como antes; las ramas se añaden luego
      // a mano con "Continúa hacia".
      if (_steps.isNotEmpty && _steps.last.nextStepIds.isEmpty) {
        _steps.last.nextStepIds.add(newStep.id);
      }
      _steps = [..._steps, newStep];
      _selectedStepId = newStep.id;
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    final removedId = _steps[index].id;
    _refresh(() {
      _steps = [..._steps]..removeAt(index);
      for (final step in _steps) {
        if (step.loopTargetId == removedId) step.loopTargetId = null;
        step.nextStepIds.remove(removedId);
      }
      if (_selectedStepId == removedId) {
        _selectedStepId = _steps.first.id;
      }
    });
  }

  void _removeStepById(String stepId) {
    final index = _steps.indexWhere((step) => step.id == stepId);
    if (index >= 0) _removeStep(index);
  }

  void _moveStep(String stepId, Offset position) {
    final step = _steps.where((item) => item.id == stepId).firstOrNull;
    if (step == null) return;
    step.positionX = position.dx;
    step.positionY = position.dy;
  }

  void _createConnection(String sourceId, String targetId, String type) {
    _refresh(() {
      final source = _steps.where((item) => item.id == sourceId).firstOrNull;
      if (source == null) return;
      if (type == 'loop') {
        source.loopTargetId = targetId;
      } else if (!source.nextStepIds.contains(targetId)) {
        source.nextStepIds.add(targetId);
      }
    });
  }

  void _deleteConnection(String sourceId, String targetId, String type) {
    _refresh(() {
      final source = _steps.where((item) => item.id == sourceId).firstOrNull;
      if (source == null) return;
      if (type == 'loop') {
        if (source.loopTargetId == targetId) source.loopTargetId = null;
      } else {
        source.nextStepIds.remove(targetId);
      }
    });
  }

  bool _canCreateConnection(String sourceId, String targetId) {
    if (sourceId == targetId) return false;
    final source = _steps.where((item) => item.id == sourceId).firstOrNull;
    if (source == null || source.nextStepIds.contains(targetId)) return false;

    final pending = <String>[targetId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      if (current == sourceId) return false;
      final step = _steps.where((item) => item.id == current).firstOrNull;
      if (step != null) pending.addAll(step.nextStepIds);
    }
    return true;
  }

  Widget _buildMetadataCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: widget.initial == null,
        leading: const Icon(Icons.description_outlined),
        title: Text(
          _tx('workflow_editor.details_title', 'Datos del workflow'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: _tx('workflow_editor.name_label', 'Nombre'),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? _tx('workflow_editor.name_required', 'Nombre obligatorio')
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: _tx(
                'workflow_editor.description_label',
                'Descripción',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _labelsController,
            decoration: InputDecoration(
              labelText: _tx(
                'workflow_editor.labels_label',
                'Labels (coma separada)',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspector() {
    final index = _steps.indexWhere((step) => step.id == _selectedStepId);
    if (index < 0) {
      return Center(
        child: Text(
          _tx(
            'workflow_editor.select_node_hint',
            'Selecciona un nodo para editarlo',
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tx(
                  'workflow_editor.inspector_title',
                  'Configuración del paso',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${index + 1}/${_steps.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildStepCard(index, key: ValueKey('inspector-${_steps[index].id}')),
      ],
    );
  }

  Widget _buildWorkspace() {
    final canvas = WorkflowVisualCanvas(
      steps: _steps,
      agents: _agents,
      selectedStepId: _selectedStepId,
      onStepSelected: (id) => _refresh(() => _selectedStepId = id),
      onStepMoved: _moveStep,
      onStepDeleted: _removeStepById,
      onConnectionCreated: _createConnection,
      onConnectionDeleted: _deleteConnection,
      canCreateConnection: _canCreateConnection,
      fitTooltip: _tx('workflow_editor.fit_view', 'Encajar diagrama'),
      zoomInTooltip: _tx('workflow_editor.zoom_in', 'Acercar'),
      zoomOutTooltip: _tx('workflow_editor.zoom_out', 'Alejar'),
      connectionHint: _tx(
        'workflow_editor.visual_hint',
        'Arrastra desde la salida de un nodo hasta la entrada de otro',
      ),
      inputLabel: _tx('workflow_editor.input_port', 'Entrada'),
      outputLabel: _tx('workflow_editor.output_port', 'Salida'),
      missingAgentLabel: _tx('workflow_editor.no_agent', 'Sin agente'),
      agentKindLabel: _tx('workflow_editor.kind_agent', 'Agente'),
      evaluatorKindLabel: _tx('workflow_editor.kind_evaluator', 'Evaluador'),
      loopLabel: _tx('workflow_editor.loop_label', 'Bucle'),
      invalidConnectionMessage: _tx(
        'workflow_editor.invalid_connection',
        'La conexión crearía un ciclo o ya existe',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: canvas),
              const SizedBox(width: 14),
              SizedBox(width: 390, child: _buildInspector()),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 3, child: canvas),
            const SizedBox(height: 12),
            Expanded(flex: 2, child: _buildInspector()),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? _tx('workflow_editor.title_new', 'Nuevo workflow')
              : _tx('workflow_editor.title_edit', 'Editar workflow'),
        ),
        actions: [
          TertiaryButton(
            onPressed: _save,
            child: Text(_tx('workflow_editor.save_btn', 'GUARDAR')),
          ),
        ],
      ),
      body: _loadingAgents
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (_error != null) ...[
                      MaterialBanner(
                        content: Text(_error!),
                        actions: [
                          TertiaryButton(
                            onPressed: () => _refresh(() => _error = null),
                            child: Text(_tx('common.close', 'Cerrar')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildMetadataCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tx(
                                  'workflow_editor.canvas_title',
                                  'Lienzo de orquestación',
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _tx(
                                  'workflow_editor.canvas_subtitle',
                                  'Diseña el flujo conectando agentes visualmente',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        SecondaryButton.icon(
                          onPressed: _addStep,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _tx('workflow_editor.add_step_btn', 'Añadir paso'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildWorkspace()),
                  ],
                ),
              ),
            ),
    );
  }
}
