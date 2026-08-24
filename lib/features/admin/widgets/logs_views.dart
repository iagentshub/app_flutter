part of '../pages/logs_page.dart';

extension _LogsViews on _LogsPageViewState {
  Widget _buildSummary() {
    if (_summaryLoading) {
      return const Center(child: IAgentsLoadingMark());
    }
    if (_summaryError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_summaryError!),
            const SizedBox(height: 12),
            PrimaryButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh),
              label: Text(_tx('common.retry')),
            ),
          ],
        ),
      );
    }
    if (_summary.isEmpty) {
      return Center(child: Text(_tx('logs.empty')));
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 170,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _summary.length,
        itemBuilder: (context, index) {
          final day = _summary[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openDay(day.date),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: FncFonts.size15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tx('logs.lines_count').replaceAll('{n}', '${day.lines}'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tx('logs.be_summary')
                          .replaceAll('{warn}', '${day.beWarnings}')
                          .replaceAll('{err}', '${day.beErrors}'),
                    ),
                    Text(
                      _tx('logs.fe_summary')
                          .replaceAll('{warn}', '${day.feWarnings}')
                          .replaceAll('{err}', '${day.feErrors}'),
                    ),
                    Text(
                      _tx('logs.audit_count')
                          .replaceAll('{n}', '${day.audits}'),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (day.errors > 0)
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: FncColors.materialRed.shade700,
                          ),
                        if (day.warnings > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: FncColors.materialOrange.shade800,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewer() {
    final data = _logsPage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _queryController,
          decoration: InputDecoration(
            labelText: _tx('logs.search_message_label'),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onSubmitted: (_) => _loadViewer(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final category in _categories)
              ChoiceChip(
                label: Text(
                  category.isEmpty ? _tx('logs.all') : _categoryLabel(category),
                ),
                selected: _category == category,
                onSelected: (_) => _filterByCategory(category),
              ),
            AppIconButton.outlined(
              onPressed: _exporting ? null : _exportCsv,
              tooltip: _tx('logs.export_csv'),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: IAgentsLoadingMark(),
                    )
                  : const Icon(Icons.download_outlined),
            ),
            FilterButton(
              activeCount: _logsActiveFilterCount,
              tooltip: _tx('common.filters'),
              onPressed: _openLogsFiltersDialog,
            ),
            if (_dateFilter != null)
              ActionChip(
                label: Text(
                  _tx('logs.day_filter_chip')
                      .replaceAll('{date}', _dateFilter!),
                ),
                onPressed: _clearDateFilter,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_viewerError != null) ...[
          Text(
            _viewerError!,
            style: TextStyle(color: FncColors.materialRed.shade700),
          ),
          const SizedBox(height: 10),
        ],
        if (_viewerLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: IAgentsLoadingMark()),
          )
        else if (data == null)
          Text(_tx('logs.viewer_hint'))
        else ...[
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(_tx('logs.col_date'))),
                    DataColumn(label: Text(_tx('logs.col_time'))),
                    DataColumn(label: Text(_tx('logs.col_level'))),
                    DataColumn(label: Text(_tx('logs.col_category'))),
                    DataColumn(label: Text(_tx('logs.col_outcome'))),
                    DataColumn(label: Text(_tx('logs.col_ip'))),
                    DataColumn(label: Text(_tx('logs.col_user'))),
                    DataColumn(label: Text(_tx('logs.col_service'))),
                    DataColumn(label: Text(_tx('logs.col_action'))),
                    DataColumn(label: Text(_tx('logs.col_resource'))),
                    DataColumn(label: Text(_tx('logs.col_message'))),
                    DataColumn(label: Text(_tx('logs.col_details'))),
                  ],
                  rows: data.items.map((entry) {
                    final resource = [
                      entry.resourceType,
                      entry.resourceId,
                    ].where((value) => value.isNotEmpty).join(':');
                    return DataRow(
                      cells: [
                        DataCell(Text(entry.date)),
                        DataCell(Text(entry.time)),
                        DataCell(
                          Text(
                            entry.level,
                            style: TextStyle(
                              color: _levelColor(entry.level),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(Text(_categoryLabel(entry.category))),
                        DataCell(
                          Text(entry.outcome.isEmpty ? '-' : entry.outcome),
                        ),
                        DataCell(
                          InkWell(
                            onTap: () => _filterByIp(entry.ip),
                            child: Text(entry.ip),
                          ),
                        ),
                        DataCell(
                          InkWell(
                            onTap: () => _filterByUsername(entry.username),
                            child: Text(entry.username),
                          ),
                        ),
                        DataCell(Text(entry.source)),
                        DataCell(
                          Text(entry.action.isEmpty ? '-' : entry.action),
                        ),
                        DataCell(Text(resource.isEmpty ? '-' : resource)),
                        DataCell(
                          SizedBox(
                            width: 420,
                            child: Tooltip(
                              message: entry.summary,
                              child: Text(
                                entry.summary,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 320,
                            child: Tooltip(
                              message: entry.detailsJson,
                              child: Text(
                                entry.detailsJson.isEmpty
                                    ? '-'
                                    : entry.detailsJson,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                _tx('logs.page_total')
                    .replaceAll('{page}', '${data.page}')
                    .replaceAll(
                      '{pages}',
                      '${data.pages == 0 ? 1 : data.pages}',
                    )
                    .replaceAll('{total}', '${data.total}'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  SecondaryButton(
                    onPressed: data.page > 1
                        ? () => _loadViewer(page: data.page - 1)
                        : null,
                    child: Text(_tx('logs.prev')),
                  ),
                  SecondaryButton(
                    onPressed: data.page < data.pages
                        ? () => _loadViewer(page: data.page + 1)
                        : null,
                    child: Text(_tx('logs.next')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}
