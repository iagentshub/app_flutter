import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../../shared/state/session_controller.dart';

class _StepDraft {
  _StepDraft({
    required this.id,
    this.agentId = '',
    this.label = '',
    this.instruction = '',
    this.kind = 'agent',
    this.evaluatorCondition = '',
    this.evaluatorMaxIterations = 5,
    this.loopTargetId,
    this.loopIterations = 2,
  });

  final String id;
  String agentId;
  String label;
  String instruction;
  String kind;
  String evaluatorCondition;
  int evaluatorMaxIterations;
  String? loopTargetId;
  int loopIterations;
}

class WorkflowEditorPage extends StatefulWidget {
  const WorkflowEditorPage({
    required this.apiClient,
    required this.sessionController,
    this.initial,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final Map<String, dynamic>? initial;

  @override
  State<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

class _WorkflowEditorPageState extends State<WorkflowEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _labelsController;
  late List<_StepDraft> _steps;
  int _stepCounter = 0;

  List<AgentItem> _agents = const [];
  bool _loadingAgents = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?['name']?.toString() ?? '');
    _descriptionController = TextEditingController(text: initial?['description']?.toString() ?? '');
    final labels = (initial?['labels'] is List)
        ? (initial?['labels'] as List).map((item) => item.toString()).join(', ')
        : 'private';
    _labelsController = TextEditingController(text: labels);

    final definition = initial?['definition'];
    _steps = definition is Map<String, dynamic> ? _stepsFromDefinition(definition) : [_newStep()];
    _loadAgents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadAgents() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loadingAgents = false;
      });
      return;
    }
    try {
      final agents = await AgentsRepository(apiClient: widget.apiClient).listAgents(token);
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _loadingAgents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los agentes disponibles';
        _loadingAgents = false;
      });
    }
  }

  _StepDraft _newStep() {
    _stepCounter += 1;
    return _StepDraft(id: 'step-${DateTime.now().millisecondsSinceEpoch}-$_stepCounter');
  }

  List<_StepDraft> _stepsFromDefinition(Map<String, dynamic> definition) {
    final nodes = (definition['nodes'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    final edges = (definition['edges'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    if (nodes.isEmpty) return [_newStep()];

    final byId = {for (final n in nodes) n['id'].toString(): n};
    final sequenceEdges = edges.where((e) => (e['type'] ?? 'sequence') == 'sequence').toList();
    final loopEdges = edges.where((e) => e['type'] == 'loop').toList();

    final outgoing = <String, String?>{};
    final incoming = <String, int>{};
    for (final n in nodes) {
      final id = n['id'].toString();
      outgoing[id] = null;
      incoming[id] = 0;
    }
    for (final e in sequenceEdges) {
      final source = e['source']?.toString();
      final target = e['target']?.toString();
      if (source == null || target == null) continue;
      outgoing[source] = target;
      incoming[target] = (incoming[target] ?? 0) + 1;
    }
    String? start;
    for (final n in nodes) {
      final id = n['id'].toString();
      if ((incoming[id] ?? 0) == 0) {
        start = id;
        break;
      }
    }
    final orderedIds = <String>[];
    String? current = start ?? nodes.first['id'].toString();
    while (current != null && !orderedIds.contains(current)) {
      orderedIds.add(current);
      current = outgoing[current];
    }
    for (final n in nodes) {
      final id = n['id'].toString();
      if (!orderedIds.contains(id)) orderedIds.add(id);
    }

    return orderedIds.map((id) {
      final n = byId[id]!;
      final loop = loopEdges.where((e) => e['source']?.toString() == id).toList();
      final evaluator = n['evaluator'] as Map<String, dynamic>?;
      return _StepDraft(
        id: id,
        agentId: n['agent_id']?.toString() ?? '',
        label: n['label']?.toString() ?? '',
        instruction: n['instruction']?.toString() ?? '',
        kind: n['kind']?.toString() ?? 'agent',
        evaluatorCondition: evaluator?['condition']?.toString() ?? '',
        evaluatorMaxIterations: (evaluator?['max_iterations'] as num?)?.toInt() ?? 5,
        loopTargetId: loop.isEmpty ? null : loop.first['target']?.toString(),
        loopIterations: loop.isEmpty ? 2 : ((loop.first['iterations'] as num?)?.toInt() ?? 2),
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
    for (var i = 0; i < _steps.length - 1; i++) {
      edges.add({'source': _steps[i].id, 'target': _steps[i + 1].id, 'type': 'sequence'});
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
    if (_steps.isEmpty) return 'La orquestación necesita al menos un paso';
    for (var i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      if (step.agentId.isEmpty) return 'Selecciona un agente para el paso ${i + 1}';
      if (step.kind == 'evaluator') {
        if (step.evaluatorCondition.trim().isEmpty) {
          return 'El paso ${i + 1} es un evaluador y necesita una condición';
        }
        if (step.loopTargetId == null) {
          return 'El paso ${i + 1} es un evaluador y debe volver a un paso anterior';
        }
      }
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red.shade700),
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
    setState(() => _steps = [..._steps, _newStep()]);
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    final removedId = _steps[index].id;
    setState(() {
      _steps = [..._steps]..removeAt(index);
      for (final step in _steps) {
        if (step.loopTargetId == removedId) step.loopTargetId = null;
      }
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final list = [..._steps];
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      for (final step in list) {
        step.loopTargetId = null;
      }
      _steps = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nuevo workflow' : 'Editar workflow'),
        actions: [
          TextButton(onPressed: _save, child: const Text('GUARDAR')),
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
                        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Nombre obligatorio' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _labelsController,
                        decoration: const InputDecoration(labelText: 'Labels (coma separada)'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pasos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          OutlinedButton.icon(
                            onPressed: _addStep,
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir paso'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _steps.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) => _buildStepCard(index, key: ValueKey(_steps[index].id)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStepCard(int index, {required Key key}) {
    final step = _steps[index];
    final earlierSteps = _steps.sublist(0, index);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                Text('Paso ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _steps.length > 1 ? () => _removeStep(index) : null,
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _agents.any((a) => a.id == step.agentId) ? step.agentId : null,
              decoration: const InputDecoration(labelText: 'Agente'),
              items: _agents
                  .map((agent) => DropdownMenuItem(value: agent.id, child: Text(agent.name)))
                  .toList(),
              onChanged: (value) => setState(() => step.agentId = value ?? ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: step.label,
              decoration: const InputDecoration(labelText: 'Etiqueta (opcional)'),
              onChanged: (value) => step.label = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: step.instruction,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Instrucción para este paso'),
              onChanged: (value) => step.instruction = value,
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'agent', label: Text('Agente')),
                ButtonSegment(value: 'evaluator', label: Text('Evaluador')),
              ],
              selected: {step.kind},
              onSelectionChanged: (selection) => setState(() {
                step.kind = selection.first;
                if (step.kind == 'agent') step.evaluatorCondition = '';
              }),
            ),
            if (step.kind == 'evaluator') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: step.evaluatorCondition,
                decoration: const InputDecoration(labelText: 'Condición de evaluación'),
                onChanged: (value) => step.evaluatorCondition = value,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Máx. vueltas'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      value: step.evaluatorMaxIterations.toDouble(),
                      min: 2,
                      max: 20,
                      divisions: 18,
                      label: '${step.evaluatorMaxIterations}',
                      onChanged: (value) => setState(() => step.evaluatorMaxIterations = value.round()),
                    ),
                  ),
                  Text('${step.evaluatorMaxIterations}'),
                ],
              ),
            ],
            if (earlierSteps.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: step.loopTargetId,
                decoration: InputDecoration(
                  labelText: step.kind == 'evaluator' ? 'Cierra ciclo hacia (obligatorio)' : 'Cierra ciclo hacia (opcional)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin ciclo')),
                  ...earlierSteps.asMap().entries.map(
                        (entry) => DropdownMenuItem(
                          value: entry.value.id,
                          child: Text('Paso ${entry.key + 1}: ${entry.value.label.isEmpty ? entry.value.agentId : entry.value.label}'),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => step.loopTargetId = value),
              ),
              if (step.loopTargetId != null && step.kind == 'agent') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Vueltas fijas'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        value: step.loopIterations.toDouble(),
                        min: 2,
                        max: 20,
                        divisions: 18,
                        label: '${step.loopIterations}',
                        onChanged: (value) => setState(() => step.loopIterations = value.round()),
                      ),
                    ),
                    Text('${step.loopIterations}'),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
