import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/widgets/public_top_bar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isEnglish = LocaleLoader.isEnglishRoute(location);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: LocaleLoader.load(isEnglish: isEnglish, namespace: 'pricing'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snapshot.data!;

          final heroTitle = LocaleLoader.text(bundle, 'hero.title');
          final heroSubtitle = LocaleLoader.text(bundle, 'hero.subtitle');
          final freeName = LocaleLoader.text(bundle, 'plans.free.name');
          final freePrice = LocaleLoader.text(bundle, 'plans.free.price');
          final freeDescription = LocaleLoader.text(
            bundle,
            'plans.free.description',
          );
          final proName = LocaleLoader.text(bundle, 'plans.pro.name');
          final proPrice = LocaleLoader.text(bundle, 'plans.pro.price');
          final proDescription = LocaleLoader.text(
            bundle,
            'plans.pro.description',
          );
          final businessName = LocaleLoader.text(bundle, 'plans.business.name');
          final businessPrice = LocaleLoader.text(
            bundle,
            'plans.business.price',
          );
          final businessDescription = LocaleLoader.text(
            bundle,
            'plans.business.description',
          );
          final ctaLabel = LocaleLoader.text(bundle, 'cta.primary');
          final loginLabel = LocaleLoader.text(
            bundle,
            'header.login',
            fallback: isEnglish ? 'Login' : 'Iniciar sesion',
          );
          final plans = [
            _PlanCard(
              name: freeName,
              price: freePrice,
              description: freeDescription,
              buttonLabel: ctaLabel,
              isPrimary: false,
            ),
            _PlanCard(
              name: proName,
              price: proPrice,
              description: proDescription,
              buttonLabel: ctaLabel,
              isPrimary: true,
            ),
            _PlanCard(
              name: businessName,
              price: businessPrice,
              description: businessDescription,
              buttonLabel: ctaLabel,
              isPrimary: false,
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
                          ? RouteNames.pricingEn
                          : RouteNames.pricing;
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
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                  child: Text(
                    heroSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: ResponsiveSliverMasonryGrid(
                  density: ResponsiveCardDensity.marketing,
                  itemCount: plans.length,
                  itemBuilder: (context, index) => plans[index],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.description,
    required this.buttonLabel,
    required this.isPrimary,
  });

  final String name;
  final String price;
  final String description;
  final String buttonLabel;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPrimary ? const Color(0xFFD90429) : const Color(0xFF333333),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF101010),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isPrimary ? const Color(0xFFD90429) : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD9D9D9)),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.register),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD90429),
                foregroundColor: Colors.white,
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
