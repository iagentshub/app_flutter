part of 'resource_preview_dialog.dart';

// ── Piezas ──────────────────────────────────────────────────────────────────

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.title,
    required this.type,
    required this.typeLabel,
    required this.autor,
    required this.stars,
  });

  final String title;
  final String type;
  final String typeLabel;
  final String autor;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ResourceTypeBadge(type: type, label: typeLabel),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: FncFonts.size20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (autor.isNotEmpty) ...[
              Icon(
                Icons.person_outline,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  autor,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
            ],
            const Icon(Icons.star, size: 14, color: FncColors.materialAmber),
            const SizedBox(width: 4),
            Text(
              tr('explore.preview_stars').replaceAll('{{count}}', '$stars'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijos});

  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    if (hijos.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo.toUpperCase(),
            style: FncFonts.overline.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...hijos,
        ],
      ),
    );
  }
}

/// Un dato suelto: icono, de qué se habla y qué vale.
class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.nota,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$etiqueta: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: valor,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (nota != null)
                  Text(
                    nota!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «3 habilidades: Redactar, Resumir, Traducir». El número delante porque es
/// lo que se compara entre dos recursos; los nombres detrás.
///
/// El singular tiene su propia clave: «1 plantillas» delata que nadie leyó la
/// pantalla, y quien la abre no es quien la programó.
class _Recuento extends StatelessWidget {
  const _Recuento({
    required this.icono,
    required this.nombre,
    required this.valores,
  });

  final IconData icono;

  /// La mitad estable de las dos claves: `preview_skills_one` / `_many`.
  final String nombre;

  final List<String> valores;

  @override
  Widget build(BuildContext context) {
    final cuantos = valores.length;
    final sufijo = cuantos == 1 ? 'one' : 'many';
    return _Dato(
      icono: icono,
      etiqueta: '$cuantos ${tr('explore.preview_${nombre}_$sufijo')}',
      valor: valores.join(' · '),
    );
  }
}

/// La categoría va con las labels pero no es una: no tiene color propio en el
/// catálogo, así que se pinta neutra como en la tarjeta.
class _CategoriaChip extends StatelessWidget {
  const _CategoriaChip({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Contorno en vez de relleno: junto a las labels, que sí son píldoras
        // de color, un fondo claro no se distinguía del propio diálogo.
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: FncFonts.size11,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Los agentes de un workflow, en el orden en que intervienen.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.agentes});

  final List<String> agentes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < agentes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: FncFonts.size11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(agentes[i], style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lo técnico, cerrado por defecto: quien decide no lo necesita y quien lo
/// necesita sabe que está aquí.
class _Plegable extends StatelessWidget {
  const _Plegable({
    required this.titulo,
    required this.texto,
    this.nota,
    this.monoespaciado = false,
  });

  final String titulo;
  final String texto;
  final String? nota;
  final bool monoespaciado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: FncColors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            titulo,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: nota == null
              ? null
              : Text(
                  nota!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                texto,
                style: monoespaciado
                    ? FncFonts.code
                    : theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lectura defensiva del payload ───────────────────────────────────────────

String _texto(dynamic valor) => valor == null ? '' : valor.toString().trim();

/// Las listas del preview llegan como nombres (`skills`, `agent_names`) o como
/// objetos (los ficheros de un pack). Un elemento que no sepamos nombrar se
/// queda fuera antes que aparecer como `{path: …}`.
List<String> _listaDeTextos(dynamic valor) {
  if (valor is! List) return const [];
  final salida = <String>[];
  for (final elemento in valor) {
    if (elemento is String) {
      if (elemento.trim().isNotEmpty) salida.add(elemento.trim());
    } else if (elemento is Map) {
      final nombre = _texto(
        elemento['path'] ?? elemento['name'] ?? elemento['title'],
      );
      if (nombre.isNotEmpty) salida.add(nombre);
    }
  }
  return salida;
}

/// 12400 → «12.400». `NumberFormat` traería `intl` entero por un separador, y
/// el separador **sale del idioma como cualquier otro texto**: es «.» en
/// español y «,» en inglés, así que un ternario aquí sería la regla del idioma
/// como booleano por la puerta de atrás.
String _conSeparadores(int valor) {
  final separador = tr('explore.preview_thousands_separator');
  final digitos = valor.abs().toString();
  final buffer = StringBuffer(valor < 0 ? '-' : '');
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write(separador);
    buffer.write(digitos[i]);
  }
  return buffer.toString();
}
