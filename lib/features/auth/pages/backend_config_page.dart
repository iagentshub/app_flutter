import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../shared/state/backend_controller.dart';

class BackendConfigPage extends StatefulWidget {
  const BackendConfigPage({required this.backendController, super.key});

  final BackendController backendController;

  @override
  State<BackendConfigPage> createState() => _BackendConfigPageState();
}

class _BackendConfigPageState extends State<BackendConfigPage> {
  late final TextEditingController _newBackendController;
  String? _statusMessage;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _newBackendController = TextEditingController(
      text: widget.backendController.effectiveBaseUrl,
    );
  }

  @override
  void dispose() {
    _newBackendController.dispose();
    super.dispose();
  }

  Future<void> _saveBackend() async {
    final error = widget.backendController.backendInputError(_newBackendController.text);
    if (error != null) {
      setState(() => _statusMessage = error);
      return;
    }

    await widget.backendController.saveCustomBackend(_newBackendController.text, selectSaved: true);
    if (!mounted) return;
    _newBackendController.text = widget.backendController.effectiveBaseUrl;
    setState(() => _statusMessage = 'Backend guardado y seleccionado: ${widget.backendController.effectiveBaseUrl}');
  }

  Future<void> _checkBackend() async {
    final rawInput = _newBackendController.text.trim();
    final target = rawInput.isEmpty
        ? widget.backendController.effectiveBaseUrl
        : widget.backendController.normalizeBackendInput(rawInput);

    if (target.isEmpty) {
      setState(() => _statusMessage = 'Backend inválido. Usa dominio/IP y puerto opcional');
      return;
    }

    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    try {
      final uri = Uri.parse('$target/api/settings/platform/public');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = response.body;
        final json = body.isNotEmpty ? jsonDecode(body) : null;
        final hasGuest = json is Map<String, dynamic> ? json['guest_enabled'] == true : false;
        final registration = json is Map<String, dynamic> ? (json['registration'] ?? 'n/a').toString() : 'n/a';
        setState(
          () => _statusMessage = hasGuest
              ? 'Conexión OK $target (HTTP ${response.statusCode}) · guest=true · registration=$registration'
              : 'Conexión OK $target (HTTP ${response.statusCode}) · guest=false · registration=$registration',
        );
      } else {
        setState(() => _statusMessage = 'Backend $target responde HTTP ${response.statusCode}');
      }
    } catch (error) {
      setState(() => _statusMessage = 'No se pudo conectar: $error');
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.backendController.selectedBackendId;
    final backendLabel = widget.backendController.selectedOption.label;
    final backendUrl = widget.backendController.effectiveBaseUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar backend')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend actual',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2D2D2D)),
                        ),
                        child: Text(
                          '$backendLabel\n$backendUrl',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownMenu<String>(
                        width: double.infinity,
                        enableSearch: true,
                        enableFilter: true,
                        menuHeight: 320,
                        initialSelection: selectedId,
                        label: const Text('Seleccionar backend'),
                        onSelected: (value) async {
                          if (value == null) return;
                          await widget.backendController.setSelectedBackend(value);
                          if (!mounted) return;
                          final selected = widget.backendController.selectedOption;
                          _newBackendController.text = selected.editable
                              ? widget.backendController.customBackendUrl
                              : selected.baseUrl;
                          setState(() {});
                        },
                        dropdownMenuEntries: widget.backendController.options
                            .map(
                              (backend) => DropdownMenuEntry<String>(
                                value: backend.id,
                                label: backend.label,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newBackendController,
                        decoration: const InputDecoration(
                          labelText: 'Dominio/IP y puerto opcional',
                          hintText: 'www.iagentshub.com o 192.168.1.20:8765',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Puedes comprobar conexión sin guardar.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saveBackend,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar backend en lista'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _checking ? null : _checkBackend,
                          icon: const Icon(Icons.wifi_find),
                          label: Text(_checking ? 'Comprobando...' : 'Comprobar conexión'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'URL activa: ${widget.backendController.effectiveBaseUrl}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _statusMessage!.startsWith('Conexión OK')
                                ? const Color(0xFF79E29A)
                                : const Color(0xFFFF8A8A),
                          ),
                        ),
                      ],
                    ],
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
