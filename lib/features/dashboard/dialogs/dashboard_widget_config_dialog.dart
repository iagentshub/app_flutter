part of '../pages/dashboard_page.dart';

class _DashboardWidgetEditResult {
  const _DashboardWidgetEditResult({required this.config, required this.size});

  final DashboardWidgetConfig config;
  final DashboardWidgetSize size;
}

class _WidgetConfigDialog extends StatefulWidget {
  const _WidgetConfigDialog({
    required this.widgetType,
    required this.initialConfig,
    required this.initialSize,
    required this.tx,
  });

  final String widgetType;
  final DashboardWidgetConfig initialConfig;
  final DashboardWidgetSize initialSize;
  final DashboardTx tx;

  @override
  State<_WidgetConfigDialog> createState() => _WidgetConfigDialogState();
}

class _WidgetConfigDialogState extends State<_WidgetConfigDialog> {
  late DashboardWidgetConfig _draft;
  late DashboardWidgetSize _size;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialConfig;
    _size = widget.initialSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget
            .tx('configure_widget_title')
            .replaceAll(
              '{{name}}',
              dashboardWidgetTitle(widget.widgetType, widget.tx),
            ),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sizeSelector(),
              const SizedBox(height: 16),
              _buildFields(),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel')),
        ),
        PrimaryButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_DashboardWidgetEditResult(config: _draft, size: _size)),
          child: Text(widget.tx('common.save')),
        ),
      ],
    );
  }

  Widget _buildFields() {
    final tx = widget.tx;
    switch (widget.widgetType) {
      case 'summary':
        return _checklist(
          kSummaryItems,
          _draft.items ?? kSummaryItems,
          (item) => summaryItemLabel(item, tx),
          (next) => setState(() => _draft = _draft.copyWith(items: next)),
        );
      case 'token-usage':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pillRow(
              tx('group_by_label'),
              {
                'connection': tx('group_by_connection'),
                'agent': tx('group_by_agent'),
              },
              _draft.groupBy ?? 'connection',
              (v) => setState(() => _draft = _draft.copyWith(groupBy: v)),
            ),
            const SizedBox(height: 12),
            _pillRow(
              tx('connections_label'),
              {'all': tx('scope_all'), 'personal': tx('scope_personal')},
              _draft.scope ?? 'all',
              (v) => setState(() => _draft = _draft.copyWith(scope: v)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label'),
              [3, 5, 10],
              _draft.limit ?? 5,
              (v) => setState(() => _draft = _draft.copyWith(limit: v)),
            ),
          ],
        );
      case 'conn-status':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pillRow(
              tx('connections_label'),
              {'all': tx('scope_all'), 'personal': tx('scope_personal')},
              _draft.scope ?? 'all',
              (v) => setState(() => _draft = _draft.copyWith(scope: v)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label'),
              [2, 4, 6, 8],
              _draft.pageSize ?? 4,
              (v) => setState(() => _draft = _draft.copyWith(pageSize: v)),
            ),
          ],
        );
      case 'recent':
        return _numberRow(
          tx('quantity_label'),
          [2, 4, 6, 8],
          _draft.pageSize ?? 4,
          (v) => setState(() => _draft = _draft.copyWith(pageSize: v)),
        );
      case 'recent-conversations':
        return _numberRow(
          tx('quantity_label'),
          [3, 5, 8],
          _draft.limit ?? 5,
          (value) => setState(() => _draft = _draft.copyWith(limit: value)),
        );
      case 'activity':
        return _numberRow(
          tx('period_days_label'),
          [7, 14, 30],
          _draft.days ?? 14,
          (v) => setState(() => _draft = _draft.copyWith(days: v)),
        );
      case 'feed':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _checklist(
              kFeedTypes,
              _draft.types ?? kFeedTypes,
              (type) => feedTypeLabel(type, tx),
              (next) => setState(() => _draft = _draft.copyWith(types: next)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label'),
              [4, 8, 15, 25],
              _draft.limit ?? 8,
              (v) => setState(() => _draft = _draft.copyWith(limit: v)),
            ),
          ],
        );
      case 'quick-actions':
        return _checklist(
          kQuickActionItems,
          _draft.items ?? kQuickActionItems,
          (item) => switch (item) {
            'agent' => tx('action_agent'),
            'connection' => tx('action_connection'),
            'workflow' => tx('action_workflow'),
            _ => tx('action_knowledge'),
          },
          (next) => setState(() => _draft = _draft.copyWith(items: next)),
        );
      case 'token-kpi':
        return _pillRow(
          tx('period_label'),
          {
            'today': tx('period_today'),
            '7d': tx('period_7d'),
            '30d': tx('period_30d'),
          },
          _draft.period ?? '7d',
          (value) => setState(() => _draft = _draft.copyWith(period: value)),
        );
      case 'recent-resources':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _checklist(
              kRecentResourceTypes,
              _draft.types ?? kRecentResourceTypes,
              (type) => switch (type) {
                'agent' => tx('feed_agent'),
                'skill' => tx('feed_skill'),
                'workflow' => tx('summary_workflows'),
                _ => tx('feed_knowledge'),
              },
              (next) => setState(() => _draft = _draft.copyWith(types: next)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label'),
              [4, 6, 10],
              _draft.limit ?? 6,
              (value) => setState(() => _draft = _draft.copyWith(limit: value)),
            ),
          ],
        );
      case 'agent-health':
        return _numberRow(
          tx('quantity_label'),
          [2, 4, 6],
          _draft.limit ?? 4,
          (value) => setState(() => _draft = _draft.copyWith(limit: value)),
        );
      default:
        return Text(tx('no_widget_options'));
    }
  }

  Widget _sizeSelector() {
    final definition = dashboardWidgetDefinition(widget.widgetType);
    final sizes = definition?.supportedSizes ?? {DashboardWidgetSize.medium};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tx('size_label'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in sizes)
              ChoiceChip(
                label: Text(switch (size) {
                  DashboardWidgetSize.compact => widget.tx('size_compact'),
                  DashboardWidgetSize.medium => widget.tx('size_medium'),
                  DashboardWidgetSize.wide => widget.tx('size_wide'),
                  DashboardWidgetSize.full => widget.tx('size_full'),
                }),
                selected: _size == size,
                onSelected: (_) => setState(() => _size = size),
              ),
          ],
        ),
      ],
    );
  }

  Widget _checklist(
    List<String> options,
    List<String> selected,
    String Function(String) label,
    void Function(List<String>) onChanged,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.map((option) {
        final checked = selected.contains(option);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: checked,
          title: Text(label(option)),
          onChanged: (value) {
            final next = [...selected];
            if (value == true && !next.contains(option)) next.add(option);
            if (value == false) next.remove(option);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }

  Widget _pillRow(
    String label,
    Map<String, String> options,
    String value,
    void Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.entries.map((entry) {
            return ChoiceChip(
              label: Text(entry.value),
              selected: value == entry.key,
              onSelected: (_) => onChanged(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _numberRow(
    String label,
    List<int> options,
    int value,
    void Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            return ChoiceChip(
              label: Text('$option'),
              selected: value == option,
              onSelected: (_) => onChanged(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}
