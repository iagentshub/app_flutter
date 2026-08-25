import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/utils/file_size_formatter.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../repositories/metadata_repository.dart';
import 'logs_page.dart';

part '../dialogs/table_data_dialog.dart';

String _fmtBytes(int bytes) {
  if (bytes <= 0) return '—';
  return formatFileSize(bytes);
}

/// Página "Sistema": Logs + Tablas de la base de datos, igual que
/// Pantalla de metadatos del sistema.
class MetadataPage extends StatefulWidget {
  const MetadataPage({super.key});

  @override
  State<MetadataPage> createState() => _MetadataPageState();
}

class _MetadataPageState extends State<MetadataPage>
    with SingleTickerProviderStateMixin {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final MetadataRepository _repository;
  late final TabController _tabController;
  late final TranslatedTexts _t;
  final TextEditingController _tableSearchController = TextEditingController();

  List<MetadataTable> _tables = const [];
  bool _tablesLoading = true;
  String? _tablesError;
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  String _tx(String path) => _t.text(path);

  String? get _token => _services.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _repository = MetadataRepository(apiClient: _services.apiClient);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: _services.localeController,
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
        _tablesError = _tx('common.no_session');
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
        _tablesError = _tx('admin.metadata_error_tables');
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
    await showAppDialog<void>(
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
      _tx('admin.metadata_tab_logs'),
      _tx('admin.metadata_tab_tables'),
    ];
    return Column(
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
        // IndexedStack (no un switch por índice) para no perder los filtros y
        // datos ya cargados del visor de logs al cambiar de pestaña y volver.
        Expanded(
          child: IndexedStack(
            index: _tabController.index,
            children: [
              LogsPageView(
                apiClient: _services.apiClient,
                sessionController: _services.sessionController,
                localeController: _services.localeController,
              ),
              _buildTablesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTablesTab() {
    if (_tablesLoading) return const Center(child: IAgentsLoadingMark());
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
                  PrimaryButton.icon(
                    onPressed: _loadTables,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry')),
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
                    labelText: _tx('admin.metadata_search_table'),
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
                    label: Text(_tx('admin.metadata_col_table')),
                    onSort: _onSort,
                  ),
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_rows')),
                    numeric: true,
                    onSort: _onSort,
                  ),
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_cols')),
                    numeric: true,
                    onSort: _onSort,
                  ),
                  DataColumn(
                    label: Text(_tx('admin.metadata_col_size')),
                    numeric: true,
                    onSort: _onSort,
                  ),
                ],
                rows: items
                    .map(
                      (table) => DataRow(
                        onSelectChanged: (_) => _openTableDialog(table),
                        cells: [
                          DataCell(Text(table.name, style: FncFonts.code)),
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
