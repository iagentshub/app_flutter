import 'package:flutter/material.dart';

import '../../../models/profile/profile_models.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

class PublicProfilePresentation extends StatelessWidget {
  const PublicProfilePresentation({
    required this.profile,
    required this.avatar,
    required this.followersCount,
    required this.followingCount,
    required this.resourcesCount,
    required this.starsCount,
    required this.isOwnProfile,
    required this.following,
    required this.followBusy,
    required this.onToggleFollow,
    required this.tx,
    super.key,
  });

  final SocialProfile profile;
  final Widget avatar;
  final int followersCount;
  final int followingCount;
  final int resourcesCount;
  final int starsCount;
  final bool isOwnProfile;
  final bool following;
  final bool followBusy;
  final VoidCallback onToggleFollow;
  final String Function(String path) tx;

  bool get _hasContact =>
      (profile.emailPublic?.isNotEmpty ?? false) ||
      (profile.github?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 5, color: theme.colorScheme.primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final identity = _Identity(
                  profile: profile,
                  avatar: avatar,
                  isOwnProfile: isOwnProfile,
                  following: following,
                  followBusy: followBusy,
                  onToggleFollow: onToggleFollow,
                  tx: tx,
                  compact: compact,
                );
                final details = _ProfileDetails(profile: profile, tx: tx);
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      if (_hasContact || profile.languages.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        details,
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: identity),
                    if (_hasContact || profile.languages.isNotEmpty) ...[
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 1,
                        height: 150,
                        child: ColoredBox(color: theme.dividerColor),
                      ),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: details),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(
                  icon: Icons.people_outline,
                  value: followersCount,
                  label: tx('public_profile.followers'),
                ),
                _Metric(
                  icon: Icons.person_outline,
                  value: followingCount,
                  label: tx('public_profile.following'),
                ),
                _Metric(
                  icon: Icons.widgets_outlined,
                  value: resourcesCount,
                  label: tx('public_profile.resources_count'),
                ),
                _Metric(
                  icon: Icons.star_outline,
                  value: starsCount,
                  label: tx('public_profile.stars'),
                  highlighted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.profile,
    required this.avatar,
    required this.isOwnProfile,
    required this.following,
    required this.followBusy,
    required this.onToggleFollow,
    required this.tx,
    required this.compact,
  });

  final SocialProfile profile;
  final Widget avatar;
  final bool isOwnProfile;
  final bool following;
  final bool followBusy;
  final VoidCallback onToggleFollow;
  final String Function(String path) tx;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx('public_profile.eyebrow'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '@${profile.username}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (profile.bio?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          SelectableText(
            profile.bio!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        if (!isOwnProfile) ...[
          const SizedBox(height: 14),
          PrimaryButton.icon(
            onPressed: followBusy ? null : onToggleFollow,
            icon: Icon(
              following ? Icons.person_remove_alt_1 : Icons.person_add_alt_1,
              size: 18,
            ),
            label: Text(
              followBusy
                  ? tx('profile.updating')
                  : following
                  ? tx('public_profile.unfollow_btn')
                  : tx('public_profile.follow_btn'),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [avatar, const SizedBox(height: 14), text],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 18),
        Expanded(child: text),
      ],
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile, required this.tx});

  final SocialProfile profile;
  final String Function(String path) tx;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.languages.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.translate,
            label: tx('public_profile.languages'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final language in profile.languages)
                Chip(label: Text(contentLanguageLabel(tx, language))),
            ],
          ),
        ],
        if (profile.languages.isNotEmpty &&
            ((profile.emailPublic?.isNotEmpty ?? false) ||
                (profile.github?.isNotEmpty ?? false)))
          const SizedBox(height: 16),
        if ((profile.emailPublic?.isNotEmpty ?? false) ||
            (profile.github?.isNotEmpty ?? false)) ...[
          _SectionLabel(
            icon: Icons.contact_page_outlined,
            label: tx('public_profile.contact'),
          ),
          const SizedBox(height: 8),
          if (profile.emailPublic?.isNotEmpty ?? false)
            _ContactLine(
              icon: Icons.alternate_email,
              value: profile.emailPublic!,
            ),
          if (profile.github?.isNotEmpty ?? false)
            _ContactLine(icon: Icons.code, value: profile.github!),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: SelectableText(
              value,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlighted
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: .45,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
