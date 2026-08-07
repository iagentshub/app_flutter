part of '../pages/admin_page.dart';

extension _AdminFilterDialogs on _AdminPageState {
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
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _users.where((u) {
      if (q.isNotEmpty) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        if (!email.contains(q) && !username.contains(q)) return false;
      }
      if (_userRole.isNotEmpty &&
          (u['role'] ?? 'standard').toString() != _userRole) {
        return false;
      }
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
      onClear: () => refresh(() {
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
            refresh(() => _userRole = v);
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
            refresh(() => _userActive = v);
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
            refresh(() => _userVerified = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredGroups {
    final q = _exploreSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _groups;
    return _groups.where((group) {
      final name = (group['name'] ?? '').toString().toLowerCase();
      final creator = (group['created_by_username'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(q) || creator.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAgents {
    final q = _exploreSearchController.text.trim().toLowerCase();
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
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _connections.where((connection) {
      if (q.isNotEmpty) {
        final name = (connection['name'] ?? '').toString().toLowerCase();
        final id = (connection['id'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(connection).toLowerCase();
        if (!name.contains(q) && !id.contains(q) && !owner.contains(q)) {
          return false;
        }
      }
      return _connOwner.isEmpty || _ownerOf(connection) == _connOwner;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredKnowledge {
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _knowledge.where((k) {
      if (q.isNotEmpty) {
        final title = (k['title'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(k).toLowerCase();
        if (!title.contains(q) && !owner.contains(q)) return false;
      }
      if (_knowledgeType.isNotEmpty &&
          (k['type'] ?? '').toString() != _knowledgeType) {
        return false;
      }
      if (_knowledgeOwner.isNotEmpty && _ownerOf(k) != _knowledgeOwner) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredWorkflows {
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _workflows.where((w) {
      if (q.isNotEmpty) {
        final name = (w['name'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(w).toLowerCase();
        if (!name.contains(q) && !owner.contains(q)) return false;
      }
      if (_workflowOwner.isNotEmpty && _ownerOf(w) != _workflowOwner) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSkills {
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _skills.where((s) {
      if (q.isNotEmpty) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(s).toLowerCase();
        if (!name.contains(q) && !owner.contains(q)) return false;
      }
      if (_skillOwner.isNotEmpty && _ownerOf(s) != _skillOwner) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPrompts {
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _prompts.where((p) {
      if (q.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final alias = (p['alias'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(p).toLowerCase();
        if (!name.contains(q) && !alias.contains(q) && !owner.contains(q)) {
          return false;
        }
      }
      if (_promptOwner.isNotEmpty && _ownerOf(p) != _promptOwner) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredMemories {
    final q = _exploreSearchController.text.trim().toLowerCase();
    return _memories.where((m) {
      if (q.isNotEmpty) {
        final filename = (m['filename'] ?? '').toString().toLowerCase();
        final owner = _ownerOf(m).toLowerCase();
        if (!filename.contains(q) && !owner.contains(q)) return false;
      }
      if (_memoryOwner.isNotEmpty && _ownerOf(m) != _memoryOwner) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Acciones: usuarios ───────────────────────────────────────────────
}
