class DashboardFeedItem {
  const DashboardFeedItem({
    required this.resourceType,
    required this.resourceId,
    required this.name,
    required this.ownerUsername,
    required this.starred,
  });

  factory DashboardFeedItem.fromJson(Map<String, dynamic> json) {
    return DashboardFeedItem(
      resourceType: json['resource_type']?.toString() ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ownerUsername: json['owner_username']?.toString() ?? '',
      starred: json['starred'] == true,
    );
  }

  final String resourceType;
  final String resourceId;
  final String name;
  final String ownerUsername;
  final bool starred;

  String get key => '$resourceType:$resourceId';
  bool get canToggleFavorite =>
      resourceType.isNotEmpty && resourceId.isNotEmpty;
}
