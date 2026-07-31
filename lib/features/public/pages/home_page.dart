import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/widgets/public_top_bar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

part '../cards/home_cards.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final location = GoRouterState.of(context).matchedLocation;
    final isEnglish = LocaleLoader.isEnglishRoute(location);
    final loginLabel = isEnglish ? 'Sign in' : 'Iniciar sesión';
    final docsLabel = isEnglish
        ? 'Explore the documentation'
        : 'Explorar la documentación';
    final pricingLabel = isEnglish ? 'View plans' : 'Ver planes';
    final title = isEnglish
        ? 'All your AI in one place'
        : 'Toda tu IA en un solo lugar';
    final subtitle = isEnglish
        ? 'Build and share AI agents connected to your own providers — Claude, OpenAI, Gemini, Grok, '
              'Ollama and more — each with its own knowledge, memory and tools. Self-host it on your own '
              'server and keep full control of your data.'
        : 'Crea y comparte agentes de IA conectados a tus propios proveedores —Claude, OpenAI, Gemini, '
              'Grok, Ollama y más—, cada uno con su propio conocimiento, memoria y herramientas. '
              'Despliega en tu propio servidor y mantén el control total de tus datos.';
    const badge = 'Open source · Self-hosted';
    final stats = [
      (number: '6+', label: isEnglish ? 'PROVIDERS' : 'PROVIDERS'),
      (number: '∞', label: isEnglish ? 'AGENTS' : 'AGENTES'),
      (number: '100%', label: isEnglish ? 'PRIVATE' : 'PRIVADO'),
    ];
    final features = [
      (
        title: isEnglish ? 'Multi-agent' : 'Multiagente',
        body: isEnglish
            ? 'Coordinate multiple specialized agents inside the same group.'
            : 'Coordina varios agentes especializados dentro del mismo grupo.',
      ),
      (
        title: isEnglish ? 'Real connections' : 'Conexiones reales',
        body: isEnglish
            ? 'Integrate providers, APIs and services with validation and monitoring.'
            : 'Integra proveedores, APIs y servicios con validación y monitoreo.',
      ),
      (
        title: isEnglish ? 'Live knowledge' : 'Knowledge vivo',
        body: isEnglish
            ? 'Manage documents, versions and context for consistent responses.'
            : 'Gestiona documentos, versiones y contexto para respuestas consistentes.',
      ),
      (
        title: isEnglish ? 'Executable workflows' : 'Workflows ejecutables',
        body: isEnglish
            ? 'Design and run automations with complete traceability.'
            : 'Diseña y ejecuta automatizaciones con trazabilidad completa.',
      ),
      (
        title: isEnglish ? 'Self-hosted' : 'Self-hosted',
        body: isEnglish
            ? 'Deploy on your own infrastructure and keep data sovereignty.'
            : 'Despliega en tu propia infraestructura y conserva soberanía de datos.',
      ),
      (
        title: isEnglish ? 'Group sharing' : 'Compartición por grupos',
        body: isEnglish
            ? 'Share resources across teams while keeping permission control.'
            : 'Comparte recursos por equipos sin perder control de permisos.',
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF050505), Color(0xFF111111)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                  child: PublicTopBar(
                    isEnglish: isEnglish,
                    loginLabel: loginLabel,
                    onLogin: () => context.go(RouteNames.login),
                    onLanguageSelected: (selected) {
                      if (selected == 'es' && isEnglish) {
                        context.go(RouteNames.home);
                      } else if (selected == 'en' && !isEnglish) {
                        context.go(RouteNames.homeEn);
                      }
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 6),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1014),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          badge,
                          style: TextStyle(
                            color: Color(0xFFFF667A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          height: 1.1,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFE8E8E8),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 0,
                        runSpacing: 10,
                        children: [
                          for (final stat in stats)
                            _StatChip(number: stat.number, label: stat.label),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          PrimaryButton(
                            onPressed: () => context.go(
                              isEnglish ? RouteNames.docsEn : RouteNames.docs,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD90429),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                            child: Text(docsLabel),
                          ),
                          SecondaryButton(
                            onPressed: () => context.go(
                              isEnglish
                                  ? RouteNames.pricingEn
                                  : RouteNames.pricing,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFFFFF),
                              side: const BorderSide(color: Color(0xFFFFFFFF)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                            child: Text(pricingLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
                sliver: ResponsiveSliverMasonryGrid(
                  density: ResponsiveCardDensity.marketing,
                  itemCount: features.length,
                  itemBuilder: (context, index) => _FeatureCard(
                    title: features[index].title,
                    body: features[index].body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
