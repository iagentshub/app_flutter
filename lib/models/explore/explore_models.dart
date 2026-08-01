class ExploreItem {
  const ExploreItem({required this.raw});

  final Map<String, dynamic> raw;

  String get resourceType => raw['resource_type'] as String? ?? 'unknown';
  String get resourceId => raw['resource_id'] as String? ?? '';
  String get ownerId => raw['owner'] as String? ?? '';
  String get ownerUsername => raw['owner_username'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get description => raw['description'] as String? ?? '';
  String get category => raw['category'] as String? ?? 'Other';

  int get stars {
    final value = raw['stars_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  List<String> get tags {
    final value = raw['tags'];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> get labels {
    final value = raw['labels'];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

class ExploreUserItem {
  const ExploreUserItem({required this.raw});

  final Map<String, dynamic> raw;

  String get username => raw['username'] as String? ?? '';

  /// Ruta relativa del avatar (p. ej. `/api/users/{username}/avatar`), o
  /// `null` si el usuario no tiene avatar subido.
  String? get avatarPath => raw['avatar_url'] as String?;

  int get followersCount => _asInt(raw['followers_count']);
  int get publicResourcesCount => _asInt(raw['public_resources_count']);

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
