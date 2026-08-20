import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/workflows/llm_orchestration_models.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/watches_resource_changes.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../connections/repositories/connections_repository.dart';
import '../cards/llm_orchestration_card.dart';
import '../pages/llm_orchestration_editor_page.dart';
import '../repositories/llm_orchestrations_repository.dart';

class LlmOrchestrationsPanel extends StatefulWidget {
  const LlmOrchestrationsPanel({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    required this.tx,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final String Function(String path) tx;

  @override
  State<LlmOrchestrationsPanel> createState() => _LlmOrchestrationsPanelState();
}

class _LlmOrchestrationsPanelState extends State<LlmOrchestrationsPanel>
    with WatchesResourceChanges {
  @override
  Set<String> get watchedResources => const {
    'llm-orchestrations',
    'connections',
  };

  @override
  Future<void> onResourcesChanged(Set<String> changed) => _load();

  late final LlmOrchestrationsRepository _repository;
  late final ConnectionsRepository _connectionsRepository;
  List<LlmOrchestrationItem> _items = const [];
  List<ConnectionItem> _connections = const [];
  bool _loading = true;
  String? _error;

  String get _token => widget.sessionController.gaToken ?? '';

  @override
  void initState() {
    super.initState();
    _repository = LlmOrchestrationsRepository(apiClient: widget.apiClient);
    _connectionsRepository = ConnectionsRepository(apiClient: widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    if (_token.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _repository.list(_token, includeInactive: true),
        _connectionsRepository.listConnections(_token, includeInactive: false),
      ]);
      if (!mounted) return;
      setState(() {
        _items = values[0] as List<LlmOrchestrationItem>;
        _connections = (values[1] as List<ConnectionItem>)
            .where((connection) => !connection.isVirtual)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiError ? error.message : error.toString();
        _loading = false;
      });
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _edit([LlmOrchestrationItem? initial]) async {
    final requiredConnections = initial?.shared == true
        ? initial!.candidates.length
        : 2;
    if (_connections.length < requiredConnections) {
      _message(
        widget
            .tx('llm_orchestrations.connections_required')
            .replaceAll('{{count}}', '$requiredConnections'),
        error: true,
      );
      return;
    }
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => LlmOrchestrationEditorPage(
          connections: _connections,
          initial: initial,
          configureBinding: initial?.shared == true,
          tx: widget.tx,
        ),
      ),
    );
    if (payload == null) return;
    try {
      if (initial?.shared == true) {
        await _repository.saveBinding(_token, initial!.id, payload);
      } else {
        await _repository.save(_token, payload);
      }
      _message(
        initial?.shared == true
            ? widget.tx('llm_orchestrations.binding_saved')
            : widget.tx('llm_orchestrations.saved'),
      );
      await _load();
    } on ApiError catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _delete(LlmOrchestrationItem item) async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: widget.tx('llm_orchestrations.delete_title'),
      message: widget
          .tx('llm_orchestrations.delete_body')
          .replaceAll('{{name}}', item.name),
      cancelLabel: widget.tx('common.cancel'),
      confirmLabel: widget.tx('common.delete'),
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _repository.delete(_token, item.id);
    } on ApiError catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _toggle(LlmOrchestrationItem item) async {
    try {
      await _repository.setOrchestrationActive(_token, item.id, !item.isActive);
    } on ApiError catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _share(LlmOrchestrationItem item) => showShareToGroupDialog(
    context: context,
    apiClient: widget.apiClient,
    token: _token,
    resourceType: 'llm_orchestration',
    resourceId: item.id,
    localeController: widget.localeController,
    onShared: _load,
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return AsyncStatePanel.error(
        title: widget.tx('llm_orchestrations.load_error'),
        message: _error!,
        retryLabel: widget.tx('common.retry'),
        onRetry: _load,
      );
    }
    final connectionsById = {for (final item in _connections) item.id: item};
    return ResourceCollectionView(
      onRefresh: _load,
      header: ResourceToolbar(
        actions: [
          AppIconButton.filled(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            tooltip: widget.tx('llm_orchestrations.create'),
          ),
          AppIconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: widget.tx('common.refresh'),
          ),
        ],
        summary: Text(
          '${widget.tx('llm_orchestrations.count')}: ${_items.length}',
        ),
      ),
      emptyFillsViewport: true,
      empty: Center(child: Text(widget.tx('llm_orchestrations.empty'))),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return LlmOrchestrationCard(
          item: item,
          connectionsById: connectionsById,
          tx: widget.tx,
          onToggleActive: () => _toggle(item),
          onEdit: () => _edit(item),
          onConfigure: () => _edit(item),
          onShare: () => _share(item),
          onDelete: () => _delete(item),
        );
      },
    );
  }
}
