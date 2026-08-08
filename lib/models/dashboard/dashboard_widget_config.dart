const kDashboardWidgetIds = [
  'summary',
  'token-usage',
  'conn-status',
  'recent',
  'recent-conversations',
  'activity',
  'composition',
  'feed',
  'quick-actions',
  'token-kpi',
  'recent-resources',
  'agent-health',
  'group',
];

const kDefaultDashboardLayout = [
  'summary',
  'quick-actions',
  'token-kpi',
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
const kFeedTypes = ['agent', 'skill', 'knowledge', 'tool'];
const kQuickActionItems = ['agent', 'connection', 'workflow', 'knowledge'];
const kRecentResourceTypes = [
  'agent',
  'skill',
  'knowledge',
  'workflow',
  'tool',
];

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
    case 'recent-conversations':
      return tx('title_recent_conversations', 'Conversaciones recientes');
    case 'activity':
      return tx('title_activity', 'Actividad');
    case 'composition':
      return tx('title_composition', 'Composición');
    case 'feed':
      return tx('title_feed', 'Actividad social');
    case 'quick-actions':
      return tx('title_quick_actions', 'Acciones rápidas');
    case 'token-kpi':
      return tx('title_token_kpi', 'Consumo de tokens');
    case 'recent-resources':
      return tx('title_recent_resources', 'Recursos recientes');
    case 'agent-health':
      return tx('title_agent_health', 'Estado de agentes');
    case 'group':
      return tx('title_group', 'Grupo activo');
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
    case 'token-kpi':
    case 'composition':
      return tx('size_compact', 'Compacto');
    case 'activity':
      return tx('size_wide', 'Ancho');
    case 'summary':
      return tx('size_full', 'Completo');
    case 'token-usage':
    case 'feed':
    case 'quick-actions':
    case 'recent-resources':
    case 'recent-conversations':
    case 'agent-health':
    case 'group':
      return tx('size_medium', 'Mediano');
    default:
      return tx('size_medium', 'Mediano');
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
    case 'tool':
      return tx('feed_tool', 'Herramientas');
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
    this.period,
  });

  final List<String>? items;
  final String? groupBy;
  final String? scope;
  final int? limit;
  final int? pageSize;
  final int? days;
  final List<String>? types;
  final String? period;

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
      period: json['period'] as String?,
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
    if (period != null) 'period': period,
  };

  DashboardWidgetConfig copyWith({
    List<String>? items,
    String? groupBy,
    String? scope,
    int? limit,
    int? pageSize,
    int? days,
    List<String>? types,
    String? period,
  }) {
    return DashboardWidgetConfig(
      items: items ?? this.items,
      groupBy: groupBy ?? this.groupBy,
      scope: scope ?? this.scope,
      limit: limit ?? this.limit,
      pageSize: pageSize ?? this.pageSize,
      days: days ?? this.days,
      types: types ?? this.types,
      period: period ?? this.period,
    );
  }
}
