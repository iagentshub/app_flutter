import '../../shared/graph/graph_models.dart';

enum AdminResourceType {
  user('user'),
  group('group'),
  agent('agent'),
  connection('connection'),
  knowledge('knowledge'),
  workflow('workflow'),
  skill('skill');

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
      throw FormatException('Unknown admin resource type');
    }
    return AdminExploreItem(type: type, data: Map<String, dynamic>.from(json));
  }
}

class AdminExploreResult {
  const AdminExploreResult({
    required this.items,
    required this.total,
    required this.counts,
  });

  final List<AdminExploreItem> items;
  final int total;
  final Map<AdminResourceType, int> counts;

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
    final rawTotal = json['total'];
    return AdminExploreResult(
      items: items,
      total: rawTotal is num ? rawTotal.toInt() : items.length,
      counts: counts,
    );
  }
}

class AdminResourceGraph {
  const AdminResourceGraph({
    required this.rootId,
    required this.nodes,
    required this.edges,
  });

  final String rootId;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  factory AdminResourceGraph.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'];
    final rawEdges = json['edges'];
    return AdminResourceGraph(
      rootId: (json['root_id'] ?? '').toString(),
      nodes: rawNodes is List
          ? rawNodes
                .whereType<Map<String, dynamic>>()
                .map((node) {
                  return GraphNode(
                    id: (node['id'] ?? '').toString(),
                    label: (node['label'] ?? '').toString(),
                    type: (node['type'] ?? '').toString(),
                    description: (node['description'] ?? '').toString(),
                  );
                })
                .toList(growable: false)
          : const [],
      edges: rawEdges is List
          ? rawEdges
                .whereType<Map<String, dynamic>>()
                .map((edge) {
                  return GraphEdge(
                    sourceId: (edge['source_id'] ?? '').toString(),
                    targetId: (edge['target_id'] ?? '').toString(),
                    dashed: edge['dashed'] == true,
                  );
                })
                .toList(growable: false)
          : const [],
    );
  }
}
