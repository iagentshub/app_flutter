class LabeledItem {
  const LabeledItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.labels,
    required this.shared,
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final List<String> labels;
  final bool shared;
}
