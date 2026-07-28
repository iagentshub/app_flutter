import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/memory/pages/memory_page.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/skills/skill_models.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/skills_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/filter_chips_row.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  late final KnowledgeRepository _repository;
  late final SkillsRepository _skillsRepository;
  late final TranslatedTexts _t;
  List<KnowledgeItem> _items = const [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String _filter = 'all';

  String _section = 'knowledge';
  List<SkillItem> _skills = const [];
  bool _skillsLoading = true;
  String? _skillsError;
  String? _activeGroupId;
  bool _groupsVisible = false;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = KnowledgeRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(localeController: widget.localeController, namespace: 'resources')
      ..addListener(_onTextsChanged);
    _load();
    _loadSkills();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadSkills() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _skillsError = 'No hay sesión activa';
        _skillsLoading = false;
      });
      return;
    }
    setState(() {
      _skillsLoading = true;
      _skillsError = null;
    });
    try {
      final skills = await _skillsRepository.listSkills(token, groupId: _activeGroupId);
      if (!mounted) return;
      setState(() {
        _skills = skills;
        _skillsLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _skillsError = error.message;
        _skillsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _skillsError = 'No se pudieron cargar las skills';
        _skillsLoading = false;
      });
    }
  }

  Future<void> _openCreateSkillDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _SkillFormDialog(),
    );
    if (payload == null) return;
    await _saveSkill(payload);
  }

  Future<void> _openEditSkillDialog(SkillItem item) async {
    if (item.readOnly) {
      _showMessage('Esta skill no es editable (pública o compartida)');
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _skillsRepository.getSkill(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SkillFormDialog(initial: initial),
    );
    if (payload == null) return;
    payload['id'] = item.id;
    await _saveSkill(payload);
  }

  Future<void> _saveSkill(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final scope = (payload.remove('scope') as String?) ?? 'private';
    try {
      await _skillsRepository.saveSkill(token, scope, payload);
      _showMessage('Skill guardada');
      await _loadSkills();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar la skill', isError: true);
    }
  }

  Future<void> _deleteSkill(SkillItem item) async {
    if (item.readOnly) {
      _showMessage('Esta skill no se puede eliminar (pública o compartida)');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar skill'),
        content: Text('¿Seguro que quieres eliminar "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _skillsRepository.deleteSkill(token, item.scope, item.id);
      _showMessage('Skill eliminada');
      await _loadSkills();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar la skill', isError: true);
    }
  }

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
      final type = _filter == 'all' ? null : _filter;
      final items = await _repository.listItems(token, type: type, groupId: _activeGroupId);
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = 'No se pudo cargar Knowledge';
        _loading = false;
      });
    }
  }

  Future<void> _openAddTextDialog() async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddTextDialog(),
    );
    if (payload == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.addText(
        token,
        title: payload['title'] ?? '',
        source: payload['source'],
        content: payload['content'] ?? '',
      );
      _showMessage('Texto añadido a Knowledge');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar el texto', isError: true);
    }
  }

  Future<void> _openAddUrlDialog() async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddUrlDialog(),
    );
    if (payload == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.addUrl(
        token,
        url: payload['url'] ?? '',
        title: payload['title'],
      );
      _showMessage('URL importada a Knowledge');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo importar la URL', isError: true);
    }
  }

  Future<void> _uploadDocument() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('No se pudieron leer los bytes del fichero', isError: true);
      return;
    }

    setState(() => _uploading = true);
    try {
      await _repository.uploadDocument(
        token,
        fileName: file.name,
        fileBytes: bytes,
      );
      _showMessage('Documento subido: ${file.name}');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo subir el documento', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteItem(KnowledgeItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar item'),
        content: Text('¿Seguro que quieres eliminar "${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteItem(token, item.id);
      _showMessage('Item eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar el item', isError: true);
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

  void _onGroupSelect(String? groupId) {
    setState(() => _activeGroupId = groupId);
    _load();
    _loadSkills();
  }

  Future<void> _shareItem(KnowledgeItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'knowledge',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _load,
    );
  }

  Future<void> _shareSkill(SkillItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'skill',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _loadSkills,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'knowledge', label: Text('Conocimiento'), icon: Icon(Icons.menu_book_outlined)),
                    ButtonSegment(value: 'skills', label: Text('Skills'), icon: Icon(Icons.auto_awesome_outlined)),
                    ButtonSegment(value: 'memory', label: Text('Memoria'), icon: Icon(Icons.memory_outlined)),
                  ],
                  selected: {_section},
                  onSelectionChanged: (selection) => setState(() => _section = selection.first),
                ),
              ),
              if (_section != 'memory') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => setState(() => _groupsVisible = !_groupsVisible),
                  icon: const Icon(Icons.groups_outlined),
                  tooltip: _tx('groups.toggle_tooltip', 'Grupos'),
                  isSelected: _groupsVisible,
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _buildSection()),
      ],
    );

    if (_section == 'memory' || !_groupsVisible) return content;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final groupPanel = GroupFilterPanel(
          apiClient: widget.apiClient,
          token: _token ?? '',
          activeGroupId: _activeGroupId,
          onSelect: _onGroupSelect,
          localeController: widget.localeController,
          vertical: wide,
        );

        if (!wide) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: groupPanel,
              ),
              Expanded(child: content),
            ],
          );
        }
        return Row(
          children: [
            groupPanel,
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildSection() {
    return switch (_section) {
      'skills' => _buildSkillsSection(),
      'memory' => MemoryPage(apiClient: widget.apiClient, sessionController: widget.sessionController),
      _ => _buildKnowledgeSection(),
    };
  }

  Widget _buildKnowledgeSection() {
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
                  const Text('Error cargando Knowledge', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _openAddTextDialog,
                    icon: const Icon(Icons.text_snippet_outlined),
                    label: const Text('Añadir texto'),
                  ),
                  FilledButton.icon(
                    onPressed: _openAddUrlDialog,
                    icon: const Icon(Icons.link_outlined),
                    label: const Text('Importar URL'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadDocument,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_uploading ? 'Subiendo...' : 'Subir documento'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilterChipsRow(
                          options: const [
                            ('all', 'Todos'),
                            ('text', 'Texto'),
                            ('url', 'URL'),
                            ('document', 'Documento'),
                          ],
                          value: _filter,
                          onChanged: (value) {
                            setState(() => _filter = value);
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_items.length}', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay items de conocimiento para este filtro.'),
                  ),
                )
              else
                ..._items.map(_buildItemCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    if (_skillsLoading) return const Center(child: CircularProgressIndicator());

    if (_skillsError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error cargando Skills', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_skillsError!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadSkills,
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

    return RefreshIndicator(
      onRefresh: _loadSkills,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _openCreateSkillDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva skill'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadSkills,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Skills: ${_skills.length}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              if (_skills.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay skills todavía.'),
                  ),
                )
              else
                ..._skills.map(_buildSkillCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillCard(SkillItem item) {
    final metaParts = <String>[item.scope];
    if (item.category.isNotEmpty) metaParts.add(item.category);
    if (item.tags.isNotEmpty) metaParts.add(item.tags.join(', '));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (item.shared) _chip('shared'),
              ],
            ),
            const SizedBox(height: 6),
            Text(metaParts.join(' · ')),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.labels,
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlazado'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('common.share_group', 'Compartir con grupo'),
                  onPressed: () => _shareSkill(item),
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditSkillDialog(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteSkill(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(KnowledgeItem item) {
    final icon = switch (item.type) {
      'url' => Icons.public,
      'document' => Icons.description_outlined,
      _ => Icons.notes_outlined,
    };

    final metaParts = <String>[item.type, '${item.charCount} chars'];
    if (item.source.isNotEmpty) metaParts.add(item.source);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(metaParts.join(' · ')),
            if (item.preview.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.preview.trim(), maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            OriginBadge(
              shared: item.shared,
              ownerLabel: _tx('common.owner', 'Propietario'),
              linkedLabel: _tx('common.linked', 'Enlazado'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('common.share_group', 'Compartir con grupo'),
                  onPressed: () => _shareItem(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AddTextDialog extends StatefulWidget {
  const _AddTextDialog();

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'source': _sourceController.text.trim(),
      'content': _contentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir texto'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Título obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(labelText: 'Fuente (opcional)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(labelText: 'Contenido'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Contenido obligatorio';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _AddUrlDialog extends StatefulWidget {
  const _AddUrlDialog();

  @override
  State<_AddUrlDialog> createState() => _AddUrlDialogState();
}

class _AddUrlDialogState extends State<_AddUrlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'url': _urlController.text.trim(),
      'title': _titleController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar URL'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL'),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) return 'URL obligatoria';
                  final uri = Uri.tryParse(raw);
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    return 'URL no válida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Importar')),
      ],
    );
  }
}

class _SkillFormDialog extends StatefulWidget {
  const _SkillFormDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_SkillFormDialog> createState() => _SkillFormDialogState();
}

class _SkillFormDialogState extends State<_SkillFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _iconController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  late final TextEditingController _contentController;
  String _scope = 'private';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?['name']?.toString() ?? '');
    _descriptionController = TextEditingController(text: initial?['description']?.toString() ?? '');
    _iconController = TextEditingController(text: initial?['icon']?.toString() ?? '🔧');
    _categoryController = TextEditingController(text: initial?['category']?.toString() ?? '');
    final tags = initial?['tags'];
    _tagsController = TextEditingController(text: tags is List ? tags.join(', ') : '');
    _contentController = TextEditingController(text: initial?['content']?.toString() ?? '');
    _scope = (initial?['scope'] as String?) ?? 'private';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tags = _tagsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'icon': _iconController.text.trim().isEmpty ? '🔧' : _iconController.text.trim(),
      'category': _categoryController.text.trim(),
      'tags': tags,
      'content': _contentController.text.trim(),
      'scope': _scope,
    };
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva skill' : 'Editar skill'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _iconController,
                      decoration: const InputDecoration(labelText: 'Icono'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Nombre obligatorio' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('private')),
                  DropdownMenuItem(value: 'public', child: Text('public')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _scope = value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (coma separada)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(labelText: 'Contenido de la skill'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
