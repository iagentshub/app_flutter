import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../features/connections/widgets/providers_section.dart';
import '../../../models/profile/profile_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/brand_icon_controller.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/brand_icon.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../controllers/profile_controller.dart';
import '../repositories/profile_repository.dart';
import '../widgets/profile_groups_section.dart';

part '../widgets/brand_icon_selector.dart';
part '../widgets/profile_account_section.dart';
part '../widgets/profile_groups_tab_section.dart';
part '../widgets/profile_social_section.dart';
part '../widgets/profile_view_helpers.dart';

/// Idiomas disponibles para el perfil público. Por ahora la plataforma solo
/// soporta Español e Inglés (a diferencia del listado más amplio de
/// la interfaz web, aún no habilitado aquí).
const _languageOptions = [('es', 'Español', '🇪🇸'), ('en', 'English', '🇬🇧')];

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin, StateMessaging {
  late final ProfileController _controller;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  static const _sectionIds = ['account', 'social', 'groups', 'providers'];

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    // `_t` primero: el controller recibe `_tx` y lo usa para sus mensajes.
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller =
        ProfileController(
          repository: ProfileRepository(apiClient: widget.apiClient),
          sessionController: widget.sessionController,
          localeController: widget.localeController,
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

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    await _runAction(
      _controller.uploadAvatar(fileName: file.name, fileBytes: file.bytes),
    );
  }

  Future<void> _openLanguagesDialog() async {
    var draft = {..._controller.selectedLanguages};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('profile.manage_languages', 'Gestionar idiomas')),
          content: SizedBox(
            width: dialogContentWidth(context, 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _languageOptions.map((option) {
                final (id, label, flag) = option;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.contains(id),
                  title: Text('$flag $label'),
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
              child: Text(_tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(draft),
              child: Text(_tx('common.save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (result != null) _controller.setLanguages(result);
  }

  Future<void> _openChangePasswordDialog() async {
    var submitting = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('profile.tab_security', 'Seguridad')),
          content: SizedBox(
            width: dialogContentWidth(context, 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _controller.currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'profile.current_password_label',
                      'Contraseña actual',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _controller.newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'profile.new_password_label',
                      'Nueva contraseña',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(_tx('common.cancel', 'Cancelar')),
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
                    ? _tx('profile.updating', 'Actualizando...')
                    : _tx('profile.change_password', 'Cambiar contraseña'),
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
      title: _tx(
        'profile.deletion_confirm_title',
        'Solicitar eliminación de cuenta',
      ),
      message: _tx(
        'profile.deletion_confirm_message',
        'La cuenta se programará para eliminación en 30 días. ¿Deseas continuar?',
      ),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.confirm', 'Confirmar'),
      destructive: true,
    );
    if (!confirm) return;

    await _runAction(_controller.requestDeletion());
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) return const AsyncStatePanel.loading();
    final error = _controller.error;
    if (error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('profile.error_title', 'Error cargando perfil'),
            message: error,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _controller.load,
          ),
        ],
      );
    }

    final bundle = _controller.bundle;
    if (bundle == null) {
      return Center(
        child: Text(_tx('profile.empty', 'No hay datos de perfil disponibles')),
      );
    }

    final tabLabels = <String>[
      _tx('profile.tab_account', 'Mi cuenta'),
      _tx('profile.tab_social', 'Perfil público'),
      _tx('profile.tab_groups', 'Grupos'),
      _tx('connections.tab_providers', 'Proveedores'),
    ];
    final section = _sectionIds[_tabController.index];
    final token = _controller.token;

    return Column(
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
                        apiClient: widget.apiClient,
                        token: token,
                        localeController: widget.localeController,
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
}
