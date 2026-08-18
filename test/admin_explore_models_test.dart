import 'package:app_flutter/models/admin/admin_explore_models.dart';
import 'package:app_flutter/shared/graph/resource_graph_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the discriminated admin inventory and its counters', () {
    final result = AdminExploreResult.fromJson({
      'items': [
        {'resource_type': 'agent', 'id': 'agent-1', 'name': 'Researcher'},
        {'resource_type': 'user', 'id': 'user-1', 'username': 'andres'},
      ],
      'total': 2,
      'counts': {'agent': 1, 'user': 1, 'group': 0},
    });

    expect(result.total, 2);
    expect(result.items.first.type, AdminResourceType.agent);
    expect(result.items.first.id, 'agent-1');
    expect(result.counts[AdminResourceType.user], 1);
    expect(result.counts[AdminResourceType.group], 0);
  });

  test('rejects inventory entries without a supported resource type', () {
    expect(
      () => AdminExploreItem.fromJson({
        'resource_type': 'folder',
        'id': 'legacy',
      }),
      throwsFormatException,
    );
  });

  test('arma el grafo de admin desde las relaciones del backend', () {
    final graph = fromRelations({
      'root': {
        'type': 'agent',
        'id': 'agent-1',
        'label': 'Researcher',
        'description': 'Root',
      },
      'items': [
        {
          'type': 'connection',
          'id': 'connection-1',
          'label': 'OpenAI',
          'relation': 'uses',
          'via': null,
        },
      ],
    });

    expect(graph.rootId, 'agent:agent-1');
    expect(graph.nodes, hasLength(2));
    expect(graph.edges.single.targetId, 'connection:connection-1');
  });
}
