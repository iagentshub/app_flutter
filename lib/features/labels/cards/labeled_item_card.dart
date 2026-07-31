import 'package:flutter/material.dart';

import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../models/labeled_item.dart';

class LabeledItemCard extends StatelessWidget {
  const LabeledItemCard({
    required this.item,
    required this.typeLabel,
    required this.ownerLabel,
    required this.linkedLabel,
    required this.onTap,
    super.key,
  });

  final LabeledItem item;
  final String typeLabel;
  final String ownerLabel;
  final String linkedLabel;
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
              Text(typeLabel, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              LabelChipsRow(
                labels: item.labels,
                leading: [
                  OriginBadge(
                    shared: item.shared,
                    ownerLabel: ownerLabel,
                    linkedLabel: linkedLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
