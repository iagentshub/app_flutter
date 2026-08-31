enum AdminResourceType {
  user('user'),
  group('group'),
  agent('agent'),
  connection('connection'),
  knowledge('knowledge'),
  workflow('workflow'),
  llmOrchestration('llm_orchestration'),
  skill('skill'),
  memory('memory'),
  prompt('prompt'),
  tool('tool');

  const AdminResourceType(this.wireName);

  final String wireName;

  static AdminResourceType? fromWireName(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

class AdminExploreItem {
  const AdminExploreItem({required this.type, required this.data});

  final AdminResourceType type;
  final Map<String, dynamic> data;

  String get id => (data['id'] ?? '').toString();

  factory AdminExploreItem.fromJson(Map<String, dynamic> json) {
    final type = AdminResourceType.fromWireName(
      (json['resource_type'] ?? '').toString(),
    );
    if (type == null) {
      throw const FormatException('Unknown admin resource type');
    }
    return AdminExploreItem(type: type, data: Map<String, dynamic>.from(json));
  }
}

class AdminExploreResult {
  const AdminExploreResult({
    required this.items,
    required this.total,
    required this.counts,
    required this.hasMore,
    this.nextCursor,
  });

  final List<AdminExploreItem> items;
  final int total;
  final Map<AdminResourceType, int> counts;
  final bool hasMore;
  final String? nextCursor;

  factory AdminExploreResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(AdminExploreItem.fromJson)
              .toList(growable: false)
        : const <AdminExploreItem>[];
    final rawCounts = json['counts'];
    final counts = <AdminResourceType, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final type = AdminResourceType.fromWireName(entry.key.toString());
        final value = entry.value;
        if (type != null && value is num) counts[type] = value.toInt();
      }
    }
    final rawPage = json['page'];
    final page = rawPage is Map<String, dynamic>
        ? rawPage
        : const <String, dynamic>{};
    final rawTotal = page['total'] ?? json['total'];
    return AdminExploreResult(
      items: items,
      total: rawTotal is num ? rawTotal.toInt() : items.length,
      counts: counts,
      hasMore: page['has_more'] == true,
      nextCursor: page['next_cursor']?.toString(),
    );
  }
}
