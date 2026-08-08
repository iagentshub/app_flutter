part of '../pages/dashboard_page.dart';

/// Card fija (no descartable) para un banner de notificación vigente — el
/// mensaje ya llega resuelto en el idioma del usuario desde el backend.
class _NotificationBannerCard extends StatelessWidget {
  const _NotificationBannerCard({required this.banner});

  final NotificationBanner banner;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.campaign_outlined,
              color: colors.onPrimaryContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                banner.message,
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
