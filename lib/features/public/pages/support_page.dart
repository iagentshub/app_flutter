import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/external_router.dart';
import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/public_top_bar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

part '../cards/support_cards.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final languageCode = LocaleLoader.routeLanguageCode(location);
    final isEnglish = languageCode == 'en';

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: LocaleLoader.load(
          languageCode: languageCode,
          namespace: 'support',
        ),
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
                TertiaryButton(
                  onPressed: () => AppRouter.go(
                    context,
                    isEnglish ? ExternalRoutes.docsEn : ExternalRoutes.docs,
                  ),
                  child: Text(isEnglish ? 'Open docs' : 'Abrir documentacion'),
                ),
              ],
            ),
            _SectionCard(
              title: statusTitle,
              subtitle: statusDescription,
              children: [
                TertiaryButton(
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
                    languageCode: languageCode,
                    loginLabel: loginLabel,
                    onLogin: () => AppRouter.toLogin(context),
                    onLanguageSelected: (selected) {
                      final target = selected == 'en'
                          ? ExternalRoutes.supportEn
                          : ExternalRoutes.support;
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
