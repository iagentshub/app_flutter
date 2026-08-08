import '../../../core/network/scoped_resource_repository.dart';
import '../../../models/skills/skill_models.dart';

/// Skills: `/api/skills/<scope>/<id>`.
///
/// Todo el contrato vive en [ScopedResourceRepository]; aquí solo quedan los
/// nombres de dominio, que en el punto de llamada dicen más que un `list()`
/// suelto.
class SkillsRepository extends ScopedResourceRepository<SkillItem> {
  SkillsRepository({required super.apiClient})
    : super(basePath: 'skills', parse: _asSkill);

  static SkillItem _asSkill(Map<String, dynamic> raw) => SkillItem(raw: raw);

  Future<List<SkillItem>> listSkills(
    String token, {
    String scope = 'all',
    String? groupId,
    bool includeInactive = false,
  }) => list(
    token,
    scope: scope,
    groupId: groupId,
    includeInactive: includeInactive,
  );

  Future<Map<String, dynamic>> getSkill(
    String token,
    String scope,
    String id,
  ) => get(token, scope, id);

  Future<Map<String, dynamic>> saveSkill(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) => save(token, scope, payload);

  Future<void> deleteSkill(String token, String scope, String id) =>
      remove(token, scope, id);

  Future<void> setSkillActive(String token, String id, bool active) =>
      setResourceActive(token, id, active);
}
