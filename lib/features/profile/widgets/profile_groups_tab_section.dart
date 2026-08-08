part of '../pages/profile_page.dart';

extension _ProfileGroupsTabSection on _ProfilePageState {
  Widget _buildGroupsSection(ProfileBundle bundle) {
    final token = _controller.token;
    if (token == null || token.isEmpty) return const SizedBox.shrink();
    return ProfileGroupsSection(
      apiClient: widget.apiClient,
      token: token,
      currentUsername: bundle.session.username,
      localeController: widget.localeController,
    );
  }
}
