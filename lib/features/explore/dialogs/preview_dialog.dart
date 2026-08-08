part of '../pages/explore_page.dart';

class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({
    required this.title,
    required this.jsonPayload,
    required this.tx,
  });

  final String title;
  final Map<String, dynamic> jsonPayload;
  final String Function(String path, String fallback) tx;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonPayload);
    return AlertDialog(
      title: Text(
        tx(
          'explore.preview_dialog_title',
          'Preview: {{title}}',
        ).replaceAll('{{title}}', title),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 760),
        child: SingleChildScrollView(
          child: SelectableText(pretty, style: FncFonts.code),
        ),
      ),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.close', 'Cerrar')),
        ),
      ],
    );
  }
}
