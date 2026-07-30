const kDashboardWidgetIds = [
  'summary',
  'token-usage',
  'conn-status',
  'recent',
  'activity',
  'composition',
  'feed',
];

const kDefaultDashboardLayout = [
  'summary',
  'token-usage',
  'conn-status',
  'recent',
];

const kSummaryItems = [
  'agents',
  'connections',
  'skills',
  'memory',
  'knowledge',
  'workflows',
];
const kFeedTypes = ['agent', 'skill', 'knowledge'];

typedef DashboardTx = String Function(String key, String fallback);

String dashboardWidgetTitle(String id, DashboardTx tx) {
  switch (id) {
    case 'summary':
      return tx('title_summary', 'Resumen');
    case 'token-usage':
      return tx('title_token_usage', 'Uso de tokens');
    case 'conn-status':
      return tx('title_conn_status', 'Estado de conexiones');
    case 'recent':
      return tx('title_recent', 'Agentes recientes');
    case 'activity':
      return tx('title_activity', 'Actividad');
    case 'composition':
      return tx('title_composition', 'Composición');
    case 'feed':
      return tx('title_feed', 'Actividad social');
    default:
      return id;
  }
}

String summaryItemLabel(String item, DashboardTx tx) {
  switch (item) {
    case 'agents':
      return tx('summary_agents', 'Agentes');
    case 'connections':
      return tx('summary_connections', 'Conexiones');
    case 'skills':
      return tx('summary_skills', 'Skills');
    case 'memory':
      return tx('summary_memory', 'Memoria');
    case 'knowledge':
      return tx('summary_knowledge', 'Knowledge');
    case 'workflows':
      return tx('summary_workflows', 'Workflows');
    default:
      return item;
  }
}

String dashboardWidgetSizeLabel(String id, DashboardTx tx) {
  switch (id) {
    case 'token-usage':
    case 'feed':
      return tx('size_medium', 'Mediano');
    case 'composition':
      return tx('size_small', 'Pequeño');
    default:
      return tx('size_large', 'Grande');
  }
}

String feedTypeLabel(String type, DashboardTx tx) {
  switch (type) {
    case 'agent':
      return tx('feed_agent', 'Agentes');
    case 'skill':
      return tx('feed_skill', 'Skills');
    case 'knowledge':
      return tx('feed_knowledge', 'Knowledge');
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
