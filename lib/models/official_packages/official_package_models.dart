class OfficialPackageItem {
  const OfficialPackageItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id']?.toString() ?? '';
  String get name => raw['name']?.toString() ?? '';
  String get description => raw['description']?.toString() ?? '';
  String get repositoryUrl => raw['repository_url']?.toString() ?? '';
  String get license => raw['license']?.toString() ?? '';
  String get publishedVersion => raw['published_version']?.toString() ?? '';
  String get latestCheckedAt => raw['latest_checked_at']?.toString() ?? '';
  bool get isOfficial => raw['is_official'] == true;
}

class OfficialPackageDetail extends OfficialPackageItem {
  const OfficialPackageDetail({required super.raw});

  Map<String, dynamic> get version =>
      (raw['version'] as Map?)?.cast<String, dynamic>() ?? const {};

  List<OfficialPackageComponent> get components {
    final value = version['components'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => OfficialPackageComponent(raw: item.cast<String, dynamic>()),
        )
        .toList();
  }
}

class OfficialPackageComponent {
  const OfficialPackageComponent({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['component_id']?.toString() ?? '';
  String get name => raw['name']?.toString() ?? '';
  String get description => raw['description']?.toString() ?? '';
  String get type => raw['component_type']?.toString() ?? '';
  String get sourcePath => raw['source_path']?.toString() ?? '';
  List<String> get targets => (raw['targets'] as List? ?? const [])
      .map((item) => item.toString())
      .toList();
}

class OfficialPackageCopy {
  const OfficialPackageCopy({required this.raw});

  final Map<String, dynamic> raw;

  String get name => raw['name']?.toString() ?? '';
  String get packageName => raw['source_package_name']?.toString() ?? '';
  String get sourceVersion => raw['source_version']?.toString() ?? '';
  String get status => raw['status']?.toString() ?? 'Sin cambios';
  bool get isOfficial => raw['is_official'] == true;
}
