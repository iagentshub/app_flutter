part of '../pages/admin_page.dart';

extension _AdminPageView on _AdminPageState {
  Widget _buildPage(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();

    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('admin.error_title', 'Error cargando Admin'),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
          ),
        ],
      );
    }

    final tabLabels = [
      _tx('admin.tab_general', 'General'),
      _tx('admin.tab_users', 'Usuarios'),
      _tx('admin.tab_groups', 'Grupos'),
      _tx('admin.tab_agents', 'Agentes'),
      _tx('admin.tab_connections', 'Conexiones'),
      _tx('admin.tab_knowledge', 'Conocimiento'),
      _tx('admin.tab_workflows', 'Orquestaciones'),
      _tx('admin.tab_config', 'Configuración'),
    ];
    final section = _AdminPageState._tabIds[_tabController.index];

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
      'groups' => _buildGroupsTab(),
      'agents' => _buildAgentsTab(),
      'connections' => _buildConnectionsTab(),
      'knowledge' => _buildKnowledgeTab(),
      'workflows' => _buildWorkflowsTab(),
      'config' => _buildConfigTab(),
      _ => _buildGeneralTab(),
    };
  }

  // ── Tab: General ──────────────────────────────────────────────────────
}
