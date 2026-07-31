part of '../pages/profile_page.dart';

extension _ProfileSecuritySection on _ProfilePageState {
  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.lock_outline,
          _tx('profile.tab_security', 'Seguridad'),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
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
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'profile.new_password_label',
                      'Nueva contraseña',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _changingPassword ? null : _changePassword,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: Text(
                    _changingPassword
                        ? _tx('profile.updating', 'Actualizando...')
                        : _tx('profile.change_password', 'Cambiar contraseña'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsSection(ProfileBundle bundle) {
    final token = _token;
    if (token == null || token.isEmpty) return const SizedBox.shrink();
    return ProfileGroupsSection(
      apiClient: widget.apiClient,
      token: token,
      currentUsername: bundle.session.username,
      localeController: widget.localeController,
    );
  }
}
