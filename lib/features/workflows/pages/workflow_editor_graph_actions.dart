part of 'workflow_editor_page.dart';

/// Mutaciones del grafo que dispara el editor: añadir, borrar, mover y
/// conectar pasos, más las reglas que deciden qué conexiones se permiten.
///
/// Vive aparte para que la página se quede como coordinadora y no vuelva a
/// pasarse del límite que impone `test/feature_architecture_test.dart`.
extension _WorkflowEditorGraphActions on _WorkflowEditorPageState {
  // ── Mutaciones del grafo ───────────────────────────────────────────────────

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
      // Sin esto el nodo nuevo caía en la rejilla por índice y podía aparecer
      // encima de otro que el usuario ya había movido a mano.
      final position = layeredLayout(_steps)[newStep.id];
      newStep.positionX = position?.dx;
      newStep.positionY = position?.dy;
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
    final step = _steps.byId(stepId);
    if (step == null) return;
    step.positionX = position.dx;
    step.positionY = position.dy;
  }

  void _createConnection(String sourceId, String targetId, String type) {
    _refresh(() {
      final source = _steps.byId(sourceId);
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
      final source = _steps.byId(sourceId);
      if (source == null) return;
      if (type == 'loop') {
        if (source.loopTargetId == targetId) source.loopTargetId = null;
      } else {
        source.nextStepIds.remove(targetId);
      }
    });
  }

  /// Una conexión de secuencia solo vale si no crea un ciclo hacia atrás.
  ///
  /// Lo usan tanto el arrastre en el lienzo como los chips "Continúa hacia",
  /// para que ambos caminos acepten exactamente lo mismo.
  bool _canCreateConnection(String sourceId, String targetId) {
    if (sourceId == targetId) return false;
    final source = _steps.byId(sourceId);
    if (source == null || source.nextStepIds.contains(targetId)) return false;

    final pending = <String>[targetId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      if (current == sourceId) return false;
      final step = _steps.byId(current);
      if (step != null) pending.addAll(step.nextStepIds);
    }
    return true;
  }

  /// Pasos a los que [stepId] puede cerrar un ciclo: solo los que están antes
  /// en el flujo, porque `workflow_validator.py` exige que el ciclo vuelva
  /// hacia atrás.
  List<WorkflowStepDraft> _loopTargetsFor(String stepId) {
    final ancestors = <String>{};
    final pending = <String>[stepId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      for (final step in _steps) {
        if (!step.nextStepIds.contains(current)) continue;
        ancestors.add(step.id);
        pending.add(step.id);
      }
    }
    return [
      for (final step in _steps)
        if (ancestors.contains(step.id)) step,
    ];
  }
}
