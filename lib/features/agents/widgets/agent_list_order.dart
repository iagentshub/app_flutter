import '../../../models/agents/agent_models.dart';

enum AgentListOrder { original, name, nameDescending, usage }

/// Sort only a copy: pagination retains its source ordering and cursor.
List<AgentItem> orderAgents(List<AgentItem> items, AgentListOrder order) {
  if (order == AgentListOrder.original) return items;
  return [...items]..sort((a, b) {
    final result = switch (order) {
      AgentListOrder.original => 0,
      AgentListOrder.name => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      AgentListOrder.nameDescending => b.name.toLowerCase().compareTo(
        a.name.toLowerCase(),
      ),
      AgentListOrder.usage => (b.tokensIn + b.tokensOut).compareTo(
        a.tokensIn + a.tokensOut,
      ),
    };
    return result == 0 ? a.id.compareTo(b.id) : result;
  });
}
