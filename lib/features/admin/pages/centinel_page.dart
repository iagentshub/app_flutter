import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../repositories/centinel_repository.dart';
import '../widgets/centinel_functional_tab.dart';
import '../widgets/centinel_probe_tab.dart';
import '../widgets/centinel_stress_tab.dart';

/// Página Centinel: 3 pestañas (Funcionalidad/Rendimiento/Buscar límite),
/// Página principal de administración de Centinel.
class CentinelPage extends StatefulWidget {
  const CentinelPage({super.key});

  @override
  State<CentinelPage> createState() => _CentinelPageState();
}

class _CentinelPageState extends State<CentinelPage>
    with SingleTickerProviderStateMixin {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final CentinelRepository _repository;
  late final TabController _tabController;
  late final TranslatedTexts _t;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String? get _token => _services.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _repository = CentinelRepository(apiClient: _services.apiClient);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    if (token == null || token.isEmpty) {
      return Center(
        child: Text(_tx('common.no_session', 'No hay sesión activa')),
      );
    }

    final tabLabels = [
      _tx('centinel.tab_functional', 'Funcionalidad'),
      _tx('centinel.tab_stress', 'Rendimiento'),
      _tx('centinel.tab_probe', 'Buscar límite'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: FncColors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tabController.index,
            children: [
              CentinelFunctionalTab(
                repository: _repository,
                token: token,
                tx: _tx,
              ),
              CentinelStressTab(repository: _repository, token: token, tx: _tx),
              CentinelProbeTab(repository: _repository, token: token, tx: _tx),
            ],
          ),
        ),
      ],
    );
  }
}
