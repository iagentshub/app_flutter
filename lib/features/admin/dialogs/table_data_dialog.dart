part of '../pages/metadata_page.dart';

class _TableDataDialog extends StatefulWidget {
  const _TableDataDialog({
    required this.repository,
    required this.token,
    required this.table,
    required this.tx,
  });

  final MetadataRepository repository;
  final String token;
  final MetadataTable table;
  final String Function(String path) tx;

  @override
  State<_TableDataDialog> createState() => _TableDataDialogState();
}

class _TableDataDialogState extends State<_TableDataDialog> {
  final _queryController = TextEditingController();
  MetadataPageData? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.tableData(
        widget.token,
        tableName: widget.table.name,
        page: _page,
        query: _queryController.text,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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
        _error = widget.tx('admin.error_generic');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.table.name,
                      style: const TextStyle(
                        fontSize: FncFonts.size16,
                        fontWeight: FontWeight.w700,
                        fontFamily: FncFonts.monospace,
                      ),
                    ),
                  ),
                  AppIconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: widget.tx('common.actions.close'),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        labelText: widget.tx('admin.metadata_search_in_table'),
                      ),
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    onPressed: () {
                      _page = 1;
                      _load();
                    },
                    child: Text(widget.tx('common.search')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: FncColors.materialRed.shade700),
                )
              else if (data != null) ...[
                Flexible(
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: data.columns
                            .map((c) => DataColumn(label: Text(c)))
                            .toList(),
                        rows: data.rows.isEmpty
                            ? [
                                DataRow(
                                  cells: data.columns.isEmpty
                                      ? [
                                          DataCell(
                                            Text(
                                              widget.tx(
                                                'admin.metadata_no_data',
                                              ),
                                            ),
                                          ),
                                        ]
                                      : List.generate(
                                          data.columns.length,
                                          (i) => DataCell(
                                            Text(
                                              i == 0
                                                  ? widget.tx(
                                                      'admin.metadata_no_data',
                                                    )
                                                  : '',
                                            ),
                                          ),
                                        ),
                                ),
                              ]
                            : data.rows
                                  .map(
                                    (row) => DataRow(
                                      cells: [
                                        for (
                                          var i = 0;
                                          i < data.columns.length;
                                          i++
                                        )
                                          DataCell(
                                            Text(
                                              i < row.length
                                                  ? (row[i] ?? '')
                                                  : '',
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.tx('admin.table_count')}: ${data.total} · ${data.page}/${data.pages == 0 ? 1 : data.pages}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        SecondaryButton(
                          onPressed: data.page > 1
                              ? () {
                                  _page = data.page - 1;
                                  _load();
                                }
                              : null,
                          child: const Text('‹'),
                        ),
                        SecondaryButton(
                          onPressed: data.page < data.pages
                              ? () {
                                  _page = data.page + 1;
                                  _load();
                                }
                              : null,
                          child: const Text('›'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
