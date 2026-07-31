import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../models/workflow_step_draft.dart';

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
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    _refresh(() {
      final list = [..._steps];
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _steps = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: _tx(
                            'workflow_editor.name_label',
                            'Nombre',
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? _tx(
                                'workflow_editor.name_required',
                                'Nombre obligatorio',
                              )
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tx('workflow_editor.steps_title', 'Pasos'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SecondaryButton.icon(
                            onPressed: _addStep,
                            icon: const Icon(Icons.add),
                            label: Text(
                              _tx(
                                'workflow_editor.add_step_btn',
                                'Añadir paso',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tx(
                          'workflow_editor.steps_hint',
                          'Cada paso puede continuar hacia varios pasos a la vez '
                              '(ramas paralelas) — marca los destinos en "Continúa hacia".',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _steps.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) => _buildStepCard(
                          index,
                          key: ValueKey(_steps[index].id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
