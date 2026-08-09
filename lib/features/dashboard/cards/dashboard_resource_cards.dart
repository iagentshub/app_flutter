part of '../pages/dashboard_page.dart';

class _RecentResourcesBody extends StatelessWidget {
  const _RecentResourcesBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final selected = (config.types ?? kRecentResourceTypes).toSet();
    final limit = config.limit ?? 6;
    final resources = <({String type, Map<String, dynamic> raw})>[
      if (selected.contains('agent'))
        for (final raw in data.agents) (type: 'agent', raw: raw),
      if (selected.contains('skill'))
        for (final raw in data.skills) (type: 'skill', raw: raw),
      if (selected.contains('knowledge'))
        for (final raw in data.knowledge) (type: 'knowledge', raw: raw),
      if (selected.contains('workflow'))
        for (final raw in data.workflows) (type: 'workflow', raw: raw),
      if (selected.contains('tool'))
        for (final raw in data.tools) (type: 'tool', raw: raw),
    ]..sort((a, b) => _resourceDate(b.raw).compareTo(_resourceDate(a.raw)));

    if (resources.isEmpty) {
      return Text(tx('no_recent_resources', 'No hay recursos recientes'));
    }

    final metadata = <String, ({IconData icon, String label, String route})>{
      'agent': (
        icon: Icons.smart_toy_outlined,
        label: tx('feed_agent', 'Agente'),
        route: InternalRoutes.agents,
      ),
      'skill': (
        icon: Icons.auto_awesome_outlined,
        label: tx('feed_skill', 'Skill'),
        route: InternalRoutes.knowledge,
      ),
      'knowledge': (
        icon: Icons.menu_book_outlined,
        label: tx('feed_knowledge', 'Knowledge'),
        route: InternalRoutes.knowledge,
      ),
      'workflow': (
        icon: Icons.account_tree_outlined,
        label: tx('summary_workflows', 'Workflow'),
        route: InternalRoutes.orchestrations,
      ),
      'tool': (
        icon: Icons.build_outlined,
        label: tx('feed_tool', 'Herramienta'),
        route: InternalRoutes.knowledge,
      ),
    };

    return Column(
      children: [
        for (final resource in resources.take(limit))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              metadata[resource.type]?.icon,
              color: labelColor(resource.type),
            ),
            title: Text(
              resource.raw['name']?.toString() ??
                  resource.raw['title']?.toString() ??
                  tx('default_resource_name', 'Recurso'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(metadata[resource.type]?.label ?? resource.type),
            onTap: () => AppRouter.go(
              context,
              metadata[resource.type]?.route ?? InternalRoutes.dashboard,
            ),
          ),
      ],
    );
  }

  DateTime _resourceDate(Map<String, dynamic> raw) {
    return DateTime.tryParse(
          raw['updated_at']?.toString() ?? raw['created_at']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _AgentHealthBody extends StatelessWidget {
  const _AgentHealthBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final connectionIds = data.connections
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final issues = <({Map<String, dynamic> agent, List<String> reasons})>[];

    for (final agent in data.agents) {
      final reasons = <String>[];
      final connectionId = agent['connection_id']?.toString() ?? '';
      if (connectionId.isEmpty || !connectionIds.contains(connectionId)) {
        reasons.add(tx('health_no_connection', 'sin conexión'));
      }
      final prompt =
          agent['system_prompt']?.toString() ??
          agent['instructions']?.toString() ??
          '';
      if (prompt.trim().isEmpty) {
        reasons.add(tx('health_no_instructions', 'sin instrucciones'));
      }
      if (reasons.isNotEmpty) issues.add((agent: agent, reasons: reasons));
    }

    final total = data.agents.length;
    final ready = total - issues.length;
    final ratio = total == 0 ? 0.0 : ready / total;
    final limit = config.limit ?? 4;

    if (total == 0) {
      return Text(tx('no_recent_agents', 'Todavía no hay agentes'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tx('health_ready_count', '{{ready}} de {{total}} listos')
                    .replaceAll('{{ready}}', '$ready')
                    .replaceAll('{{total}}', '$total'),
              ),
            ),
            Text('${(ratio * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: ratio),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final issue in issues.take(limit))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: Text(
                issue.agent['name']?.toString() ??
                    tx('default_agent_name', 'Agente'),
              ),
              subtitle: Text(issue.reasons.join(' · ')),
              onTap: () => AppRouter.toAgents(context),
            ),
        ],
      ],
    );
  }
}

class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.data, required this.tx});

  final DashboardData data;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? active;
    for (final group in data.groups) {
      if (group['active'] == true) {
        active = group;
        break;
      }
    }
    final teamCount = data.groups
        .where((group) => group['type'] == 'team')
        .length;

    if (active == null) {
      return Text(tx('group_empty', 'No hay ningún grupo activo'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
          title: Text(active['name']?.toString() ?? 'Grupo'),
          subtitle: Text(
            active['role']?.toString() ?? tx('group_member', 'Miembro'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _GroupStat(
                value: '$teamCount',
                label: tx('group_teams', 'Grupos compartidos'),
              ),
            ),
            Expanded(
              child: _GroupStat(
                value: '${data.invitations.length}',
                label: tx('group_invitations', 'Invitaciones'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TertiaryButton.icon(
            onPressed: () => AppRouter.toManager(context),
            icon: const Icon(Icons.settings_outlined),
            label: Text(tx('group_manage', 'Gestionar')),
          ),
        ),
      ],
    );
  }
}

class _GroupStat extends StatelessWidget {
  const _GroupStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
