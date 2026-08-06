part of '../app_shell.dart';

class _WidgetPickerDrawerContent extends StatelessWidget {
  const _WidgetPickerDrawerContent({required this.state, required this.t});

  final DashboardEditState state;
  final Map<String, dynamic> t;

  String _dashboardTx(String key, String fallback) =>
      LocaleLoader.text(t, 'dashboard_$key', fallback: fallback);

  @override
  Widget build(BuildContext context) {
    final missing = state.missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            LocaleLoader.text(
              t,
              'customize_dashboard',
              fallback: 'Personalizar dashboard',
            ),
            style: const TextStyle(
              fontSize: FncFonts.size16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            LocaleLoader.text(
              t,
              'customize_hint',
              fallback: 'Toca un widget para añadirlo al dashboard.',
            ),
            style: const TextStyle(
              fontSize: FncFonts.size12,
              color: FncColors.materialGrey,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: missing.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    LocaleLoader.text(
                      t,
                      'customize_empty',
                      fallback: 'Ya has añadido todos los widgets disponibles.',
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: missing.map((id) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => state.addWidget(id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                dashboardWidgetDefinition(id)?.icon ??
                                    Icons.widgets_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dashboardWidgetTitle(id, _dashboardTx),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  dashboardWidgetSizeLabel(id, _dashboardTx),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.add, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
