import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/logs/log_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../repositories/logs_repository.dart';

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
const _categories = ['', 'AUDIT', 'DIAGNOSTIC'];
const _outcomes = ['', 'SUCCESS', 'DENIED', 'FAILURE'];

class _LogsPageViewState extends State<LogsPageView> with StateMessaging {
  late final LogsRepository _repository;
  late final TranslatedTexts _t;

  bool _viewerTab = false;

  List<LogsSummaryDay> _summary = const [];
  bool _summaryLoading = true;
  String? _summaryError;

  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _queryController = TextEditingController();
  final _actionController = TextEditingController();
  final _resourceTypeController = TextEditingController();
  final _resourceIdController = TextEditingController();
  String _level = '';
  String _source = '';
  String _category = '';
  String _outcome = '';
  String? _dateFilter;

  LogsPage? _logsPage;
  bool _viewerLoading = false;
  bool _exporting = false;
  String? _viewerError;

  String _tx(String path) => _t.text(path);

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
    _actionController.dispose();
    _resourceTypeController.dispose();
    _resourceIdController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadSummary() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _summaryError = _tx('common.no_session');
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
        _summaryError = _tx('logs.error_summary');
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadViewer({int page = 1}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() => _viewerError = _tx('common.no_session'));
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
        category: _category,
        action: _actionController.text.trim(),
        resourceType: _resourceTypeController.text.trim(),
        resourceId: _resourceIdController.text.trim(),
        outcome: _outcome,
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
        _viewerError = _tx('logs.error_load');
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
        category: _category,
        action: _actionController.text.trim(),
        resourceType: _resourceTypeController.text.trim(),
        resourceId: _resourceIdController.text.trim(),
        outcome: _outcome,
      );
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      await FilePicker.saveFile(
        dialogTitle: _tx('logs.save_dialog_title'),
        fileName: 'logs_$stamp.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('logs.error_export'), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  int get _logsActiveFilterCount =>
      (_level.isNotEmpty ? 1 : 0) +
      (_source.isNotEmpty ? 1 : 0) +
      (_category.isNotEmpty ? 1 : 0) +
      (_outcome.isNotEmpty ? 1 : 0) +
      (_ipController.text.isNotEmpty ? 1 : 0) +
      (_usernameController.text.isNotEmpty ? 1 : 0) +
      (_actionController.text.isNotEmpty ? 1 : 0) +
      (_resourceTypeController.text.isNotEmpty ? 1 : 0) +
      (_resourceIdController.text.isNotEmpty ? 1 : 0);

  void _openLogsFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('logs.filter_btn'),
      onApply: _loadViewer,
      onClear: () {
        setState(() {
          _level = '';
          _source = '';
          _category = '';
          _outcome = '';
        });
        _ipController.clear();
        _usernameController.clear();
        _actionController.clear();
        _resourceTypeController.clear();
        _resourceIdController.clear();
      },
      buildFields: (setDialogState) => [
        DropdownButtonFormField<String>(
          initialValue: _level,
          decoration: InputDecoration(labelText: _tx('logs.level_label')),
          items: _levels
              .map(
                (l) => DropdownMenuItem(
                  value: l,
                  child: Text(l.isEmpty ? _tx('logs.all') : l),
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
          decoration: InputDecoration(labelText: _tx('logs.service_label')),
          items: _sources
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.isEmpty ? _tx('logs.all') : s),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _source = value ?? '');
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: InputDecoration(labelText: _tx('logs.category_label')),
          items: _categories
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(
                    category.isEmpty
                        ? _tx('logs.all')
                        : _categoryLabel(category),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _category = value ?? '');
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _outcome,
          decoration: InputDecoration(labelText: _tx('logs.outcome_label')),
          items: _outcomes
              .map(
                (outcome) => DropdownMenuItem(
                  value: outcome,
                  child: Text(outcome.isEmpty ? _tx('logs.all') : outcome),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _outcome = value ?? '');
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ipController,
          decoration: InputDecoration(labelText: _tx('logs.ip_label')),
          onChanged: (_) => setDialogState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(labelText: _tx('logs.user_label')),
          onChanged: (_) => setDialogState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _actionController,
          decoration: InputDecoration(labelText: _tx('logs.action_label')),
          onChanged: (_) => setDialogState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _resourceTypeController,
          decoration: InputDecoration(
            labelText: _tx('logs.resource_type_label'),
          ),
          onChanged: (_) => setDialogState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _resourceIdController,
          decoration: InputDecoration(labelText: _tx('logs.resource_id_label')),
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
    _actionController.clear();
    _resourceTypeController.clear();
    _resourceIdController.clear();
    setState(() {
      _dateFilter = date;
      _level = '';
      _source = '';
      _category = '';
      _outcome = '';
      _viewerTab = true;
    });
    _loadViewer();
  }

  void _clearDateFilter() {
    setState(() => _dateFilter = null);
    _loadViewer();
  }

  void _filterByCategory(String category) {
    setState(() => _category = category);
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

  String _categoryLabel(String category) => switch (category) {
    'AUDIT' => _tx('logs.category_audit'),
    'DIAGNOSTIC' => _tx('logs.category_diagnostic'),
    _ => _tx('logs.all'),
  };

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
                label: Text(_tx('logs.tab_summary')),
                icon: const Icon(Icons.dashboard_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(_tx('logs.tab_viewer')),
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
