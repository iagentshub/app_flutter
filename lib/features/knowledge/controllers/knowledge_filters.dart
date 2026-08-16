part of '../pages/knowledge_page.dart';

/// Filtros derivados de las cuatro pestañas de Knowledge.
///
/// Viven fuera de la página porque son cálculo puro sobre lo ya cargado, y
/// porque `feature_architecture_test.dart` no deja que la página crezca sin
/// límite. El estado memoizado sigue en la clase: una extensión no declara
/// campos.
/// Cuántos elementos visibles se consideran suficientes para que la pestaña
/// tenga scroll con el que pedir la página siguiente.
const _minVisibleKnowledgeItems = 12;

extension _KnowledgeFilters on _KnowledgePageState {
  List<KnowledgeItem> get _urlItems =>
      _urlItemsMemo.of([_items, _knowledgeOrigin], () {
        return _items
            .where((item) => item.type == 'url')
            .where(_matchesKnowledgeOrigin)
            .toList();
      });

  List<KnowledgeItem> get _documentItems =>
      _documentItemsMemo.of([_items, _knowledgeOrigin], () {
        return _items
            .where((item) => item.type != 'url')
            .where(_matchesKnowledgeOrigin)
            .toList();
      });

  /// Lo que la pestaña de Documentos enseña de verdad, ya filtrado.
  ///
  /// Los filtros de origen y de modo packs se resuelven aquí, sobre una lista
  /// que llega paginada, así que este recuento es también el que decide si hace
  /// falta pedir más páginas — ver `_ensureKnowledgeCollectionFilled`.
  List<Object> get _knowledgeCollection {
    final all = [..._urlItems, ..._documentItems];
    final items = _knowledgePacksMode
        ? all.where((item) => item.packId == null).toList()
        : all;
    return _knowledgePacksMode
        ? <Object>[..._packs, ...items]
        : <Object>[...items];
  }

  bool _matchesKnowledgeOrigin(KnowledgeItem item) {
    if (_knowledgeOrigin == 'owner') return item.propertyType == 'owner';
    if (_knowledgeOrigin == 'linked') return item.propertyType == 'linked';
    if (_knowledgeOrigin == 'fork') return item.propertyType == 'fork';
    return true;
  }

  int get _knowledgeFilterCount =>
      (_knowledgeOrigin != 'all' ? 1 : 0) + (_knowledgePacksMode ? 0 : 1);

  List<String> get _skillCategoryOptions =>
      _skills.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList()
        ..sort();

  int get _skillFilterCount =>
      (_skillScope != 'all' ? 1 : 0) + (_skillCategory != 'all' ? 1 : 0);

  List<SkillItem> get _filteredSkills =>
      _filteredSkillsMemo.of([_skills, _skillScope, _skillCategory], () {
        return _skills.where((item) {
          if (_skillScope != 'all' && item.scope != _skillScope) return false;
          if (_skillCategory != 'all' && item.category != _skillCategory) {
            return false;
          }
          return true;
        }).toList();
      });

  int get _promptFilterCount => _promptScope != 'all' ? 1 : 0;

  List<PromptItem> get _filteredPrompts => _filteredPromptsMemo.of(
    [_prompts, _promptScope],
    () {
      return _prompts
          .where((item) => _promptScope == 'all' || item.scope == _promptScope)
          .toList();
    },
  );

  List<String> get _toolLanguageOptions =>
      _tools.map((t) => t.language).where((l) => l.isNotEmpty).toSet().toList()
        ..sort();

  int get _toolFilterCount =>
      (_toolScope != 'all' ? 1 : 0) + (_toolLanguage != 'all' ? 1 : 0);

  List<ToolItem> get _filteredTools =>
      _filteredToolsMemo.of([_tools, _toolScope, _toolLanguage], () {
        return _tools.where((item) {
          if (_toolScope != 'all' && item.scope != _toolScope) return false;
          if (_toolLanguage != 'all' && item.language != _toolLanguage) {
            return false;
          }
          return true;
        }).toList();
      });
}
