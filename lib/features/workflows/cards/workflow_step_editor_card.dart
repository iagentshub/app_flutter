part of '../pages/workflow_editor_page.dart';

extension _WorkflowStepEditorCard on _WorkflowEditorPageState {
  String _stepLabel(int index) {
    final step = _steps[index];
    final name = step.label.isNotEmpty ? step.label : step.agentId;
    final stepPrefix = _tx('workflow_editor.step_prefix', 'Paso');
    return '$stepPrefix ${index + 1}${name.isEmpty ? '' : ': $name'}';
  }

  /// Chip de "Continúa hacia" que respeta las mismas reglas que el lienzo.
  ///
  /// Antes escribía directo en `nextStepIds`, así que por aquí se podían crear
  /// ciclos que arrastrando en el lienzo estaban prohibidos.
  Widget _connectionChip(WorkflowStepDraft step, int otherIndex) {
    final targetId = _steps[otherIndex].id;
    final selected = step.nextStepIds.contains(targetId);
    final allowed = selected || _canCreateConnection(step.id, targetId);
    final chip = FilterChip(
      label: Text(_stepLabel(otherIndex)),
      selected: selected,
      onSelected: allowed
          ? (value) => _refresh(() {
              if (value) {
                step.nextStepIds.add(targetId);
              } else {
                step.nextStepIds.remove(targetId);
              }
            })
          : null,
    );
    if (allowed) return chip;
    return Tooltip(
      message: _tx(
        'workflow_editor.invalid_connection',
        'La conexión crearía un ciclo o ya existe',
      ),
      child: chip,
    );
  }

  Widget _buildStepCard(int index, {required Key key}) {
    final step = _steps[index];
    final otherSteps = [
      for (var i = 0; i < _steps.length; i++)
        if (i != index) i,
    ];
    final loopTargets = _loopTargetsFor(step.id);
    final loopTargetId = step.loopTargetId;
    final stepPrefix = _tx('workflow_editor.step_prefix', 'Paso');

    return Container(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
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
                tooltip: _tx('common.actions.delete', 'Eliminar'),
                onPressed: _steps.length > 1 ? () => _removeStep(index) : null,
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
            maxLength: maxLabelLength,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            decoration: InputDecoration(
              labelText: _tx(
                'workflow_editor.step_label_field',
                'Etiqueta (opcional)',
              ),
            ),
            onChanged: (value) => _refresh(() => step.label = value),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: step.instruction,
            minLines: 2,
            maxLines: 5,
            maxLength: maxInstructionLength,
            decoration: InputDecoration(
              labelText: _tx(
                'workflow_editor.instruction_label',
                'Instrucción para este paso',
              ),
            ),
            onChanged: (value) => _refresh(() => step.instruction = value),
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
                label: Text(_tx('workflow_editor.kind_evaluator', 'Evaluador')),
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
              maxLength: maxConditionLength,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: InputDecoration(
                labelText: _tx(
                  'workflow_editor.evaluator_condition_label',
                  'Condición de evaluación',
                ),
              ),
              // Sin _refresh el problema "necesita una condición" seguía
              // listado aunque ya la hubieras escrito.
              onChanged: (value) =>
                  _refresh(() => step.evaluatorCondition = value),
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
                  _connectionChip(step, otherIndex),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: loopTargets.any((item) => item.id == loopTargetId)
                  ? loopTargetId
                  : null,
              decoration: InputDecoration(
                labelText: step.isEvaluator
                    ? _tx(
                        'workflow_editor.loop_target_required',
                        'Cierra ciclo hacia (obligatorio)',
                      )
                    : _tx(
                        'workflow_editor.loop_target_optional',
                        'Cierra ciclo hacia (opcional)',
                      ),
                helperText: loopTargets.isEmpty
                    ? _tx(
                        'workflow_editor.loop_needs_ancestor',
                        'Un ciclo solo puede volver a un paso anterior del flujo',
                      )
                    : null,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(_tx('workflow_editor.no_loop', 'Sin ciclo')),
                ),
                // Solo los pasos anteriores: el backend rechaza un ciclo que
                // salte hacia delante (workflow_validator.py:211-214).
                for (final target in loopTargets)
                  DropdownMenuItem(
                    value: target.id,
                    child: Text(_stepLabel(_steps.indexOf(target))),
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
    );
  }
}
