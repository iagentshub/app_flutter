import '../../../models/common/resource_item.dart';

class LabeledItem {
  const LabeledItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.labels,
    required this.shared,
  });

  /// Construye un LabeledItem desde cualquier recurso (agente, skill, workflow…).
  /// `type` es el resource_type canónico ('agent', 'skill', 'workflow'…).
  factory LabeledItem.fromResource(ResourceItem resource, String type) {
    return LabeledItem(
      id: resource.id,
      name: resource.name,
      description: resource.description,
      type: type,
      labels: resource.labels,
      shared: resource.shared,
    );
  }

  final String id;
  final String name;
  final String description;
  final String type;
  final List<String> labels;
  final bool shared;
}
