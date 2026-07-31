import 'package:flutter/material.dart';

/// Tabla de colores de labels, igual a GROUPS en frontend_vanilla
/// (assets/js/labels.js): 3 grupos exclusivos (visibilidad, entorno, estado).
/// Incluye también "owner"/"linked", usados por el badge de origen
/// (OriginBadge) y por el grupo informativo de propiedad del catálogo.
const Map<String, Color> _labelColors = {
  'owner': Color(0xFF059669),
  'linked': Color(0xFF0891B2),
  'agent': Color(0xFF2563EB),
  'skill': Color(0xFF9333EA),
  'knowledge': Color(0xFF0D9488),
  'connection': Color(0xFFDB2777),
  'memory': Color(0xFFB45309),
  'workflow': Color(0xFF16A34A),
  'private': Color(0xFF64748B),
  'public': Color(0xFF059669),
  'production': Color(0xFF0891B2),
  'staging': Color(0xFF475569),
  'development': Color(0xFFD97706),
  'test': Color(0xFF7C3AED),
  'favorite': Color(0xFFF59E0B),
  'draft': Color(0xFF8B5CF6),
  'review': Color(0xFFF97316),
  'deprecated': Color(0xFFCA8A04),
  'quarantine': Color(0xFFEF4444),
  'archived': Color(0xFF94A3B8),
  'delete': Color(0xFFDC2626),
};

Color labelColor(String key) => _labelColors[key] ?? const Color(0xFF64748B);

/// Claves de label conocidas por el catálogo, en el mismo orden que
/// GROUPS en frontend_vanilla (visibilidad, entorno, estado).
const List<String> kLabelKeys = [
  'private',
  'public',
  'production',
  'staging',
  'development',
  'test',
  'favorite',
  'draft',
  'review',
  'deprecated',
  'quarantine',
  'archived',
  'delete',
];

/// Los 3 grupos de GROUPS en frontend_vanilla son excluyentes entre sí
/// (algo no puede ser "private" y "public" a la vez). `required` marca si
/// el grupo siempre debe tener exactamente una selección (visibilidad) o
/// puede quedar vacío (entorno). "Estado" no es excluyente: un recurso
/// puede llevar varias labels de estado a la vez.
class LabelGroupDef {
  const LabelGroupDef({
    required this.titleKey,
    required this.fallbackTitle,
    required this.keys,
    required this.exclusive,
    this.required = false,
  });

  final String titleKey;
  final String fallbackTitle;
  final List<String> keys;
  final bool exclusive;
  final bool required;
}

/// Grupo de propiedad ("Propietario" vs "Enlazado"): no es un label real
/// asignable al recurso (no vive en `labels`, se calcula del flag `_shared`),
/// por eso vive fuera de `kLabelGroups` y no aparece en GroupedLabelPicker.
/// Debe mostrarse siempre primero en el catálogo explicativo.
const kOwnershipGroup = LabelGroupDef(
  titleKey: 'labels.group_ownership',
  fallbackTitle: 'Propiedad',
  keys: ['owner', 'linked'],
  exclusive: true,
  required: true,
);

/// Grupo de tipo de objeto (agente, skill, knowledge, conexión, memoria,
/// orquestación): tampoco es un label asignable, es el `type`/`resourceType`
/// del recurso. Las claves coinciden con los `resourceType` reales usados en
/// Explorar/Dashboard para que `labelColor` sirva de fuente única de color.
/// Vive fuera de `kLabelGroups` por el mismo motivo que ownership.
const kResourceTypeGroup = LabelGroupDef(
  titleKey: 'labels.group_type',
  fallbackTitle: 'Tipo',
  keys: ['agent', 'skill', 'knowledge', 'connection', 'memory', 'workflow'],
  exclusive: true,
  required: true,
);

const kLabelGroups = [
  LabelGroupDef(
    titleKey: 'labels.group_visibility',
    fallbackTitle: 'Visibilidad',
    keys: ['private', 'public'],
    exclusive: true,
    required: true,
  ),
  LabelGroupDef(
    titleKey: 'labels.group_environment',
    fallbackTitle: 'Entorno',
    keys: ['production', 'staging', 'development', 'test'],
    exclusive: true,
  ),
  LabelGroupDef(
    titleKey: 'labels.group_status',
    fallbackTitle: 'Estado',
    keys: [
      'favorite',
      'draft',
      'review',
      'deprecated',
      'quarantine',
      'archived',
      'delete',
    ],
    exclusive: false,
  ),
];
