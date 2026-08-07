part of '../dialogs/agent_form_dialog.dart';

extension _AgentFormSections on _AgentFormDialogState {
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
          Text(
            widget.tx('agents.field_labels', 'Etiquetas'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useMemory,
            title: Text(widget.tx('agents.field_use_memory', 'Usar memoria')),
            onChanged: (value) => refresh(() => _useMemory = value),
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
                          onSelected: (value) => refresh(
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
                          refresh(() {
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
                          refresh(() {
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
          const SizedBox(height: 20),
          Text(
            widget.tx('agents.field_prompts', 'Prompts'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _loadingPrompts
              ? const LinearProgressIndicator(minHeight: 2)
              : _prompts.isEmpty
              ? Text(
                  widget.tx('agents.no_prompts', 'No hay prompts disponibles.'),
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
                    children: _prompts.map((prompt) {
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedPromptIds.contains(prompt.id),
                        title: Text(prompt.name),
                        subtitle: Text(
                          '@${prompt.alias}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) {
                          refresh(() {
                            if (value == true) {
                              _selectedPromptIds = {
                                ..._selectedPromptIds,
                                prompt.id,
                              };
                            } else {
                              _selectedPromptIds = {..._selectedPromptIds}
                                ..remove(prompt.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 20),
          Text(
            widget.tx('agents.field_tools', 'Herramientas'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _loadingTools
              ? const LinearProgressIndicator(minHeight: 2)
              : _tools.isEmpty
              ? Text(
                  widget.tx(
                    'agents.no_tools',
                    'No hay herramientas disponibles.',
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
                    children: _tools.map((tool) {
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedToolIds.contains(tool.id),
                        title: Text(tool.name),
                        subtitle: Text(
                          toolLanguageLabel(widget.tx, tool.language),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) {
                          refresh(() {
                            if (value == true) {
                              _selectedToolIds = {..._selectedToolIds, tool.id};
                            } else {
                              _selectedToolIds = {..._selectedToolIds}
                                ..remove(tool.id);
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
