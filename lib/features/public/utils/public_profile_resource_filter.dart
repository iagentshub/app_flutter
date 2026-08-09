import '../../../models/explore/explore_models.dart';

List<ExploreItem> filterPublicProfileResources(
  Iterable<ExploreItem> resources, {
  required String query,
  required Set<String> selectedTypes,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return resources
      .where((item) {
        if (selectedTypes.isNotEmpty &&
            !selectedTypes.contains(item.resourceType)) {
          return false;
        }
        if (normalizedQuery.isEmpty) return true;
        final searchable = [
          item.name,
          item.description,
          item.category,
          ...item.tags,
          ...item.labels,
        ].join(' ').toLowerCase();
        return searchable.contains(normalizedQuery);
      })
      .toList(growable: false);
}
