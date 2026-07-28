import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/logs/log_models.dart';
import '../repositories/logs_repository.dart';
import '../../../shared/state/session_controller.dart';

class LogsPageView extends StatefulWidget {
  const LogsPageView({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<LogsPageView> createState() => _LogsPageViewState();
}

const _levels = ['', 'DEBUG', 'INFO', 'OK', 'WARNING', 'ERROR'];
const _sources = ['', 'BE', 'FE'];

class _LogsPageViewState extends State<LogsPageView> {
  late final LogsRepository _repository;

  bool _viewerTab = false;

  List<LogsSummaryDay> _summary = const [];
  bool _summaryLoading = true;
  String? _summaryError;

  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _queryController = TextEditingController();
  String _level = '';
  String _source = '';

  LogsPage? _logsPage;
  bool _viewerLoading = false;
  bool _exporting = false;
  String? _viewerError;

  @override
  void initState() {
    super.initState();
    _repository = LogsRepository(apiClient: widget.apiClient);
    _loadSummary();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadSummary() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _summaryError = 'No hay sesión activa';
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
        _summaryError = 'No se pudo cargar el resumen de logs';
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadViewer({int page = 1}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() => _viewerError = 'No hay sesión activa');
      return;
    }
    setState(() {
      _viewerLoading = true;
      _viewerError = null;
    });
    try {
      final result = await _repository.list(
        token,
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
        _viewerError = 'No se pudieron cargar los logs';
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
        ip: _ipController.text.trim(),
        username: _usernameController.text.trim(),
        query: _queryController.text.trim(),
        level: _level,
        source: _source,
      );
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar logs',
        fileName: 'logs_$stamp.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo exportar el CSV', isError: true);
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Resumen'), icon: Icon(Icons.dashboard_outlined)),
                  ButtonSegment(value: true, label: Text('Visor'), icon: Icon(Icons.list_alt_outlined)),
                ],
                selected: {_viewerTab},
                onSelectionChanged: (selection) {
                  final wantsViewer = selection.first;
                  setState(() => _viewerTab = wantsViewer);
                  if (wantsViewer && _logsPage == null) _loadViewer();
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _viewerTab ? _buildViewer() : _buildSummary(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_summaryLoading) return const Center(child: CircularProgressIndicator());
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
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_summary.isEmpty) {
      return const Center(child: Text('Sin datos de logs todavía'));
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.date, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Líneas: ${day.lines}'),
                  const SizedBox(height: 4),
                  Text('BE: ${day.beWarnings} warn · ${day.beErrors} err'),
                  Text('FE: ${day.feWarnings} warn · ${day.feErrors} err'),
                  const Spacer(),
                  Row(
                    children: [
                      if (day.errors > 0)
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                      if (day.warnings > 0) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange.shade800),
                      ],
                    ],
                  ),
                ],
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Nivel'),
                items: _levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l.isEmpty ? 'Todos' : l)))
                    .toList(),
                onChanged: (value) => setState(() => _level = value ?? ''),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: _sources
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.isEmpty ? 'Todos' : s)))
                    .toList(),
                onChanged: (value) => setState(() => _source = value ?? ''),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'IP'),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _queryController,
                decoration: const InputDecoration(labelText: 'Buscar en mensaje'),
                onSubmitted: (_) => _loadViewer(),
              ),
            ),
            FilledButton.icon(
              onPressed: _viewerLoading ? null : () => _loadViewer(),
              icon: const Icon(Icons.search),
              label: const Text('Filtrar'),
            ),
            OutlinedButton.icon(
              onPressed: _exporting ? null : _exportCsv,
              icon: _exporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
              label: const Text('Exportar CSV'),
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
          const Text('Ajusta los filtros y pulsa "Filtrar" para ver logs')
        else ...[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Hora')),
                  DataColumn(label: Text('Nivel')),
                  DataColumn(label: Text('IP')),
                  DataColumn(label: Text('Usuario')),
                  DataColumn(label: Text('Servicio')),
                  DataColumn(label: Text('Mensaje')),
                ],
                rows: data.items.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(Text(entry.date)),
                      DataCell(Text(entry.time)),
                      DataCell(Text(
                        entry.level,
                        style: TextStyle(color: _levelColor(entry.level), fontWeight: FontWeight.w700),
                      )),
                      DataCell(
                        InkWell(onTap: () => _filterByIp(entry.ip), child: Text(entry.ip)),
                      ),
                      DataCell(
                        InkWell(onTap: () => _filterByUsername(entry.username), child: Text(entry.username)),
                      ),
                      DataCell(Text(entry.source)),
                      DataCell(SizedBox(width: 420, child: Text(entry.summary, overflow: TextOverflow.ellipsis))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Página ${data.page}/${data.pages == 0 ? 1 : data.pages} · Total: ${data.total}'),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: data.page > 1 ? () => _loadViewer(page: data.page - 1) : null,
                    child: const Text('Anterior'),
                  ),
                  OutlinedButton(
                    onPressed: data.page < data.pages ? () => _loadViewer(page: data.page + 1) : null,
                    child: const Text('Siguiente'),
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
