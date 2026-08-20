part of '../app_shell.dart';

class _WidgetPickerDrawerContent extends StatelessWidget {
  const _WidgetPickerDrawerContent({required this.state, required this.tx});

  final DashboardEditState state;
  final String Function(String key) tx;

  /// La clave lleva el tipo de widget dentro, así que puede no existir: se cae
  /// al propio tipo, que es legible.
  String _dashboardTx(String key) => trOr('dashboard_$key', key);

  @override
  Widget build(BuildContext context) {
    final missing = state.missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            tx('customize_dashboard'),
            style: const TextStyle(
              fontSize: FncFonts.size16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tx('customize_hint'),
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
                  child: Text(tx('customize_empty')),
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
