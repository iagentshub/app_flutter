import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/async_state_panel.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/admin/admin_explore_models.dart';
import '../repositories/admin_repository.dart';
import '../../../shared/graph/graph_dialog.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/kpi/kpi_hero_card.dart';
import '../../../shared/widgets/kpi/kpi_tile.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../utils/validators.dart';

part '../dialogs/admin_agent_dialog.dart';
part '../dialogs/admin_filter_dialogs.dart';
part '../dialogs/admin_user_dialogs.dart';
part '../dialogs/notification_banner_form_dialog.dart';
part '../cards/admin_content_cards.dart';
part '../cards/admin_integration_cards.dart';
part '../cards/admin_people_cards.dart';
part '../widgets/admin_config_banners_card.dart';
part '../widgets/admin_config_tab.dart';
part '../widgets/admin_config_updates_card.dart';
part '../widgets/admin_explore_tab.dart';
part '../widgets/admin_actions.dart';
part '../widgets/admin_overview_section.dart';
part '../widgets/admin_page_view.dart';
part '../widgets/admin_view_helpers.dart';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

String _fmtTokens(int n) {
  if (n <= 0) return '—';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _fmtDate(Object? raw) {
  if (raw == null) return '—';
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _ownerOf(Map<String, dynamic> item) =>
    (item['owner_username'] ?? '').toString();

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late final AdminRepository _repository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  static const _tabIds = ['general', 'explore', 'config'];

  final TextEditingController _exploreSearchController =
      TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();

  /// Vacío = sin filtro de tipo (se muestran todos) — igual que antes hacía
  /// `_exploreType == null`, pero ahora admite seleccionar varios a la vez.
  final Set<AdminResourceType> _exploreTypes = {};

  String _userRole = '';
  String _userActive = '';
  String _userVerified = '';
  String _agentOwner = '';
  String _connOwner = '';
  String _knowledgeType = '';
  String _knowledgeOwner = '';
  String _workflowOwner = '';
  String _skillOwner = '';
  String _memoryOwner = '';
  String _promptOwner = '';

  AdminStats? _stats;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _agents = const [];
  List<Map<String, dynamic>> _connections = const [];
  List<Map<String, dynamic>> _knowledge = const [];
  List<Map<String, dynamic>> _workflows = const [];
  List<Map<String, dynamic>> _skills = const [];
  List<Map<String, dynamic>> _memories = const [];
  List<Map<String, dynamic>> _prompts = const [];
  List<AdminExploreItem> _exploreItems = const [];
  Map<AdminResourceType, int> _exploreCounts = const {};
  Map<String, dynamic>? _platformSettings;

  bool _loading = true;
  String? _error;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String? get _token => widget.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _repository = AdminRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: _tabIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  /// Recalcula el filtro (y reconstruye la lista) tras una pausa al
  /// escribir, en vez de en cada tecla — evita repetir el `.where()` y
  /// la reconstrucción de tarjetas en cada pulsación.
  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _exploreSearchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getStats(token),
        _repository.explore(token),
        _repository.getPlatformSettings(token),
      ]);

      if (!mounted) return;
      final explore = results[1] as AdminExploreResult;
      List<Map<String, dynamic>> ofType(AdminResourceType type) => explore.items
          .where((item) => item.type == type)
          .map((item) => item.data)
          .toList(growable: false);
      setState(() {
        _stats = results[0] as AdminStats;
        _exploreItems = explore.items;
        _exploreCounts = explore.counts;
        _users = ofType(AdminResourceType.user);
        _groups = ofType(AdminResourceType.group);
        _agents = ofType(AdminResourceType.agent);
        _connections = ofType(AdminResourceType.connection);
        _knowledge = ofType(AdminResourceType.knowledge);
        _workflows = ofType(AdminResourceType.workflow);
        _skills = ofType(AdminResourceType.skill);
        _memories = ofType(AdminResourceType.memory);
        _prompts = ofType(AdminResourceType.prompt);
        _platformSettings = results[2] as Map<String, dynamic>;
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
        _error = _tx('admin.error_generic', 'No se pudo cargar Admin');
        _loading = false;
      });
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

  void _refresh(VoidCallback update) => setState(update);

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      widget.apiClient.invalidateCache();
      _showMessage(successMessage);
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('admin.error_generic', 'No se pudo completar la acción'),
        isError: true,
      );
    }
  }

  Future<bool> _confirm(
    String title,
    String body, {
    String? confirmLabel,
  }) async {
    return showConfirmActionDialog(
      context,
      title: title,
      message: body,
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: confirmLabel ?? _tx('common.delete', 'Eliminar'),
    );
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);
}
