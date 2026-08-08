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
import '../../../shared/tools/tool_language.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';

part '../widgets/agent_form_sections.dart';

/// Diálogo de creación/edición de agentes, en 4 pestañas (Básico, Conexión,
/// Conocimiento, Avanzado). Se reutiliza tanto desde la lista de Agentes
/// como desde el Agent Builder por IA (para revisar/editar el borrador
/// antes de guardarlo), pasando `initial` con los datos a precargar.
class AgentFormDialog extends StatefulWidget {
  const AgentFormDialog({
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
  State<AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<AgentFormDialog> with StateMessaging {
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
  bool _loadingConnections = true;
  String? _connectionId;
  double _temperature = 0.7;
  Set<String> _selectedLabels = {};
  String _agentType = 'generic';

  bool _useMemory = false;
  List<MemoryFileItem> _memoryFiles = const [];
  bool _loadingMemory = true;

  Set<String> _selectedSkillIds = {};
  List<SkillItem> _skills = const [];
  bool _loadingSkills = true;

  Set<String> _selectedKnowledgeIds = {};
  List<KnowledgeItem> _knowledgeItems = const [];
  bool _loadingKnowledge = true;

  Set<String> _selectedPromptIds = {};
  List<PromptItem> _prompts = const [];
  bool _loadingPrompts = true;

  Set<String> _selectedToolIds = {};
  List<ToolItem> _tools = const [];
  bool _loadingTools = true;

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

    _loadConnections();
    _loadMemory();
    _loadSkills();
    _loadKnowledge();
    _loadPrompts();
    _loadTools();
  }

  Future<void> _loadConnections() async {
    try {
      final connections = await _connectionsRepository.listConnections(
        widget.token,
      );
      if (!mounted) return;
      refresh(() {
        _connections = connections;
        _loadingConnections = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingConnections = false);
    }
  }

  Future<void> _loadMemory() async {
    try {
      final list = await _memoryRepository.listFiles(widget.token);
      if (!mounted) return;
      refresh(() {
        _memoryFiles = list;
        _loadingMemory = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingMemory = false);
    }
  }

  Future<void> _loadSkills() async {
    try {
      final list = await _skillsRepository.listSkills(
        widget.token,
        scope: 'all',
      );
      if (!mounted) return;
      refresh(() {
        _skills = list;
        _loadingSkills = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingSkills = false);
    }
  }

  Future<void> _loadKnowledge() async {
    try {
      final list = await _knowledgeRepository.listItems(widget.token);
      if (!mounted) return;
      refresh(() {
        _knowledgeItems = list;
        _loadingKnowledge = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingKnowledge = false);
    }
  }

  Future<void> _loadPrompts() async {
    try {
      final list = await _promptsRepository.listPrompts(
        widget.token,
        scope: 'all',
      );
      if (!mounted) return;
      refresh(() {
        _prompts = list;
        _loadingPrompts = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingPrompts = false);
    }
  }

  Future<void> _loadTools() async {
    try {
      final list = await _toolsRepository.listTools(widget.token, scope: 'all');
      if (!mounted) return;
      refresh(() {
        _tools = list;
        _loadingTools = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingTools = false);
    }
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
      'memory_file': _useMemory && _memoryFileController.text.trim().isNotEmpty
          ? _memoryFileController.text.trim()
          : null,
      'skills': _selectedSkillIds.toList(),
      'knowledge': _selectedKnowledgeIds.toList(),
      'prompts': _selectedPromptIds.toList(),
      'tools': _selectedToolIds.toList(),
    };

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AlertDialog(
        title: Text(_title),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        content: SizedBox(
          width: dialogContentWidth(context, 580),
          height: dialogContentHeight(context, 480),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: widget.tx('agents.tab_basic', 'Básico')),
                    Tab(text: widget.tx('agents.tab_connection', 'Conexión')),
                    Tab(
                      text: widget.tx('agents.tab_knowledge', 'Conocimiento'),
                    ),
                    Tab(text: widget.tx('agents.tab_advanced', 'Avanzado')),
                  ],
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
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: _submit,
            child: Text(widget.tx('common.save', 'Guardar')),
          ),
        ],
      ),
    );
  }
}
