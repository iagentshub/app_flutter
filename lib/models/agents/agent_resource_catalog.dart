import '../connections/connection_models.dart';
import '../knowledge/knowledge_models.dart';
import '../prompts/prompt_models.dart';
import '../skills/skill_models.dart';
import '../tools/tool_models.dart';

/// Snapshot compartida por listado, importación y formulario de agentes.
/// Evita volver a pedir los mismos seis catálogos al abrir cada formulario.
class AgentResourceCatalog {
  const AgentResourceCatalog({
    this.connections = const [],
    this.skills = const [],
    this.knowledge = const [],
    this.packs = const [],
    this.prompts = const [],
    this.tools = const [],
  });

  final List<ConnectionItem> connections;
  final List<SkillItem> skills;
  final List<KnowledgeItem> knowledge;
  final List<KnowledgePack> packs;
  final List<PromptItem> prompts;
  final List<ToolItem> tools;
}
