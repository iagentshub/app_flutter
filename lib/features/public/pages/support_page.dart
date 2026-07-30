import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/widgets/public_top_bar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isEnglish = LocaleLoader.isEnglishRoute(location);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: LocaleLoader.load(isEnglish: isEnglish, namespace: 'support'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snapshot.data!;

          final heroTitle = LocaleLoader.text(bundle, 'hero.title');
          final heroSubtitle = LocaleLoader.text(bundle, 'hero.subtitle');
          final contactTitle = LocaleLoader.text(bundle, 'contact.title');
          final contactSubtitle = LocaleLoader.text(bundle, 'contact.subtitle');
          final emailLabel = LocaleLoader.text(
            bundle,
            'contact.channels.email.label',
          );
          final emailValue = LocaleLoader.text(
            bundle,
            'contact.channels.email.value',
          );
          final chatLabel = LocaleLoader.text(
            bundle,
            'contact.channels.chat.label',
          );
          final chatValue = LocaleLoader.text(
            bundle,
            'contact.channels.chat.value',
          );
          final helpTitle = LocaleLoader.text(
            bundle,
            'resources.helpCenter.title',
          );
          final helpDescription = LocaleLoader.text(
            bundle,
            'resources.helpCenter.description',
          );
          final docsTitle = LocaleLoader.text(bundle, 'resources.docs.title');
          final docsDescription = LocaleLoader.text(
            bundle,
            'resources.docs.description',
          );
          final statusTitle = LocaleLoader.text(
            bundle,
            'resources.status.title',
          );
          final statusDescription = LocaleLoader.text(
            bundle,
            'resources.status.description',
          );
          final loginLabel = LocaleLoader.text(
            bundle,
            'header.login',
            fallback: isEnglish ? 'Login' : 'Iniciar sesion',
          );
          final sections = [
            _SectionCard(
              title: contactTitle,
              subtitle: contactSubtitle,
              children: [
                _ChannelRow(label: emailLabel, value: emailValue),
                const SizedBox(height: 8),
                _ChannelRow(label: chatLabel, value: chatValue),
              ],
            ),
            _SectionCard(
              title: helpTitle,
              subtitle: helpDescription,
              children: const [],
            ),
            _SectionCard(
              title: docsTitle,
              subtitle: docsDescription,
              children: [
                TextButton(
                  onPressed: () => context.go(
                    isEnglish ? RouteNames.docsEn : RouteNames.docs,
                  ),
                  child: Text(isEnglish ? 'Open docs' : 'Abrir documentacion'),
                ),
              ],
            ),
            _SectionCard(
              title: statusTitle,
              subtitle: statusDescription,
              children: [
                TextButton(
                  onPressed: null,
                  child: Text(isEnglish ? 'View status' : 'Ver estado'),
                ),
              ],
            ),
          ];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                  child: PublicTopBar(
                    isEnglish: isEnglish,
                    loginLabel: loginLabel,
                    onLogin: () => context.go(RouteNames.login),
                    onLanguageSelected: (selected) {
                      final target = selected == 'en'
                          ? RouteNames.supportEn
                          : RouteNames.support;
                      if ((selected == 'en' && !isEnglish) ||
                          (selected == 'es' && isEnglish)) {
                        context.go(target);
                      }
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text(
                    heroTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Text(
                    heroSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                sliver: ResponsiveSliverMasonryGrid(
                  density: ResponsiveCardDensity.marketing,
                  itemCount: sections.length,
                  itemBuilder: (context, index) => sections[index],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF101010),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD4D4D4)),
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD4D4D4)),
          ),
        ),
      ],
    );
  }
}
