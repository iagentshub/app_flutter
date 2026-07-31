import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/filter_button.dart';

Future<void> showLabelsFilterDialog(
  BuildContext context, {
  required String title,
  required String clearLabel,
  required String closeLabel,
  required String typeLabel,
  required String selectedType,
  required List<DropdownMenuItem<String>> typeOptions,
  required ValueChanged<String> onTypeChanged,
  required VoidCallback onClear,
}) {
  return showFilterDialog(
    context,
    title: title,
    clearLabel: clearLabel,
    closeLabel: closeLabel,
    onClear: onClear,
    buildFields: (setDialogState) => [
      DropdownButtonFormField<String>(
        initialValue: selectedType,
        decoration: InputDecoration(labelText: typeLabel),
        items: typeOptions,
        onChanged: (value) {
          if (value == null) return;
          onTypeChanged(value);
          setDialogState(() {});
        },
      ),
    ],
  );
}
