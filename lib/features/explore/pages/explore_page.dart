import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/manager/group_models.dart';
import '../../manager/repositories/manager_repository.dart';
import '../repositories/explore_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

part '../dialogs/preview_dialog.dart';
part '../cards/explore_resource_card.dart';
part '../cards/explore_user_card.dart';
part '../widgets/explore_collection_views.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  late final ExploreRepository _repository;
  late final ManagerRepository _managerRepository;
  late final TranslatedTexts _t;
  late final TabController _tabController;
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _userQueryController = TextEditingController();
  final Debouncer _userSearchDebouncer = Debouncer();

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  List<ExploreItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _type = 'all';
  String _category = '';
  final Set<String> _labels = <String>{};
  final Set<String> _busyKeys = <String>{};
  final Set<String> _linkedKeys = <String>{};
  final Set<String> _starredKeys = <String>{};

  static const _usersPageSize = 20;
  List<ExploreUserItem> _users = const [];
  bool _usersLoading = true;
  bool _usersLoadingMore = false;
  String? _usersError;
  bool _usersHasMore = false;
  int _usersOffset = 0;
  final Set<String> _invitingUsernames = <String>{};

  List<String> get _categoryOptions {
    final set = <String>{};
    for (final item in _items) {
      if (item.category.isNotEmpty) set.add(item.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _repository = ExploreRepository(apiClient: widget.apiClient);
    _managerRepository = ManagerRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: 2, vsync: this);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
    _loadUsers();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _queryController.dispose();
    _userQueryController.dispose();
    _userSearchDebouncer.dispose();
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  String _itemKey(ExploreItem item) =>
      '${item.resourceType}:${item.resourceId}';

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
      final items = await _repository.listResources(
        token,
        type: _type,
        query: _queryController.text,
        category: _category,
        labels: _labels.toList(),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        if (_category.isNotEmpty && !_categoryOptions.contains(_category)) {
          _category = '';
        }
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
        _error = _tx('explore.error_title', 'No se pudo cargar Explore');
        _loading = false;
      });
    }
  }

  Future<void> _preview(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    setState(() => _busyKeys.add(key));
    try {
      final preview = await _repository.getPreview(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _PreviewDialog(title: item.name, jsonPayload: preview),
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cargar preview', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _link(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    if (_linkedKeys.contains(key)) return;
    setState(() => _busyKeys.add(key));
    try {
      final result = await _repository.linkResource(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      if (mounted) setState(() => _linkedKeys.add(key));
      _showMessage('Recurso enlazado: ${result['name'] ?? item.name}');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo enlazar el recurso', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _toggleStar(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    final remove = _starredKeys.contains(key);
    setState(() => _busyKeys.add(key));
    try {
      final stars = remove
          ? await _repository.unstar(
              token,
              resourceType: item.resourceType,
              resourceId: item.resourceId,
            )
          : await _repository.star(
              token,
              resourceType: item.resourceType,
              resourceId: item.resourceId,
            );

      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere(
          (element) =>
              element.resourceType == item.resourceType &&
              element.resourceId == item.resourceId,
        );
        if (idx >= 0) {
          _items[idx].raw['stars_count'] = stars;
        }
        if (remove) {
          _starredKeys.remove(key);
        } else {
          _starredKeys.add(key);
        }
      });
      _showMessage(remove ? 'Star removido' : 'Star añadido');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar star', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
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

  // ── Pestaña Usuarios ────────────────────────────────────────────────

  void _onUserSearchChanged() {
    _userSearchDebouncer.run(() => _loadUsers());
  }

  Future<void> _loadUsers() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _usersError = _tx('common.no_session', 'No hay sesión activa');
        _usersLoading = false;
      });
      return;
    }

    setState(() {
      _usersLoading = true;
      _usersError = null;
    });

    try {
      final users = await _repository.searchUsers(
        token,
        query: _userQueryController.text,
        limit: _usersPageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _usersOffset = users.length;
        _usersHasMore = users.length >= _usersPageSize;
        _usersLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _usersError = error.message;
        _usersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usersError = _tx('explore.users_error_title', 'No se pudo cargar');
        _usersLoading = false;
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    final token = _token;
    if (token == null || token.isEmpty || _usersLoadingMore || !_usersHasMore) {
      return;
    }
    setState(() => _usersLoadingMore = true);
    try {
      final next = await _repository.searchUsers(
        token,
        query: _userQueryController.text,
        limit: _usersPageSize,
        offset: _usersOffset,
      );
      if (!mounted) return;
      setState(() {
        _users = [..._users, ...next];
        _usersOffset += next.length;
        _usersHasMore = next.length >= _usersPageSize;
        _usersLoadingMore = false;
      });
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      if (mounted) setState(() => _usersLoadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _usersLoadingMore = false);
    }
  }

  void _openProfile(String username) {
    context.push('${RouteNames.publicProfilePrefix}$username');
  }

  Future<void> _inviteUser(String username) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _invitingUsernames.add(username));
    try {
      final groups = await _managerRepository.listGroups(token);
      GroupItem? active;
      for (final group in groups) {
        if (group.active) {
          active = group;
          break;
        }
      }
      if (active == null || active.isPersonal) {
        _showMessage(
          _tx(
            'explore.users_invite_no_group',
            'Activa un grupo de equipo para invitar usuarios',
          ),
          isError: true,
        );
        return;
      }
      await _managerRepository.inviteMember(token, active.id, username);
      _showMessage(
        '${_tx('explore.users_invite_sent', 'Invitación enviada a')} $username',
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('explore.users_invite_error', 'No se pudo enviar la invitación'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _invitingUsernames.remove(username));
    }
  }

  List<(String, String)> get _typeOptions => [
    ('all', _tx('explore.type_all', 'Todos')),
    ('agent', _tx('explore.type_agents', 'Agentes')),
    ('skill', _tx('explore.type_skills', 'Skills')),
    ('prompt', _tx('explore.type_prompts', 'Prompts')),
    ('knowledge', _tx('explore.type_knowledge', 'Knowledge')),
    ('workflow', _tx('explore.type_workflows', 'Workflows')),
  ];

  static const _categoryKeys = {
    'Coding': 'category_coding',
    'Writing': 'category_writing',
    'Research': 'category_research',
    'Data': 'category_data',
    'DevOps': 'category_devops',
    'Support': 'category_support',
    'Education': 'category_education',
    'Productivity': 'category_productivity',
    'Marketing': 'category_marketing',
    'Finance': 'category_finance',
    'Other': 'category_other',
  };

  /// Traduce el tipo de recurso ("agent", "skill"...) al idioma del sistema,
  /// reutilizando las mismas etiquetas que el filtro de tipo.
  String _typeChipLabel(String type) {
    for (final option in _typeOptions) {
      if (option.$1 == type) return option.$2;
    }
    return type;
  }

  /// Traduce la categoría ("Coding", "Other"...) al idioma del sistema.
  String _categoryChipLabel(String category) {
    final key = _categoryKeys[category];
    if (key == null) return category;
    return _tx('explore.$key', category);
  }

  // En Explore todo lo listado es público (el backend solo devuelve
  // is_public=true), así que filtrar por "public"/"private" no aporta nada.
  static final _explorableLabelKeys = kLabelKeys
      .where((l) => l != 'public' && l != 'private')
      .toList();

  static const _labelKeys = {
    'production': 'label_production',
    'staging': 'label_staging',
    'development': 'label_development',
    'test': 'label_test',
    'favorite': 'label_favorite',
    'draft': 'label_draft',
    'review': 'label_review',
    'deprecated': 'label_deprecated',
    'quarantine': 'label_quarantine',
    'archived': 'label_archived',
    'delete': 'label_delete',
  };

  /// Traduce el nombre de una label ("favorite", "draft"...) al idioma del sistema.
  String _labelChipLabel(String label) {
    final key = _labelKeys[label];
    if (key == null) return label;
    return _tx('explore.$key', label);
  }

  int get _activeFilterCount =>
      (_type != 'all' ? 1 : 0) +
      (_category.isNotEmpty ? 1 : 0) +
      _labels.length;

  void _openFiltersDialog() {
    final optionAll = _tx('explore.option_all', 'Todas');
    final categoryOptions = [
      ('', optionAll),
      ..._categoryOptions.map((c) => (c, _categoryChipLabel(c))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () {
        setState(() {
          _type = 'all';
          _category = '';
          _labels.clear();
        });
        _load();
      },
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('explore.type_label', 'Tipo'),
          value: _type,
          options: _typeOptions,
          onChanged: (v) {
            setState(() => _type = v);
            _load();
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('explore.category_label', 'Categoría'),
          value: _category,
          options: categoryOptions,
          onChanged: (v) {
            setState(() => _category = v);
            _load();
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        Text(
          _tx('explore.label_label', 'Label'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _explorableLabelKeys.map((l) {
            final selected = _labels.contains(l);
            return FilterChip(
              label: Text(_labelChipLabel(l)),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _labels.add(l);
                  } else {
                    _labels.remove(l);
                  }
                });
                _load();
                setDialogState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: options
          .map(
            (opt) => DropdownMenuItem(
              value: opt.$1,
              child: Text(opt.$2, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: _tx('explore.tab_resources', 'Recursos')),
              Tab(text: _tx('explore.tab_users', 'Usuarios')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildResourcesTab(), _buildUsersTab()],
          ),
        ),
      ],
    );
  }
}
