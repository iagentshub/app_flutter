import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../models/connections/connection_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../shared/widgets/status_dot.dart';
import '../cards/connection_card.dart';
import '../controllers/connections_controller.dart';
import '../repositories/connections_repository.dart';

part '../dialogs/connection_form_dialog.dart';
part '../widgets/connections_page_view.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with SingleTickerProviderStateMixin, StateMessaging {
  late final ConnectionsController _controller;

  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final TranslatedTexts _t;
  late final TabController _tabController;

  String _tx(String path) => _t.text(path);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller = ConnectionsController(
      repository: ConnectionsRepository(apiClient: _services.apiClient),
      sessionController: _services.sessionController,
      tx: _tx,
    )..addListener(_onControllerChanged);
    _tabController = TabController(
      length: connectionCategoryIds.length,
      vsync: this,
    )..addListener(_onTabChanged);
    unawaited(_controller.load());
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (!mounted) return;
    _controller.setCategoryIndex(_tabController.index);
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<ActionResult?> action) async {
    final result = await action;
    if (!mounted || result == null) return;
    showMessage(result.message, isError: result.isError);
  }

  void _openFiltersDialog() {
    final providerOptions = [
      ('all', _tx('explore.option_all')),
      ..._controller
          .providersForCategory(_controller.currentCategory)
          .map(
            (provider) => (
              provider.type,
              provider.label.isEmpty ? provider.type : provider.label,
            ),
          ),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: _controller.clearProviderFilter,
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('connections.provider_label'),
          value: _controller.providerFilter,
          options: providerOptions,
          onChanged: (value) {
            _controller.setProviderFilter(value);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  Future<void> _shareConnection(ConnectionItem item) async {
    final token = _controller.token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'connection',
      resourceId: item.id,
      localeController: _services.localeController,
      onShared: _controller.load,
    );
  }

  Future<Map<String, dynamic>?> _presentConnectionForm(
    List<ConnectionProvider> providers,
    Map<String, dynamic>? initial,
    Future<List<String>> Function(String host) discoverOllamaModels,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConnectionFormDialog(
        providers: providers,
        initial: initial,
        tx: _tx,
        onDiscoverOllamaModels: discoverOllamaModels,
      ),
    );
  }

  void _openCreateDialog() => unawaited(
    _runAction(_controller.createConnection(present: _presentConnectionForm)),
  );

  void _openEditDialog(ConnectionItem item) => unawaited(
    _runAction(
      _controller.editConnection(item, present: _presentConnectionForm),
    ),
  );

  void _deleteConnection(ConnectionItem item) => unawaited(
    _runAction(
      _controller.deleteConnection(
        item,
        confirm: () => showConfirmActionDialog(
          context,
          title: _tx('connections.delete_title'),
          message: _tx(
            'connections.delete_confirm',
          ).replaceAll('{{name}}', item.name),
          cancelLabel: _tx('common.cancel'),
          confirmLabel: _tx('common.delete'),
        ),
      ),
    ),
  );

  void _testConnection(ConnectionItem item) =>
      unawaited(_runAction(_controller.testConnection(item)));

  void _toggleConnectionActive(ConnectionItem item) =>
      unawaited(_runAction(_controller.toggleActive(item)));

  void _syncHub(ConnectionItem item) =>
      unawaited(_runAction(_controller.syncHub(item)));

  void _testAll() =>
      unawaited(_runAction(_controller.testAll(present: _showMassTestSummary)));

  Future<void> _showMassTestSummary(ConnectionsMassTestSummary summary) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _tx(
            'connections.mass_test_title',
          ).replaceAll('{{n}}', '${summary.results.length}'),
        ),
        content: SizedBox(
          width: dialogContentWidth(context, 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tx('connections.mass_test_summary')
                    .replaceAll('{{ok}}', '${summary.passed}')
                    .replaceAll('{{fail}}', '${summary.failed}'),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: summary.results
                      .map(
                        (result) => ListTile(
                          dense: true,
                          leading: Icon(
                            result.ok
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                          ),
                          title: Text(
                            summary.namesById[result.id] ?? result.id,
                          ),
                          subtitle: Text(result.message),
                          trailing: result.latencyMs == null
                              ? null
                              : Text('${result.latencyMs}ms'),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_tx('common.close')),
          ),
        ],
      ),
    );
  }

  StatusDotState? _statusDotFor(String id) =>
      switch (_controller.testStatus(id)) {
        ConnectionTestStatus.ok => StatusDotState.ok,
        ConnectionTestStatus.error => StatusDotState.error,
        ConnectionTestStatus.pending => StatusDotState.pending,
        null => null,
      };

  @override
  Widget build(BuildContext context) => _buildPage(context);
}
