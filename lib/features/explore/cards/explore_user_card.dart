part of '../pages/explore_page.dart';

extension _ExploreUserCard on _ExplorePageState {
  Widget _buildUserCard(ExploreUserItem user) {
    final username = user.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final token = _token;
    // La ruta va tal cual al cliente: él la resuelve contra el backend activo
    // y, en web, contra el mismo origen —que es lo que hace que la cookie de
    // sesión viaje con la petición de la imagen.
    final avatarPath = user.avatarPath;
    final inviting = _controller.isInviting(username);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: avatarPath == null
                        ? _userAvatarFallback(initial)
                        : Image(
                            image: ResizeImage(
                              _services.apiClient.authenticatedImage(
                                avatarPath,
                                gaToken: token,
                              ),
                              width: 80,
                              height: 80,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _userAvatarFallback(initial),
                            frameBuilder: (context, child, frame, _) =>
                                frame == null
                                ? _userAvatarFallback(initial)
                                : child,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: FncFonts.size15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${user.followersCount} '
                  '${_tx('explore.users_followers')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${user.publicResourcesCount} '
                  '${_tx('explore.users_resources')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.person_outline,
                  tooltip: _tx('explore.users_view_profile'),
                  onPressed: () => _openProfile(username),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('explore.users_invite'),
                  onPressed: inviting
                      ? null
                      : () => _runAction(_controller.inviteUser(username)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _userAvatarFallback(String initial) {
    return CircleAvatar(
      radius: 20,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: FncFonts.size14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
