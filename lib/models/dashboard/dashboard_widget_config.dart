const kDashboardWidgetIds = [
  'summary',
  'token-usage',
  'conn-status',
  'recent',
  'activity',
  'composition',
  'feed',
];

const kDefaultDashboardLayout = ['summary', 'token-usage', 'conn-status', 'recent'];

const kSummaryItems = ['agents', 'connections', 'skills', 'memory', 'knowledge', 'workflows'];
const kFeedTypes = ['agent', 'skill', 'knowledge'];

String dashboardWidgetTitle(String id) {
  switch (id) {
    case 'summary':
      return 'Resumen';
    case 'token-usage':
      return 'Uso de tokens';
    case 'conn-status':
      return 'Estado de conexiones';
    case 'recent':
      return 'Agentes recientes';
    case 'activity':
      return 'Actividad';
    case 'composition':
      return 'Composición';
    case 'feed':
      return 'Actividad social';
    default:
      return id;
  }
}

String summaryItemLabel(String item) {
  switch (item) {
    case 'agents':
      return 'Agentes';
    case 'connections':
      return 'Conexiones';
    case 'skills':
      return 'Skills';
    case 'memory':
      return 'Memoria';
    case 'knowledge':
      return 'Knowledge';
    case 'workflows':
      return 'Workflows';
    default:
      return item;
  }
}

String dashboardWidgetSizeLabel(String id) {
  switch (id) {
    case 'token-usage':
    case 'feed':
      return 'Mediano';
    case 'composition':
      return 'Pequeño';
    default:
      return 'Grande';
  }
}

String feedTypeLabel(String type) {
  switch (type) {
    case 'agent':
      return 'Agentes';
    case 'skill':
      return 'Skills';
    case 'knowledge':
      return 'Knowledge';
    default:
      return type;
  }
}

class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    this.items,
    this.groupBy,
    this.scope,
    this.limit,
    this.pageSize,
    this.days,
    this.types,
  });

  final List<String>? items;
  final String? groupBy;
  final String? scope;
  final int? limit;
  final int? pageSize;
  final int? days;
  final List<String>? types;

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    List<String>? stringList(Object? value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      return null;
    }

    return DashboardWidgetConfig(
      items: stringList(json['items']),
      groupBy: json['groupBy'] as String?,
      scope: json['scope'] as String?,
      limit: (json['limit'] as num?)?.toInt(),
      pageSize: (json['pageSize'] as num?)?.toInt(),
      days: (json['days'] as num?)?.toInt(),
      types: stringList(json['types']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (items != null) 'items': items,
        if (groupBy != null) 'groupBy': groupBy,
        if (scope != null) 'scope': scope,
        if (limit != null) 'limit': limit,
        if (pageSize != null) 'pageSize': pageSize,
        if (days != null) 'days': days,
        if (types != null) 'types': types,
      };

  DashboardWidgetConfig copyWith({
    List<String>? items,
    String? groupBy,
    String? scope,
    int? limit,
    int? pageSize,
    int? days,
    List<String>? types,
  }) {
    return DashboardWidgetConfig(
      items: items ?? this.items,
      groupBy: groupBy ?? this.groupBy,
      scope: scope ?? this.scope,
      limit: limit ?? this.limit,
      pageSize: pageSize ?? this.pageSize,
      days: days ?? this.days,
      types: types ?? this.types,
    );
  }
}
