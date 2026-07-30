import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/manager/workspace_models.dart';
import '../../manager/repositories/manager_repository.dart';
import '../repositories/explore_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/filter_button.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

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
      final workspaces = await _managerRepository.listWorkspaces(token);
      WorkspaceItem? active;
      for (final ws in workspaces) {
        if (ws.active) {
          active = ws;
          break;
        }
      }
      if (active == null || active.isPersonal) {
        _showMessage(
          _tx(
            'explore.users_invite_no_workspace',
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

  Widget _buildResourcesTab() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tx('explore.error_title', 'Error cargando Explore'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
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

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(onRefresh: _load, child: _buildScrollView());
  }

  Widget _buildScrollView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    labelText: _tx('explore.search_hint', 'Buscar'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 10),
                FilterButton(
                  activeCount: _activeFilterCount,
                  tooltip: _tx('common.filters', 'Filtros'),
                  onPressed: _openFiltersDialog,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${_tx('explore.results', 'Resultados')}: ${_items.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        if (_items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _tx('explore.empty', 'No hay resultados para ese filtro.'),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: ResponsiveSliverMasonryGrid(
              itemCount: _items.length,
              itemBuilder: (context, index) => _buildItemCard(_items[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_usersError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tx('explore.users_error_title', 'No se pudo cargar'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_usersError!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadUsers,
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

    if (_usersLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: _buildUsersScrollView(),
    );
  }

  Widget _buildUsersScrollView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _userQueryController,
              decoration: InputDecoration(
                labelText: _tx('explore.users_search_hint', 'Buscar usuarios'),
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (_) => _onUserSearchChanged(),
            ),
          ),
        ),
        if (_users.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _tx('explore.users_empty', 'No se encontraron usuarios.'),
                  ),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: ResponsiveSliverMasonryGrid(
              density: ResponsiveCardDensity.compact,
              itemCount: _users.length,
              itemBuilder: (context, index) => _buildUserCard(_users[index]),
            ),
          ),
          if (_usersHasMore)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: _usersLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          onPressed: _loadMoreUsers,
                          child: Text(
                            _tx('explore.users_load_more', 'Cargar más'),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildUserCard(ExploreUserItem user) {
    final username = user.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final token = _token;
    final avatarPath = user.avatarPath;
    final avatarUrl = avatarPath != null
        ? '${widget.apiClient.backendController.effectiveBaseUrl}$avatarPath'
        : null;
    final inviting = _invitingUsernames.contains(username);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: (avatarUrl != null && token != null)
                        ? Image.network(
                            avatarUrl,
                            headers: {'Cookie': 'ga_token=$token'},
                            fit: BoxFit.cover,
                            cacheWidth: 80,
                            cacheHeight: 80,
                            errorBuilder: (context, error, stack) =>
                                _userAvatarFallback(initial),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : _userAvatarFallback(initial),
                          )
                        : _userAvatarFallback(initial),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${user.followersCount} '
                  '${_tx('explore.users_followers', 'seguidores')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${user.publicResourcesCount} '
                  '${_tx('explore.users_resources', 'recursos')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.person_outline,
                  tooltip: _tx('explore.users_view_profile', 'Ver perfil'),
                  onPressed: () => _openProfile(username),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('explore.users_invite', 'Invitar'),
                  onPressed: inviting ? null : () => _inviteUser(username),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _userAvatarFallback(String initial) {
    return CircleAvatar(
      radius: 20,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  static const _linkableTypes = {'agent', 'skill', 'knowledge', 'workflow'};

  Widget _buildItemCard(ExploreItem item) {
    final key = _itemKey(item);
    final busy = _busyKeys.contains(key);
    final myUsername = widget.sessionController.user?.username ?? '';
    final isOwn = myUsername.isNotEmpty && item.owner == myUsername;
    final isLinkable = !isOwn && _linkableTypes.contains(item.resourceType);
    final linked = _linkedKeys.contains(key);
    final starred = _starredKeys.contains(key);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.owner,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                const SizedBox(width: 4),
                Text(
                  '${item.stars}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.labels,
              leading: [
                _chip(_typeChipLabel(item.resourceType)),
                _chip(_categoryChipLabel(item.category)),
              ],
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags
                    .take(4)
                    .map((tag) => _miniChip('#$tag'))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: _tx('explore.preview', 'Vista previa'),
                  onPressed: busy ? null : () => _preview(item),
                ),
                if (isLinkable)
                  ActionIconButton(
                    icon: linked ? Icons.link : Icons.link_outlined,
                    tooltip: linked
                        ? _tx('explore.linked_tooltip', 'Ya enlazado')
                        : _tx('explore.link', 'Enlazar'),
                    onPressed: (busy || linked) ? null : () => _link(item),
                  ),
                const Spacer(),
                ActionIconButton(
                  icon: starred ? Icons.star : Icons.star_outline,
                  tooltip: starred
                      ? _tx('explore.unstar', 'Quitar de favoritos')
                      : _tx('explore.star', 'Añadir a favoritos'),
                  onPressed: busy ? null : () => _toggleStar(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({required this.title, required this.jsonPayload});

  final String title;
  final Map<String, dynamic> jsonPayload;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonPayload);
    return AlertDialog(
      title: Text('Preview: $title'),
      content: SizedBox(
        width: dialogContentWidth(context, 760),
        child: SingleChildScrollView(
          child: SelectableText(
            pretty,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
