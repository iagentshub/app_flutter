import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../../../models/dashboard/dashboard_widget_instance.dart';
import '../../../models/dashboard/dashboard_widget_registry.dart';
import '../../../models/dashboard/notification_banner.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../explore/repositories/explore_repository.dart';
import '../cards/dashboard_widget_card.dart';
import '../repositories/dashboard_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/dashboard_edit_state.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/kpi/kpi_row_tile.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../widgets/responsive_dashboard_grid.dart';

part '../cards/dashboard_activity_cards.dart';
part '../cards/dashboard_feed_cards.dart';
part '../cards/dashboard_metrics_cards.dart';
part '../cards/dashboard_notification_banner_card.dart';
part '../cards/dashboard_resource_cards.dart';
part '../dialogs/dashboard_widget_config_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.backendController,
    required this.sessionController,
    required this.authRepository,
    required this.dashboardRepository,
    required this.apiClient,
    required this.dashboardEditState,
    required this.localeController,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final ApiClient apiClient;
  final DashboardEditState dashboardEditState;
  final LocaleController localeController;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final ExploreRepository _exploreRepository;
  late final TranslatedTexts _t;

  DashboardData? _data;
  List<DashboardWidgetInstance> _layout = defaultDashboardInstances();
  List<NotificationBanner> _banners = [];
  bool _loading = true;
  bool _editing = false;
  String? _error;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String _widgetTx(String key, String fallback) =>
      _tx('dashboard.$key', fallback);

  @override
  void initState() {
    super.initState();
    _exploreRepository = ExploreRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_editing) widget.dashboardEditState.stopEditing();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preferences = await widget.dashboardRepository.getPreferences(
        token,
      );
      final data = await widget.dashboardRepository.fetchData(
        gaToken: token,
        sources: dashboardDataSourcesFor(preferences.instances),
      );
      final banners = await widget.dashboardRepository.getActiveBanners(
        token,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _layout = preferences.instances;
        _banners = banners;
        _loading = false;
      });
      if (!preferences.isVersioned) _persistLayout();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx(
          'dashboard.error_generic',
          'No se pudo cargar el dashboard',
        );
        _loading = false;
      });
    }
  }

  Future<void> _persistLayout() async {
    final token = _token;
    if (token == null) return;
    try {
      await widget.dashboardRepository.savePreferences(token, _layout);
    } catch (_) {
      // best-effort: el layout sigue aplicado localmente aunque falle el guardado
    }
  }

  List<String> get _availableWidgetTypes {
    return [
      for (final definition in dashboardWidgetDefinitions)
        if (!definition.singleton ||
            !_layout.any((item) => item.type == definition.type))
          definition.type,
    ];
  }

  void _toggleEditing() {
    setState(() => _editing = !_editing);
    if (_editing) {
      widget.dashboardEditState.startEditing(
        missing: _availableWidgetTypes,
        onAdd: _addWidget,
      );
    } else {
      widget.dashboardEditState.stopEditing();
    }
  }

  void _addWidget(String type) {
    setState(() => _layout = [..._layout, createDashboardWidgetInstance(type)]);
    widget.dashboardEditState.updateMissing(_availableWidgetTypes);
    _persistLayout();
    _reloadDataForCurrentLayout();
  }

  void _removeWidget(String instanceId) {
    setState(() => _layout = _layout.where((w) => w.id != instanceId).toList());
    widget.dashboardEditState.updateMissing(_availableWidgetTypes);
    _persistLayout();
  }

  Future<void> _reloadDataForCurrentLayout() async {
    final token = _token;
    if (token == null) return;
    final data = await widget.dashboardRepository.fetchData(
      gaToken: token,
      sources: dashboardDataSourcesFor(_layout),
    );
    if (mounted) setState(() => _data = data);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final list = [..._layout];
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _layout = list;
    });
    _persistLayout();
  }

  Future<void> _editWidget(DashboardWidgetInstance instance) async {
    final result = await showDialog<_DashboardWidgetEditResult>(
      context: context,
      builder: (context) => _WidgetConfigDialog(
        widgetType: instance.type,
        initialConfig: instance.config,
        initialSize: instance.size,
        tx: _widgetTx,
      ),
    );
    if (result == null) return;
    setState(() {
      _layout = [
        for (final item in _layout)
          if (item.id == instance.id)
            item.copyWith(size: result.size, config: result.config)
          else
            item,
      ];
    });
    _persistLayout();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? _tx('dashboard.no_data', 'Sin datos')),
            const SizedBox(height: 12),
            PrimaryButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(_tx('common.retry', 'Reintentar')),
            ),
          ],
        ),
      );
    }

    final data = _data!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_editing)
                Expanded(
                  child: Text(
                    _tx(
                      'dashboard.edit_hint',
                      'Abre el menú (☰) para añadir widgets',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                const Spacer(),
              TertiaryButton.icon(
                onPressed: _toggleEditing,
                icon: Icon(_editing ? Icons.check : Icons.tune),
                label: Text(
                  _editing
                      ? _tx('dashboard.done_btn', 'Listo')
                      : _tx('dashboard.customize_btn', 'Personalizar'),
                ),
              ),
            ],
          ),
        ),
        if (_banners.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                for (final banner in _banners)
                  _NotificationBannerCard(banner: banner),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _layout.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            _tx(
                              'dashboard.empty_layout',
                              'No hay widgets. Pulsa "Personalizar" y abre el menú para añadir alguno.',
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _editing
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    buildDefaultDragHandles: false,
                    itemCount: _layout.length,
                    onReorder: _reorder,
                    itemBuilder: (context, index) =>
                        _buildCard(_layout[index], data, index: index),
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: ResponsiveDashboardGrid(
                            items: _layout,
                            itemBuilder: (context, instance, index) =>
                                _buildCard(instance, data, inGrid: true),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    DashboardWidgetInstance instance,
    DashboardData data, {
    int index = 0,
    bool inGrid = false,
  }) {
    final definition = dashboardWidgetDefinition(instance.type);
    return DashboardWidgetCard(
      key: ValueKey(instance.id),
      instanceId: instance.id,
      title: dashboardWidgetTitle(instance.type, _widgetTx),
      body: _bodyFor(instance.type, data, instance.config),
      editing: _editing,
      reorderIndex: index,
      inGrid: inGrid,
      canConfigure:
          definition?.configurable == true ||
          (definition?.supportedSizes.length ?? 0) > 1,
      configureTooltip: _tx('dashboard.configure_tooltip', 'Configurar'),
      removeTooltip: _tx('dashboard.remove_tooltip', 'Quitar'),
      onConfigure: () => _editWidget(instance),
      onRemove: () => _removeWidget(instance.id),
    );
  }

  Widget _bodyFor(String id, DashboardData data, DashboardWidgetConfig config) {
    switch (id) {
      case 'summary':
        return _SummaryBody(data: data, config: config, tx: _widgetTx);
      case 'token-usage':
        return _TokenUsageBody(data: data, config: config, tx: _widgetTx);
      case 'conn-status':
        return _ConnectionStatusBody(
          key: ValueKey('conn-status-${_token ?? ''}'),
          data: data,
          token: _token ?? '',
          repository: widget.dashboardRepository,
          config: config,
          tx: _widgetTx,
        );
      case 'recent':
        return _RecentAgentsBody(data: data, config: config, tx: _widgetTx);
      case 'recent-conversations':
        return _RecentConversationsBody(
          data: data,
          config: config,
          tx: _widgetTx,
        );
      case 'activity':
        return _ActivityBody(data: data, config: config, tx: _widgetTx);
      case 'composition':
        return _CompositionBody(data: data, tx: _widgetTx);
      case 'feed':
        return _FeedBody(
          key: ValueKey('feed-${config.types}-${config.limit}'),
          token: _token ?? '',
          repository: widget.dashboardRepository,
          exploreRepository: _exploreRepository,
          config: config,
          tx: _widgetTx,
        );
      case 'quick-actions':
        return _QuickActionsBody(config: config, tx: _widgetTx);
      case 'token-kpi':
        return _TokenKpiBody(data: data, config: config, tx: _widgetTx);
      case 'recent-resources':
        return _RecentResourcesBody(data: data, config: config, tx: _widgetTx);
      case 'agent-health':
        return _AgentHealthBody(data: data, config: config, tx: _widgetTx);
      case 'group':
        return _GroupBody(data: data, tx: _widgetTx);
      default:
        return const SizedBox.shrink();
    }
  }
}
