import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/profile/profile_models.dart';
import '../repositories/profile_repository.dart';
import '../../../shared/state/session_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileRepository _repository;

  ProfileBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _savingSettings = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _requestingDeletion = false;

  final _bioController = TextEditingController();
  final _emailPublicController = TextEditingController();
  final _githubController = TextEditingController();
  final _cvController = TextEditingController();
  final _languagesController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String _theme = 'dark-red';
  String _language = 'es';

  @override
  void initState() {
    super.initState();
    _repository = ProfileRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _emailPublicController.dispose();
    _githubController.dispose();
    _cvController.dispose();
    _languagesController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bundle = await _repository.fetchBundle(token);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _theme = bundle.settings.theme;
        _language = bundle.settings.language;
        _bioController.text = bundle.social.bio ?? '';
        _emailPublicController.text = bundle.social.emailPublic ?? '';
        _githubController.text = bundle.social.github ?? '';
        _cvController.text = bundle.social.cv ?? '';
        _languagesController.text = bundle.social.languages.join(', ');
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
        _error = 'No se pudo cargar el perfil';
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _savingSettings = true);
    try {
      final updated = await _repository.updateSettings(
        token,
        theme: _theme,
        language: _language,
      );
      if (!mounted) return;
      setState(() {
        _theme = updated.theme;
        _language = updated.language;
      });
      _showMessage('Preferencias guardadas');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudieron guardar las preferencias', isError: true);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _savePublicProfile() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _savingProfile = true);
    try {
      final languages = _languagesController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      await _repository.updateSocialProfile(
        token,
        bio: _bioController.text.trim(),
        emailPublic: _emailPublicController.text.trim(),
        github: _githubController.text.trim(),
        cv: _cvController.text.trim(),
        languages: languages,
      );
      _showMessage('Perfil público actualizado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar el perfil público', isError: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    if (current.isEmpty || next.isEmpty) {
      _showMessage('Completa contraseña actual y nueva', isError: true);
      return;
    }
    if (next.trim().length < 8) {
      _showMessage('La nueva contraseña debe tener al menos 8 caracteres', isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await _repository.changePassword(
        token,
        currentPassword: current,
        newPassword: next,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _showMessage('Contraseña actualizada');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar la contraseña', isError: true);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _requestDeletion() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final bundle = _bundle;
    if (bundle == null) return;
    if (bundle.deletion.scheduled) {
      _showMessage('La cuenta ya está programada para eliminación');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar eliminación de cuenta'),
        content: const Text(
          'La cuenta se programará para eliminación en 30 días. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _requestingDeletion = true);
    try {
      final message = await _repository.requestDeletion(token);
      _showMessage(message);
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo programar la eliminación de cuenta', isError: true);
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                  const Text('Error cargando perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final bundle = _bundle;
    if (bundle == null) {
      return const Center(child: Text('No hay datos de perfil disponibles'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(bundle.session.username),
              subtitle: Text(
                'Rol: ${bundle.session.role} · Workspace: ${bundle.session.workspaceName ?? bundle.session.workspaceId ?? '-'}',
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Workspaces'),
              subtitle: const Text('Gestionar espacios de trabajo, miembros e invitaciones'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.manager),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferencias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _theme,
                    decoration: const InputDecoration(labelText: 'Tema'),
                    items: _themes
                        .map((theme) => DropdownMenuItem<String>(value: theme, child: Text(theme)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _theme = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: const InputDecoration(labelText: 'Idioma'),
                    items: const [
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _language = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _savingSettings ? null : _saveSettings,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_savingSettings ? 'Guardando...' : 'Guardar preferencias'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Perfil público', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Bio'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailPublicController,
                    decoration: const InputDecoration(labelText: 'Email público'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _githubController,
                    decoration: const InputDecoration(labelText: 'GitHub (https://...)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _languagesController,
                    decoration: const InputDecoration(labelText: 'Idiomas (coma separada, ej: es,en,fr)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _cvController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'CV / Resumen profesional'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _savingProfile ? null : _savePublicProfile,
                    icon: const Icon(Icons.save_as_outlined),
                    label: Text(_savingProfile ? 'Guardando...' : 'Guardar perfil público'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seguridad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña actual'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _changingPassword ? null : _changePassword,
                    icon: const Icon(Icons.lock_reset_outlined),
                    label: Text(_changingPassword ? 'Actualizando...' : 'Cambiar contraseña'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zona de cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    bundle.deletion.scheduled
                        ? 'Eliminación programada para: ${bundle.deletion.deletionDate ?? '-'}'
                        : 'No hay eliminación programada',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _requestingDeletion || bundle.deletion.scheduled ? null : _requestDeletion,
                    icon: const Icon(Icons.warning_amber_outlined),
                    label: Text(_requestingDeletion ? 'Programando...' : 'Solicitar eliminación de cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _themes = [
  'dark-red',
  'dark-blue',
  'dark-orange',
  'dark-purple',
  'light-red',
  'light-blue',
  'light-orange',
  'light-purple',
  'noir',
  'marble',
  'ember',
  'ocean',
  'forest',
  'dusk',
];
