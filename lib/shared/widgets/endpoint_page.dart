import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../state/session_controller.dart';

class EndpointPage extends StatefulWidget {
  const EndpointPage({
    required this.title,
    required this.endpoint,
    required this.apiClient,
    required this.sessionController,
    this.description,
    super.key,
  });

  final String title;
  final String endpoint;
  final String? description;
  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<EndpointPage> createState() => _EndpointPageState();
}

class _EndpointPageState extends State<EndpointPage> {
  Object? _payload;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = widget.sessionController.gaToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    try {
      final response = await widget.apiClient.get(
        widget.endpoint,
        gaToken: token,
      );
      if (!mounted) return;
      setState(() {
        _payload = response.body;
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
        _error = 'No se pudo cargar ${widget.endpoint}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          if (widget.description != null) ...[
            const SizedBox(height: 6),
            Text(widget.description!),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: FncColors.materialRed),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _PayloadView(payload: _payload),
              ),
            ),
        ],
      ),
    );
  }
}

class _PayloadView extends StatelessWidget {
  const _PayloadView({required this.payload});

  final Object? payload;

  @override
  Widget build(BuildContext context) {
    if (payload is List) {
      final list = payload as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registros: ${list.length}'),
          const SizedBox(height: 10),
          ...list
              .take(25)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(const JsonEncoder.withIndent('  ').convert(item)),
                ),
              ),
        ],
      );
    }

    return Text(const JsonEncoder.withIndent('  ').convert(payload));
  }
}
