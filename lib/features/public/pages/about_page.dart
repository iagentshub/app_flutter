import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/widgets/public_top_bar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isEnglish = LocaleLoader.isEnglishRoute(location);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: LocaleLoader.load(isEnglish: isEnglish, namespace: 'about'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snapshot.data!;

          final heroTitle = LocaleLoader.text(bundle, 'hero.title');
          final heroSubtitle = LocaleLoader.text(bundle, 'hero.subtitle');
          final missionTitle = LocaleLoader.text(bundle, 'mission.title');
          final missionDescription = LocaleLoader.text(
            bundle,
            'mission.description',
          );
          final visionTitle = LocaleLoader.text(bundle, 'vision.title');
          final visionDescription = LocaleLoader.text(
            bundle,
            'vision.description',
          );
          final ctaTitle = LocaleLoader.text(bundle, 'cta.title');
          final ctaDescription = LocaleLoader.text(bundle, 'cta.description');
          final ctaButton = LocaleLoader.text(bundle, 'cta.button');
          final loginLabel = LocaleLoader.text(
            bundle,
            'header.login',
            fallback: isEnglish ? 'Login' : 'Iniciar sesion',
          );
          final infoCards = [
            _InfoCard(title: missionTitle, body: missionDescription),
            _InfoCard(title: visionTitle, body: visionDescription),
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
                          ? RouteNames.aboutEn
                          : RouteNames.about;
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
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    heroSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                sliver: ResponsiveSliverMasonryGrid(
                  density: ResponsiveCardDensity.marketing,
                  itemCount: infoCards.length,
                  itemBuilder: (context, index) => infoCards[index],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF3A3A3A)),
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF121212),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctaTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            ctaDescription,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFFD3D3D3)),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () => context.go(RouteNames.register),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD90429),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(ctaButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0E0E0E),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD6D6D6)),
            ),
          ],
        ),
      ),
    );
  }
}
