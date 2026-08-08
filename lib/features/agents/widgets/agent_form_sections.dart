part of '../pages/agent_form_page.dart';

extension _AgentFormSections on _AgentFormPageState {
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
              if (value == null || value.trim().isEmpty) {
                return widget.tx(
                  'agents.name_required',
                  'El nombre es obligatorio',
                );
              }
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
          GroupedLabelPicker(
            selected: _selectedLabels,
            onChanged: (next) => refresh(() => _selectedLabels = next),
            tx: widget.tx,
          ),
          TextFormField(
            controller: _promptController,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_prompt', 'System prompt'),
            ),
            validator: (value) {
              if (!widget.requireQualityPrompt) return null;
              if (value == null || value.trim().length < 90) {
                return widget.tx(
                  'agents.prompt_too_short',
                  'Añade instrucciones más completas (mínimo 90 caracteres)',
                );
              }
              return null;
            },
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
          _loadingCatalogs
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
                          '${conn.name} (${conn.type == 'llm_orchestration' ? (conn.model == 'balanced' ? widget.tx('llm_orchestrations.balanced', 'Balanceo') : widget.tx('llm_orchestrations.stack', 'Pila')) : conn.type})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => refresh(() => _connectionId = value),
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
            onChanged: (value) => refresh(() => _temperature = value),
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
          Text(
            widget.tx('agents.resources_section_title', 'Recursos del agente'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.tx(
              'agents.resources_section_description',
              'Añade skills, documentos, prompts y herramientas sin saturar el formulario.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingCatalogs)
            const LinearProgressIndicator(minHeight: 2)
          else
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _resourceSummaryRow(
                      icon: Icons.auto_awesome_outlined,
                      label: widget.tx('agents.field_skills', 'Skills'),
                      selectedIds: _selectedSkillIds,
                      names: {for (final item in _skills) item.id: item.name},
                    ),
                    const Divider(height: 24),
                    _resourceSummaryRow(
                      icon: Icons.description_outlined,
                      label: widget.tx(
                        'agents.field_knowledge',
                        'Conocimiento',
                      ),
                      selectedIds: _selectedKnowledgeIds,
                      names: {
                        for (final item in _knowledgeItems) item.id: item.title,
                      },
                    ),
                    const Divider(height: 24),
                    _resourceSummaryRow(
                      icon: Icons.short_text_outlined,
                      label: widget.tx('agents.field_prompts', 'Prompts'),
                      selectedIds: _selectedPromptIds,
                      names: {for (final item in _prompts) item.id: item.name},
                    ),
                    const Divider(height: 24),
                    _resourceSummaryRow(
                      icon: Icons.build_outlined,
                      label: widget.tx('agents.field_tools', 'Herramientas'),
                      selectedIds: _selectedToolIds,
                      names: {for (final item in _tools) item.id: item.name},
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton.icon(
                        key: const ValueKey('agent-open-resources-picker'),
                        onPressed: _openResourcePicker,
                        icon: const Icon(Icons.add_link),
                        label: Text(
                          widget.tx(
                            'agents.resources_manage',
                            'Buscar y seleccionar recursos',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            widget.tx('agents.memory_section_title', 'Memoria persistente'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useMemory,
            title: Text(widget.tx('agents.field_use_memory', 'Usar memoria')),
            onChanged: (value) => refresh(() => _useMemory = value),
          ),
          if (_useMemory) ...[
            _loadingCatalogs
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
                          onSelected: (value) =>
                              refresh(() => _memoryFileController.text = value),
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
        ],
      ),
    );
  }

  Widget _resourceSummaryRow({
    required IconData icon,
    required String label,
    required Set<String> selectedIds,
    required Map<String, String> names,
  }) {
    final selectedNames = selectedIds
        .map((id) => names[id])
        .whereType<String>()
        .take(2)
        .toList();
    final summary = selectedNames.isEmpty
        ? widget.tx('agents.resources_none_selected', 'Sin seleccionar')
        : [
            ...selectedNames,
            if (selectedIds.length > selectedNames.length)
              '+${selectedIds.length - selectedNames.length}',
          ].join(' · ');
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Badge(label: Text('${selectedIds.length}')),
      ],
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
              refresh(() => _agentType = value);
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
