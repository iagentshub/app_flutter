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

  /// Entradas que comparten todos los filtros del panel: el texto del buscador
  /// y los selectores. Sirven de clave de memoización — los getters se leían
  /// dentro de `build`, así que recorrían y copiaban la colección completa en
  /// cada repintado.
  List<Object?> get _adminFilterDeps => [
    _exploreSearchController.text,
    _userRole,
    _userActive,
    _userVerified,
    _agentOwner,
    _connOwner,
    _knowledgeType,
    _knowledgeOwner,
    _workflowOwner,
    _llmOrchestrationOwner,
    _skillOwner,
    _memoryOwner,
    _promptOwner,
    _toolOwner,
  ];

  // ── Filtros ───────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredUsers =>
      _filteredUsersMemo.of([_users, ..._adminFilterDeps], () {
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
      });

  int get _usersActiveFilterCount =>
      (_userRole.isNotEmpty ? 1 : 0) +
      (_userActive.isNotEmpty ? 1 : 0) +
      (_userVerified.isNotEmpty ? 1 : 0);

  void _openUsersFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => _setExploreFilter(() {
        _userRole = '';
        _userActive = '';
        _userVerified = '';
      }),
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('admin.filter_role'),
          value: _userRole,
          options: [
            ('', _tx('admin.all_roles')),
            ('admin', _tx('admin.role_admin')),
            ('standard', _tx('admin.role_standard')),
          ],
          onChanged: (v) {
            _setExploreFilter(() => _userRole = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('admin.filter_status'),
          value: _userActive,
          options: [
            ('', _tx('admin.all_status')),
            ('true', _tx('admin.status_active')),
            ('false', _tx('admin.status_blocked')),
          ],
          onChanged: (v) {
            _setExploreFilter(() => _userActive = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('admin.filter_verified'),
          value: _userVerified,
          options: [
            ('', _tx('admin.all_verification')),
            ('true', _tx('admin.verified_yes')),
            ('false', _tx('admin.verified_no')),
          ],
          onChanged: (v) {
            _setExploreFilter(() => _userVerified = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredGroups =>
      _filteredGroupsMemo.of([_groups, ..._adminFilterDeps], () {
        final q = _exploreSearchController.text.trim().toLowerCase();
        if (q.isEmpty) return _groups;
        return _groups.where((group) {
          final name = (group['name'] ?? '').toString().toLowerCase();
          final creator = (group['created_by_username'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(q) || creator.contains(q);
        }).toList();
      });

  List<Map<String, dynamic>> get _filteredAgents => _filteredAgentsMemo.of(
    [_agents, ..._adminFilterDeps],
    () {
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
    },
  );

  List<Map<String, dynamic>> get _filteredConnections =>
      _filteredConnectionsMemo.of([_connections, ..._adminFilterDeps], () {
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
      });

  List<Map<String, dynamic>> get _filteredKnowledge =>
      _filteredKnowledgeMemo.of([_knowledge, ..._adminFilterDeps], () {
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
      });

  List<Map<String, dynamic>> get _filteredWorkflows =>
      _filteredWorkflowsMemo.of([_workflows, ..._adminFilterDeps], () {
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
      });

  List<Map<String, dynamic>> get _filteredSkills =>
      _filteredSkillsMemo.of([_skills, ..._adminFilterDeps], () {
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
      });

  List<Map<String, dynamic>> get _filteredPrompts =>
      _filteredPromptsMemo.of([_prompts, ..._adminFilterDeps], () {
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
      });

  List<Map<String, dynamic>> get _filteredTools =>
      _filteredToolsMemo.of([_tools, ..._adminFilterDeps], () {
        final q = _exploreSearchController.text.trim().toLowerCase();
        return _tools.where((t) {
          if (q.isNotEmpty) {
            final name = (t['name'] ?? '').toString().toLowerCase();
            final owner = _ownerOf(t).toLowerCase();
            if (!name.contains(q) && !owner.contains(q)) return false;
          }
          if (_toolOwner.isNotEmpty && _ownerOf(t) != _toolOwner) {
            return false;
          }
          return true;
        }).toList();
      });

  List<Map<String, dynamic>> get _filteredMemories =>
      _filteredMemoriesMemo.of([_memories, ..._adminFilterDeps], () {
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
      });

  // ── Acciones: usuarios ───────────────────────────────────────────────
}
