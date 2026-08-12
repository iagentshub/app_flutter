import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../features/knowledge/repositories/knowledge_repository.dart';
import '../../../features/knowledge/repositories/prompts_repository.dart';
import '../../../features/knowledge/repositories/skills_repository.dart';
import '../../../features/knowledge/repositories/tools_repository.dart';
import '../../../features/memory/repositories/memory_repository.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/memory/memory_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/tools/tool_language.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../dialogs/agent_publish_dependencies_dialog.dart';
import '../dialogs/agent_resource_picker_dialog.dart';

part '../widgets/agent_form_sections.dart';

/// Vista dedicada de creación/edición de agentes.
///
/// El formulario devuelve el payload con [Navigator.pop], de modo que puede
/// reutilizarse desde la lista, una plantilla pública o el constructor por IA
/// sin encerrar una tarea larga dentro de un diálogo.
class AgentFormPage extends StatefulWidget {
  const AgentFormPage({
    required this.apiClient,
    required this.token,
    required this.tx,
    this.initial,
    this.requireQualityPrompt = false,
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;
  final bool requireQualityPrompt;

  @override
  State<AgentFormPage> createState() => _AgentFormPageState();
}

class _AgentFormPageState extends State<AgentFormPage> with StateMessaging {
  /// Un único indicador para los seis catálogos: llegan juntos.
  bool _loadingCatalogs = true;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  late final TextEditingController _memoryFileController;
  late final ConnectionsRepository _connectionsRepository;
  late final MemoryRepository _memoryRepository;
  late final SkillsRepository _skillsRepository;
  late final KnowledgeRepository _knowledgeRepository;
  late final PromptsRepository _promptsRepository;
  late final ToolsRepository _toolsRepository;

  List<ConnectionItem> _connections = const [];
  String? _connectionId;
  double _temperature = 0.7;
  Set<String> _selectedLabels = {};
  String _agentType = 'generic';

  bool _useMemory = false;
  List<MemoryFileItem> _memoryFiles = const [];

  Set<String> _selectedSkillIds = {};
  List<SkillItem> _skills = const [];

  Set<String> _selectedKnowledgeIds = {};
  List<KnowledgeItem> _knowledgeItems = const [];

  Set<String> _selectedPromptIds = {};
  List<PromptItem> _prompts = const [];

  Set<String> _selectedToolIds = {};
  List<ToolItem> _tools = const [];
  Set<String> _publishedDependencyKeys = {};

  /// La visibilidad ya no es un campo aparte: es la label "private"/"public"
  /// del grupo excluyente de Visibilidad (una sola fuente de verdad).
  String get _scope =>
      _selectedLabels.contains('public') ? 'public' : 'private';

  String get _title => widget.initial == null
      ? widget.tx('agents.new_title', 'Nuevo agente')
      : widget.tx('agents.edit_title', 'Editar agente');

  @override
  void initState() {
    super.initState();
    _connectionsRepository = ConnectionsRepository(apiClient: widget.apiClient);
    _memoryRepository = MemoryRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _knowledgeRepository = KnowledgeRepository(apiClient: widget.apiClient);
    _promptsRepository = PromptsRepository(apiClient: widget.apiClient);
    _toolsRepository = ToolsRepository(apiClient: widget.apiClient);
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    _modelController = TextEditingController(
      text: initial?['model']?.toString() ?? '',
    );
    _promptController = TextEditingController(
      text: initial?['system_prompt']?.toString() ?? '',
    );

    final connId = initial?['connection_id']?.toString() ?? '';
    _connectionId = connId.isEmpty ? null : connId;
    _temperature =
        (num.tryParse(initial?['temperature']?.toString() ?? '0.7') ?? 0.7)
            .toDouble()
            .clamp(0.0, 1.0);

    final labelsRaw = initial?['labels'];
    _selectedLabels = labelsRaw is List
        ? labelsRaw.map((e) => e.toString()).toSet()
        : {'private'};
    if (!_selectedLabels.contains('private') &&
        !_selectedLabels.contains('public')) {
      _selectedLabels = {..._selectedLabels, 'private'};
    }
    final legacyLanguage = initial?['language']?.toString().toLowerCase() ?? '';
    final legacyLanguageLabel = languageLabelKey(legacyLanguage);
    if (kContentLanguageCodes.contains(legacyLanguage) &&
        !_selectedLabels.contains(legacyLanguageLabel)) {
      _selectedLabels = {..._selectedLabels, legacyLanguageLabel};
    }

    _agentType = (initial?['agent_type'] as String?) ?? 'generic';

    final memoryFile = initial?['memory_file']?.toString() ?? '';
    _useMemory = memoryFile.isNotEmpty;
    _memoryFileController = TextEditingController(text: memoryFile);

    final skillsRaw = initial?['skills'];
    _selectedSkillIds = skillsRaw is List
        ? skillsRaw.map((e) => e.toString()).toSet()
        : {};
    final knowledgeRaw = initial?['knowledge'];
    _selectedKnowledgeIds = knowledgeRaw is List
        ? knowledgeRaw.map((e) => e.toString()).toSet()
        : {};
    final promptsRaw = initial?['prompts'];
    _selectedPromptIds = promptsRaw is List
        ? promptsRaw.map((e) => e.toString()).toSet()
        : {};
    final toolsRaw = initial?['tools'];
    _selectedToolIds = toolsRaw is List
        ? toolsRaw.map((e) => e.toString()).toSet()
        : {};
    final publishedDependenciesRaw = initial?['public_dependencies'];
    _publishedDependencyKeys = publishedDependenciesRaw is List
        ? publishedDependenciesRaw.map((value) => value.toString()).toSet()
        : {};

    _loadCatalogs();
  }

  /// Los seis catálogos se pedían con seis métodos calcados, seis flags y seis
  /// setState: llegaban en orden impredecible y el formulario se reconstruía
  /// hasta seis veces, con las secciones apareciendo a saltos. Una sola espera
  /// deja un único repintado y un único indicador de carga.
  ///
  /// Cada petición conserva su propio catch: que falle el catálogo de memoria
  /// no debe dejar sin skills al formulario.
  Future<void> _loadCatalogs() async {
    Future<List<T>> opcional<T>(Future<List<T>> peticion) =>
        peticion.catchError((_) => <T>[]);

    final resultados = await Future.wait([
      opcional(_connectionsRepository.listConnections(widget.token)),
      opcional(_memoryRepository.listFiles(widget.token)),
      opcional(_skillsRepository.listSkills(widget.token, scope: 'all')),
      opcional(_knowledgeRepository.listItems(widget.token)),
      opcional(_promptsRepository.listPrompts(widget.token, scope: 'all')),
      opcional(_toolsRepository.listTools(widget.token, scope: 'all')),
    ]);
    if (!mounted) return;
    refresh(() {
      _connections = resultados[0] as List<ConnectionItem>;
      _memoryFiles = resultados[1] as List<MemoryFileItem>;
      _skills = resultados[2] as List<SkillItem>;
      _knowledgeItems = resultados[3] as List<KnowledgeItem>;
      _prompts = resultados[4] as List<PromptItem>;
      _tools = resultados[5] as List<ToolItem>;
      _loadingCatalogs = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    _memoryFileController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Set<String> dependenciesToPublish = {};
    if (_scope == 'public') {
      final options = _publicationOptions();
      if (options.isNotEmpty) {
        final selection = await showAgentPublishDependenciesDialog(
          context: context,
          options: options,
          initialSelection: _publishedDependencyKeys,
          tx: widget.tx,
        );
        if (!mounted || selection == null) return;
        dependenciesToPublish = selection;
        _publishedDependencyKeys = selection;
      }
    }

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'scope': _scope,
      'agent_type': _agentType,
      'model': _modelController.text.trim(),
      'connection_id': _connectionId ?? '',
      'system_prompt': _promptController.text.trim(),
      'temperature': _temperature,
      'labels': _selectedLabels.toList(),
      'language': _selectedLabels
          .where(isLanguageLabel)
          .map(languageCodeFromLabel)
          .whereType<String>()
          .firstOrNull,
      'memory_file': _useMemory && _memoryFileController.text.trim().isNotEmpty
          ? _memoryFileController.text.trim()
          : null,
      'use_memory': _useMemory,
      'skills': _selectedSkillIds.toList(),
      'knowledge': _selectedKnowledgeIds.toList(),
      'prompts': _selectedPromptIds.toList(),
      'tools': _selectedToolIds.toList(),
      'publish_dependencies': dependenciesToPublish.toList()..sort(),
    };

    Navigator.of(context).pop(payload);
  }

  List<AgentPublishDependencyOption> _publicationOptions() {
    bool isPublic(List<String> labels, String scope) =>
        scope == 'public' || labels.contains('public');

    final options = <AgentPublishDependencyOption>[];
    for (final id in _selectedSkillIds) {
      final item = _skills.where((candidate) => candidate.id == id).firstOrNull;
      options.add(
        AgentPublishDependencyOption(
          key: 'skill:$id',
          name: item?.name ?? id,
          typeLabel: widget.tx('resources.skill', 'Skill'),
          alreadyPublic: item != null && isPublic(item.labels, item.scope),
        ),
      );
    }
    for (final id in _selectedKnowledgeIds) {
      final item = _knowledgeItems
          .where((candidate) => candidate.id == id)
          .firstOrNull;
      options.add(
        AgentPublishDependencyOption(
          key: 'knowledge:$id',
          name: item?.title ?? id,
          typeLabel: widget.tx('resources.knowledge', 'Conocimiento'),
          alreadyPublic: item != null && isPublic(item.labels, item.scope),
        ),
      );
    }
    for (final id in _selectedPromptIds) {
      final item = _prompts
          .where((candidate) => candidate.id == id)
          .firstOrNull;
      options.add(
        AgentPublishDependencyOption(
          key: 'prompt:$id',
          name: item?.name ?? id,
          typeLabel: widget.tx('resources.prompt', 'Prompt'),
          alreadyPublic: item != null && isPublic(item.labels, item.scope),
        ),
      );
    }
    for (final id in _selectedToolIds) {
      final item = _tools.where((candidate) => candidate.id == id).firstOrNull;
      options.add(
        AgentPublishDependencyOption(
          key: 'tool:$id',
          name: item?.name ?? id,
          typeLabel: widget.tx('resources.tool', 'Tool'),
          alreadyPublic: item != null && isPublic(item.labels, item.scope),
        ),
      );
    }
    final memoryFile = _memoryFileController.text.trim();
    if (_useMemory && memoryFile.isNotEmpty) {
      options.add(
        AgentPublishDependencyOption(
          key: 'memory:$memoryFile',
          name: memoryFile,
          typeLabel: widget.tx('resources.memory', 'Memoria'),
        ),
      );
    }
    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return options;
  }

  Future<void> _openResourcePicker() async {
    if (_loadingCatalogs) return;
    final selection = await showDialog<AgentResourceSelection>(
      context: context,
      builder: (context) => AgentResourcePickerDialog(
        options: [
          for (final skill in _skills)
            AgentResourceOption(
              id: skill.id,
              type: AgentResourceType.skill,
              title: skill.name,
              subtitle: skill.category,
            ),
          for (final item in _knowledgeItems)
            AgentResourceOption(
              id: item.id,
              type: AgentResourceType.knowledge,
              title: item.title,
              subtitle: item.type,
            ),
          for (final prompt in _prompts)
            AgentResourceOption(
              id: prompt.id,
              type: AgentResourceType.prompt,
              title: prompt.name,
              subtitle: prompt.alias.isEmpty ? '' : '@${prompt.alias}',
            ),
          for (final tool in _tools)
            AgentResourceOption(
              id: tool.id,
              type: AgentResourceType.tool,
              title: tool.name,
              subtitle: toolLanguageLabel(widget.tx, tool.language),
            ),
        ],
        initial: AgentResourceSelection(
          skillIds: _selectedSkillIds,
          knowledgeIds: _selectedKnowledgeIds,
          promptIds: _selectedPromptIds,
          toolIds: _selectedToolIds,
        ),
        tx: widget.tx,
      ),
    );
    if (!mounted || selection == null) return;
    refresh(() {
      _selectedSkillIds = selection.skillIds;
      _selectedKnowledgeIds = selection.knowledgeIds;
      _selectedPromptIds = selection.promptIds;
      _selectedToolIds = selection.toolIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(_title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PrimaryButton.icon(
                key: const ValueKey('agent-form-save'),
                onPressed: _submit,
                icon: const Icon(Icons.check, size: 18),
                label: Text(widget.tx('common.save', 'Guardar')),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Material(
                          color: colors.surfaceContainerLow,
                          child: TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              Tab(
                                text: widget.tx('agents.tab_basic', 'Básico'),
                              ),
                              Tab(
                                text: widget.tx(
                                  'agents.tab_connection',
                                  'Conexión',
                                ),
                              ),
                              Tab(
                                text: widget.tx(
                                  'agents.tab_knowledge',
                                  'Conocimiento',
                                ),
                              ),
                              Tab(
                                text: widget.tx(
                                  'agents.tab_advanced',
                                  'Avanzado',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildBasicTab(),
                              _buildConnectionTab(),
                              _buildKnowledgeTab(),
                              _buildAdvancedTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
