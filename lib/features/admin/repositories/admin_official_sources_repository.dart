import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../models/official_import_models.dart';

/// Fuentes oficiales del panel de administración.
///
/// Lo que una fuente trae son recursos normales del hub, así que sincronizar
/// invalida también el catálogo y el inventario: lo que se deja de marcar
/// desaparece de golpe.
class AdminOfficialSourcesRepository extends ApiRepository {
  AdminOfficialSourcesRepository({required super.apiClient});

  Future<List<OfficialSource>> list(String token) async {
    final response = await apiClient.get(
      '/api/admin/official-sources',
      gaToken: token,
    );
    final payload = response.body;
    return payload is List
        ? payload
              .whereType<Map>()
              .map(
                (item) => OfficialSource.fromJson(item.cast<String, dynamic>()),
              )
              .toList(growable: false)
        : const <OfficialSource>[];
  }

  /// Alta de la fuente + primera descarga. Devuelve sus componentes para que
  /// el admin elija qué se queda, sin materializar nada todavía.
  Future<ImportDraft> importRepository(
    String token,
    String repositoryUrl, {
    String trackingMode = 'release',
    String importMode = 'deterministic',
    String? llmConnectionId,
  }) async {
    final response = await apiClient.post(
      '/api/admin/official-sources/inspect',
      gaToken: token,
      body: {
        'repository_url': repositoryUrl,
        'tracking_mode': trackingMode,
        'tracking_ref': 'main',
        'import_mode': importMode,
        'llm_connection_id': ?llmConnectionId,
      },
    );
    _invalidate();
    return _hydrateDraft(token, response.json);
  }

