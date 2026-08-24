import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/token_usage_badge.dart';

/// Panel lateral con el listado de conversaciones del chat: botón de nueva
/// conversación y la lista con selección/borrado. Extraído de `ChatPage`
/// para mantenerla dentro del límite de líneas de
/// `feature_architecture_test.dart`.
class ChatHistoryPanel extends StatelessWidget {
  const ChatHistoryPanel({
    required this.conversations,
    required this.activeConversationId,
    required this.loading,
    required this.onNewConversation,
    required this.onSelectConversation,
    required this.onDeleteConversation,
    required this.newConversationLabel,
    required this.untitledConversationLabel,
    required this.tokensTooltip,
    required this.deleteTooltip,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    super.key,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final bool loading;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<String> onDeleteConversation;
  final String newConversationLabel;
  final String untitledConversationLabel;
  final String tokensTooltip;
  final String deleteTooltip;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: PrimaryButton.icon(
            onPressed: onNewConversation,
            icon: const Icon(Icons.add),
            label: Text(newConversationLabel),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: IAgentsLoadingMark()),
          )
        else
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (hasMore && notification.metrics.extentAfter < 200) {
                  onLoadMore();
                }
                return false;
              },
              child: ListView.builder(
                itemCount: conversations.length + (loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == conversations.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: IAgentsLoadingMark()),
                    );
                  }
                  final item = conversations[index];
                  final active = item.id == activeConversationId;
                  return ListTile(
                    selected: active,
                    dense: true,
                    title: Text(
                      item.title.isEmpty
                          ? untitledConversationLabel
                          : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item.tokensIn + item.tokensOut > 0
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TokenUsageBadge(
                              tokensIn: item.tokensIn,
                              tokensOut: item.tokensOut,
                              tooltip: tokensTooltip,
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).maybePop();
                      onSelectConversation(item.id);
                    },
                    trailing: AppIconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: deleteTooltip,
                      onPressed: () => onDeleteConversation(item.id),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
