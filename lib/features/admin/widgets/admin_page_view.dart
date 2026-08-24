part of '../pages/admin_page.dart';

extension _AdminPageView on _AdminPageState {
  Widget _buildPage(BuildContext context) {
    final tabLabels = [
      _tx('admin.tab_general'),
      _tx('admin.tab_explore'),
      _tx('admin.tab_official'),
      _tx('admin.tab_config'),
    ];
    final section = _AdminPageState._tabIds[_tabController.index];

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: FncColors.transparent,
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

    return IAgentsAsyncView(
      key: const Key('admin-loading-overlay'),
      loading: _loading,
      localeController: _services.localeController,
      error: _error,
      errorTitle: _tx('admin.error_title'),
      retryLabel: _tx('common.retry'),
      onRetry: _load,
      child: content,
    );
  }

  Widget _buildSection(String section) {
    return switch (section) {
      'explore' => _buildExploreTab(),
      'official' => OfficialSourcesAdminTab(
        apiClient: _services.apiClient,
        token: _token ?? '',
        tx: _tx,
      ),
      'config' => _buildConfigTab(),
      _ => _buildGeneralTab(),
    };
  }

  // ── Tab: General ──────────────────────────────────────────────────────
}
