part of '../pages/profile_page.dart';

extension _ProfileSocialSection on _ProfilePageState {
  Widget _buildSocialSection(ProfileBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionHeader(
                Icons.public_outlined,
                _tx('profile.tab_social', 'Perfil público'),
              ),
            ),
            TertiaryButton.icon(
              onPressed: () =>
                  AppRouter.toPublicProfile(context, bundle.session.username),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(_tx('profile.view_public_profile', 'Ver mi perfil')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _bioController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: _tx('profile.bio_label', 'Bio'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tx('profile.languages_label', 'Idiomas'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _selectedLanguages.isEmpty
                          ? Text(
                              _tx(
                                'profile.languages_empty',
                                'Sin idiomas seleccionados',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _languageOptions
                                  .where(
                                    (option) =>
                                        _selectedLanguages.contains(option.$1),
                                  )
                                  .map(
                                    (option) => Chip(
                                      label: Text('${option.$3} ${option.$2}'),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    SecondaryButton.icon(
                      onPressed: _openLanguagesDialog,
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        _tx('profile.manage_languages', 'Gestionar idiomas'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isEmailPublic,
                  onChanged: (value) => _refresh(() => _isEmailPublic = value),
                  secondary: const Icon(Icons.alternate_email, size: 20),
                  title: Text(
                    _tx('profile.email_public_label', 'Mostrar mi email'),
                  ),
                  subtitle: Text(
                    _isEmailPublic
                        ? (_bundle?.session.email ?? '')
                        : _tx(
                            'profile.email_private_hint',
                            'Tu email permanece privado.',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _githubController,
                  decoration: InputDecoration(
                    labelText: _tx('profile.github_label', 'Usuario de GitHub'),
                    prefixIcon: const Icon(Icons.code, size: 20),
                    prefixText: 'github.com/',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tx('profile.cv_label', 'Resumen profesional'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _tx(
                    'profile.cv_hint',
                    'Soporta Markdown. Aparecerá en tu perfil público.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cvController,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(
                    fontFamily: FncFonts.monospace,
                    fontSize: FncFonts.size13,
                  ),
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _savingProfile ? null : _savePublicProfile,
                  icon: const Icon(Icons.save_as_outlined),
                  label: Text(
                    _savingProfile
                        ? _tx('profile.saving', 'Guardando...')
                        : _tx('profile.save_social', 'Guardar perfil público'),
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
