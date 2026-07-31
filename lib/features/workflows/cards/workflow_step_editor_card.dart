part of '../pages/workflow_editor_page.dart';

extension _WorkflowStepEditorCard on _WorkflowEditorPageState {
  String _stepLabel(int index) {
    final step = _steps[index];
    final name = step.label.isNotEmpty ? step.label : step.agentId;
    final stepPrefix = _tx('workflow_editor.step_prefix', 'Paso');
    return '$stepPrefix ${index + 1}${name.isEmpty ? '' : ': $name'}';
  }

  Widget _buildStepCard(int index, {required Key key}) {
    final step = _steps[index];
    final otherSteps = [
      for (var i = 0; i < _steps.length; i++)
        if (i != index) i,
    ];
    final stepPrefix = _tx('workflow_editor.step_prefix', 'Paso');

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
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.tune, size: 20),
                ),
                Text(
                  '$stepPrefix ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                AppIconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _steps.length > 1
                      ? () => _removeStep(index)
                      : null,
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _agents.any((a) => a.id == step.agentId)
                  ? step.agentId
                  : null,
              decoration: InputDecoration(
                labelText: _tx('workflow_editor.agent_label', 'Agente'),
              ),
              items: _agents
                  .map(
                    (agent) => DropdownMenuItem(
                      value: agent.id,
                      child: Text(agent.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _refresh(() => step.agentId = value ?? ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: step.label,
              decoration: InputDecoration(
                labelText: _tx(
                  'workflow_editor.step_label_field',
                  'Etiqueta (opcional)',
                ),
              ),
              onChanged: (value) => step.label = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: step.instruction,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: _tx(
                  'workflow_editor.instruction_label',
                  'Instrucción para este paso',
                ),
              ),
              onChanged: (value) => step.instruction = value,
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'agent',
                  label: Text(_tx('workflow_editor.kind_agent', 'Agente')),
                ),
                ButtonSegment(
                  value: 'evaluator',
                  label: Text(
                    _tx('workflow_editor.kind_evaluator', 'Evaluador'),
                  ),
                ),
              ],
              selected: {step.kind},
              onSelectionChanged: (selection) => _refresh(() {
                step.kind = selection.first;
                if (step.kind == 'agent') step.evaluatorCondition = '';
              }),
            ),
            if (step.kind == 'evaluator') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: step.evaluatorCondition,
                decoration: InputDecoration(
                  labelText: _tx(
                    'workflow_editor.evaluator_condition_label',
                    'Condición de evaluación',
                  ),
                ),
                onChanged: (value) => step.evaluatorCondition = value,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _tx('workflow_editor.max_iterations_label', 'Máx. vueltas'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      value: step.evaluatorMaxIterations.toDouble(),
                      min: 2,
                      max: 20,
                      divisions: 18,
                      label: '${step.evaluatorMaxIterations}',
                      onChanged: (value) => _refresh(
                        () => step.evaluatorMaxIterations = value.round(),
                      ),
                    ),
                  ),
                  Text('${step.evaluatorMaxIterations}'),
                ],
              ),
            ],
            if (otherSteps.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _tx('workflow_editor.continue_to_label', 'Continúa hacia'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final otherIndex in otherSteps)
                    FilterChip(
                      label: Text(_stepLabel(otherIndex)),
                      selected: step.nextStepIds.contains(
                        _steps[otherIndex].id,
                      ),
                      onSelected: (selected) => _refresh(() {
                        final targetId = _steps[otherIndex].id;
                        if (selected) {
                          step.nextStepIds.add(targetId);
                        } else {
                          step.nextStepIds.remove(targetId);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: step.loopTargetId,
                decoration: InputDecoration(
                  labelText: step.kind == 'evaluator'
                      ? _tx(
                          'workflow_editor.loop_target_required',
                          'Cierra ciclo hacia (obligatorio)',
                        )
                      : _tx(
                          'workflow_editor.loop_target_optional',
                          'Cierra ciclo hacia (opcional)',
                        ),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(_tx('workflow_editor.no_loop', 'Sin ciclo')),
                  ),
                  for (final otherIndex in otherSteps)
                    DropdownMenuItem(
                      value: _steps[otherIndex].id,
                      child: Text(_stepLabel(otherIndex)),
                    ),
                ],
                onChanged: (value) => _refresh(() => step.loopTargetId = value),
              ),
              if (step.loopTargetId != null && step.kind == 'agent') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      _tx(
                        'workflow_editor.fixed_iterations_label',
                        'Vueltas fijas',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        value: step.loopIterations.toDouble(),
                        min: 2,
                        max: 20,
                        divisions: 18,
                        label: '${step.loopIterations}',
                        onChanged: (value) =>
                            _refresh(() => step.loopIterations = value.round()),
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