  Stream<OfficialImportEvent> importRepositoryStream(
    String token,
    String repositoryUrl, {
    String trackingMode = 'release',
    String importMode = 'deterministic',
    String? llmConnectionId,
  }) async* {
    final lines = apiClient.postStream(
      '/api/admin/official-sources/inspect-stream',
      gaToken: token,
      body: {
        'repository_url': repositoryUrl,
        'tracking_mode': trackingMode,
        'tracking_ref': 'main',
        'import_mode': importMode,
        'llm_connection_id': ?llmConnectionId,
      },
    );
    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final decoded = jsonDecode(line.substring(6));
      if (decoded is! Map) continue;
      final event = decoded.cast<String, dynamic>();
      switch ('${event['type'] ?? ''}') {
        case 'progress':
          yield OfficialImportEvent(
            progress: OfficialImportProgress.fromJson(event),
          );
          break;
        case 'result':
          final value = event['draft'];
          if (value is Map) {
            yield OfficialImportEvent(
              draft: await _hydrateDraft(token, value.cast<String, dynamic>()),
            );
          }
          break;
        case 'error':
          yield OfficialImportEvent(error: '${event['message'] ?? ''}');
          break;
      }
    }
  }

  Future<ImportDraft> createSyncDraft(String token, String sourceId) async {
    final response = await apiClient.post(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}/sync',
      gaToken: token,
    );
    return _hydrateDraft(token, response.json);
  }

  Future<ImportComponent> updateDraftComponent(
    String token,
    String draftId,
    String componentId, {
    bool? selected,
    String? forcedType,
    String? forcedLanguage,
    String? forcedToolLanguage,
    bool? securityAccepted,
    List<String>? dependencies,
  }) async {
    final response = await apiClient.patch(
      '/api/admin/official-source-drafts/${Uri.encodeComponent(draftId)}/'
      'components/${Uri.encodeComponent(componentId)}',
      gaToken: token,
      body: Map<String, dynamic>.fromEntries(
        <MapEntry<String, dynamic>>[
          MapEntry('selected', selected),
          MapEntry('forced_type', forcedType),
          MapEntry('forced_language', forcedLanguage),
          MapEntry('forced_tool_language', forcedToolLanguage),
          MapEntry('security_accepted', securityAccepted),
          MapEntry('dependencies', dependencies),
        ].where((entry) => entry.value != null),
      ),
    );
    return ImportComponent.fromJson(response.json);
  }

  Future<ImportDraft> getDraft(String token, String draftId) async {
    final response = await apiClient.get(
      '/api/admin/official-source-drafts/${Uri.encodeComponent(draftId)}',
      gaToken: token,
    );
    return _hydrateDraft(token, response.json);
  }

  Future<ImportDraft> _hydrateDraft(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final draft = ImportDraft.fromJson(payload);
    final total =
        (payload['component_count'] as num?)?.toInt() ??
        draft.components.length;
    if (draft.components.length >= total) return draft;

    const pageSize = 500;
    final components = <ImportComponent>[];
    for (var offset = 0; offset < total; offset += pageSize) {
      final response = await apiClient.get(
        '/api/admin/official-source-drafts/${Uri.encodeComponent(draft.id)}/'
        'components?offset=$offset&limit=$pageSize',
        gaToken: token,
      );
      final items = response.json['items'] as List? ?? const [];
      components.addAll(
        items.whereType<Map>().map(
          (item) => ImportComponent.fromJson(item.cast<String, dynamic>()),
        ),
      );
    }
    return draft.withComponents(components);
  }

  Future<ImportDiff> getDiff(String token, String draftId) async {
    final response = await apiClient.get(
      '/api/admin/official-source-drafts/${Uri.encodeComponent(draftId)}/diff',
      gaToken: token,
    );
    return ImportDiff.fromJson(response.json);
  }

  Future<GraphBuild> getDraftGraph(String token, String draftId) async {
    final response = await apiClient.get(
      '/api/admin/official-source-drafts/${Uri.encodeComponent(draftId)}/relations',
      gaToken: token,
    );
    return fromRelations(response.json);
  }

  Future<Map<String, dynamic>> applyDraft(String token, String draftId) async {
    final response = await apiClient.post(
      '/api/admin/official-source-drafts/${Uri.encodeComponent(draftId)}/apply',
      gaToken: token,
    );
    _invalidate();
    return response.json;
  }

  Future<OriginInfo> getOrigin(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/admin/resources/${Uri.encodeComponent(resourceType)}/'
      '${Uri.encodeComponent(resourceId)}/origin',
      gaToken: token,
    );
    return OriginInfo.fromJson(response.json);
  }

  /// Sin [componentIds] solo mira qué trae la fuente; con lista, esa pasa a
  /// ser exactamente la selección materializada.
  Future<Map<String, dynamic>> sync(
    String token,
    String sourceId, {
    Set<String>? componentIds,
  }) async {
    final response = await apiClient.post(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}/sync',
      gaToken: token,
      body: componentIds == null
          ? null
          : {'component_ids': componentIds.toList()},
    );
    if (componentIds != null) _invalidate();
    return response.json;
  }

  Future<void> updateSource(
    String token,
    String sourceId,
    Map<String, dynamic> payload,
  ) async {
    await apiClient.put(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}',
      gaToken: token,
      body: payload,
    );
    _invalidate();
  }

  Future<Map<String, dynamic>> deleteSource(
    String token,
    String sourceId,
  ) async {
    final response = await apiClient.delete(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}',
      gaToken: token,
    );
    _invalidate();
    return response.json;
  }

  /// Marca (o desmarca) como oficial un recurso que no viene de ningún
  /// repositorio.
  Future<Map<String, dynamic>> markOfficial(
    String token, {
    required String resourceType,
    required String resourceId,
    required bool official,
  }) async {
    final response = await apiClient.post(
      '/api/admin/resources/${Uri.encodeComponent(resourceType)}/'
      '${Uri.encodeComponent(resourceId)}/official',
      gaToken: token,
      body: {'official': official},
    );
    _invalidate();
    return response.json;
  }

  void _invalidate() {
    apiClient.invalidateCache('/api/admin/official-sources');
    apiClient.invalidateCache('/api/explore');
    apiClient.invalidateCache('/api/admin/explore');
  }
}
