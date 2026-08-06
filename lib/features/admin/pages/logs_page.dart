import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/logs/log_models.dart';
import '../repositories/logs_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/filter_button.dart';

part '../widgets/logs_views.dart';

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
      await FilePicker.saveFile(
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
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
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
    final base = switch (level) {
      'ERROR' => FncColors.materialRed.shade700,
      'WARNING' => FncColors.materialOrange.shade800,
      'OK' => FncColors.materialGreen.shade700,
      _ => FncColors.materialGrey.shade600,
    };
    return AppTheme.statusColor(base, Theme.of(context).colorScheme.surface);
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
}
