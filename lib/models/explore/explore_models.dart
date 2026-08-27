import '../../utils/i18n.dart';

class ExploreItem {
  const ExploreItem({required this.raw});

  final Map<String, dynamic> raw;

  String get resourceType => raw['resource_type'] as String? ?? 'unknown';
  String get resourceId => raw['resource_id'] as String? ?? '';
  String get ownerId => raw['owner'] as String? ?? '';
  String get ownerUsername => raw['owner_username'] as String? ?? '';
  String get name => raw['name'] as String? ?? tr('common.unnamed');
  String get description => raw['description'] as String? ?? '';
  String get category => raw['category'] as String? ?? '';

  /// El catálogo dice si ya existe una copia enlazada de esta fila. Antes esto
  /// solo se sabía dentro de la sesión, así que al recargar un recurso ya
  /// enlazado volvía a ofrecerse como nuevo.
  bool get linkedByMe => raw['linked_by_me'] == true;

  /// La estrella que este usuario ya puso sobre la fila. Mismo caso que
  /// `linkedByMe`: hasta que el catálogo empezó a mandarla, el icono aparecía
  /// apagado al recargar aunque la estrella siguiera guardada.
  bool get starred => raw['starred'] == true;

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

class ExploreOfficialPack {
  const ExploreOfficialPack({
    required this.sourceId,
    required this.name,
    required this.repositoryUrl,
    required this.counts,
    this.description = '',
    this.repositoryOwner = '',
    this.repositoryName = '',
    this.provider = 'github',
    this.license = '',
    this.commitSha = '',
    this.matchingCount = 0,
    this.totalCount = 0,
    this.linkedCount = 0,
    this.linkState = 'none',
    this.ownedByRequester = false,
  });

  factory ExploreOfficialPack.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    return ExploreOfficialPack(
      sourceId: json['source_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      repositoryUrl: json['repository_url']?.toString() ?? '',
      repositoryOwner: json['repository_owner']?.toString() ?? '',
      repositoryName: json['repository_name']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'github',
      license: json['license']?.toString() ?? '',
      commitSha: json['commit_sha']?.toString() ?? '',
      counts: rawCounts is Map
          ? rawCounts.map(
              (key, value) => MapEntry(key.toString(), _intValue(value)),
            )
          : const {},
      matchingCount: _intValue(json['matching_count']),
      totalCount: _intValue(json['total_count']),
      linkedCount: _intValue(json['linked_count']),
      linkState: json['link_state']?.toString() ?? 'none',
      ownedByRequester: json['owned_by_requester'] == true,
    );
  }

  final String sourceId;
  final String name;
  final String description;
  final String repositoryUrl;
  final String repositoryOwner;
  final String repositoryName;
  final String provider;
  final String license;
  final String commitSha;
  final Map<String, int> counts;
  final int matchingCount;
  final int totalCount;
  final int linkedCount;
  final String linkState;
  final bool ownedByRequester;

  bool get fullyLinked => linkState == 'complete';
}

class ExploreOfficialPackComponent {
  const ExploreOfficialPackComponent({
    required this.componentKey,
    required this.resourceType,
    required this.resourceId,
    required this.name,
    this.description = '',
    this.labels = const [],
    this.dependencies = const [],
    this.selectable = true,
    this.linked = false,
  });

  factory ExploreOfficialPackComponent.fromJson(Map<String, dynamic> json) =>
      ExploreOfficialPackComponent(
        componentKey: json['component_key']?.toString() ?? '',
        resourceType: json['resource_type']?.toString() ?? 'unknown',
        resourceId: json['resource_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        labels: _stringList(json['labels']),
        dependencies: _stringList(json['dependencies']),
        selectable: json['selectable'] != false,
        linked: json['linked'] == true,
      );

  final String componentKey;
  final String resourceType;
  final String resourceId;
  final String name;
  final String description;
  final List<String> labels;
  final List<String> dependencies;
  final bool selectable;
  final bool linked;
}

class ExploreOfficialPackDetail {
  const ExploreOfficialPackDetail({
    required this.pack,
    required this.components,
  });

  factory ExploreOfficialPackDetail.fromJson(Map<String, dynamic> json) =>
      ExploreOfficialPackDetail(
        pack: ExploreOfficialPack.fromJson(
          (json['pack'] as Map? ?? const {}).cast<String, dynamic>(),
        ),
        components: (json['components'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => ExploreOfficialPackComponent.fromJson(
                item.cast<String, dynamic>(),
              ),
            )
            .toList(),
      );

  final ExploreOfficialPack pack;
  final List<ExploreOfficialPackComponent> components;
}

class ExploreOfficialPackLinkResult {
  const ExploreOfficialPackLinkResult({
    required this.createdCount,
    required this.existingCount,
    required this.includedDependencies,
  });

  factory ExploreOfficialPackLinkResult.fromJson(Map<String, dynamic> json) =>
      ExploreOfficialPackLinkResult(
        createdCount: (json['created'] as List? ?? const []).length,
        existingCount: (json['existing'] as List? ?? const []).length,
        includedDependencies: _stringList(json['included_dependencies']),
      );

  final int createdCount;
  final int existingCount;
  final List<String> includedDependencies;
}

int _intValue(Object? value) => value is num ? value.toInt() : 0;

List<String> _stringList(Object? value) => (value as List? ?? const [])
    .map((item) => item.toString())
    .where((item) => item.isNotEmpty)
    .toList();

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
