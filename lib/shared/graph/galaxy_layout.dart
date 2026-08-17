import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'graph_models.dart';

/// Geometría determinista de las constelaciones del modo galaxia.
///
/// Los centros se calculan solo a partir del tipo de nodo y el tamaño del
/// lienzo. La simulación de fuerzas puede atraer cada nodo hacia su centro sin
/// convertir esos centros virtuales en nodos o alterar el modelo del grafo.
abstract final class GalaxyLayout {
  static const knownTypes = <String>{
    'agent',
    'skill',
    'prompt',
    'tool',
    'knowledge',
    'connection',
    'provider',
    'official_source',
    'memory',
    'workflow',
    'evaluator',
  };

  static String constellationKey(String type) =>
      knownTypes.contains(type) ? type : 'other';

  static Map<String, Offset> centersFor({
    required List<GraphNode> nodes,
    required String rootId,
    required Size canvasSize,
  }) {
    final keys = <String>{
      for (final node in nodes)
        if (node.id != rootId) constellationKey(node.type),
    }.toList()..sort();
    if (keys.isEmpty) return const {};

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final orbit = math.min(canvasSize.width, canvasSize.height) * 0.265;
    const startAngle = -math.pi / 2;
    return {
      for (var i = 0; i < keys.length; i++)
        keys[i]:
            center +
            Offset.fromDirection(
              startAngle + (2 * math.pi * i / keys.length),
              orbit,
            ),
    };
  }
}
