import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../repositories/centinel_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../widgets/centinel_functional_tab.dart';
import '../widgets/centinel_probe_tab.dart';
import '../widgets/centinel_stress_tab.dart';

/// Página Centinel: 3 pestañas (Funcionalidad/Rendimiento/Buscar límite),
/// igual que /admin/centinel/ en frontend_vanilla.
class CentinelPage extends StatefulWidget {
  const CentinelPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<CentinelPage> createState() => _CentinelPageState();
}

class _CentinelPageState extends State<CentinelPage>
    with SingleTickerProviderStateMixin {
  late final CentinelRepository _repository;
  late final TabController _tabController;
  late final TranslatedTexts _t;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String? get _token => widget.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _repository = CentinelRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
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
            color: Colors.transparent,
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
