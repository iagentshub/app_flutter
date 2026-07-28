import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../explore/repositories/explore_repository.dart';
import '../repositories/public_profile_repository.dart';
import '../../../shared/state/session_controller.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    required this.username,
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final String username;
  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  late final PublicProfileRepository _repository;
  late final ExploreRepository _exploreRepository;

  List<ExploreItem> _resources = const [];
  PublicFollowStatus? _followStatus;
  bool _loading = true;
  String? _error;
  bool _followBusy = false;
  String _type = 'all';

  @override
  void initState() {
    super.initState();
    _repository = PublicProfileRepository(apiClient: widget.apiClient);
    _exploreRepository = ExploreRepository(apiClient: widget.apiClient);
    _load();
  }

  String? get _token => widget.sessionController.gaToken;

  String get _cleanUsername => widget.username.trim();

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.listResources(token, username: _cleanUsername, type: _type),
        _repository.getFollowStatus(token, _cleanUsername),
      ]);

      if (!mounted) return;
      setState(() {
        _resources = results[0] as List<ExploreItem>;
        _followStatus = results[1] as PublicFollowStatus;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el perfil público';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final token = _token;
    final status = _followStatus;
    if (token == null || token.isEmpty || status == null) return;
    setState(() => _followBusy = true);
    try {
      if (status.following) {
        await _repository.unfollow(token, _cleanUsername);
      } else {
        await _repository.follow(token, _cleanUsername);
      }
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar follow', isError: true);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _preview(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final preview = await _exploreRepository.getPreview(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.name),
          content: SizedBox(
            width: 740,
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(preview),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
          ],
        ),
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo abrir preview', isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error cargando perfil público', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final followStatus = _followStatus;
    if (followStatus == null) {
      return const Center(child: Text('Sin estado de seguimiento'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Perfil público @$_cleanUsername',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('Seguidores: ${followStatus.followersCount}'),
                      Text('Siguiendo: ${followStatus.followingCount}'),
                      FilledButton.icon(
                        onPressed: _followBusy ? null : _toggleFollow,
                        icon: Icon(followStatus.following ? Icons.person_remove_alt_1 : Icons.person_add_alt_1),
                        label: Text(_followBusy
                            ? 'Actualizando...'
                            : (followStatus.following ? 'Dejar de seguir' : 'Seguir')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tipo recurso'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('all')),
                        DropdownMenuItem(value: 'agent', child: Text('agent')),
                        DropdownMenuItem(value: 'skill', child: Text('skill')),
                        DropdownMenuItem(value: 'knowledge', child: Text('knowledge')),
                        DropdownMenuItem(value: 'workflow', child: Text('workflow')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                        _load();
                      },
                    ),
                  ),
                  Text('Recursos: ${_resources.length}'),
                ],
              ),
              const SizedBox(height: 12),
              if (_resources.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Este usuario no tiene recursos públicos en este filtro.'),
                  ),
                )
              else
                ..._resources.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.resourceType} · ${item.category} · ⭐ ${item.stars}'),
                      trailing: OutlinedButton.icon(
                        onPressed: () => _preview(item),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Preview'),
                      ),
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
