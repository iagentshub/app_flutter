import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../repositories/metadata_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import 'logs_page.dart';

String _fmtBytes(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

/// Página "Sistema": Logs + Tablas de la base de datos, igual que
/// /admin/metadata/ en frontend_vanilla (título "Sistema" en el nav).
class MetadataPage extends StatefulWidget {
  const MetadataPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<MetadataPage> createState() => _MetadataPageState();
}

class _MetadataPageState extends State<MetadataPage>
    with SingleTickerProviderStateMixin {
  late final MetadataRepository _repository;
  late final TabController _tabController;
  late final TranslatedTexts _t;
  final TextEditingController _tableSearchController = TextEditingController();

  List<MetadataTable> _tables = const [];
  bool _tablesLoading = true;
  String? _tablesError;
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String? get _token => widget.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _repository = MetadataRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _loadTables();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tableSearchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _tablesError = _tx('common.no_session', 'No hay sesión activa');
        _tablesLoading = false;
      });
      return;
    }
    setState(() {
      _tablesLoading = true;
      _tablesError = null;
    });
    try {
      final tables = await _repository.listTables(token);
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _tablesLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _tablesError = error.message;
        _tablesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tablesError = _tx(
          'admin.metadata_error_tables',
          'No se pudieron cargar las tablas',
        );
        _tablesLoading = false;
      });
    }
  }

  List<MetadataTable> get _filteredTables {
    final q = _tableSearchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _tables
        : _tables.where((t) => t.name.toLowerCase().contains(q)).toList();
    final sorted = [...filtered]
      ..sort((a, b) {
        int cmp;
        switch (_sortColumnIndex) {
          case 0:
            cmp = a.name.compareTo(b.name);
          case 2:
            cmp = a.colCount.compareTo(b.colCount);
          case 3:
            cmp = a.sizeBytes.compareTo(b.sizeBytes);
          default:
            cmp = a.rows.compareTo(b.rows);
        }
        return _sortAscending ? cmp : -cmp;
      });
    return sorted;
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Future<void> _openTableDialog(MetadataTable table) async {
    final token = _token;
    if (token == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _TableDataDialog(
        repository: _repository,
        token: token,
        table: table,
        tx: _tx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabLabels = [
      _tx('admin.metadata_tab_logs', 'Logs'),
      _tx('admin.metadata_tab_tables', 'Tablas'),
    ];
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
        // IndexedStack (no un switch por índice) para no perder los filtros y
        // datos ya cargados del visor de logs al cambiar de pestaña y volver.
        Expanded(
          child: IndexedStack(
            index: _tabController.index,
            children: [
              LogsPageView(
                apiClient: widget.apiClient,
                sessionController: widget.sessionController,
                localeController: widget.localeController,
              ),
              _buildTablesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTablesTab() {
    if (_tablesLoading) return const Center(child: CircularProgressIndicator());
    if (_tablesError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tablesError!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadTables,
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

    final items = _filteredTables;
    return RefreshIndicator(
      onRefresh: _loadTables,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _tableSearchController,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'admin.metadata_search_table',
                      'Buscar tabla',
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(
                '${items.length}/${_tables.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_table', 'Tabla')),
                    onSort: _onSort,
                  ),
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_rows', 'Filas')),
                    numeric: true,
                    onSort: _onSort,
                  ),
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_cols', 'Columnas')),
                    numeric: true,
                    onSort: _onSort,
                  ),
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_size', 'Peso')),
                    numeric: true,
                    onSort: _onSort,
                  ),
                ],
                rows: items
                    .map(
                      (table) => DataRow(
                        onSelectChanged: (_) => _openTableDialog(table),
                        cells: [
                          DataCell(
                            Text(
                              table.name,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(Text('${table.rows}')),
                          DataCell(Text('${table.colCount}')),
                          DataCell(Text(_fmtBytes(table.sizeBytes))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  final String Function(String path, String fallback) tx;

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
        _error = widget.tx(
          'admin.error_generic',
          'No se pudo completar la acción',
        );
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                        labelText: widget.tx(
                          'admin.metadata_search_in_table',
                          'Buscar en tabla',
                        ),
                      ),
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      _page = 1;
                      _load();
                    },
                    child: Text(widget.tx('common.search', 'Buscar')),
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
                Text(_error!, style: TextStyle(color: Colors.red.shade700))
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
                                                'Sin datos',
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
                                                      'Sin datos',
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
                      '${widget.tx('admin.table_count', 'Total')}: ${data.total} · ${data.page}/${data.pages == 0 ? 1 : data.pages}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: data.page > 1
                              ? () {
                                  _page = data.page - 1;
                                  _load();
                                }
                              : null,
                          child: const Text('‹'),
                        ),
                        OutlinedButton(
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
