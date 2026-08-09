import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../controllers/workflow_runs_controller.dart';
import '../models/workflow_run.dart';

class WorkflowRunsButton extends StatelessWidget {
  const WorkflowRunsButton({
    required this.controller,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final WorkflowRunsController controller;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Badge(
      isLabelVisible: controller.activeCount > 0,
      label: Text('${controller.activeCount}'),
      child: AppIconButton.outlined(
        onPressed: onPressed,
        icon: const Icon(Icons.motion_photos_on_outlined),
        tooltip: tooltip,
      ),
    ),
  );
}

class WorkflowRunsPanel extends StatelessWidget {
  const WorkflowRunsPanel({
    required this.controller,
    required this.onOpen,
    required this.tx,
    super.key,
  });

  final WorkflowRunsController controller;
  final ValueChanged<WorkflowRun> onOpen;
  final String Function(String path, String fallback) tx;

  String _status(WorkflowRun run) => switch (run.status) {
    'queued' => tx('workflows.run_status_queued', 'En cola'),
    'running' => tx('workflows.run_status_running', 'En curso'),
    'cancelling' => tx('workflows.run_cancelling', 'Cancelando…'),
    'cancelled' => tx('workflows.run_cancelled', 'Cancelada'),
    'completed' => tx('workflows.run_status_done', 'Completada'),
    _ => tx('workflows.run_status_error', 'Error'),
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tx('workflows.run_history_title', 'Ejecuciones')),
    content: SizedBox(
      width: 620,
      height: 520,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final runs = controller.runs;
          if (runs.isEmpty) {
            return Center(
              child: Text(
                tx(
                  'workflows.run_history_empty',
                  'Todavía no hay ejecuciones.',
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              itemCount: runs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final run = runs[index];
                final progress = run.totalSteps == 0
                    ? ''
                    : ' · ${run.completedSteps}/${run.totalSteps}';
                return ListTile(
                  leading: Icon(
                    run.active
                        ? Icons.motion_photos_on_outlined
                        : run.status == 'completed'
                        ? Icons.check_circle_outline
                        : run.status == 'cancelled'
                        ? Icons.cancel_outlined
                        : Icons.error_outline,
                  ),
                  title: Text(run.workflowName),
                  subtitle: Text('${_status(run)}$progress'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpen(run),
                );
              },
            ),
          );
        },
      ),
    ),
    actions: [
      TertiaryButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(tx('common.close', 'Cerrar')),
      ),
    ],
  );
}
