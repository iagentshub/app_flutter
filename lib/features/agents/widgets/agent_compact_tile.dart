import 'package:flutter/material.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_motion.dart';

/// Compact overview; expanding keeps every action from the original card.
class AgentCompactTile extends StatelessWidget {
  const AgentCompactTile({
    required this.item,
    required this.details,
    required this.chatLabel,
    required this.inactiveLabel,
    required this.onChat,
    super.key,
  });

  final AgentItem item;
  final Widget details;
  final String chatLabel;
  final String inactiveLabel;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey('agent-compact-${item.id}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      expansionAnimationStyle: AnimationStyle(
        duration: AppMotion.reduced(context)
            ? Duration.zero
            : AppMotion.section,
      ),
      leading: AppIconButton(
        onPressed: onChat,
        tooltip: chatLabel,
        icon: const Icon(Icons.chat_bubble_outline),
      ),
      title: Text(
        item.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        [
          if (!item.isActive) inactiveLabel,
          item.agentType,
          if (item.model.isNotEmpty) item.model,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      children: [details],
    ),
  );
}
