import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/profile/profile_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/explore_search_toolbar.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../explore/repositories/explore_repository.dart';
import '../cards/public_resource_card.dart';
import '../repositories/public_profile_repository.dart';
import '../utils/public_profile_resource_filter.dart';
import '../widgets/public_profile_presentation.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({required this.username, super.key});

  final String username;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage>
    with StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final PublicProfileRepository _repository;
  late final ExploreRepository _exploreRepository;
  late final TranslatedTexts _t;
  final TextEditingController _searchController = TextEditingController();

  List<ExploreItem> _resources = const [];
  SocialProfile? _profile;
  PublicFollowStatus? _followStatus;
  bool _loading = true;
  String? _error;
  bool _followBusy = false;
  Set<String> _selectedTypes = <String>{};

  String _tx(String path) => _t.text(path);

  @override
  void initState() {
    super.initState();
    _repository = PublicProfileRepository(apiClient: _services.apiClient);
    _exploreRepository = ExploreRepository(apiClient: _services.apiClient);
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  String get _cleanUsername => widget.username.trim();

  static const _resourceTypes = [
    'agent',
    'skill',
    'prompt',
    'tool',
    'knowledge',
    'workflow',
  ];

  List<ExploreItem> get _filteredResources => filterPublicProfileResources(
    _resources,
    query: _searchController.text,
    selectedTypes: _selectedTypes,
  );

  int get _totalStars => _resources.fold(0, (sum, item) => sum + item.stars);

  int _typeCount(String type) =>
      _resources.where((item) => item.resourceType == type).length;

  String _typeLabel(String type) => switch (type) {
    'agent' => _tx('explore.type_agents'),
    'skill' => _tx('explore.type_skills'),
    'prompt' => _tx('explore.type_prompts'),
    'tool' => _tx('explore.type_tools'),
    'knowledge' => _tx('explore.type_knowledge'),
    'workflow' => _tx('explore.type_workflows'),
    _ => type,
  };

  IconData _typeIcon(String type) => switch (type) {
    'agent' => Icons.smart_toy_outlined,
    'skill' => Icons.bolt_outlined,
    'prompt' => Icons.chat_bubble_outline,
    'tool' => Icons.build_outlined,
    'knowledge' => Icons.menu_book_outlined,
    'workflow' => Icons.account_tree_outlined,
    _ => Icons.category_outlined,
  };

  List<ExploreTypeOption> get _typeOptions => [
    for (final type in _resourceTypes)
      ExploreTypeOption(
        value: type,
        label: _typeLabel(type),
        icon: _typeIcon(type),
        color: labelColor(type),
        count: _typeCount(type),
      ),
  ];

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session');
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
        _repository.getProfile(token, _cleanUsername),
        _repository.listResources(token, username: _cleanUsername),
        _repository.getFollowStatus(token, _cleanUsername),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as SocialProfile;
        _resources = results[1] as List<ExploreItem>;
        _followStatus = results[2] as PublicFollowStatus;
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
        _error = _tx('public_profile.error_generic');
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final token = _token;
    final status = _followStatus;
    if (token == null || token.isEmpty || status == null) return;
    setState(() => _followBusy = true);
    try {
      if (status.following) {
        await _repository.unfollow(token, _cleanUsername);
      } else {
        await _repository.follow(token, _cleanUsername);
      }
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('public_profile.follow_update_error'), isError: true);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Widget _avatarFallback() {
    final initial = _cleanUsername.isEmpty
        ? '?'
        : _cleanUsername[0].toUpperCase();
    return CircleAvatar(
      radius: 36,
      child: Text(initial, style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  Widget _buildAvatar(SocialProfile profile) {
    final path = profile.avatarUrl;
    if (path == null || path.isEmpty) return _avatarFallback();
    return ClipOval(
      child: SizedBox(
        width: 72,
        height: 72,
        child: Image(
          image: ResizeImage(
            _services.apiClient.authenticatedImage(path, gaToken: _token),
            width: 144,
            height: 144,
          ),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _avatarFallback(),
        ),
      ),
    );
  }

  Future<void> _preview(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final preview = await _exploreRepository.getPreview(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.name),
          content: SizedBox(
            width: dialogContentWidth(context, 740),
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(preview),
                style: FncFonts.code,
              ),
            ),
          ),
          actions: [
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tx('common.close')),
            ),
          ],
        ),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('public_profile.preview_error'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('public_profile.error_loading'),
            message: _error!,
            retryLabel: _tx('common.retry'),
            onRetry: _load,
          ),
        ],
      );
    }

    final followStatus = _followStatus;
    final profile = _profile;
    if (followStatus == null || profile == null) {
      return Center(child: Text(_tx('public_profile.no_follow_status')));
    }

    final filteredResources = _filteredResources;
    final isOwnProfile =
        _services.sessionController.user?.username == _cleanUsername;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PublicProfilePresentation(
          profile: profile,
          avatar: _buildAvatar(profile),
          followersCount: followStatus.followersCount,
          followingCount: followStatus.followingCount,
          resourcesCount: _resources.length,
          starsCount: _totalStars,
          isOwnProfile: isOwnProfile,
          following: followStatus.following,
          followBusy: _followBusy,
          onToggleFollow: _toggleFollow,
          tx: _tx,
        ),
        if (profile.cv?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tx('public_profile.professional_summary'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          profile.cv!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.55),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          _tx('public_profile.resources_title'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _tx('public_profile.resources_subtitle'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ExploreSearchToolbar(
          searchController: _searchController,
          searchHint: _tx('public_profile.search_hint'),
          typeOptions: _typeOptions,
          selectedTypes: _selectedTypes,
          allTypesLabel: _tx('explore.type_all'),
          typeFilterTooltip: _tx('explore.type_filter_tooltip'),
          multipleTypesLabel: (count) =>
              _tx('labels.types_selected').replaceAll('{count}', '$count'),
          allowMultipleTypes: false,
          onSearchChanged: (_) => setState(() {}),
          onTypesChanged: (types) {
            setState(() => _selectedTypes = types);
          },
          actions: [
            Text(
              _tx(
                'public_profile.results_count',
              ).replaceAll('{count}', '${filteredResources.length}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );

    return ResourceCollectionView(
      header: header,
      onRefresh: _load,
      empty: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_tx('public_profile.empty_resources')),
        ),
      ),
      itemCount: filteredResources.length,
      itemBuilder: (context, index) {
        final item = filteredResources[index];
        return PublicResourceCard(
          item: item,
          typeLabel: _typeLabel(item.resourceType),
          previewTooltip: _tx('explore.preview'),
          onPreview: () => _preview(item),
        );
      },
    );
  }
}
