import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../../utils/i18n.dart';
import '../utils/file_size_formatter.dart';
import 'buttons/app_buttons.dart';
import 'label_chips_row.dart';
import 'motion/app_modal.dart';
import 'resource_type_badge.dart';
import 'responsive_dialog.dart';

// Las piezas de presentación —cabecera, secciones, datos, plegables— viven
// aparte para que ninguno de los dos ficheros pase de las 600 líneas que
// vigila `test/feature_architecture_test.dart`.
part 'resource_preview_parts.dart';

/// La ficha de un recurso del catálogo, para quien decide si lo quiere.
///
/// Antes esta vista volcaba el payload como JSON con sangría, el mismo en
/// Explorar y en el perfil público. Quien tiene que elegir un agente no lee
/// `"use_memory": true`: lee «recuerda conversaciones anteriores». Lo técnico
/// —las instrucciones, el código de una tool, el texto de una plantilla— sigue
/// estando, pero plegado, porque es lo que menos gente abre.
Future<void> showResourcePreviewDialog({
  required BuildContext context,
  required Map<String, dynamic> payload,
  required String title,
  required String typeLabel,
  int stars = 0,
  String categoryLabel = '',
}) => showAppDialog<void>(
  context: context,
  builder: (context) => ResourcePreviewDialog(
    payload: payload,
    title: title,
    typeLabel: typeLabel,
    stars: stars,
    categoryLabel: categoryLabel,
  ),
);

class ResourcePreviewDialog extends StatelessWidget {
  const ResourcePreviewDialog({
    required this.payload,
    required this.title,
    required this.typeLabel,
    this.stars = 0,
    this.categoryLabel = '',
    super.key,
  });

  final Map<String, dynamic> payload;
  final String title;

  /// Ya traducido por quien abre el diálogo: las dos pantallas que lo usan
  /// tienen su propia tabla de tipos.
  final String typeLabel;
  final int stars;

  /// También traducido fuera, y opcional: el perfil público enseña la
  /// categoría cruda porque no tiene tabla que la traduzca.
  final String categoryLabel;

  String get _type => _texto(payload['resource_type']);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descripcion = _texto(payload['description']);
    final autor = _texto(payload['owner_username']);

