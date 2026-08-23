part of '../pages/knowledge_page.dart';

Future<Set<String>?> _showContentLabelsDialog(
  BuildContext context, {
  required String Function(String path) tx,
  Set<String> initial = const {'private'},
}) {
  var selected = Set<String>.of(initial);
  return showAppDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(tx('knowledge.document_labels_title')),
        content: SizedBox(
          width: dialogContentWidth(context, 420),
          child: GroupedLabelPicker(
            selected: selected,
            onChanged: (next) => setDialogState(() => selected = next),
            tx: tx,
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tx('common.cancel')),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: Text(tx('common.continue')),
          ),
        ],
      ),
    ),
  );
}
