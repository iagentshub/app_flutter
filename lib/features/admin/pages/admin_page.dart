import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../repositories/admin_repository.dart';
import '../../../shared/state/session_controller.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final AdminRepository _repository;
  final TextEditingController _userSearchController = TextEditingController();

  AdminStats? _stats;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _workspaces = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = AdminRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
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
        _repository.getStats(token),
        _repository.listUsers(token, query: _userSearchController.text),
        _repository.listWorkspaces(token),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _users = results[1] as List<Map<String, dynamic>>;
        _workspaces = results[2] as List<Map<String, dynamic>>;
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
        _error = 'No se pudo cargar Admin';
        _loading = false;
      });
    }
  }

  Future<void> _setUserActive(String username, bool active) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.setUserActive(token, username, active);
      _showMessage(active ? 'Usuario activado' : 'Usuario desactivado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar el usuario', isError: true);
    }
  }

  Future<void> _toggleWorkspaceStatus(Map<String, dynamic> ws) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final status = (ws['status'] as String?) == 'active' ? 'disabled' : 'active';
    try {
      await _repository.setWorkspaceStatus(token, (ws['id'] ?? '').toString(), status);
      _showMessage('Workspace ${status == 'active' ? 'activado' : 'desactivado'}');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cambiar el estado del workspace', isError: true);
    }
  }

  Future<void> _deleteWorkspace(Map<String, dynamic> ws) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final id = (ws['id'] ?? '').toString();
    final name = (ws['name'] ?? id).toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar workspace'),
        content: Text('¿Seguro que quieres eliminar "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repository.deleteWorkspace(token, id);
      _showMessage('Workspace eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar el workspace', isError: true);
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
                  const Text('Error cargando Admin', style: TextStyle(fontWeight: FontWeight.bold)),
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

    final stats = _stats;
    if (stats == null) return const Center(child: Text('Sin estadísticas'));

    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _statCard('Usuarios', stats.usersTotal),
                  _statCard('Activos', stats.usersActive),
                  _statCard('Verificados', stats.usersVerified),
                  _statCard('Conexiones', stats.connectionsTotal),
                  _statCard('Knowledge', stats.knowledgeTotal),
                  _statCard('Workflows', stats.workflowsTotal),
                  _statCard('Conversaciones', stats.conversationsTotal),
                  _statCard('Agentes públicos', stats.agentsPublic),
                  _statCard('Agentes privados', stats.agentsPrivate),
                ],
              ),
              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Usuarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 320,
                            child: TextField(
                              controller: _userSearchController,
                              decoration: const InputDecoration(labelText: 'Buscar por usuario o email'),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_users.isEmpty)
                        const Text('Sin usuarios para ese filtro')
                      else
                        SizedBox(
                          height: 320,
                          child: ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final username = (user['username'] ?? '').toString();
                              final email = (user['email'] ?? '').toString();
                              final role = (user['role'] ?? 'standard').toString();
                              final active = user['is_active'] == true || user['is_active'] == 1;
                              final verified = user['is_verified'] == true || user['is_verified'] == 1;
                              return ListTile(
                                dense: true,
                                title: Text(username),
                                subtitle: Text('$email · $role · verified=${verified ? 'yes' : 'no'}'),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _setUserActive(username, !active),
                                      child: Text(active ? 'Desactivar' : 'Activar'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Workspaces', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (_workspaces.isEmpty)
                        const Text('Sin workspaces')
                      else
                        ..._workspaces.take(50).map((ws) {
                          final id = (ws['id'] ?? '').toString();
                          final name = (ws['name'] ?? id).toString();
                          final status = (ws['status'] ?? 'active').toString();
                          final members = ws['member_count']?.toString() ?? '0';
                          return ListTile(
                            dense: true,
                            title: Text(name),
                            subtitle: Text('id: $id · status: $status · members: $members'),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _toggleWorkspaceStatus(ws),
                                  child: Text(status == 'active' ? 'Desactivar' : 'Activar'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _deleteWorkspace(ws),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
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

  Widget _statCard(String title, int value) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
