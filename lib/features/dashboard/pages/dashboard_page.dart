import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../auth/repositories/auth_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/session_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.backendController,
    required this.sessionController,
    required this.authRepository,
    required this.dashboardRepository,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final token = widget.sessionController.gaToken;
    if (token == null || token.isEmpty) return;
    setState(() => _future = widget.dashboardRepository.fetchData(gaToken: token));
  }

  Future<void> _logout(BuildContext context) async {
    final token = widget.sessionController.gaToken;
    if (token != null && token.isNotEmpty) {
      await widget.authRepository.logout(token);
    }
    await widget.sessionController.logout();
    if (!context.mounted) return;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.user;
    final token = widget.sessionController.gaToken;

    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text('Usuario: ${user?.username ?? '-'}'),
              subtitle: Text('Rol: ${user?.role ?? '-'} · Backend: ${widget.backendController.effectiveBaseUrl}'),
              trailing: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Cerrar sesión',
                onPressed: () => _logout(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (token == null || token.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay token de sesión disponible.'),
              ),
            )
          else
            FutureBuilder<DashboardData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error cargando dashboard: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null) return const SizedBox.shrink();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryGrid(data: data),
                        const SizedBox(height: 14),
                        wide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _ActivityWidget(data: data)),
                                    const SizedBox(width: 14),
                                    Expanded(child: _TokenUsageWidget(data: data)),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  _ActivityWidget(data: data),
                                  const SizedBox(height: 14),
                                  _TokenUsageWidget(data: data),
                                ],
                              ),
                        const SizedBox(height: 14),
                        wide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _ConnectionStatusWidget(
                                        data: data,
                                        token: token,
                                        repository: widget.dashboardRepository,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(child: _RecentAgentsWidget(data: data)),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  _ConnectionStatusWidget(
                                    data: data,
                                    token: token,
                                    repository: widget.dashboardRepository,
                                  ),
                                  const SizedBox(height: 14),
                                  _RecentAgentsWidget(data: data),
                                ],
                              ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DashPanel extends StatelessWidget {
  const _DashPanel({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                ?action,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int, String?, IconData)>[
      ('Agentes', data.agents.length, RouteNames.agents, Icons.smart_toy_outlined),
      ('Conexiones', data.connections.length, RouteNames.connections, Icons.cable_outlined),
      ('Knowledge', data.knowledge.length, RouteNames.knowledge, Icons.menu_book_outlined),
      ('Skills', data.skills.length, RouteNames.knowledge, Icons.auto_awesome_outlined),
      ('Memoria', data.memory.length, RouteNames.knowledge, Icons.description_outlined),
      ('Workflows', data.workflows.length, RouteNames.orchestrations, Icons.account_tree_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 96,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final (label, value, route, icon) = items[index];
        return Card(
          child: InkWell(
            onTap: route == null ? null : () => context.go(route),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(label, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityWidget extends StatelessWidget {
  const _ActivityWidget({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final daily = data.tokenDaily;
    final total = daily.fold<int>(0, (sum, item) => sum + item.tokens);
    final max = daily.fold<int>(0, (m, item) => item.tokens > m ? item.tokens : m);

    return _DashPanel(
      title: 'Actividad (tokens/día)',
      child: daily.isEmpty
          ? const Text('Sin actividad todavía')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total: $total tokens', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: daily.map((point) {
                      final ratio = max > 0 ? point.tokens / max : 0.0;
                      return Expanded(
                        child: Tooltip(
                          message: '${point.day}: ${point.tokens} tokens',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: FractionallySizedBox(
                              heightFactor: ratio.clamp(0.03, 1.0),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(daily.first.day, style: Theme.of(context).textTheme.labelSmall),
                    Text(daily.last.day, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ),
    );
  }
}

class _TokenUsageWidget extends StatelessWidget {
  const _TokenUsageWidget({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final rows = data.connectionsByTokens.take(5).toList();
    final max = rows.isEmpty ? 1 : rows.first.value;

    return _DashPanel(
      title: 'Uso de tokens por conexión',
      child: rows.isEmpty
          ? const Text('Todavía no hay consumo de tokens')
          : Column(
              children: rows.map((entry) {
                final name = entry.key['name']?.toString() ?? entry.key['type']?.toString() ?? 'Conexión';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                          Text('${entry.value}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value / max,
                          minHeight: 6,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _ConnectionStatusWidget extends StatefulWidget {
  const _ConnectionStatusWidget({required this.data, required this.token, required this.repository});

  final DashboardData data;
  final String token;
  final DashboardRepository repository;

  @override
  State<_ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<_ConnectionStatusWidget> {
  bool _testing = false;
  List<ConnectionTestResult> _results = const [];
  bool _tested = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.connections.isNotEmpty) _runTest();
  }

  Future<void> _runTest() async {
    setState(() => _testing = true);
    try {
      final results = await widget.repository.testAllConnections(widget.token);
      if (!mounted) return;
      setState(() {
        _results = results;
        _tested = true;
      });
    } catch (_) {
      // silencioso: el panel simplemente no mostrará resultados
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = widget.data.connections;
    final resultsById = {for (final r in _results) r.id: r};
    final okCount = _results.where((r) => r.ok).length;

    return _DashPanel(
      title: 'Estado de conexiones',
      action: IconButton(
        icon: _testing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
        onPressed: _testing ? null : _runTest,
      ),
      child: connections.isEmpty
          ? const Text('No hay conexiones configuradas')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tested) Text('$okCount / ${connections.length} operativas'),
                const SizedBox(height: 6),
                ...connections.take(6).map((conn) {
                  final id = conn['id']?.toString() ?? '';
                  final name = conn['name']?.toString() ?? conn['type']?.toString() ?? 'Conexión';
                  final result = resultsById[id];
                  final color = result == null
                      ? Colors.grey
                      : (result.ok ? Colors.green.shade600 : Colors.red.shade600);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                        if (result?.latencyMs != null) Text('${result!.latencyMs}ms'),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _RecentAgentsWidget extends StatelessWidget {
  const _RecentAgentsWidget({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final recent = data.agents.reversed.take(4).toList();
    return _DashPanel(
      title: 'Agentes recientes',
      child: recent.isEmpty
          ? const Text('Todavía no hay agentes')
          : Column(
              children: recent.map((agent) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text(agent['name']?.toString() ?? 'Agente'),
                  subtitle: agent['model'] != null ? Text(agent['model'].toString()) : null,
                  onTap: () => context.go(RouteNames.agents),
                );
              }).toList(),
            ),
    );
  }
}
