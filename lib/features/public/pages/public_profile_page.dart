import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../explore/repositories/explore_repository.dart';
import '../cards/public_resource_card.dart';
import '../repositories/public_profile_repository.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    required this.username,
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final String username;
  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage>
    with StateMessaging {
  late final PublicProfileRepository _repository;
  late final ExploreRepository _exploreRepository;
  late final TranslatedTexts _t;

  List<ExploreItem> _resources = const [];
  PublicFollowStatus? _followStatus;
  bool _loading = true;
  String? _error;
  bool _followBusy = false;
  String _type = 'all';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = PublicProfileRepository(apiClient: widget.apiClient);
    _exploreRepository = ExploreRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  String get _cleanUsername => widget.username.trim();

  void _openFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () {
        setState(() => _type = 'all');
        _load();
      },
      buildFields: (setDialogState) => [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: InputDecoration(
            labelText: _tx('labels.type_label', 'Tipo de recurso'),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('all')),
            DropdownMenuItem(value: 'agent', child: Text('agent')),
            DropdownMenuItem(value: 'skill', child: Text('skill')),
            DropdownMenuItem(value: 'knowledge', child: Text('knowledge')),
            DropdownMenuItem(value: 'workflow', child: Text('workflow')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _type = value);
            _load();
            setDialogState(() {});
          },
        ),
      ],
    );
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
        _repository.listResources(token, username: _cleanUsername, type: _type),
        _repository.getFollowStatus(token, _cleanUsername),
      ]);

      if (!mounted) return;
      setState(() {
        _resources = results[0] as List<ExploreItem>;
        _followStatus = results[1] as PublicFollowStatus;
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
        _error = _tx(
          'public_profile.error_generic',
          'No se pudo cargar el perfil público',
        );
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
      showMessage(
        _tx(
          'public_profile.follow_update_error',
          'No se pudo actualizar follow',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
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
              child: Text(_tx('common.close', 'Cerrar')),
            ),
          ],
        ),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('public_profile.preview_error', 'No se pudo abrir preview'),
        isError: true,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx(
              'public_profile.error_loading',
              'Error cargando perfil público',
            ),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
          ),
        ],
      );
    }

    final followStatus = _followStatus;
    if (followStatus == null) {
      return Center(
        child: Text(
          _tx('public_profile.no_follow_status', 'Sin estado de seguimiento'),
        ),
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_tx('public_profile.title_prefix', 'Perfil público')} @$_cleanUsername',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_tx('public_profile.followers', 'Seguidores')}: ${followStatus.followersCount}',
                ),
                Text(
                  '${_tx('public_profile.following', 'Siguiendo')}: ${followStatus.followingCount}',
                ),
                PrimaryButton.icon(
                  onPressed: _followBusy ? null : _toggleFollow,
                  icon: Icon(
                    followStatus.following
                        ? Icons.person_remove_alt_1
                        : Icons.person_add_alt_1,
                  ),
                  label: Text(
                    _followBusy
                        ? _tx('profile.updating', 'Actualizando...')
                        : (followStatus.following
                              ? _tx(
                                  'public_profile.unfollow_btn',
                                  'Dejar de seguir',
                                )
                              : _tx('public_profile.follow_btn', 'Seguir')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterButton(
              activeCount: _type != 'all' ? 1 : 0,
              tooltip: _tx('common.filters', 'Filtros'),
              onPressed: _openFiltersDialog,
            ),
            Text(
              '${_tx('public_profile.resources_count', 'Recursos')}: ${_resources.length}',
            ),
          ],
        ),
      ],
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(child: header),
          ),
          if (_resources.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _tx(
                        'public_profile.empty_resources',
                        'Este usuario no tiene recursos públicos en este filtro.',
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: _resources.length,
                itemBuilder: (context, index) {
                  final item = _resources[index];
                  return PublicResourceCard(
                    item: item,
                    typeLabel: _tx(
                      'labels.${item.resourceType}',
                      item.resourceType,
                    ),
                    previewTooltip: _tx('explore.preview', 'Vista previa'),
                    onPreview: () => _preview(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
