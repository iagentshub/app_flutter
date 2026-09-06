import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Navegación de secciones: pestañas nativas y selector agrupado en web.
/// Conserva TabBar para teclado, semántica y sincronización con TabBarView.
class AppSectionTabs extends StatelessWidget {
  const AppSectionTabs({
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.tabAlignment,
    super.key,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;
  final TabAlignment? tabAlignment;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return TabBar(
        controller: controller,
        isScrollable: isScrollable,
        tabAlignment: tabAlignment,
        tabs: tabs,
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.10)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerHeight: 0,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(3),
          indicator: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 18),
          splashBorderRadius: BorderRadius.circular(8),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return colors.primary.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.onSurface.withValues(alpha: 0.05);
            }
            if (states.contains(WidgetState.pressed)) {
              return colors.primary.withValues(alpha: 0.10);
            }
            return Colors.transparent;
          }),
          tabs: tabs,
        ),
      ),
    );
  }
}
