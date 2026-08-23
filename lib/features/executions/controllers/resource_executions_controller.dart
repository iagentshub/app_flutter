import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/state/session_controller.dart';
import '../models/resource_execution.dart';
import '../repositories/resource_executions_repository.dart';

class ResourceExecutionsController extends ChangeNotifier {
  ResourceExecutionsController({
    required ApiClient apiClient,
    required SessionController sessionController,
    bool autoStart = true,
    this.pollInterval = const Duration(seconds: 5),
  }) : _repository = ResourceExecutionsRepository(apiClient: apiClient),
       _apiClient = apiClient,
       _session = sessionController,
       _autoStart = autoStart {
    _lastIdentity = _identity;
    if (autoStart) {
      _session.addListener(_identityChanged);
      _apiClient.backendController.addListener(_identityChanged);
      scheduleMicrotask(refresh);
    }
  }

  final ResourceExecutionsRepository _repository;
  final ApiClient _apiClient;
  final SessionController _session;
  final bool _autoStart;
  final Duration pollInterval;
  Timer? _timer;
  bool _loading = false;
  bool _refreshQueued = false;
  bool _disposed = false;
  int _generation = 0;
  List<ResourceExecution> _executions = const [];
  Set<String> _activeKeys = const {};
  late String _lastIdentity;

  List<ResourceExecution> get executions => _executions;
  bool get loading => _loading;

  bool isInProgress(String resourceType, String resourceId) =>
      _activeKeys.contains('$resourceType\u0000$resourceId');

  String? get _token {
    if (!_session.isLoggedIn) return null;
    final value = _session.gaToken;
    return value == null || value.isEmpty ? null : value;
  }

  String get _identity =>
      '${_apiClient.backendController.selectedBackendId}|${_session.cacheIdentity}|${_token == null ? 0 : 1}';

  void _identityChanged() {
    final next = _identity;
    if (next == _lastIdentity) return;
    _lastIdentity = next;
    _generation += 1;
    _timer?.cancel();
    _executions = const [];
    _activeKeys = const {};
    notifyListeners();
    if (_token != null) unawaited(refresh());
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null || _disposed) return;
    if (_loading) {
      _refreshQueued = true;
      return;
    }
    final generation = _generation;
    _loading = true;
    try {
      final executions = await _repository.list(token);
      if (_disposed || generation != _generation) return;
      _executions = executions;
      _activeKeys = {
        for (final execution in executions)
          for (final resourceId in execution.resourceIds)
            '${execution.resourceType}\u0000$resourceId',
      };
      notifyListeners();
    } catch (error, stackTrace) {
      AppDiagnostics.report('resource_executions.refresh', error, stackTrace);
    } finally {
      _loading = false;
      if (!_disposed) {
        if (_refreshQueued) {
          _refreshQueued = false;
          unawaited(refresh());
        } else {
          _schedule();
        }
      }
    }
  }

  void _schedule() {
    if (!_autoStart || _disposed || _token == null) return;
    _timer?.cancel();
    _timer = Timer(pollInterval, refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _session.removeListener(_identityChanged);
    _apiClient.backendController.removeListener(_identityChanged);
    super.dispose();
  }
}
