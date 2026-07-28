import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../auth/repositories/auth_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../../../models/dashboard/dashboard_summary.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/session_controller.dart';

class DashboardPage extends StatelessWidget {
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

  Future<void> _logout(BuildContext context) async {
    final token = sessionController.gaToken;
    if (token != null && token.isNotEmpty) {
      await authRepository.logout(token);
    }
    await sessionController.logout();
    if (!context.mounted) return;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = sessionController.user;
    final token = sessionController.gaToken;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text('Usuario: ${user?.username ?? '-'}'),
            subtitle: Text('Rol: ${user?.role ?? '-'}'),
            trailing: const Icon(Icons.account_circle_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Backend activo'),
            subtitle: Text(backendController.effectiveBaseUrl),
            trailing: const Icon(Icons.cloud_done_outlined),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
        const SizedBox(height: 12),
        if (token == null || token.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay token de sesion disponible.'),
            ),
          )
        else
          FutureBuilder<DashboardSummary>(
            future: dashboardRepository.fetchSummary(gaToken: token),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error cargando dashboard: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              final summary = snapshot.data;
              if (summary == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No se recibieron datos del dashboard.'),
                  ),
                );
              }

              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SummaryCard(label: 'Agentes', value: summary.agents),
                  _SummaryCard(label: 'Conexiones', value: summary.connections),
                  _SummaryCard(label: 'Knowledge', value: summary.knowledge),
                  _SummaryCard(label: 'Workflows', value: summary.workflows),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
