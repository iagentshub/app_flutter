part of 'explore_controller.dart';

extension ExploreResourceLoading on ExploreController {
  Future<void> _scheduleResourceLoad() {
    // Invalida inmediatamente una página o carga anterior; no esperamos a que
    // venza el debounce para impedir que una respuesta del filtro viejo entre.
    _resourceLoadGeneration++;
    _resourceFilterTimer?.cancel();
    final previous = _resourceFilterCompleter;
    if (previous != null && !previous.isCompleted) previous.complete();
    final completer = Completer<void>();
    _resourceFilterCompleter = completer;
    _resourceFilterTimer = Timer(const Duration(milliseconds: 150), () async {
      await load();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> load() async {
    final generation = ++_resourceLoadGeneration;
    final token = _token;
    if (token == null || token.isEmpty) {
      _error = _tx('common.no_session');
      _loading = false;
      _notify();
      return;
    }

    _loading = true;
    _error = null;
    _notify();

    try {
      final resourcesFuture = _repository.listResourcePage(
        token,
        type: _type,
        query: queryController.text,
        category: _category,
        labels: _labels.toList(),
        languages: _languages.toList(),
        includeOfficial: !_officialPacksMode,
        packMode: _officialPacksMode,
        relation: _relation,
        limit: ExploreController.resourcesPageSize,
      );
      final packsFuture = _officialPacksMode
          ? _repository.listOfficialPacks(
              token,
              type: _type,
              query: queryController.text,
              category: _category,
              labels: _labels.toList(),
              languages: _languages.toList(),
              relation: _relation,
            )
          : Future<List<ExploreOfficialPack>>.value(const []);
      final results = await Future.wait([resourcesFuture, packsFuture]);
      if (generation != _resourceLoadGeneration || _disposed) return;
      final resourceResult =
          results[0] as ({PageResult<ExploreItem> page, int linkedMatches});
      final resourcePage = resourceResult.page;
      _items = resourcePage.items;
      // La página recién llegada ya trae `starred` por fila: el override de la
      // pantalla anterior sobra y solo podría contradecirla.
      _starOverride.clear();
      _seenResourceCursors.clear();
      _nextResourcesCursor = resourcePage.nextCursor;
      if (_nextResourcesCursor != null) {
        _seenResourceCursors.add(_nextResourcesCursor!);
      }
      _resourcesHasMore = resourcePage.hasMore;
      _officialPacks = results[1] as List<ExploreOfficialPack>;
      // Solo la envía el backend cuando el filtro dejó la página vacía; con
      // packs en pantalla no hay vacío que explicar, y los packs son de la
      // carga que acaba de llegar, no de la anterior.
      _linkedMatches = _officialPacks.isEmpty
          ? resourceResult.linkedMatches
          : 0;
      if (_type == 'all') {
        _typeCounts.clear();
        for (final item in _items) {
          _typeCounts.update(
            item.resourceType,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        for (final pack in _officialPacks) {
          for (final entry in pack.counts.entries) {
            _typeCounts.update(
              entry.key,
              (count) => count + entry.value,
              ifAbsent: () => entry.value,
            );
          }
        }
      }
      _loading = false;
      if (_category.isNotEmpty && !categoryOptions.contains(_category)) {
        _category = '';
      }
    } on ApiError catch (error) {
      if (generation != _resourceLoadGeneration || _disposed) return;
      _error = error.message;
      _loading = false;
    } catch (_) {
      if (generation != _resourceLoadGeneration || _disposed) return;
      _error = _tx('explore.error_title');
      _loading = false;
    }
    _notify();
  }

  Future<ActionResult?> loadMoreResources() async {
    final token = _token;
    if (token == null ||
        token.isEmpty ||
        _resourcesLoadingMore ||
        !_resourcesHasMore) {
      return null;
    }
    final generation = _resourceLoadGeneration;
    _resourcesLoadingMore = true;
    _notify();
    try {
      final page = await _repository.listResourcePage(
        token,
        type: _type,
        query: queryController.text,
        category: _category,
        labels: _labels.toList(),
        languages: _languages.toList(),
        includeOfficial: !_officialPacksMode,
        packMode: _officialPacksMode,
        relation: _relation,
        limit: ExploreController.resourcesPageSize,
        cursor: _nextResourcesCursor,
      );
      if (generation != _resourceLoadGeneration || _disposed) return null;
      final known = _items.map(itemKey).toSet();
      _items = [
        ..._items,
        ...page.page.items.where((item) => known.add(itemKey(item))),
      ];
      final nextCursor = page.page.nextCursor;
      if (nextCursor != null && !_seenResourceCursors.add(nextCursor)) {
        throw const CursorPaginationException.repeatedCursor();
      }
      _nextResourcesCursor = nextCursor;
      _resourcesHasMore = page.page.hasMore;
      return null;
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.error_title'));
    } finally {
      _resourcesLoadingMore = false;
      _notify();
    }
  }
}
