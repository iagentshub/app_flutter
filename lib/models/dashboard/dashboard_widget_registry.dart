import 'package:flutter/material.dart';

import 'dashboard_widget_config.dart';
import 'dashboard_widget_instance.dart';

class DashboardWidgetDefinition {
  const DashboardWidgetDefinition({
    required this.type,
    required this.icon,
    required this.defaultSize,
    required this.supportedSizes,
    required this.dataSources,
    this.singleton = true,
    this.configurable = true,
  });

  final String type;
  final IconData icon;
  final DashboardWidgetSize defaultSize;
  final Set<DashboardWidgetSize> supportedSizes;
  final Set<DashboardDataSource> dataSources;
  final bool singleton;
  final bool configurable;
}

const dashboardWidgetDefinitions = [
  DashboardWidgetDefinition(
    type: 'summary',
    icon: Icons.space_dashboard_outlined,
    defaultSize: DashboardWidgetSize.full,
    supportedSizes: {
      DashboardWidgetSize.medium,
      DashboardWidgetSize.wide,
      DashboardWidgetSize.full,
    },
    dataSources: {
      DashboardDataSource.agents,
      DashboardDataSource.connections,
      DashboardDataSource.skills,
      DashboardDataSource.memory,
      DashboardDataSource.knowledge,
      DashboardDataSource.workflows,
    },
  ),
  DashboardWidgetDefinition(
    type: 'quick-actions',
    icon: Icons.bolt_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {
      DashboardWidgetSize.compact,
      DashboardWidgetSize.medium,
      DashboardWidgetSize.wide,
    },
    dataSources: {},
  ),
  DashboardWidgetDefinition(
    type: 'token-kpi',
    icon: Icons.data_usage_outlined,
    defaultSize: DashboardWidgetSize.compact,
    supportedSizes: {DashboardWidgetSize.compact, DashboardWidgetSize.medium},
    dataSources: {DashboardDataSource.tokenDaily},
    singleton: false,
  ),
  DashboardWidgetDefinition(
    type: 'token-usage',
    icon: Icons.leaderboard_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {DashboardDataSource.agents, DashboardDataSource.connections},
  ),
  DashboardWidgetDefinition(
    type: 'activity',
    icon: Icons.show_chart,
    defaultSize: DashboardWidgetSize.wide,
    supportedSizes: {
      DashboardWidgetSize.medium,
      DashboardWidgetSize.wide,
      DashboardWidgetSize.full,
    },
    dataSources: {DashboardDataSource.tokenDaily},
  ),
  DashboardWidgetDefinition(
    type: 'conn-status',
    icon: Icons.monitor_heart_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {DashboardDataSource.connections},
  ),
  DashboardWidgetDefinition(
    type: 'recent',
    icon: Icons.smart_toy_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {DashboardDataSource.agents},
  ),
  DashboardWidgetDefinition(
    type: 'recent-conversations',
    icon: Icons.forum_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {
      DashboardDataSource.agents,
      DashboardDataSource.conversations,
    },
  ),
  DashboardWidgetDefinition(
    type: 'recent-resources',
    icon: Icons.update_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {
      DashboardDataSource.agents,
      DashboardDataSource.skills,
      DashboardDataSource.knowledge,
      DashboardDataSource.workflows,
    },
  ),
  DashboardWidgetDefinition(
    type: 'agent-health',
    icon: Icons.health_and_safety_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {DashboardDataSource.agents, DashboardDataSource.connections},
  ),
  DashboardWidgetDefinition(
    type: 'group',
    icon: Icons.groups_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.compact, DashboardWidgetSize.medium},
    dataSources: {DashboardDataSource.groups, DashboardDataSource.invitations},
  ),
  DashboardWidgetDefinition(
    type: 'composition',
    icon: Icons.donut_small_outlined,
    defaultSize: DashboardWidgetSize.compact,
    supportedSizes: {DashboardWidgetSize.compact, DashboardWidgetSize.medium},
    dataSources: {DashboardDataSource.agents, DashboardDataSource.connections},
    configurable: false,
  ),
  DashboardWidgetDefinition(
    type: 'feed',
    icon: Icons.dynamic_feed_outlined,
    defaultSize: DashboardWidgetSize.medium,
    supportedSizes: {DashboardWidgetSize.medium, DashboardWidgetSize.wide},
    dataSources: {},
  ),
];

DashboardWidgetDefinition? dashboardWidgetDefinition(String type) {
  for (final definition in dashboardWidgetDefinitions) {
    if (definition.type == type) return definition;
  }
  return null;
}

Set<DashboardDataSource> dashboardDataSourcesFor(
  Iterable<DashboardWidgetInstance> instances,
) {
  return {
    for (final instance in instances)
      ...?dashboardWidgetDefinition(instance.type)?.dataSources,
  };
}

List<DashboardWidgetInstance> migrateLegacyDashboardLayout(
  Iterable<String> layout,
  Map<String, DashboardWidgetConfig> config,
) {
  return [
    for (final type in layout.map(normalizeDashboardWidgetType))
      if (dashboardWidgetDefinition(type) case final definition?)
        DashboardWidgetInstance(
          id: type,
          type: type,
          size: definition.defaultSize,
          config: config[type] ?? const DashboardWidgetConfig(),
        ),
  ];
}

List<DashboardWidgetInstance> defaultDashboardInstances() {
  return migrateLegacyDashboardLayout(
    kDefaultDashboardLayout,
    const <String, DashboardWidgetConfig>{},
  );
}

int _dashboardInstanceCounter = 0;

DashboardWidgetInstance createDashboardWidgetInstance(String type) {
  final definition = dashboardWidgetDefinition(type);
  if (definition == null) {
    throw ArgumentError.value(type, 'type', 'Tipo de widget desconocido');
  }
  _dashboardInstanceCounter += 1;
  return DashboardWidgetInstance(
    id: '$type-${DateTime.now().microsecondsSinceEpoch}-$_dashboardInstanceCounter',
    type: type,
    size: definition.defaultSize,
  );
}
