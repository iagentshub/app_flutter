import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/config/content_languages.dart';
import '../../../features/connections/widgets/providers_section.dart';
import '../../../models/profile/profile_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/state/brand_icon_controller.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/brand_icon.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/iagents_async_view.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../utils/i18n.dart';
import '../controllers/profile_controller.dart';
import '../dialogs/active_sessions_dialog.dart';
import '../dialogs/avatar_crop_dialog.dart';
import '../dialogs/avatar_source_dialog.dart';
import '../repositories/profile_repository.dart';
import '../widgets/profile_groups_section.dart';

part '../widgets/brand_icon_selector.dart';
part '../widgets/profile_account_section.dart';
part '../widgets/profile_groups_tab_section.dart';
part '../widgets/profile_social_section.dart';
part '../widgets/profile_view_helpers.dart';

/// Idiomas en los que el usuario declara publicar, del catálogo canónico:
/// [ContentLanguages] tiene nueve y el backend valida contra los mismos nueve
/// (`CONTENT_LANGUAGE_SET`). Aquí había dos escritos a mano —español e inglés,
/// con su bandera— así que los otros siete eran inalcanzables desde la app
/// aunque el backend los aceptara y sus etiquetas estuvieran traducidas.
///
/// Sin banderas a propósito: un idioma no es un país (el árabe no tiene
/// bandera y el inglés tiene varias), y la etiqueta traducida ya lo dice.
List<(String, String)> get _languageOptions => ContentLanguages.values
    .map((item) => (item.code, trOr('labels.${item.labelKey}', item.code)))
    .toList(growable: false);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin, StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final ProfileController _controller;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  static const _sectionIds = ['account', 'social', 'groups', 'providers'];

  String _tx(String path) => _t.text(path);

  @override
  void initState() {
    super.initState();
    // `_t` primero: el controller recibe `_tx` y lo usa para sus mensajes.
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller = ProfileController(
      repository: ProfileRepository(apiClient: _services.apiClient),
      sessionController: _services.sessionController,
      localeController: _services.localeController,
      syncTheme: _syncTheme,
      tx: _tx,
    )..addListener(_onControllerChanged);
    _tabController = TabController(length: _sectionIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _controller.load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  /// El tema vive en un `InheritedNotifier`, así que sólo se alcanza desde el
  /// árbol de widgets: el controller lo delega aquí.
  Future<void> _syncTheme(String theme) async {
    if (!mounted) return;
    await ThemeControllerScope.of(
      context,
      listen: false,
    ).syncFromBackend(theme);
  }

  /// Ejecuta una acción del controller y muestra su mensaje, si lo hay.
  Future<void> _runAction(Future<ActionResult?> action) async {
    final result = await action;
    if (result == null) return;
    showMessage(result.message, isError: result.isError);
  }

  /// Tres pasos, y los tres pueden cancelarse: de dónde sale la foto, elegirla
  /// y encuadrarla. Antes era uno solo —un selector de archivos— y en el móvil
  /// eso significaba rebuscar entre carpetas una foto que la galería enseña de
  /// primeras, sin manera ninguna de hacerla en el momento.
  Future<void> _pickAndUploadAvatar() async {
    final canRemove = _controller.hasAvatar;
    AvatarSource? source;
    if (avatarNeedsSourceDialog(canRemove: canRemove)) {
      source = await showAvatarSourceDialog(
        context: context,
        tx: _tx,
        canRemove: canRemove,
      );
      if (source == null) return;
    }

    if (source == AvatarSource.remove) {
      if (!mounted) return;
      final confirmed = await showConfirmActionDialog(
        context,
        title: _tx('profile.avatar_remove'),
        message: _tx('profile.avatar_remove_confirm'),
        confirmLabel: _tx('profile.avatar_remove'),
        cancelLabel: _tx('common.cancel'),
        destructive: true,
      );
      if (!confirmed) return;
      await _runAction(_controller.removeAvatar());
      return;
    }

    final picked = await pickAvatarImage(source);
    if (picked == null || !mounted) return;

    final adjustment = await showAvatarCropDialog(
      context: context,
      bytes: picked.bytes,
      tx: _tx,
    );
    if (adjustment == null) return;

    await _runAction(
      _controller.uploadAvatar(
        fileName: picked.fileName,
        fileBytes: picked.bytes,
        quarterTurns: adjustment.quarterTurns,
        crop: adjustment.crop,
      ),
    );
  }

  Future<void> _openLanguagesDialog() async {
    var draft = {..._controller.selectedLanguages};
    final result = await showAppDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('profile.manage_languages')),
          content: SizedBox(
            width: dialogContentWidth(context, 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _languageOptions.map((option) {
                final (id, label) = option;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.contains(id),
                  title: Text(label),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        draft = {...draft, id};
                      } else {
                        draft = {...draft}..remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tx('common.cancel')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(draft),
              child: Text(_tx('common.save')),
            ),
          ],
        ),
      ),
    );
    if (result != null) _controller.setLanguages(result);
  }

  Future<void> _openActiveSessionsDialog() async {
    final token = _controller.token;
    if (token == null || token.isEmpty) return;
    await showActiveSessionsDialog(
      context: context,
      repository: _controller.repository,
      token: token,
      tx: _tx,
    );
  }

  Future<void> _openChangePasswordDialog() async {
    var submitting = false;
    await showAppDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('profile.tab_security')),
          content: SizedBox(
            width: dialogContentWidth(context, 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _controller.currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tx('profile.current_password_label'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _controller.newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tx('profile.new_password_label'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(_tx('common.cancel')),
            ),
            PrimaryButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      final result = await _controller.changePassword();
                      showMessage(result.message, isError: result.isError);
                      if (!context.mounted) return;
                      if (result.isError) {
                        setDialogState(() => submitting = false);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
              icon: const Icon(Icons.lock_reset_outlined),
              label: Text(
                submitting
                    ? _tx('profile.updating')
                    : _tx('profile.change_password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final bundle = _controller.bundle;
    if (bundle == null) return;
    if (bundle.deletion.scheduled) {
      final already = _controller.deletionAlreadyScheduled;
      showMessage(already.message, isError: already.isError);
      return;
    }
    if (!_controller.canRequestDeletion) return;

    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('profile.deletion_confirm_title'),
      message: _tx('profile.deletion_confirm_message'),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('common.confirm'),
      destructive: true,
    );
    if (!confirm) return;

    await _runAction(_controller.requestDeletion());
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _controller.bundle;
    final Widget content;
    if (bundle == null) {
      content = Center(child: Text(_tx('profile.empty')));
    } else {
      final tabLabels = <String>[
        _tx('profile.tab_account'),
        _tx('profile.tab_social'),
        _tx('profile.tab_groups'),
        _tx('connections.tab_providers'),
      ];
      final section = _sectionIds[_tabController.index];
      final token = _controller.token;

      content = Column(
        children: [
          Material(
            color: FncColors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
          Expanded(
            // Proveedores trae su propio ListView con scroll interno,
            // incompatible con el ListView de ancho acotado que usan el resto
            // de secciones — se monta a pantalla completa.
            child: section == 'providers'
                ? (token == null || token.isEmpty
                      ? const SizedBox.shrink()
                      : ProvidersSection(
                          apiClient: _services.apiClient,
                          token: token,
                          localeController: _services.localeController,
                        ))
                : RefreshIndicator(
                    onRefresh: _controller.load,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            switch (section) {
                              'social' => _buildSocialSection(bundle),
                              'groups' => _buildGroupsSection(bundle),
                              _ => _buildAccountSection(bundle),
                            },
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      );
    }
    return IAgentsAsyncView(
      loading: _controller.loading,
      localeController: _services.localeController,
      error: _controller.error,
      errorTitle: _tx('profile.error_title'),
      retryLabel: _tx('common.retry'),
      onRetry: _controller.load,
      child: content,
    );
  }
}
