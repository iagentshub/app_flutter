import 'package:app_flutter/models/dashboard/dashboard_widget_config.dart';
import 'package:app_flutter/models/dashboard/dashboard_widget_instance.dart';
import 'package:app_flutter/models/dashboard/dashboard_widget_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializa una instancia versionada con tamaño y configuración', () {
    const instance = DashboardWidgetInstance(
      id: 'token-kpi-a',
      type: 'token-kpi',
      size: DashboardWidgetSize.compact,
      config: DashboardWidgetConfig(period: '30d', limit: 4),
    );

    final restored = DashboardWidgetInstance.fromJson(instance.toJson());

    expect(restored.id, instance.id);
    expect(restored.type, instance.type);
    expect(restored.size, DashboardWidgetSize.compact);
    expect(restored.config.period, '30d');
    expect(restored.config.limit, 4);
  });

  test('migra el layout anterior conservando configuración y orden', () {
    final migrated = migrateLegacyDashboardLayout(
      const ['recent', 'token-usage'],
      const {'recent': DashboardWidgetConfig(pageSize: 8)},
    );

    expect(migrated.map((item) => item.type), ['recent', 'token-usage']);
    expect(migrated.first.id, 'recent');
    expect(migrated.first.config.pageSize, 8);
    expect(migrated.first.size, DashboardWidgetSize.medium);
  });

  test('migra el nombre anterior del widget de grupo', () {
    const legacyType =
        'work'
        'space';
    final restored = DashboardWidgetInstance.fromJson({
      'id': 'legacy-group',
      'type': legacyType,
      'size': 'medium',
    });
    final migrated = migrateLegacyDashboardLayout([legacyType], const {});

    expect(restored.type, 'group');
    expect(migrated.single.type, 'group');
  });

  test('permite instancias repetidas y calcula solo sus dependencias', () {
    final first = createDashboardWidgetInstance('token-kpi');
    final second = createDashboardWidgetInstance('token-kpi');
    final sources = dashboardDataSourcesFor([first, second]);

    expect(first.id, isNot(second.id));
    expect(sources, {DashboardDataSource.tokenDaily});
  });
}
