import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../repositories/centinel_repository.dart';
import '../../../shared/state/session_controller.dart';

class CentinelPage extends StatefulWidget {
  const CentinelPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<CentinelPage> createState() => _CentinelPageState();
}

class _CentinelPageState extends State<CentinelPage> {
  late final CentinelRepository _repository;
  final TextEditingController _targetController = TextEditingController(text: 'tests/');

  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _history = const [];
  Map<String, dynamic>? _tree;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _rerunFailed = false;

  @override
  void initState() {
    super.initState();
    _repository = CentinelRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.status(token),
        _repository.history(token),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as Map<String, dynamic>;
        _history = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar Centinel';
        _loading = false;
      });
    }
  }

  Future<void> _startRun() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await _repository.run(
        token,
        target: _targetController.text.trim().isEmpty ? 'tests/' : _targetController.text.trim(),
        rerunFailed: _rerunFailed,
      );
      _showMessage('Run iniciado: ${result['run_id'] ?? '-'}');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo iniciar el run', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abortRun() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _repository.abort(token);
      _showMessage('Run abortado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo abortar el run', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadTree() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tree = await _repository.tree(token);
      if (!mounted) return;
      setState(() => _tree = tree);
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cargar el árbol de tests', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error cargando Centinel', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final status = _status ?? const <String, dynamic>{};
    final runStatus = (status['status'] ?? 'idle').toString();
    final failedIds = status['failed_ids'];
    final failedCount = failedIds is List ? failedIds.length : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estado actual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('status: $runStatus'),
                      Text('run_id: ${status['run_id'] ?? '-'}'),
                      Text('target: ${status['target'] ?? '-'}'),
                      Text('fallidos: $failedCount'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 320,
                            child: TextField(
                              controller: _targetController,
                              decoration: const InputDecoration(labelText: 'Target tests'),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _rerunFailed,
                                onChanged: (value) => setState(() => _rerunFailed = value ?? false),
                              ),
                              const Text('Re-run failed'),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: _busy ? null : _startRun,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Iniciar run'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _abortRun,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Abortar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refrescar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _loadTree,
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('Árbol tests'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_tree != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tree', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Resumen: ${_tree!['summary'] ?? {}}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Historial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        const Text('Sin ejecuciones previas')
                      else
                        ..._history.map((entry) {
                          final id = (entry['run_id'] ?? '-').toString();
                          final statusEntry = (entry['status'] ?? '-').toString();
                          final target = (entry['target'] ?? '-').toString();
                          final summary = (entry['summary'] ?? {}).toString();
                          return ListTile(
                            dense: true,
                            title: Text('$statusEntry · $id'),
                            subtitle: Text('$target\n$summary'),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
