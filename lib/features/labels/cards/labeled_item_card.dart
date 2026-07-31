import 'package:flutter/material.dart';

import '../../../shared/widgets/label_chips_row.dart';
import '../models/labeled_item.dart';

class LabeledItemCard extends StatelessWidget {
  const LabeledItemCard({
    required this.item,
    required this.typeLabel,
    required this.sharedLabel,
    required this.onTap,
    super.key,
  });

  final LabeledItem item;
  final String typeLabel;
  final String sharedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(typeLabel, style: Theme.of(context).textTheme.bodySmall),
                  if (item.shared) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· $sharedLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              if (item.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                LabelChipsRow(labels: item.labels),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
