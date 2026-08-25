part of '../pages/profile_page.dart';

extension _ProfileAccountSection on _ProfilePageState {
  Widget _buildAccountSection(ProfileBundle bundle) {
    final username = bundle.session.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final planTier = bundle.license.tier;
    final planLabel = planTier == 'free' ? _tx('profile.plan_free') : planTier;
    // El backend manda ISO-8601 completo, con segundos, microsegundos y zona.
    // Se pintaba tal cual: veintitantos caracteres en UTC para decir un día.
    final memberSince = formatDateTimeShort(bundle.social.createdAt);

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
                          fontSize: FncFonts.size20,
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
                          _badge(planLabel, color: FncColors.teal),
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
        _sectionHeader(Icons.badge_outlined, _tx('profile.identity_title')),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _infoRow(
                Icons.groups_outlined,
                _tx('profile.active_group_label'),
                bundle.session.groupName ?? bundle.session.groupId ?? '-',
              ),
              if (bundle.social.createdAt?.isNotEmpty ?? false) ...[
                const Divider(height: 1),
                _infoRow(
                  Icons.calendar_today_outlined,
                  _tx('profile.member_since'),
                  memberSince,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(Icons.tune_outlined, _tx('profile.tab_preferences')),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_controller.themeConfigurable)
                  DropdownButtonFormField<String>(
                    initialValue: _controller.theme,
                    decoration: InputDecoration(
                      labelText: _tx('profile.theme_label'),
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
                      _controller.setTheme(value);
                    },
                  )
                else
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: _tx('profile.theme_label'),
                      helperText: _tx('profile.theme_managed_hint'),
                    ),
                    child: Text(_controller.defaultTheme),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _controller.language,
                  decoration: InputDecoration(
                    labelText: _tx('profile.language_label'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _controller.setLanguage(value);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  _tx('profile.app_icon_label'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _tx('profile.app_icon_description'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _BrandIconSelector(tx: _tx),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _controller.savingSettings
                      ? null
                      : () => _runAction(_controller.saveSettings()),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _controller.savingSettings
                        ? _tx('profile.saving')
                        : _tx('profile.save_preferences'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(Icons.lock_outline, _tx('profile.tab_security')),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_tx('profile.security_hint'))),
                    SecondaryButton.icon(
                      onPressed: _openChangePasswordDialog,
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: Text(_tx('profile.change_password')),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(child: Text(_tx('profile.sessions_hint'))),
                    SecondaryButton.icon(
                      onPressed: _openActiveSessionsDialog,
                      icon: const Icon(Icons.devices_other),
                      label: Text(_tx('profile.sessions_open')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(
          Icons.warning_amber_outlined,
          _tx('profile.account_zone_title'),
          color: FncColors.materialRed,
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
                      ? '${_tx('profile.deletion_scheduled')}: '
                            '${formatDateTimeShort(bundle.deletion.deletionDate)}'
                      : _tx('profile.no_deletion_scheduled'),
                ),
                const SizedBox(height: 10),
                SecondaryButton.icon(
                  onPressed:
                      _controller.requestingDeletion ||
                          bundle.deletion.scheduled
                      ? null
                      : _requestDeletion,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: Text(
                    _controller.requestingDeletion
                        ? _tx('profile.scheduling')
                        : _tx('profile.request_deletion'),
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
