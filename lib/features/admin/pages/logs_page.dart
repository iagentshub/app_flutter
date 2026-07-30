import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/logs/log_models.dart';
import '../repositories/logs_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/filter_button.dart';

class LogsPageView extends StatefulWidget {
  const LogsPageView({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<LogsPageView> createState() => _LogsPageViewState();
}

const _levels = ['', 'DEBUG', 'INFO', 'OK', 'WARNING', 'ERROR'];
const _sources = ['', 'BE', 'FE'];

class _LogsPageViewState extends State<LogsPageView> {
  late final LogsRepository _repository;
  late final TranslatedTexts _t;

  bool _viewerTab = false;

  List<LogsSummaryDay> _summary = const [];
  bool _summaryLoading = true;
  String? _summaryError;

  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _queryController = TextEditingController();
  String _level = '';
  String _source = '';
  String? _dateFilter;

  LogsPage? _logsPage;
  bool _viewerLoading = false;
  bool _exporting = false;
  String? _viewerError;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = LogsRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _loadSummary();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _queryController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadSummary() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _summaryError = _tx('common.no_session', 'No hay sesión activa');
        _summaryLoading = false;
      });
      return;
    }
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final summary = await _repository.summary(token);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _summaryLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _summaryError = error.message;
        _summaryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summaryError = _tx(
          'logs.error_summary',
          'No se pudo cargar el resumen de logs',
        );
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadViewer({int page = 1}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(
        () => _viewerError = _tx('common.no_session', 'No hay sesión activa'),
      );
      return;
    }
    setState(() {
      _viewerLoading = true;
      _viewerError = null;
    });
    try {
      final result = await _repository.list(
        token,
        dateFrom: _dateFilter,
        dateTo: _dateFilter,
        ip: _ipController.text.trim(),
        username: _usernameController.text.trim(),
        query: _queryController.text.trim(),
        level: _level,
        source: _source,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _logsPage = result;
        _viewerLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _viewerError = error.message;
        _viewerLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _viewerError = _tx('logs.error_load', 'No se pudieron cargar los logs');
        _viewerLoading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final csv = await _repository.exportCsv(
        token,
        dateFrom: _dateFilter,
        dateTo: _dateFilter,
        ip: _ipController.text.trim(),
        username: _usernameController.text.trim(),
        query: _queryController.text.trim(),
        level: _level,
        source: _source,
      );
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      await FilePicker.platform.saveFile(
        dialogTitle: _tx('logs.save_dialog_title', 'Guardar logs'),
        fileName: 'logs_$stamp.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('logs.error_export', 'No se pudo exportar el CSV'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
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

  int get _logsActiveFilterCount =>
      (_level.isNotEmpty ? 1 : 0) +
      (_source.isNotEmpty ? 1 : 0) +
      (_ipController.text.isNotEmpty ? 1 : 0) +
      (_usernameController.text.isNotEmpty ? 1 : 0);

  void _openLogsFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('logs.filter_btn', 'Filtrar'),
      onApply: _loadViewer,
      onClear: () {
        setState(() {
          _level = '';
          _source = '';
        });
        _ipController.clear();
        _usernameController.clear();
      },
      buildFields: (setDialogState) => [
        DropdownButtonFormField<String>(
          initialValue: _level,
          decoration: InputDecoration(
            labelText: _tx('logs.level_label', 'Nivel'),
          ),
          items: _levels
              .map(
                (l) => DropdownMenuItem(
                  value: l,
                  child: Text(l.isEmpty ? _tx('logs.all', 'Todos') : l),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _level = value ?? '');
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _source,
          decoration: InputDecoration(
            labelText: _tx('logs.service_label', 'Servicio'),
          ),
          items: _sources
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.isEmpty ? _tx('logs.all', 'Todos') : s),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _source = value ?? '');
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ipController,
          decoration: InputDecoration(labelText: _tx('logs.ip_label', 'IP')),
          onChanged: (_) => setDialogState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: _tx('logs.user_label', 'Usuario'),
          ),
          onChanged: (_) => setDialogState(() {}),
        ),
      ],
    );
  }

  void _filterByIp(String ip) {
    _ipController.text = ip;
    setState(() => _viewerTab = true);
    _loadViewer();
  }

  void _filterByUsername(String username) {
    _usernameController.text = username;
    setState(() => _viewerTab = true);
    _loadViewer();
  }

  void _openDay(String date) {
    _ipController.clear();
    _usernameController.clear();
    _queryController.clear();
    setState(() {
      _dateFilter = date;
      _level = '';
      _source = '';
      _viewerTab = true;
    });
    _loadViewer();
  }

  void _clearDateFilter() {
    setState(() => _dateFilter = null);
    _loadViewer();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red.shade700;
      case 'WARNING':
        return Colors.orange.shade800;
      case 'OK':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(_tx('logs.tab_summary', 'Resumen')),
                icon: const Icon(Icons.dashboard_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(_tx('logs.tab_viewer', 'Visor')),
                icon: const Icon(Icons.list_alt_outlined),
              ),
            ],
            selected: {_viewerTab},
            onSelectionChanged: (selection) {
              final wantsViewer = selection.first;
              setState(() => _viewerTab = wantsViewer);
              if (wantsViewer && _logsPage == null) _loadViewer();
            },
          ),
          const SizedBox(height: 14),
          Expanded(child: _viewerTab ? _buildViewer() : _buildSummary()),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_summaryLoading)
      return const Center(child: CircularProgressIndicator());
    if (_summaryError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_summaryError!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh),
              label: Text(_tx('common.retry', 'Reintentar')),
            ),
          ],
        ),
      );
    }
    if (_summary.isEmpty) {
      return Center(
        child: Text(_tx('logs.empty', 'Sin datos de logs todavía')),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 150,
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tx(
                        'logs.lines_count',
                        'Líneas: {n}',
                      ).replaceAll('{n}', '${day.lines}'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tx('logs.be_summary', 'BE: {warn} warn · {err} err')
                          .replaceAll('{warn}', '${day.beWarnings}')
                          .replaceAll('{err}', '${day.beErrors}'),
                    ),
                    Text(
                      _tx('logs.fe_summary', 'FE: {warn} warn · {err} err')
                          .replaceAll('{warn}', '${day.feWarnings}')
                          .replaceAll('{err}', '${day.feErrors}'),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (day.errors > 0)
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                        if (day.warnings > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: Colors.orange.shade800,
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
            labelText: _tx('logs.search_message_label', 'Buscar en mensaje'),
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
            IconButton.outlined(
              onPressed: _exporting ? null : _exportCsv,
              tooltip: _tx('logs.export_csv', 'Exportar CSV'),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
            FilterButton(
              activeCount: _logsActiveFilterCount,
              tooltip: _tx('common.filters', 'Filtros'),
              onPressed: _openLogsFiltersDialog,
            ),
            if (_dateFilter != null)
              ActionChip(
                label: Text(
                  _tx(
                    'logs.day_filter_chip',
                    'Día: {date} ✕',
                  ).replaceAll('{date}', _dateFilter!),
                ),
                onPressed: _clearDateFilter,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_viewerError != null) ...[
          Text(_viewerError!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 10),
        ],
        if (_viewerLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data == null)
          Text(
            _tx(
              'logs.viewer_hint',
              'Ajusta los filtros y pulsa "Filtrar" para ver logs',
            ),
          )
        else ...[
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(_tx('logs.col_date', 'Fecha'))),
                    DataColumn(label: Text(_tx('logs.col_time', 'Hora'))),
                    DataColumn(label: Text(_tx('logs.col_level', 'Nivel'))),
                    DataColumn(label: Text(_tx('logs.col_ip', 'IP'))),
                    DataColumn(label: Text(_tx('logs.col_user', 'Usuario'))),
                    DataColumn(
                      label: Text(_tx('logs.col_service', 'Servicio')),
                    ),
                    DataColumn(label: Text(_tx('logs.col_message', 'Mensaje'))),
                  ],
                  rows: data.items.map((entry) {
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
                          SizedBox(
                            width: 420,
                            child: Text(
                              entry.summary,
                              overflow: TextOverflow.ellipsis,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tx('logs.page_total', 'Página {page}/{pages} · Total: {total}')
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
                  OutlinedButton(
                    onPressed: data.page > 1
                        ? () => _loadViewer(page: data.page - 1)
                        : null,
                    child: Text(_tx('logs.prev', 'Anterior')),
                  ),
                  OutlinedButton(
                    onPressed: data.page < data.pages
                        ? () => _loadViewer(page: data.page + 1)
                        : null,
                    child: Text(_tx('logs.next', 'Siguiente')),
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
