class ExploreItem {
  const ExploreItem({required this.raw});

  final Map<String, dynamic> raw;

  String get resourceType => raw['resource_type'] as String? ?? 'unknown';
  String get resourceId => raw['resource_id'] as String? ?? '';
  String get ownerId => raw['owner'] as String? ?? '';
  String get ownerUsername => raw['owner_username'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get description => raw['description'] as String? ?? '';
  String get category => raw['category'] as String? ?? '';
  bool get isOfficial => raw['is_official'] == true;
  bool get hubInstallable => raw['hub_installable'] == true;
  String get officialPackageId => raw['official_package_id']?.toString() ?? '';
  String get officialPackageName =>
      raw['official_package_name']?.toString() ?? '';
  String get officialComponentId =>
      raw['official_component_id']?.toString() ?? '';
  String get officialVersion => raw['official_version']?.toString() ?? '';
  String get officialLicense => raw['official_license']?.toString() ?? '';
  String get officialRepositoryUrl =>
      raw['official_repository_url']?.toString() ?? '';

  List<ExploreDependency> get dependencies {
    final value = raw['dependencies'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => ExploreDependency(raw: item.cast<String, dynamic>()))
        .toList();
  }

  List<String> get directDependencyIds =>
      (raw['direct_dependency_ids'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();

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

  List<String> get languages {
    final value = raw['languages'];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return labels
        .where((label) => label.startsWith('lang_'))
        .map((label) => label.substring('lang_'.length))
        .toList();
  }
}

class ExploreDependency {
  const ExploreDependency({required this.raw});

  final Map<String, dynamic> raw;

  String get componentId => raw['component_id']?.toString() ?? '';
  String get name => raw['name']?.toString() ?? '';
  String get type => raw['component_type']?.toString() ?? 'unknown';
  List<String> get dependencies => (raw['dependencies'] as List? ?? const [])
      .map((item) => item.toString())
      .toList();
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
