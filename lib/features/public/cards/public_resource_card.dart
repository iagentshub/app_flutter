import 'package:flutter/material.dart';

import '../../../models/explore/explore_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';

class PublicResourceCard extends StatelessWidget {
  const PublicResourceCard({
    required this.item,
    required this.previewTooltip,
    required this.onPreview,
    super.key,
  });

  final ExploreItem item;
  final String previewTooltip;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(item.name),
        subtitle: Row(
          children: [
            Text(
              '${item.resourceType} · ${item.category}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 10),
            Icon(Icons.star, size: 13, color: Colors.amber.shade600),
            const SizedBox(width: 3),
            Text('${item.stars}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: ActionIconButton(
          icon: Icons.visibility_outlined,
          tooltip: previewTooltip,
          onPressed: onPreview,
        ),
      ),
    );
  }
}
