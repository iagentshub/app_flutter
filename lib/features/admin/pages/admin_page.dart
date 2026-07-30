import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../repositories/admin_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/filter_button.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

String _fmtTokens(int n) {
  if (n <= 0) return '—';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _fmtDate(Object? raw) {
  if (raw == null) return '—';
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _ownerOf(Map<String, dynamic> item) =>
    (item['owner_email'] ?? item['owner_id'] ?? '').toString();

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late final AdminRepository _repository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  static const _tabIds = [
    'general',
    'users',
    'workspaces',
    'agents',
    'connections',
    'knowledge',
    'workflows',
    'config',
  ];

  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _wsSearchController = TextEditingController();
  final TextEditingController _agentSearchController = TextEditingController();
  final TextEditingController _knowledgeSearchController =
      TextEditingController();
  final TextEditingController _workflowSearchController =
      TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();

  String _userRole = '';
  String _userActive = '';
  String _userVerified = '';
  String _agentOwner = '';
  String _connOwner = '';
  String _knowledgeType = '';
  String _knowledgeOwner = '';
  String _workflowOwner = '';

  AdminStats? _stats;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _workspaces = const [];
  List<Map<String, dynamic>> _agents = const [];
  List<Map<String, dynamic>> _connections = const [];
  List<Map<String, dynamic>> _knowledge = const [];
  List<Map<String, dynamic>> _workflows = const [];
  Map<String, dynamic>? _platformSettings;

  bool _loading = true;
  String? _error;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String? get _token => widget.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _repository = AdminRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: _tabIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  /// Recalcula el filtro (y reconstruye la lista) tras una pausa al
  /// escribir, en vez de en cada tecla — evita repetir el `.where()` y
  /// la reconstrucción de tarjetas en cada pulsación.
  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _userSearchController.dispose();
    _wsSearchController.dispose();
    _agentSearchController.dispose();
    _knowledgeSearchController.dispose();
    _workflowSearchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

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
      final results = await Future.wait([
        _repository.getStats(token),
        _repository.listUsers(token),
        _repository.listWorkspaces(token),
        _repository.listAgents(token),
        _repository.listAdminConnections(token),
        _repository.listAdminKnowledge(token),
        _repository.listAdminWorkflows(token),
        _repository.getPlatformSettings(token),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _users = results[1] as List<Map<String, dynamic>>;
        _workspaces = results[2] as List<Map<String, dynamic>>;
        _agents = results[3] as List<Map<String, dynamic>>;
        _connections = results[4] as List<Map<String, dynamic>>;
        _knowledge = results[5] as List<Map<String, dynamic>>;
        _workflows = results[6] as List<Map<String, dynamic>>;
        _platformSettings = results[7] as Map<String, dynamic>;
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
        _error = _tx('admin.error_generic', 'No se pudo cargar Admin');
        _loading = false;
      });
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

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      _showMessage(successMessage);
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('admin.error_generic', 'No se pudo completar la acción'),
        isError: true,
      );
    }
  }

  Future<bool> _confirm(
    String title,
    String body, {
    String? confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel ?? _tx('common.delete', 'Eliminar')),
          ),
        ],
      ),
    );
    return result == true;
  }

  List<String> _ownersOf(List<Map<String, dynamic>> items) {
    final owners = <String>{};
    for (final item in items) {
      final o = _ownerOf(item);
      if (o.isNotEmpty) owners.add(o);
    }
    final list = owners.toList()..sort();
    return list;
  }

  // ── Filtros ───────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _userSearchController.text.trim().toLowerCase();
    return _users.where((u) {
      if (q.isNotEmpty) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        if (!email.contains(q) && !username.contains(q)) return false;
      }
      if (_userRole.isNotEmpty &&
          (u['role'] ?? 'standard').toString() != _userRole)
        return false;
      if (_userActive.isNotEmpty) {
        final active = u['is_active'] != 0 && u['is_active'] != false;
        if (active != (_userActive == 'true')) return false;
      }
      if (_userVerified.isNotEmpty) {
        final verified = u['is_verified'] != 0 && u['is_verified'] != false;
        if (verified != (_userVerified == 'true')) return false;
      }
      return true;
    }).toList();
  }

  int get _usersActiveFilterCount =>
      (_userRole.isNotEmpty ? 1 : 0) +
      (_userActive.isNotEmpty ? 1 : 0) +
      (_userVerified.isNotEmpty ? 1 : 0);

  void _openUsersFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => setState(() {
        _userRole = '';
        _userActive = '';
        _userVerified = '';
      }),
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('admin.filter_role', 'Rol'),
          value: _userRole,
          options: [
            ('', _tx('admin.all_roles', 'Todos los roles')),
            ('admin', _tx('admin.role_admin', 'Admin')),
            ('standard', _tx('admin.role_standard', 'Estándar')),
          ],
          onChanged: (v) {
            setState(() => _userRole = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('admin.filter_status', 'Estado'),
          value: _userActive,
          options: [
            ('', _tx('admin.all_status', 'Cualquier estado')),
            ('true', _tx('admin.status_active', 'Activos')),
            ('false', _tx('admin.status_blocked', 'Bloqueados')),
          ],
          onChanged: (v) {
            setState(() => _userActive = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('admin.filter_verified', 'Verificación'),
          value: _userVerified,
          options: [
            ('', _tx('admin.all_verification', 'Cualquier verificación')),
            ('true', _tx('admin.verified_yes', 'Verificados')),
            ('false', _tx('admin.verified_no', 'Sin verificar')),
          ],
          onChanged: (v) {
            setState(() => _userVerified = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredWorkspaces {
    final q = _wsSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _workspaces;
    return _workspaces.where((ws) {
      final name = (ws['name'] ?? '').toString().toLowerCase();
      final creator = (ws['created_by'] ?? '').toString().toLowerCase();
      return name.contains(q) || creator.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAgents {
    final q = _agentSearchController.text.trim().toLowerCase();
    return _agents.where((a) {
      if (q.isNotEmpty) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        final id = (a['id'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !id.contains(q)) return false;
      }
      if (_agentOwner.isNotEmpty && _ownerOf(a) != _agentOwner) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredConnections {
    if (_connOwner.isEmpty) return _connections;
    return _connections.where((c) => _ownerOf(c) == _connOwner).toList();
  }

  List<Map<String, dynamic>> get _filteredKnowledge {
    final q = _knowledgeSearchController.text.trim().toLowerCase();
    return _knowledge.where((k) {
      if (q.isNotEmpty) {
        final title = (k['title'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(k).toLowerCase();
        if (!title.contains(q) && !owner.contains(q)) return false;
      }
      if (_knowledgeType.isNotEmpty &&
          (k['type'] ?? '').toString() != _knowledgeType)
        return false;
      if (_knowledgeOwner.isNotEmpty && _ownerOf(k) != _knowledgeOwner)
        return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredWorkflows {
    final q = _workflowSearchController.text.trim().toLowerCase();
    return _workflows.where((w) {
      if (q.isNotEmpty) {
        final name = (w['name'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(w).toLowerCase();
        if (!name.contains(q) && !owner.contains(q)) return false;
      }
      if (_workflowOwner.isNotEmpty && _ownerOf(w) != _workflowOwner)
        return false;
      return true;
    }).toList();
  }

  // ── Acciones: usuarios ───────────────────────────────────────────────

  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final active = user['is_active'] != 0 && user['is_active'] != false;
    await _run(
      () => _repository.setUserActive(token, username, !active),
      active
          ? _tx('admin.toast_user_blocked', 'Usuario bloqueado')
          : _tx('admin.toast_user_unblocked', 'Usuario desbloqueado'),
    );
  }

  Future<void> _promoteUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final ok = await _confirm(
      _tx('admin.action_make_admin', 'Hacer admin'),
      _tx(
        'admin.confirm_promote',
        '¿Ascender a "{username}" a administrador?',
      ).replaceAll('{username}', username),
      confirmLabel: _tx('admin.action_make_admin', 'Hacer admin'),
    );
    if (!ok) return;
    await _run(
      () => _repository.patchUser(token, username, role: 'admin'),
      _tx('admin.toast_user_promoted', 'Usuario ascendido a admin'),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_user',
        '¿Seguro que quieres eliminar al usuario "{username}"?',
      ).replaceAll('{username}', username),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteUser(token, username),
      _tx('admin.toast_user_deleted', 'Usuario eliminado'),
    );
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserEditDialog(user: user, tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _repository.patchUser(
        token,
        username,
        role: result['role'] as String?,
        isActive: result['is_active'] as bool?,
        password: (result['password'] as String?)?.isEmpty == true
            ? null
            : result['password'] as String?,
      ),
      _tx('admin.toast_user_updated', 'Usuario actualizado'),
    );
  }

  Future<void> _openCreateUserDialog() async {
    final token = _token;
    if (token == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserCreateDialog(tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _repository.createUser(
        token,
        email: result['email'] as String,
        password: result['password'] as String,
        displayName: result['display_name'] as String?,
        role: result['role'] as String,
      ),
      _tx('admin.toast_user_created', 'Usuario creado'),
    );
  }

  // ── Acciones: grupos (workspaces) ────────────────────────────────────

  Future<void> _toggleWorkspaceStatus(Map<String, dynamic> ws) async {
    final token = _token;
    if (token == null) return;
    final id = (ws['id'] ?? '').toString();
    final name = (ws['name'] ?? id).toString();
    final isDisabled = (ws['status'] ?? 'active').toString() == 'disabled';
    final newStatus = isDisabled ? 'active' : 'disabled';
    if (!isDisabled) {
      final ok = await _confirm(
        _tx('admin.action_deactivate', 'Desactivar'),
        _tx(
          'admin.confirm_deactivate_workspace',
          '¿Desactivar el grupo "{name}"?',
        ).replaceAll('{name}', name),
        confirmLabel: _tx('admin.action_deactivate', 'Desactivar'),
      );
      if (!ok) return;
    }
    await _run(
      () => _repository.setWorkspaceStatus(token, id, newStatus),
      isDisabled
          ? _tx('admin.toast_ws_reactivated', 'Grupo reactivado')
          : _tx('admin.toast_ws_deactivated', 'Grupo desactivado'),
    );
  }

  Future<void> _deleteWorkspace(Map<String, dynamic> ws) async {
    final token = _token;
    if (token == null) return;
    final id = (ws['id'] ?? '').toString();
    final name = (ws['name'] ?? id).toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_workspace',
        '¿Seguro que quieres eliminar el grupo "{name}"?',
      ).replaceAll('{name}', name),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteWorkspace(token, id),
      _tx('admin.toast_ws_deleted', 'Grupo eliminado'),
    );
  }

  // ── Acciones: agentes ────────────────────────────────────────────────

  Future<void> _openEditAgentDialog(Map<String, dynamic> agent) async {
    final token = _token;
    if (token == null) return;
    final id = (agent['id'] ?? '').toString();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AgentEditDialog(agent: agent, tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _repository.updateAgent(token, id, result),
      _tx('admin.toast_agent_updated', 'Agente actualizado'),
    );
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final token = _token;
    if (token == null) return;
    final id = (agent['id'] ?? '').toString();
    final name = (agent['name'] ?? id).toString();
    final scope = (agent['scope'] ?? 'private').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_agent',
        '¿Seguro que quieres eliminar el agente "{name}"?',
      ).replaceAll('{name}', name),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAgent(token, id, scope: scope),
      _tx('admin.toast_agent_deleted', 'Agente eliminado'),
    );
  }

  // ── Acciones: conexiones / knowledge / workflows ─────────────────────

  Future<void> _deleteConnection(Map<String, dynamic> conn) async {
    final token = _token;
    if (token == null) return;
    final id = (conn['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_connection',
        '¿Seguro que quieres eliminar esta conexión?',
      ),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAdminConnection(token, id),
      _tx('admin.toast_connection_deleted', 'Conexión eliminada'),
    );
  }

  Future<void> _deleteKnowledge(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_knowledge',
        '¿Seguro que quieres eliminar este elemento?',
      ),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAdminKnowledge(token, id),
      _tx('admin.toast_knowledge_deleted', 'Elemento eliminado'),
    );
  }

  Future<void> _deleteWorkflow(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_workflow',
        '¿Seguro que quieres eliminar esta orquestación?',
      ),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAdminWorkflow(token, id),
      _tx('admin.toast_workflow_deleted', 'Orquestación eliminada'),
    );
  }

  // ── Acciones: cambiar propietario (agentes/conexiones/knowledge/orquest.) ─

  Future<void> _changeOwner(
    Map<String, dynamic> item,
    String resourceType,
  ) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final currentOwner = _ownerOf(item);
    final usernames =
        _users
            .map((u) => (u['username'] ?? '').toString())
            .where((u) => u.isNotEmpty && u != currentOwner)
            .toList()
          ..sort();
    final newOwner = await showDialog<String>(
      context: context,
      builder: (context) => _OwnerPickerDialog(
        currentOwner: currentOwner,
        usernames: usernames,
        tx: _tx,
      ),
    );
    if (newOwner == null || newOwner.isEmpty) return;
    await _run(
      () => _repository.setResourceOwner(token, resourceType, id, newOwner),
      _tx('admin.toast_owner_changed', 'Propietario actualizado'),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
    double width = 170,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: options
            .map(
              (opt) => DropdownMenuItem(
                value: opt.$1,
                child: Text(opt.$2, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next == null) return;
          onChanged(next);
        },
      ),
    );
  }

  /// Diálogo de filtros compartido por las pestañas Agentes/Conexiones/
  /// Orquestaciones, que solo filtran por propietario.
  void _openOwnerFilterDialog({
    required List<String> owners,
    required String currentOwner,
    required ValueChanged<String> onChanged,
  }) {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => onChanged(''),
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('admin.table_owner', 'Propietario'),
          value: currentOwner,
          width: 360,
          options: [
            ('', _tx('admin.all_owners', 'Todos los propietarios')),
            ...owners.map((o) => (o, o)),
          ],
          onChanged: (v) {
            onChanged(v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  void _openKnowledgeFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => setState(() {
        _knowledgeType = '';
        _knowledgeOwner = '';
      }),
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('admin.filter_type', 'Tipo'),
          value: _knowledgeType,
          width: 360,
          options: [
            ('', _tx('admin.all_types', 'Todos los tipos')),
            ('url', 'URL'),
            ('document', _tx('admin.type_document', 'Documento')),
          ],
          onChanged: (v) {
            setState(() => _knowledgeType = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('admin.table_owner', 'Propietario'),
          value: _knowledgeOwner,
          width: 360,
          options: [
            ('', _tx('admin.all_owners', 'Todos los propietarios')),
            ..._ownersOf(_knowledge).map((o) => (o, o)),
          ],
          onChanged: (v) {
            setState(() => _knowledgeOwner = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  Widget _emptyCard(String text) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
  );

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
                  Text(
                    _tx('admin.error_title', 'Error cargando Admin'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final tabLabels = [
      _tx('admin.tab_general', 'General'),
      _tx('admin.tab_users', 'Usuarios'),
      _tx('admin.tab_workspaces', 'Grupos'),
      _tx('admin.tab_agents', 'Agentes'),
      _tx('admin.tab_connections', 'Conexiones'),
      _tx('admin.tab_knowledge', 'Conocimiento'),
      _tx('admin.tab_workflows', 'Orquestaciones'),
      _tx('admin.tab_config', 'Configuración'),
    ];
    final section = _tabIds[_tabController.index];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
        ),
        Expanded(child: _buildSection(section)),
      ],
    );
  }

  Widget _buildSection(String section) {
    return switch (section) {
      'users' => _buildUsersTab(),
      'workspaces' => _buildWorkspacesTab(),
      'agents' => _buildAgentsTab(),
      'connections' => _buildConnectionsTab(),
      'knowledge' => _buildKnowledgeTab(),
      'workflows' => _buildWorkflowsTab(),
      'config' => _buildConfigTab(),
      _ => _buildGeneralTab(),
    };
  }

  // ── Tab: General ──────────────────────────────────────────────────────

  Widget _buildGeneralTab() {
    final stats = _stats;
    if (stats == null) return const Center(child: Text('—'));
    final statItems = [
      (_tx('admin.stat_users', 'Usuarios'), stats.usersTotal),
      (_tx('admin.stat_active', 'Activos'), stats.usersActive),
      (_tx('admin.stat_verified', 'Verificados'), stats.usersVerified),
      (_tx('admin.stat_connections', 'Conexiones'), stats.connectionsTotal),
      (_tx('admin.stat_knowledge', 'Knowledge'), stats.knowledgeTotal),
      (_tx('admin.stat_workflows', 'Orquestaciones'), stats.workflowsTotal),
      (
        _tx('admin.stat_conversations', 'Conversaciones'),
        stats.conversationsTotal,
      ),
      (_tx('admin.stat_agents_public', 'Agentes públicos'), stats.agentsPublic),
      (
        _tx('admin.stat_agents_private', 'Agentes privados'),
        stats.agentsPrivate,
      ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: ResponsiveSliverMasonryGrid(
              density: ResponsiveCardDensity.compact,
              itemCount: statItems.length,
              itemBuilder: (context, index) =>
                  _statCard(statItems[index].$1, statItems[index].$2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int value) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Usuarios ────────────────────────────────────────────────────

  /// Cuadrícula con construcción perezosa compartida por las pestañas
  /// tabulares de Admin: antes cada una era un `ListView` con
  /// `...items.map(cardBuilder)`, que construye TODAS las tarjetas de golpe
  /// en cada rebuild (cada tecla en el buscador) en vez de solo las
  /// visibles — con cientos de usuarios/recursos eso escala mal.
  /// Buscador ocupando toda la fila, con los botones de acción juntos en la
  /// fila de abajo — mismo patrón en todas las pestañas con listado.
  Widget _toolbar({Widget? search, required List<Widget> buttons}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (search != null) ...[search, const SizedBox(height: 10)],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: buttons,
        ),
      ],
    );
  }

  Widget _buildFilterableList({
    required Widget toolbar,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) itemBuilder,
    required String emptyText,
  }) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(child: toolbar),
          ),
          if (items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(child: _emptyCard(emptyText)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: items.length,
                itemBuilder: (context, index) => itemBuilder(items[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final showNewUser =
        (_platformSettings?['registration'] ?? 'open').toString() == 'closed';
    return _buildFilterableList(
      items: _filteredUsers,
      itemBuilder: _buildUserCard,
      emptyText: _tx('admin.users_empty', 'Sin usuarios para ese filtro'),
      toolbar: _toolbar(
        search: TextField(
          controller: _userSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.users_search_hint',
              'Buscar por email o usuario',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          if (showNewUser)
            IconButton.filled(
              onPressed: _openCreateUserDialog,
              icon: const Icon(Icons.add),
              tooltip: _tx('admin.users_new_btn', 'Nuevo usuario'),
            ),
          IconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount: _usersActiveFilterCount,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: _openUsersFiltersDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final email = (user['email'] ?? user['username'] ?? '').toString();
    final role = (user['role'] ?? 'standard').toString();
    final isAdmin = role == 'admin';
    final active = user['is_active'] != 0 && user['is_active'] != false;
    final verified = user['is_verified'] != 0 && user['is_verified'] != false;
    final tokens = _asInt(user['tokens_in']) + _asInt(user['tokens_out']);
    final date = _fmtDate(user['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(
                  isAdmin
                      ? _tx('admin.role_admin', 'Admin')
                      : _tx('admin.role_standard', 'Estándar'),
                  isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                ),
                _badge(
                  active
                      ? _tx('admin.status_active', 'Activo')
                      : _tx('admin.status_blocked', 'Bloqueado'),
                  active ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
                _badge(
                  verified
                      ? _tx('admin.verified_yes', 'Verificado')
                      : _tx('admin.verified_no', 'Sin verificar'),
                  verified ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 6),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditUserDialog(user),
                ),
                ActionIconButton(
                  icon: active
                      ? Icons.block_outlined
                      : Icons.check_circle_outline,
                  tooltip: active
                      ? _tx('admin.action_block', 'Bloquear')
                      : _tx('admin.action_unblock', 'Desbloquear'),
                  onPressed: () => _toggleUserActive(user),
                ),
                if (!isAdmin)
                  ActionIconButton(
                    icon: Icons.shield_outlined,
                    tooltip: _tx('admin.action_make_admin', 'Hacer admin'),
                    onPressed: () => _promoteUser(user),
                  ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteUser(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Grupos ──────────────────────────────────────────────────────

  Widget _buildWorkspacesTab() {
    return _buildFilterableList(
      items: _filteredWorkspaces,
      itemBuilder: _buildWorkspaceCard,
      emptyText: _tx('admin.ws_empty', 'Sin grupos'),
      toolbar: _toolbar(
        search: TextField(
          controller: _wsSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.ws_search_hint',
              'Buscar por nombre o creador',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          IconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard(Map<String, dynamic> ws) {
    final name = (ws['name'] ?? ws['id'] ?? '').toString();
    final disabled = (ws['status'] ?? 'active').toString() == 'disabled';
    final creator = (ws['created_by'] ?? '—').toString();
    final members = _asInt(ws['member_count']);
    final connections = _asInt(ws['connections_count']);
    final agents = _asInt(ws['agents_count']);
    final knowledge = _asInt(ws['knowledge_count']);
    final tokens = _asInt(ws['tokens_in']) + _asInt(ws['tokens_out']);
    final date = _fmtDate(ws['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _badge(
                  disabled
                      ? _tx('admin.status_disabled', 'Desactivado')
                      : _tx('admin.status_active', 'Activo'),
                  disabled ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_tx('admin.table_creator', 'Creador')}: $creator · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(
                  '${_tx('admin.table_members', 'Miembros')}: $members',
                  const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.tab_connections', 'Conexiones')}: $connections',
                  const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.tab_agents', 'Agentes')}: $agents',
                  const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.tab_knowledge', 'Conocimiento')}: $knowledge',
                  const Color(0xFF64748B),
                ),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: disabled
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                  tooltip: disabled
                      ? _tx('admin.action_reactivate', 'Reactivar')
                      : _tx('admin.action_deactivate', 'Desactivar'),
                  onPressed: () => _toggleWorkspaceStatus(ws),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteWorkspace(ws),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Agentes ─────────────────────────────────────────────────────

  Widget _buildAgentsTab() {
    return _buildFilterableList(
      items: _filteredAgents,
      itemBuilder: _buildAgentCard,
      emptyText: _tx('admin.agents_empty', 'Sin agentes'),
      toolbar: _toolbar(
        search: TextField(
          controller: _agentSearchController,
          decoration: InputDecoration(
            labelText: _tx('admin.agents_search_hint', 'Buscar agente'),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          IconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount: _agentOwner.isNotEmpty ? 1 : 0,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: () => _openOwnerFilterDialog(
              owners: _ownersOf(_agents),
              currentOwner: _agentOwner,
              onChanged: (v) => setState(() => _agentOwner = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final name = (agent['name'] ?? agent['id'] ?? '').toString();
    final type = (agent['agent_type'] ?? '—').toString();
    final owner = _ownerOf(agent);
    final connId = (agent['connection_id'] ?? '').toString();
    final scope = (agent['scope'] ?? 'private').toString();
    final tokens = _asInt(agent['tokens_in']) + _asInt(agent['tokens_out']);
    final date = _fmtDate(agent['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${owner.isEmpty ? '—' : owner}${connId.isEmpty ? '' : ' · $connId'} · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(type, const Color(0xFF64748B)),
                _badge(scope, labelColor(scope)),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditAgentDialog(agent),
                ),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(agent, 'agent'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteAgent(agent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Conexiones ──────────────────────────────────────────────────

  Widget _buildConnectionsTab() {
    return _buildFilterableList(
      items: _filteredConnections,
      itemBuilder: _buildAdminConnectionCard,
      emptyText: _tx('admin.connections_empty', 'Sin conexiones'),
      toolbar: _toolbar(
        buttons: [
          IconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount: _connOwner.isNotEmpty ? 1 : 0,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: () => _openOwnerFilterDialog(
              owners: _ownersOf(_connections),
              currentOwner: _connOwner,
              onChanged: (v) => setState(() => _connOwner = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminConnectionCard(Map<String, dynamic> conn) {
    final name = (conn['name'] ?? conn['id'] ?? '').toString();
    final type = (conn['type'] ?? '—').toString();
    final owner = _ownerOf(conn);
    final tokens = _asInt(conn['tokens_in']) + _asInt(conn['tokens_out']);
    final date = _fmtDate(conn['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${owner.isEmpty ? '—' : owner} · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(type, const Color(0xFF64748B)),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(conn, 'connection'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteConnection(conn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Conocimiento ────────────────────────────────────────────────

  Widget _buildKnowledgeTab() {
    return _buildFilterableList(
      items: _filteredKnowledge,
      itemBuilder: _buildAdminKnowledgeCard,
      emptyText: _tx('admin.knowledge_empty', 'Sin elementos de Knowledge'),
      toolbar: _toolbar(
        search: TextField(
          controller: _knowledgeSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.knowledge_search_hint',
              'Buscar por título o propietario',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          IconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount:
                (_knowledgeType.isNotEmpty ? 1 : 0) +
                (_knowledgeOwner.isNotEmpty ? 1 : 0),
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: _openKnowledgeFiltersDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminKnowledgeCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? item['id'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final owner = _ownerOf(item);
    final chars = _asInt(item['char_count']);
    final date = _fmtDate(item['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${owner.isEmpty ? '—' : owner} · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(
                  type == 'url'
                      ? 'URL'
                      : _tx('admin.type_document', 'Documento'),
                  type == 'url'
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.table_chars', 'Caracteres')}: $chars',
                  const Color(0xFF0891B2),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(item, 'knowledge'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteKnowledge(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Orquestaciones ──────────────────────────────────────────────

  Widget _buildWorkflowsTab() {
    return _buildFilterableList(
      items: _filteredWorkflows,
      itemBuilder: _buildAdminWorkflowCard,
      emptyText: _tx('admin.workflows_empty', 'Sin orquestaciones'),
      toolbar: _toolbar(
        search: TextField(
          controller: _workflowSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.workflows_search_hint',
              'Buscar orquestación',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          IconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount: _workflowOwner.isNotEmpty ? 1 : 0,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: () => _openOwnerFilterDialog(
              owners: _ownersOf(_workflows),
              currentOwner: _workflowOwner,
              onChanged: (v) => setState(() => _workflowOwner = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWorkflowCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? item['id'] ?? '').toString();
    final owner = _ownerOf(item);
    final steps = _asInt(item['steps']);
    final date = _fmtDate(item['updated_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${owner.isEmpty ? '—' : owner} · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _badge(
              '${_tx('admin.table_steps', 'Pasos')}: $steps',
              const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(item, 'workflow'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteWorkflow(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Configuración ───────────────────────────────────────────────

  Widget _buildConfigTab() {
    final token = _token;
    if (token == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: _AdminConfigTab(
          key: ValueKey(_platformSettings.hashCode),
          repository: _repository,
          token: token,
          initialSettings: _platformSettings ?? const {},
          tx: _tx,
          onSaved: (settings) => setState(() => _platformSettings = settings),
        ),
      ),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────

class _OwnerPickerDialog extends StatefulWidget {
  const _OwnerPickerDialog({
    required this.currentOwner,
    required this.usernames,
    required this.tx,
  });

  final String currentOwner;
  final List<String> usernames;
  final String Function(String path, String fallback) tx;

  @override
  State<_OwnerPickerDialog> createState() => _OwnerPickerDialogState();
}

class _OwnerPickerDialogState extends State<_OwnerPickerDialog> {
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return AlertDialog(
      title: Text(tx('admin.change_owner_title', 'Cambiar propietario')),
      content: SizedBox(
        width: dialogContentWidth(context, 360),
        child: Autocomplete<String>(
          optionsBuilder: (value) {
            if (value.text.isEmpty) return widget.usernames;
            final q = value.text.toLowerCase();
            return widget.usernames.where((u) => u.toLowerCase().contains(q));
          },
          onSelected: (value) => setState(() => _selected = value),
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: tx('admin.change_owner_hint', 'Nuevo propietario'),
                helperText: tx('admin.change_owner_current', 'Actual: {owner}')
                    .replaceAll(
                      '{owner}',
                      widget.currentOwner.isEmpty ? '—' : widget.currentOwner,
                    ),
              ),
              onChanged: (v) => setState(() => _selected = v),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _selected.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.trim()),
          child: Text(tx('admin.action_change_owner', 'Cambiar propietario')),
        ),
      ],
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({required this.user, required this.tx});

  final Map<String, dynamic> user;
  final String Function(String path, String fallback) tx;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late String _role;
  late bool _active;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _role = (widget.user['role'] ?? 'standard').toString();
    _active =
        widget.user['is_active'] != 0 && widget.user['is_active'] != false;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = (widget.user['email'] ?? widget.user['username'] ?? '')
        .toString();
    return AlertDialog(
      title: Text(widget.tx('admin.edit_user_title', 'Editar usuario')),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_role', 'Rol'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'standard',
                  child: Text(widget.tx('admin.role_standard', 'Estándar')),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text(widget.tx('admin.role_admin', 'Admin')),
                ),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'standard'),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.tx('admin.field_active', 'Activo')),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.tx(
                  'admin.field_password_optional',
                  'Nueva contraseña (opcional)',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'role': _role,
            'is_active': _active,
            'password': _passwordController.text.trim(),
          }),
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}

class _UserCreateDialog extends StatefulWidget {
  const _UserCreateDialog({required this.tx});

  final String Function(String path, String fallback) tx;

  @override
  State<_UserCreateDialog> createState() => _UserCreateDialogState();
}

class _UserCreateDialogState extends State<_UserCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'standard';

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.of(context).pop({
      'email': _emailController.text.trim(),
      'display_name': _displayNameController.text.trim(),
      'password': _passwordController.text.trim(),
      'role': _role,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('admin.create_user_title', 'Nuevo usuario')),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: widget.tx('admin.field_email', 'Email'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? widget.tx('agents.name_required', 'Obligatorio')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'admin.field_display_name',
                    'Nombre para mostrar',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.tx('admin.field_password', 'Contraseña'),
                ),
                validator: (value) => (value == null || value.trim().length < 4)
                    ? widget.tx('agents.name_required', 'Obligatorio')
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(
                  labelText: widget.tx('admin.field_role', 'Rol'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text(widget.tx('admin.role_standard', 'Estándar')),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text(widget.tx('admin.role_admin', 'Admin')),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'standard'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.tx('common.create', 'Crear')),
        ),
      ],
    );
  }
}

class _AgentEditDialog extends StatefulWidget {
  const _AgentEditDialog({required this.agent, required this.tx});

  final Map<String, dynamic> agent;
  final String Function(String path, String fallback) tx;

  @override
  State<_AgentEditDialog> createState() => _AgentEditDialogState();
}

class _AgentEditDialogState extends State<_AgentEditDialog> {
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _connectionController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _promptController = TextEditingController();
  String _agentType = 'generic';

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.agent['name'] ?? '').toString();
    _agentType = (widget.agent['agent_type'] ?? 'generic').toString();
    _modelController.text = (widget.agent['model'] ?? '').toString();
    _connectionController.text = (widget.agent['connection_id'] ?? '')
        .toString();
    _temperatureController.text = (widget.agent['temperature'] ?? 0.7)
        .toString();
    _promptController.text = (widget.agent['system_prompt'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _connectionController.dispose();
    _temperatureController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop({
      'name': name,
      'agent_type': _agentType,
      'model': _modelController.text.trim(),
      'connection_id': _connectionController.text.trim().isEmpty
          ? null
          : _connectionController.text.trim(),
      'temperature': double.tryParse(_temperatureController.text.trim()) ?? 0.7,
      'system_prompt': _promptController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('admin.edit_agent_title', 'Editar agente')),
      content: SizedBox(
        width: dialogContentWidth(context, 540),
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_name', 'Nombre'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _agentType,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_type', 'Tipo'),
              ),
              items: const [
                DropdownMenuItem(value: 'claude', child: Text('claude')),
                DropdownMenuItem(value: 'openai', child: Text('openai')),
                DropdownMenuItem(value: 'github', child: Text('github')),
                DropdownMenuItem(value: 'ollama', child: Text('ollama')),
                DropdownMenuItem(value: 'generic', child: Text('generic')),
              ],
              onChanged: (v) => setState(() => _agentType = v ?? 'generic'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_model', 'Modelo'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _connectionController,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_connection', 'Conexión'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _temperatureController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_temperature', 'Temperatura'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _promptController,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                labelText: widget.tx(
                  'admin.field_system_prompt',
                  'Prompt de sistema',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}

// ── Tab: Configuración (widget con estado propio) ────────────────────

class _AdminConfigTab extends StatefulWidget {
  const _AdminConfigTab({
    required this.repository,
    required this.token,
    required this.initialSettings,
    required this.tx,
    required this.onSaved,
    super.key,
  });

  final AdminRepository repository;
  final String token;
  final Map<String, dynamic> initialSettings;
  final String Function(String path, String fallback) tx;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<_AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<_AdminConfigTab> {
  late String _registration;
  late final TextEditingController _maxUsersController;
  late final TextEditingController _maxSessionsController;
  late final TextEditingController _logRetentionController;
  late final TextEditingController _stressConcurrencyController;
  late bool _emailVerify;
  late bool _guestEnabled;
  late bool _landingEnabled;
  late bool _billingEnabled;
  late bool _oauthGoogle;
  late bool _oauthApple;
  late bool _oauthMicrosoft;
  late bool _autoUpdate;

  bool _saving = false;
  String? _saveMsg;
  bool _checkingUpdate = false;
  String? _checkResult;
  bool? _checkOk;
  String? _autoUpdateResult;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialSettings;
    var mode = (cfg['registration'] ?? 'open').toString();
    if (mode == 'invite') mode = 'closed';
    _registration = mode;
    _maxUsersController = TextEditingController(
      text: (cfg['max_users'] ?? 0).toString(),
    );
    _maxSessionsController = TextEditingController(
      text: (cfg['max_concurrent_sessions'] ?? 0).toString(),
    );
    _logRetentionController = TextEditingController(
      text: (cfg['log_retention_days'] ?? 30).toString(),
    );
    _stressConcurrencyController = TextEditingController(
      text: (cfg['stress_max_concurrency'] ?? 0).toString(),
    );
    _emailVerify = cfg['email_verify'] == true;
    _guestEnabled = cfg['guest_enabled'] != false;
    _landingEnabled = cfg['landing_enabled'] == true;
    _billingEnabled = cfg['billing_enabled'] == true;
    _oauthGoogle = cfg['oauth_google_enabled'] != false;
    _oauthApple = cfg['oauth_apple_enabled'] != false;
    _oauthMicrosoft = cfg['oauth_microsoft_enabled'] != false;
    _autoUpdate = cfg['auto_update_enabled'] != false;
  }

  @override
  void dispose() {
    _maxUsersController.dispose();
    _maxSessionsController.dispose();
    _logRetentionController.dispose();
    _stressConcurrencyController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveMsg = null;
    });
    try {
      final payload = {
        'registration': _registration,
        'max_users': int.tryParse(_maxUsersController.text.trim()) ?? 0,
        'max_concurrent_sessions':
            int.tryParse(_maxSessionsController.text.trim()) ?? 0,
        'email_verify': _emailVerify,
        'guest_enabled': _guestEnabled,
        'landing_enabled': _landingEnabled,
        'billing_enabled': _billingEnabled,
        'log_retention_days':
            int.tryParse(_logRetentionController.text.trim()) ?? 30,
        'stress_max_concurrency':
            int.tryParse(_stressConcurrencyController.text.trim()) ?? 0,
        'oauth_google_enabled': _oauthGoogle,
        'oauth_apple_enabled': _oauthApple,
        'oauth_microsoft_enabled': _oauthMicrosoft,
      };
      final updated = await widget.repository.updatePlatformSettings(
        widget.token,
        payload,
      );
      widget.onSaved(updated);
      if (!mounted) return;
      setState(
        () => _saveMsg = _tx('admin.config_saved', 'Configuración guardada'),
      );
      _showMessage(_tx('admin.config_saved', 'Configuración guardada'));
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('admin.error_generic', 'No se pudo completar la acción'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAutoUpdate(bool desired) async {
    setState(() {
      _autoUpdate = desired;
      _autoUpdateResult = null;
    });
    try {
      final result = await widget.repository.setAutoUpdate(
        widget.token,
        desired,
      );
      final enabled = result['auto_update_enabled'] == true;
      if (!mounted) return;
      setState(() {
        _autoUpdate = enabled;
        _autoUpdateResult = enabled
            ? _tx('admin.config_auto_update_on', 'Auto-actualización activada')
            : _tx(
                'admin.config_auto_update_off',
                'Auto-actualización desactivada',
              );
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _autoUpdate = !desired;
        _autoUpdateResult = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoUpdate = !desired;
        _autoUpdateResult = _tx(
          'admin.error_generic',
          'No se pudo completar la acción',
        );
      });
    }
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _checkResult = null;
      _checkOk = null;
    });
    try {
      final data = await widget.repository.checkUpdate(widget.token);
      if (!mounted) return;
      if (data['checked'] != true) {
        setState(() {
          _checkResult = _tx(
            'admin.config_check_error',
            'No se pudo comprobar actualizaciones',
          );
          _checkOk = null;
        });
      } else if (data['update_available'] == true) {
        setState(() {
          _checkResult =
              _tx(
                    'admin.config_update_available',
                    'Actualización disponible: {latest} (actual: {current})',
                  )
                  .replaceAll('{latest}', '${data['latest_version']}')
                  .replaceAll('{current}', '${data['current_version']}');
          _checkOk = false;
        });
      } else {
        setState(() {
          _checkResult = _tx(
            'admin.config_up_to_date',
            'Al día (versión {version})',
          ).replaceAll('{version}', '${data['current_version']}');
          _checkOk = true;
        });
      }
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _checkResult = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _checkResult = _tx(
          'admin.config_check_error',
          'No se pudo comprobar actualizaciones',
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(_tx('admin.config_section_registration', 'Registro'), [
          DropdownButtonFormField<String>(
            initialValue: _registration,
            decoration: InputDecoration(
              labelText: _tx('admin.config_mode_label', 'Modo'),
            ),
            items: [
              DropdownMenuItem(
                value: 'open',
                child: Text(_tx('admin.config_mode_open', 'Abierto')),
              ),
              DropdownMenuItem(
                value: 'closed',
                child: Text(_tx('admin.config_mode_closed', 'Cerrado')),
              ),
            ],
            onChanged: (v) => setState(() => _registration = v ?? 'open'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _maxUsersController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  '${_tx('admin.config_max_users', 'Máx. usuarios')} ${_tx('admin.config_unlimited_hint', '(0=∞)')}',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx(
                'admin.config_email_verify',
                'Verificar email al registrarse',
              ),
            ),
            value: _emailVerify,
            onChanged: (v) => setState(() => _emailVerify = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx('admin.config_guest_enabled', 'Acceso como invitado'),
            ),
            value: _guestEnabled,
            onChanged: (v) => setState(() => _guestEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx(
                'admin.config_landing_enabled',
                'Landing de presentación en "/"',
              ),
            ),
            subtitle: Text(
              _tx(
                'admin.config_landing_hint',
                'Si está desactivado, "/" redirige directo a /login/',
              ),
            ),
            value: _landingEnabled,
            onChanged: (v) => setState(() => _landingEnabled = v),
          ),
        ]),
        _sectionCard(_tx('admin.config_section_sessions', 'Sesiones'), [
          TextField(
            controller: _maxSessionsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  '${_tx('admin.config_max_sessions', 'Máx. sesiones simultáneas')} ${_tx('admin.config_unlimited_hint', '(0=∞)')}',
            ),
          ),
        ]),
        _sectionCard(
          _tx('admin.config_section_centinel', 'Centinel · Stress Test'),
          [
            TextField(
              controller: _stressConcurrencyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    '${_tx('admin.config_stress_concurrency', 'Concurrencia máx.')} ${_tx('admin.config_unlimited_500_hint', '(0=∞, máx 500)')}',
              ),
            ),
          ],
        ),
        _sectionCard(_tx('admin.config_section_logs', 'Logs'), [
          TextField(
            controller: _logRetentionController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  '${_tx('admin.config_retention', 'Retención')} ${_tx('admin.config_days_hint', '(días)')}',
            ),
          ),
        ]),
        _sectionCard(_tx('admin.config_section_billing', 'Facturación'), [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx(
                'admin.config_billing_enabled',
                'Activar planes de suscripción',
              ),
            ),
            value: _billingEnabled,
            onChanged: (v) => setState(() => _billingEnabled = v),
          ),
        ]),
        _sectionCard(_tx('admin.config_section_oauth', 'Login social'), [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx('admin.config_oauth_google', 'Mostrar botón de Google'),
            ),
            value: _oauthGoogle,
            onChanged: (v) => setState(() => _oauthGoogle = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx('admin.config_oauth_apple', 'Mostrar botón de Apple'),
            ),
            value: _oauthApple,
            onChanged: (v) => setState(() => _oauthApple = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx('admin.config_oauth_microsoft', 'Mostrar botón de Microsoft'),
            ),
            value: _oauthMicrosoft,
            onChanged: (v) => setState(() => _oauthMicrosoft = v),
          ),
        ]),
        _sectionCard(_tx('admin.config_section_updates', 'Actualizaciones'), [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx(
                'admin.config_auto_update',
                'Actualización automática (Watchtower)',
              ),
            ),
            value: _autoUpdate,
            onChanged: _toggleAutoUpdate,
          ),
          if (_autoUpdateResult != null)
            Text(
              _autoUpdateResult!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _checkingUpdate ? null : _checkUpdate,
            child: Text(
              _checkingUpdate
                  ? _tx('admin.config_check_update_loading', 'Buscando...')
                  : _tx(
                      'admin.config_check_update_btn',
                      'Buscar actualización',
                    ),
            ),
          ),
          if (_checkResult != null) ...[
            const SizedBox(height: 6),
            Text(
              _checkResult!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _checkOk == null
                    ? null
                    : (_checkOk == true
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706)),
              ),
            ),
          ],
        ]),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? _tx('admin.config_save_loading', 'Guardando...')
                    : _tx('admin.config_save_btn', 'Guardar configuración'),
              ),
            ),
            if (_saveMsg != null)
              Text(_saveMsg!, style: const TextStyle(color: Color(0xFF059669))),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
