import 'dashboard_widget_config.dart';

enum DashboardWidgetSize {
  compact,
  medium,
  wide,
  full;

  static DashboardWidgetSize fromJson(Object? value) {
    return values.firstWhere(
      (size) => size.name == value,
      orElse: () => DashboardWidgetSize.medium,
    );
  }
}

enum DashboardDataSource {
  agents,
  connections,
  knowledge,
  workflows,
  skills,
  memory,
  tokenDaily,
  groups,
  invitations,
  conversations,
}

String normalizeDashboardWidgetType(Object? value) {
  final type = value?.toString() ?? '';
  final legacyGroupType =
      'work'
      'space';
  return type == legacyGroupType ? 'group' : type;
}

class DashboardWidgetInstance {
  const DashboardWidgetInstance({
    required this.id,
    required this.type,
    required this.size,
    this.config = const DashboardWidgetConfig(),
  });

  final String id;
  final String type;
  final DashboardWidgetSize size;
  final DashboardWidgetConfig config;

  factory DashboardWidgetInstance.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetInstance(
      id: json['id']?.toString() ?? '',
      type: normalizeDashboardWidgetType(json['type']),
      size: DashboardWidgetSize.fromJson(json['size']),
      config: DashboardWidgetConfig.fromJson(
        json['config'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'size': size.name,
    'config': config.toJson(),
  };

  DashboardWidgetInstance copyWith({
    DashboardWidgetSize? size,
    DashboardWidgetConfig? config,
  }) {
    return DashboardWidgetInstance(
      id: id,
      type: type,
      size: size ?? this.size,
      config: config ?? this.config,
    );
  }
}
