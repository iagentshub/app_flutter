import 'package:flutter/material.dart';

import '../models/workflow_graph_validation.dart';

/// Lista los problemas que impiden guardar, cada uno clicable para saltar al
/// nodo culpable.
///
/// Sustituye al `SnackBar` que solo mostraba el primer error y desaparecía, y
/// al 422 del backend que llegaba cuando el editor ya estaba cerrado.
class WorkflowIssuesPanel extends StatelessWidget {
  const WorkflowIssuesPanel({
    required this.issues,
    required this.onSelectNode,
    required this.title,
    required this.translate,
    super.key,
  });

  final List<WorkflowIssue> issues;
  final ValueChanged<String> onSelectNode;
  final String title;

  /// Traduce la clave i18n del problema; recibe también el texto por defecto.
  final String Function(String key, String fallback) translate;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_outlined, size: 18, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.replaceAll('{{n}}', '${issues.length}'),
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 132),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: issues.length,
              itemBuilder: (context, index) {
                final issue = issues[index];
                final message = issue.render(
                  translate(issue.key, issue.fallback),
                );
                final nodeId = issue.nodeId;
                return InkWell(
                  onTap: nodeId == null ? null : () => onSelectNode(nodeId),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 8),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: colors.error,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            message,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(height: 1.4),
                          ),
                        ),
                        if (nodeId != null)
                          Icon(
                            Icons.my_location_rounded,
                            size: 15,
                            color: colors.error.withValues(alpha: .75),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