    return AlertDialog(
      title: _Cabecera(
        title: title,
        type: _type,
        typeLabel: typeLabel,
        autor: autor,
        stars: stars,
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                descripcion.isEmpty
                    ? tr('explore.preview_no_description')
                    : descripcion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: descripcion.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : null,
                  fontStyle: descripcion.isEmpty ? FontStyle.italic : null,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              LabelChipsRow(
                labels: _listaDeTextos(payload['labels']),
                // El catálogo solo publica recursos públicos: la etiqueta
                // «public» no distingue a ninguno de los demás.
                hide: const ['public', 'private'],
                labelText: (label) => trOr('labels.$label', label),
                leading: [
                  if (categoryLabel.trim().isNotEmpty)
                    _CategoriaChip(texto: categoryLabel),
                ],
              ),
              ..._secciones(context),
            ],
          ),
        ),
      ),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          // Clave propia y no `common.close`: esa vive en `resources.json` y
          // `tr()` exige que una clave con prefijo de namespace esté en el
          // fichero que anuncia. Lo vigila i18n_claves_existentes_test.
          child: Text(tr('explore.preview_close')),
        ),
      ],
    );
  }

  /// Lo que se enseña de cada tipo de recurso, en lenguaje de quien decide.
  List<Widget> _secciones(BuildContext context) => switch (_type) {
    'agent' => _agente(context),
    'skill' => _conTexto(context, tr('explore.preview_skill_content')),
    'prompt' => _prompt(context),
    'tool' => _tool(context),
    'knowledge' => _knowledge(context),
    'knowledge_pack' => _pack(context),
    'workflow' => _workflow(context),
    _ => const [],
  };

  // ── Agente ────────────────────────────────────────────────────────────────

  List<Widget> _agente(BuildContext context) {
    final skills = _listaDeTextos(payload['skills']);
    final prompts = _listaDeTextos(payload['prompts']);
    final tools = _listaDeTextos(payload['tools']);
    final knowledge = _listaDeTextos(payload['knowledge']);
    final incluye = <Widget>[
      if (skills.isNotEmpty)
        _Recuento(
          icono: Icons.bolt_outlined,
          nombre: 'skills',
          valores: skills,
        ),
      if (prompts.isNotEmpty)
        _Recuento(
          icono: Icons.chat_bubble_outline,
          nombre: 'prompts',
          valores: prompts,
        ),
      if (tools.isNotEmpty)
        _Recuento(
          icono: Icons.build_outlined,
          nombre: 'tools',
          valores: tools,
        ),
      if (knowledge.isNotEmpty)
        _Recuento(
          icono: Icons.menu_book_outlined,
          nombre: 'knowledge',
          valores: knowledge,
        ),
    ];

    final instrucciones = _texto(payload['system_prompt']);
    return [
      if (incluye.isNotEmpty)
        _Seccion(titulo: tr('explore.preview_what_it_uses'), hijos: incluye),
      _Seccion(
        titulo: tr('explore.preview_how_it_works'),
        hijos: [
          _Dato(
            icono: Icons.psychology_outlined,
            etiqueta: tr('explore.preview_memory'),
            valor: payload['use_memory'] == true
                ? tr('explore.preview_memory_on')
                : tr('explore.preview_memory_off'),
          ),
          _Dato(
            icono: Icons.tune,
            etiqueta: tr('explore.preview_style'),
            valor: _estiloDeRespuesta(payload['temperature']),
          ),
        ],
      ),
      if (instrucciones.isNotEmpty)
        _Plegable(
          titulo: tr('explore.preview_instructions'),
          nota: tr('explore.preview_instructions_note'),
          texto: instrucciones,
        ),
    ];
  }

  /// La temperatura del modelo, dicha como se comporta y no como número: 0.9
  /// no le dice nada a quien elige un agente para su equipo.
  String _estiloDeRespuesta(dynamic valor) {
    final temperatura = valor is num ? valor.toDouble() : 0.7;
    if (temperatura <= 0.35) return tr('explore.preview_style_precise');
    if (temperatura <= 0.75) return tr('explore.preview_style_balanced');
    return tr('explore.preview_style_creative');
  }

  // ── Resto de tipos ────────────────────────────────────────────────────────

  List<Widget> _conTexto(BuildContext context, String titulo) {
    final contenido = _texto(payload['content']);
    if (contenido.isEmpty) return const [];
    return [_Plegable(titulo: titulo, texto: contenido)];
  }

  List<Widget> _prompt(BuildContext context) {
    final alias = _texto(payload['alias']);
    return [
      if (alias.isNotEmpty)
        _Seccion(
          titulo: tr('explore.preview_how_to_call_it'),
          hijos: [
            _Dato(
              icono: Icons.alternate_email,
              etiqueta: tr('explore.preview_alias'),
              valor: '@$alias',
              nota: tr('explore.preview_alias_note'),
            ),
          ],
        ),
      ..._conTexto(context, tr('explore.preview_prompt_content')),
    ];
  }

  List<Widget> _tool(BuildContext context) {
    final lenguaje = _texto(payload['language']);
    final fichero = _texto(payload['binary_filename']);
    final bytes = payload['binary_size'];
    final codigo = _texto(payload['content']);
    return [
      _Seccion(
        titulo: tr('explore.preview_technical_data'),
        hijos: [
          if (lenguaje.isNotEmpty)
            _Dato(
              icono: Icons.code,
              etiqueta: tr('explore.preview_language'),
              valor: trOr('tools.language_$lenguaje', lenguaje),
            ),
          if (fichero.isNotEmpty)
            _Dato(
              icono: Icons.inventory_2_outlined,
              etiqueta: tr('explore.preview_binary'),
              valor: bytes is num && bytes > 0
                  ? '$fichero · ${formatFileSize(bytes.toInt())}'
                  : fichero,
            ),
        ],
      ),
      if (codigo.isNotEmpty)
        _Plegable(
          titulo: tr('explore.preview_source_code'),
          texto: codigo,
          monoespaciado: true,
        ),
    ];
  }

  List<Widget> _knowledge(BuildContext context) {
    final tipo = _texto(payload['type']);
    final origen = _texto(payload['source']);
    final caracteres = payload['char_count'];
    return [
      _Seccion(
        titulo: tr('explore.preview_document'),
        hijos: [
          if (tipo.isNotEmpty)
            _Dato(
              icono: Icons.description_outlined,
              etiqueta: tr('explore.preview_document_type'),
              valor: tipo.toUpperCase(),
            ),
          if (origen.isNotEmpty)
            _Dato(
              icono: Icons.link,
              etiqueta: tr('explore.preview_source'),
              valor: origen,
            ),
          if (caracteres is num && caracteres > 0)
            _Dato(
              icono: Icons.straighten,
              etiqueta: tr('explore.preview_length'),
              valor: tr(
                'explore.preview_characters',
              ).replaceAll('{{count}}', _conSeparadores(caracteres.toInt())),
            ),
        ],
      ),
      ..._conTexto(context, tr('explore.preview_extract')),
    ];
  }

  List<Widget> _pack(BuildContext context) {
    final ficheros = payload['file_count'];
    final bytes = payload['size_bytes'];
    final items = _listaDeTextos(payload['items']);
    return [
      _Seccion(
        titulo: tr('explore.preview_pack_content'),
        hijos: [
          _Dato(
            icono: Icons.folder_copy_outlined,
            etiqueta: tr('explore.preview_documents'),
            valor: '${ficheros is num ? ficheros.toInt() : items.length}',
          ),
          if (bytes is num && bytes > 0)
            _Dato(
              icono: Icons.straighten,
              etiqueta: tr('explore.preview_size'),
              valor: formatFileSize(bytes.toInt()),
            ),
        ],
      ),
      if (items.isNotEmpty)
        _Plegable(
          titulo: tr('explore.preview_file_list'),
          texto: items.join('\n'),
        ),
    ];
  }

  List<Widget> _workflow(BuildContext context) {
    final agentes = _listaDeTextos(payload['agent_names']);
    final pasos = payload['steps'];
    return [
      _Seccion(
        titulo: tr('explore.preview_sequence'),
        hijos: [
          _Dato(
            icono: Icons.account_tree_outlined,
            etiqueta: tr('explore.preview_steps'),
            valor: '${pasos is num ? pasos.toInt() : agentes.length}',
          ),
          if (agentes.isNotEmpty) _Pasos(agentes: agentes),
        ],
      ),
    ];
  }
}
