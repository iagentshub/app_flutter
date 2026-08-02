import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';

/// Pide el input inicial antes de lanzar una orquestación.
class RunWorkflowDialog extends StatefulWidget {
  const RunWorkflowDialog({
    required this.workflowName,
    required this.tx,
    super.key,
  });

  final String workflowName;
  final String Function(String path, String fallback) tx;

  @override
  State<RunWorkflowDialog> createState() => _RunWorkflowDialogState();
}

class _RunWorkflowDialogState extends State<RunWorkflowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_inputController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget
            .tx('workflows.run_dialog_title', 'Ejecutar: {{name}}')
            .replaceAll('{{name}}', widget.workflowName),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 640),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _inputController,
            minLines: 5,
            maxLines: 10,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.tx(
                'workflows.run_input_label',
                'Input inicial',
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return widget.tx(
                  'workflows.run_input_required',
                  'Input obligatorio',
                );
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _submit,
          child: Text(widget.tx('workflows.run_btn', 'Ejecutar')),
        ),
      ],
    );
  }
}
