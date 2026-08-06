import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

/// Tabla canónica de colores para labels.
/// (assets/js/labels.js): 3 grupos exclusivos (visibilidad, entorno, estado).
/// Incluye también "owner"/"linked", usados por el badge de origen
/// (OriginBadge) y por el grupo informativo de propiedad del catálogo.
const Map<String, Color> _labelColors = {
  'owner': FncColors.labelOwner,
  'linked': FncColors.labelLinked,
  'agent': FncColors.labelAgent,
  'skill': FncColors.labelSkill,
  'prompt': FncColors.labelPrompt,
  'knowledge': FncColors.labelKnowledge,
  'connection': FncColors.labelConnection,
  'memory': FncColors.labelMemory,
  'workflow': FncColors.labelWorkflow,
  'evaluator': FncColors.labelEvaluator,
  'private': FncColors.labelPrivate,
  'public': FncColors.labelPublic,
  'production': FncColors.labelProduction,
  'staging': FncColors.labelStaging,
  'development': FncColors.labelDevelopment,
  'test': FncColors.labelTest,
  'favorite': FncColors.labelFavorite,
  'draft': FncColors.labelDraft,
  'review': FncColors.labelReview,
  'deprecated': FncColors.labelDeprecated,
  'quarantine': FncColors.labelQuarantine,
  'archived': FncColors.labelArchived,
  'delete': FncColors.labelDelete,
};

Color labelColor(String key) => _labelColors[key] ?? FncColors.labelFallback;

/// Claves de label conocidas por el catálogo, en el mismo orden que
/// Los grupos representan visibilidad, entorno y estado.
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

/// Los tres grupos son excluyentes entre sí
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
  keys: [
    'agent',
    'skill',
    'prompt',
    'knowledge',
    'connection',
    'memory',
    'workflow',
  ],
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
