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
                _tx('profile.tab_social'),
              ),
            ),
            TertiaryButton.icon(
              onPressed: () =>
                  AppRouter.toPublicProfile(context, bundle.session.username),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(_tx('profile.view_public_profile')),
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
                  controller: _controller.bioController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: _tx('profile.bio_label'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tx('profile.languages_label'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: !_controller.hasLanguages
                          ? Text(
                              _tx('profile.languages_empty'),
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _languageOptions
                                  .where(
                                    (option) =>
                                        _controller.hasLanguage(option.$1),
                                  )
                                  .map(
                                    (option) => Chip(label: Text(option.$2)),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    SecondaryButton.icon(
                      onPressed: _openLanguagesDialog,
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(_tx('profile.manage_languages')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _controller.isEmailPublic,
                  onChanged: _controller.setEmailPublic,
                  secondary: const Icon(Icons.alternate_email, size: 20),
                  title: Text(_tx('profile.email_public_label')),
                  subtitle: Text(
                    _controller.isEmailPublic
                        ? (bundle.session.email ?? '')
                        : _tx('profile.email_private_hint'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _controller.githubController,
                  decoration: InputDecoration(
                    labelText: _tx('profile.github_label'),
                    prefixIcon: const Icon(Icons.code, size: 20),
                    prefixText: 'github.com/',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tx('profile.cv_label'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _tx('profile.cv_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _controller.cvController,
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
                  onPressed: _controller.savingProfile
                      ? null
                      : () => _runAction(_controller.savePublicProfile()),
                  icon: const Icon(Icons.save_as_outlined),
                  label: Text(
                    _controller.savingProfile
                        ? _tx('profile.saving')
                        : _tx('profile.save_social'),
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
