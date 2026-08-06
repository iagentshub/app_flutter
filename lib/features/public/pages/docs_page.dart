import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/external_router.dart';
import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/widgets/public_top_bar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

part '../cards/docs_cards.dart';

class DocsPage extends StatelessWidget {
  const DocsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isEnglish = LocaleLoader.isEnglishRoute(location);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: LocaleLoader.load(isEnglish: isEnglish, namespace: 'docs'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snapshot.data!;

          final heroTitle = LocaleLoader.text(bundle, 'hero.title');
          final heroSubtitle = LocaleLoader.text(bundle, 'hero.subtitle');
          final quickTitle = LocaleLoader.text(bundle, 'quickStart.title');
          final quickDescription = LocaleLoader.text(
            bundle,
            'quickStart.description',
          );
          final quickStep1 = LocaleLoader.text(bundle, 'quickStart.steps.0');
          final quickStep2 = LocaleLoader.text(bundle, 'quickStart.steps.1');
          final quickStep3 = LocaleLoader.text(bundle, 'quickStart.steps.2');
          final sectionsTitle = LocaleLoader.text(bundle, 'sections.title');
          final integrationsTitle = LocaleLoader.text(
            bundle,
            'sections.items.integrations.title',
          );
          final integrationsDesc = LocaleLoader.text(
            bundle,
            'sections.items.integrations.description',
          );
          final apiTitle = LocaleLoader.text(
            bundle,
            'sections.items.api.title',
          );
          final apiDesc = LocaleLoader.text(
            bundle,
            'sections.items.api.description',
          );
          final troubleshootingTitle = LocaleLoader.text(
            bundle,
            'sections.items.troubleshooting.title',
          );
          final troubleshootingDesc = LocaleLoader.text(
            bundle,
            'sections.items.troubleshooting.description',
          );
          final loginLabel = LocaleLoader.text(
            bundle,
            'header.login',
            fallback: isEnglish ? 'Login' : 'Iniciar sesion',
          );
          final sectionCards = [
            _Card(title: integrationsTitle, subtitle: integrationsDesc),
            _Card(title: apiTitle, subtitle: apiDesc),
            _Card(title: troubleshootingTitle, subtitle: troubleshootingDesc),
          ];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                  child: PublicTopBar(
                    isEnglish: isEnglish,
                    loginLabel: loginLabel,
                    onLogin: () => AppRouter.toLogin(context),
                    onLanguageSelected: (selected) {
                      final target = selected == 'en'
                          ? ExternalRoutes.docsEn
                          : ExternalRoutes.docs;
                      if ((selected == 'en' && !isEnglish) ||
                          (selected == 'es' && isEnglish)) {
                        AppRouter.go(context, target);
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
                      color: FncColors.white,
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
                      color: FncColors.grayE0E0E0,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                  child: _Card(
                    title: quickTitle,
                    subtitle: quickDescription,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepLine(step: '1', text: quickStep1),
                        _StepLine(step: '2', text: quickStep2),
                        _StepLine(step: '3', text: quickStep3),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Text(
                    sectionsTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: FncColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: ResponsiveSliverMasonryGrid(
                  density: ResponsiveCardDensity.marketing,
                  itemCount: sectionCards.length,
                  itemBuilder: (context, index) => sectionCards[index],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
