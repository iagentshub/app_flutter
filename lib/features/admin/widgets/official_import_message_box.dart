import 'package:flutter/material.dart';

class OfficialImportMessageBox extends StatelessWidget {
  const OfficialImportMessageBox({
    required this.messages,
    required this.color,
    super.key,
  });

  final List<String> messages;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(messages.join('\n')),
  );
}
