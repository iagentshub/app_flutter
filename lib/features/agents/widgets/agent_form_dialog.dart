import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../features/knowledge/repositories/knowledge_repository.dart';
import '../../../features/knowledge/repositories/skills_repository.dart';
import '../../../features/memory/repositories/memory_repository.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/memory/memory_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../shared/widgets/grouped_label_picker.dart';

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
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;

  @override
  State<AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<AgentFormDialog> {
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

    _loadConnections();
    _loadMemory();
    _loadSkills();
    _loadKnowledge();
  }

  Future<void> _loadConnections() async {
    try {
      final list = await _connectionsRepository.listConnections(widget.token);
      if (!mounted) return;
      setState(() {
        _connections = list;
        _loadingConnections = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConnections = false);
    }
  }

  Future<void> _loadMemory() async {
    try {
      final list = await _memoryRepository.listFiles(widget.token);
      if (!mounted) return;
      setState(() {
        _memoryFiles = list;
        _loadingMemory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMemory = false);
    }
  }

  Future<void> _loadSkills() async {
    try {
      final list = await _skillsRepository.listSkills(
        widget.token,
        scope: 'all',
      );
      if (!mounted) return;
      setState(() {
        _skills = list;
        _loadingSkills = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSkills = false);
    }
  }

  Future<void> _loadKnowledge() async {
    try {
      final list = await _knowledgeRepository.listItems(widget.token);
      if (!mounted) return;
      setState(() {
        _knowledgeItems = list;
        _loadingKnowledge = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingKnowledge = false);
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
          width: 580,
          height: 480,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.tx('common.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.tx('common.save', 'Guardar')),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_name', 'Nombre'),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return widget.tx(
                  'agents.name_required',
                  'El nombre es obligatorio',
                );
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_description', 'Descripción'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.tx('agents.field_labels', 'Etiquetas'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          GroupedLabelPicker(
            selected: _selectedLabels,
            onChanged: (next) => setState(() => _selectedLabels = next),
            tx: widget.tx,
          ),
          TextFormField(
            controller: _promptController,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_prompt', 'System prompt'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadingConnections
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _connectionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: widget.tx(
                      'agents.field_connection',
                      'Conexión LLM',
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        widget.tx('agents.no_connection', '-- Sin conexión --'),
                      ),
                    ),
                    ..._connections.map(
                      (conn) => DropdownMenuItem<String>(
                        value: conn.id,
                        child: Text(
                          '${conn.name} (${conn.type})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _connectionId = value),
                ),
          const SizedBox(height: 20),
          Text(
            '${widget.tx('agents.field_temperature', 'Temperatura')}: ${_temperature.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Slider(
            value: _temperature,
            min: 0,
            max: 1,
            divisions: 20,
            label: _temperature.toStringAsFixed(2),
            onChanged: (value) => setState(() => _temperature = value),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useMemory,
            title: Text(widget.tx('agents.field_use_memory', 'Usar memoria')),
            onChanged: (value) => setState(() => _useMemory = value),
          ),
          if (_useMemory) ...[
            _loadingMemory
                ? const LinearProgressIndicator(minHeight: 2)
                : Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memoryFileController,
                          decoration: InputDecoration(
                            labelText: widget.tx(
                              'agents.field_memory_file',
                              'Archivo de memoria',
                            ),
                          ),
                        ),
                      ),
                      if (_memoryFiles.isNotEmpty)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.folder_open_outlined),
                          tooltip: widget.tx(
                            'agents.pick_existing',
                            'Elegir existente',
                          ),
                          onSelected: (value) => setState(
                            () => _memoryFileController.text = value,
                          ),
                          itemBuilder: (context) => _memoryFiles
                              .map(
                                (file) => PopupMenuItem<String>(
                                  value: file.filename,
                                  child: Text(file.filename),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
          ],
          const SizedBox(height: 20),
          Text(
            widget.tx('agents.field_skills', 'Skills'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _loadingSkills
              ? const LinearProgressIndicator(minHeight: 2)
              : _skills.isEmpty
              ? Text(
                  widget.tx('agents.no_skills', 'No hay skills disponibles.'),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _skills.map((skill) {
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedSkillIds.contains(skill.id),
                        title: Text(skill.name),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedSkillIds = {
                                ..._selectedSkillIds,
                                skill.id,
                              };
                            } else {
                              _selectedSkillIds = {..._selectedSkillIds}
                                ..remove(skill.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 20),
          Text(
            widget.tx('agents.field_knowledge', 'Conocimiento'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _loadingKnowledge
              ? const LinearProgressIndicator(minHeight: 2)
              : _knowledgeItems.isEmpty
              ? Text(
                  widget.tx(
                    'agents.no_knowledge',
                    'No hay contenido de conocimiento disponible.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _knowledgeItems.map((item) {
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedKnowledgeIds.contains(item.id),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedKnowledgeIds = {
                                ..._selectedKnowledgeIds,
                                item.id,
                              };
                            } else {
                              _selectedKnowledgeIds = {..._selectedKnowledgeIds}
                                ..remove(item.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _agentType,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_type', 'Tipo de agente'),
            ),
            items: const [
              DropdownMenuItem(value: 'generic', child: Text('generic')),
              DropdownMenuItem(value: 'claude', child: Text('claude')),
              DropdownMenuItem(value: 'openai', child: Text('openai')),
              DropdownMenuItem(value: 'github', child: Text('github')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _agentType = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_model', 'Modelo (opcional)'),
            ),
          ),
        ],
      ),
    );
  }
}
