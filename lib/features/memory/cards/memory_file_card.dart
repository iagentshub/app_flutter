import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../models/memory/memory_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';

class MemoryFileCard extends StatelessWidget {
  const MemoryFileCard({
    required this.file,
    required this.sizeLabel,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final MemoryFileItem file;
  final String sizeLabel;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.filename,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$sizeLabel: ${file.size} chars'
              '${file.updatedAt.isEmpty ? '' : ' · ${file.updatedAt}'}',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: editTooltip,
                  onPressed: onEdit,
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: deleteTooltip,
                  danger: true,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
