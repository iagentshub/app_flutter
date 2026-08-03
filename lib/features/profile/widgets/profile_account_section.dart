part of '../pages/profile_page.dart';

extension _ProfileAccountSection on _ProfilePageState {
  Widget _buildAccountSection(ProfileBundle bundle) {
    final username = bundle.session.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final planTier = bundle.license.tier;
    final planLabel = planTier == 'free'
        ? _tx('profile.plan_free', 'Gratuito')
        : planTier;
    final memberSince = bundle.social.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildAvatar(initial),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _badge(
                            bundle.session.role,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          _badge(planLabel, color: const Color(0xFF0891B2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader(
          Icons.badge_outlined,
          _tx('profile.identity_title', 'Identidad'),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _infoRow(
                Icons.groups_outlined,
                _tx('profile.active_group_label', 'Grupo activo'),
                bundle.session.groupName ?? bundle.session.groupId ?? '-',
              ),
              if (memberSince != null && memberSince.isNotEmpty) ...[
                const Divider(height: 1),
                _infoRow(
                  Icons.calendar_today_outlined,
                  _tx('profile.member_since', 'Miembro desde'),
                  memberSince,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(
          Icons.tune_outlined,
          _tx('profile.tab_preferences', 'Preferencias'),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_themeConfigurable)
                  DropdownButtonFormField<String>(
                    initialValue: _theme,
                    decoration: InputDecoration(
                      labelText: _tx('profile.theme_label', 'Tema'),
                    ),
                    items: kThemeIds
                        .map(
                          (theme) => DropdownMenuItem<String>(
                            value: theme,
                            child: Text(theme),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _refresh(() => _theme = value);
                    },
                  )
                else
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: _tx('profile.theme_label', 'Tema'),
                      helperText: _tx(
                        'profile.theme_managed_hint',
                        'El tema está definido por el administrador.',
                      ),
                    ),
                    child: Text(_defaultTheme),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: InputDecoration(
                    labelText: _tx('profile.language_label', 'Idioma'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _refresh(() => _language = value);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  _tx('profile.app_icon_label', 'Icono de la aplicación'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _tx(
                    'profile.app_icon_description',
                    'Elige el icono que se muestra dentro de iAgents.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                const _BrandIconSelector(),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _savingSettings ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _savingSettings
                        ? _tx('profile.saving', 'Guardando...')
                        : _tx(
                            'profile.save_preferences',
                            'Guardar preferencias',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(
          Icons.lock_outline,
          _tx('profile.tab_security', 'Seguridad'),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(_tx('profile.security_hint', 'Contraseña')),
                ),
                SecondaryButton.icon(
                  onPressed: _openChangePasswordDialog,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: Text(
                    _tx('profile.change_password', 'Cambiar contraseña'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(
          Icons.warning_amber_outlined,
          _tx('profile.account_zone_title', 'Zona de cuenta'),
          color: Colors.red,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.deletion.scheduled
                      ? '${_tx('profile.deletion_scheduled', 'Eliminación programada para')}: ${bundle.deletion.deletionDate ?? '-'}'
                      : _tx(
                          'profile.no_deletion_scheduled',
                          'No hay eliminación programada',
                        ),
                ),
                const SizedBox(height: 10),
                SecondaryButton.icon(
                  onPressed: _requestingDeletion || bundle.deletion.scheduled
                      ? null
                      : _requestDeletion,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: Text(
                    _requestingDeletion
                        ? _tx('profile.scheduling', 'Programando...')
                        : _tx(
                            'profile.request_deletion',
                            'Solicitar eliminación de cuenta',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
