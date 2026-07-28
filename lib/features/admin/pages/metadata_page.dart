import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../repositories/metadata_repository.dart';
import '../../../shared/state/session_controller.dart';

class MetadataPage extends StatefulWidget {
  const MetadataPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<MetadataPage> createState() => _MetadataPageState();
}

class _MetadataPageState extends State<MetadataPage> {
  late final MetadataRepository _repository;
  final TextEditingController _queryController = TextEditingController();
  List<MetadataTable> _tables = const [];
  MetadataTable? _selectedTable;
  MetadataPageData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = MetadataRepository(apiClient: widget.apiClient);
    _loadTables();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadTables() async {
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
      final tables = await _repository.listTables(token);
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _selectedTable = tables.isNotEmpty ? tables.first : null;
        _loading = false;
      });
      if (_selectedTable != null) {
        await _loadData(page: 1);
      }
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar metadatos';
        _loading = false;
      });
    }
  }

  Future<void> _loadData({required int page}) async {
    final token = _token;
    final table = _selectedTable;
    if (token == null || token.isEmpty || table == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.tableData(
        token,
        tableName: table.name,
        page: page,
        query: _queryController.text,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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
        _error = 'No se pudo cargar la tabla';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _tables.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _tables.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error cargando metadata', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadTables,
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

    final data = _data;
    final selected = _selectedTable;

    return RefreshIndicator(
      onRefresh: _loadTables,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: selected?.name,
                      decoration: const InputDecoration(labelText: 'Tabla'),
                      items: _tables
                          .map((t) => DropdownMenuItem(value: t.name, child: Text('${t.name} (${t.rows})')))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final table = _tables.firstWhere((t) => t.name == value);
                        setState(() => _selectedTable = table);
                        _loadData(page: 1);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(labelText: 'Buscar en tabla'),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: selected == null ? null : () => _loadData(page: 1),
                    icon: const Icon(Icons.search),
                    label: const Text('Consultar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selected != null)
                Text(
                  'Filas estimadas: ${selected.rows} · Columnas: ${selected.colCount} · Size: ${selected.sizeBytes} bytes',
                ),
              const SizedBox(height: 10),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                const SizedBox(height: 10),
              ],
              if (data == null)
                const Text('Selecciona una tabla y consulta para ver datos')
              else ...[
                Text('Página ${data.page}/${data.pages == 0 ? 1 : data.pages} · Total filas: ${data.total}'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: data.columns.map((col) => DataColumn(label: Text(col))).toList(),
                    rows: data.rows
                        .map(
                          (row) => DataRow(
                            cells: [
                              for (var i = 0; i < data.columns.length; i++)
                                DataCell(Text(i < row.length ? (row[i] ?? '') : '')),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: data.page > 1 ? () => _loadData(page: data.page - 1) : null,
                      child: const Text('Anterior'),
                    ),
                    OutlinedButton(
                      onPressed: (data.page < data.pages) ? () => _loadData(page: data.page + 1) : null,
                      child: const Text('Siguiente'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
