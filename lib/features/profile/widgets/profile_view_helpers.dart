part of '../pages/profile_page.dart';

extension _ProfileViewHelpers on _ProfilePageState {
  Widget _sectionHeader(IconData icon, String text, {Color? color}) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: FncFonts.size12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: resolvedColor,
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: FncColors.white,
          fontSize: FncFonts.size11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    final token = _controller.token;
    final url = _controller.avatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: url == null
                ? _avatarFallback(initial)
                : Image(
                    // El avatar subido puede pesar lo que el administrador
                    // permita —por defecto, lo que sea—; decodificar solo a
                    // 128px (2x el tamaño en pantalla) evita mantener un
                    // bitmap gigante en memoria para un círculo de 64x64.
                    image: ResizeImage(
                      _services.apiClient.authenticatedImage(
                        url,
                        gaToken: token,
                      ),
                      width: 128,
                      height: 128,
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        _avatarFallback(initial),
                    frameBuilder: (context, child, frame, _) =>
                        frame == null ? _avatarFallback(initial) : child,
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            onTap: _controller.uploadingAvatar ? null : _pickAndUploadAvatar,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              child: _controller.uploadingAvatar
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: IAgentsLoadingMark(),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 13,
                      color: FncColors.white,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String initial) {
    return CircleAvatar(
      radius: 32,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: FncFonts.size24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
