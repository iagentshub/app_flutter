part of '../pages/knowledge_page.dart';

Future<Set<String>?> _showContentLanguageDialog(
  BuildContext context, {
  required String Function(String path, String fallback) tx,
  Set<String> initial = const {},
}) {
  var selected = Set<String>.of(initial);
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          tx('knowledge.document_language_title', 'Idioma del documento'),
        ),
        content: SizedBox(
          width: dialogContentWidth(context, 420),
          child: GroupedLabelPicker(
            selected: selected,
            onChanged: (next) => setDialogState(() => selected = next),
            tx: tx,
            groups: const [kLanguageLabelGroup],
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: Text(tx('common.continue', 'Continuar')),
          ),
        ],
      ),
    ),
  );
}
