part of '../pages/dashboard_page.dart';

class _ConnectionStatusBody extends StatefulWidget {
  const _ConnectionStatusBody({
    super.key,
    required this.data,
    required this.token,
    required this.repository,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final String token;
  final DashboardRepository repository;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  State<_ConnectionStatusBody> createState() => _ConnectionStatusBodyState();
}

class _ConnectionStatusBodyState extends State<_ConnectionStatusBody> {
  bool _testing = false;
  List<ConnectionTestResult> _results = const [];
  bool _tested = false;

  List<Map<String, dynamic>> get _connections {
    final scope = widget.config.scope ?? 'all';
    if (scope != 'personal') return widget.data.connections;
    return widget.data.connections
        .where((c) => c['_personal_key'] == true || c['scope'] == 'personal')
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (_connections.isNotEmpty) _runTest();
  }

  Future<void> _runTest() async {
    setState(() => _testing = true);
    try {
      final ids = _connections
          .map((connection) => connection['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final results = await widget.repository.testAllConnections(
        widget.token,
        ids: ids,
      );
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
    final connections = _connections;
    final pageSize = widget.config.pageSize ?? 4;
    final resultsById = {for (final r in _results) r.id: r};
    final okCount = _results.where((r) => r.ok).length;
    final defaultConnectionName = widget.tx(
      'default_connection_name',
      'Conexión',
    );

    if (connections.isEmpty) {
      return Text(
        widget.tx('no_connections', 'No hay conexiones configuradas'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tested
                  ? widget
                        .tx(
                          'operational_count',
                          '{{ok}} / {{total}} operativas',
                        )
                        .replaceAll('{{ok}}', '$okCount')
                        .replaceAll('{{total}}', '${connections.length}')
                  : widget.tx('checking', 'Comprobando…'),
            ),
            AppIconButton(
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              onPressed: _testing ? null : _runTest,
            ),
          ],
        ),
        ...connections.take(pageSize).map((conn) {
          final id = conn['id']?.toString() ?? '';
          final name =
              conn['name']?.toString() ??
              conn['type']?.toString() ??
              defaultConnectionName;
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
    );
  }
}

class _RecentAgentsBody extends StatelessWidget {
  const _RecentAgentsBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final pageSize = config.pageSize ?? 4;
    final recent = data.agents.reversed.take(pageSize).toList();
    final defaultAgentName = tx('default_agent_name', 'Agente');
    if (recent.isEmpty) {
      return Text(tx('no_recent_agents', 'Todavía no hay agentes'));
    }
    return Column(
      children: recent.map((agent) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.smart_toy_outlined),
          title: Text(agent['name']?.toString() ?? defaultAgentName),
          subtitle: agent['model'] != null
              ? Text(agent['model'].toString())
              : null,
          onTap: () => context.go(RouteNames.agents),
        );
      }).toList(),
    );
  }
}

class _RecentConversationsBody extends StatelessWidget {
  const _RecentConversationsBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final limit = config.limit ?? 5;
    final agentNames = {
      for (final agent in data.agents)
        if (agent['id'] != null)
          agent['id'].toString():
              agent['name']?.toString() ?? tx('default_agent_name', 'Agente'),
    };
    final conversations = data.conversations.take(limit).toList();

    if (conversations.isEmpty) {
      return Text(
        tx('no_recent_conversations', 'Todavía no hay conversaciones'),
      );
    }
    return Column(
      children: [
        for (final conversation in conversations)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.forum_outlined),
            title: Text(
              (conversation['title']?.toString().trim().isNotEmpty ?? false)
                  ? conversation['title'].toString()
                  : tx('untitled_conversation', 'Conversación sin título'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              agentNames[conversation['agent_id']?.toString()] ??
                  tx('default_agent_name', 'Agente'),
            ),
            onTap: () => context.go(RouteNames.agents),
          ),
      ],
    );
  }
}

class _CompositionBody extends StatelessWidget {
  const _CompositionBody({required this.data, required this.tx});

  final DashboardData data;
  final DashboardTx tx;

  static const _colors = [
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final c in data.connections) {
      final key = (c['type']?.toString() ?? 'other').toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final a in data.agents) {
      final model = a['model']?.toString() ?? 'other';
      final key = model.toLowerCase().split(RegExp('[-/]')).first;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(6).toList();
    if (top.isEmpty) {
      return Text(tx('no_composition_data', 'Sin datos suficientes todavía'));
    }
    final max = top.first.value;

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(top[i].key), Text('${top[i].value}')],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top[i].value / max,
                    minHeight: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _colors[i % _colors.length],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
