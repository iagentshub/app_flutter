import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

/// Tabla canónica de colores para labels.
/// (assets/js/labels.js): 3 grupos exclusivos (visibilidad, entorno, estado).
/// Incluye también "owner"/"linked"/"fork", usados por el badge de propiedad
/// (OriginBadge) y por el grupo informativo de propiedad del catálogo.
const Map<String, Color> _labelColors = {
  'owner': FncColors.labelOwner,
  'linked': FncColors.labelLinked,
  'fork': FncColors.labelFork,
  'agent': FncColors.labelAgent,
  'skill': FncColors.labelSkill,
  'prompt': FncColors.labelPrompt,
  'tool': FncColors.labelTool,
  'knowledge': FncColors.labelKnowledge,
  'connection': FncColors.labelConnection,
  'provider': FncColors.labelConnection,
  'official_source': FncColors.labelOfficial,
  'memory': FncColors.labelMemory,
  'workflow': FncColors.labelWorkflow,
  'evaluator': FncColors.labelEvaluator,
  'private': FncColors.labelPrivate,
  'public': FncColors.labelPublic,
  'official': FncColors.labelOfficial,
  'community': FncColors.labelCommunity,
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
  'lang_es': FncColors.labelLanguage,
  'lang_en': FncColors.labelLanguage,
  'lang_fr': FncColors.labelLanguage,
  'lang_de': FncColors.labelLanguage,
  'lang_pt': FncColors.labelLanguage,
  'lang_it': FncColors.labelLanguage,
  'lang_zh': FncColors.labelLanguage,
  'lang_ja': FncColors.labelLanguage,
  'lang_ar': FncColors.labelLanguage,
};

Color labelColor(String key) => _labelColors[key] ?? FncColors.labelFallback;

/// Claves de label conocidas por el catálogo, en el mismo orden que
/// Los grupos representan visibilidad, entorno y estado.
const List<String> kLabelKeys = [
  'private',
  'public',
  'official',
  'community',
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
  ...kLanguageLabelKeys,
];

const List<String> kContentLanguageCodes = [
  'es',
  'en',
  'fr',
  'de',
  'pt',
  'it',
  'zh',
  'ja',
  'ar',
];

const List<String> kLanguageLabelKeys = [
  'lang_es',
  'lang_en',
  'lang_fr',
  'lang_de',
  'lang_pt',
  'lang_it',
  'lang_zh',
  'lang_ja',
  'lang_ar',
];

bool isLanguageLabel(String key) => kLanguageLabelKeys.contains(key);

String languageLabelKey(String code) => 'lang_${code.toLowerCase()}';

String? languageCodeFromLabel(String key) =>
    isLanguageLabel(key) ? key.substring('lang_'.length) : null;

String contentLanguageLabel(
  String Function(String path, String fallback) tx,
  String codeOrKey,
) {
  final key = codeOrKey.startsWith('lang_')
      ? codeOrKey
      : languageLabelKey(codeOrKey);
  final code = languageCodeFromLabel(key) ?? codeOrKey;
  final fallback = switch (code) {
    'es' => 'Español',
    'en' => 'Inglés',
    'fr' => 'Francés',
    'de' => 'Alemán',
    'pt' => 'Portugués',
    'it' => 'Italiano',
    'zh' => 'Chino',
    'ja' => 'Japonés',
    'ar' => 'Árabe',
    _ => code.toUpperCase(),
  };
  return tx('labels.$key', fallback);
}

/// Construye el contrato canónico que comparten los recursos textuales.
/// Descarta valores ajenos al catálogo y mantiene el orden estable para que
/// crear y editar produzcan exactamente el mismo payload.
List<String> contentLabelsForScope(
  String scope,
  Iterable<String> selectedLanguages,
) {
  final normalizedScope = scope == 'public' ? 'public' : 'private';
  final selected = selectedLanguages.where(isLanguageLabel).toSet();
  return [
    normalizedScope,
    for (final label in kLanguageLabelKeys)
      if (selected.contains(label)) label,
  ];
}

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

/// Grupo informativo de propiedad. `linked` y `fork` también se persisten en
/// recursos locales para que sus permisos no dependan del contexto de listado.
/// Debe mostrarse siempre primero en el catálogo explicativo.
const kOwnershipGroup = LabelGroupDef(
  titleKey: 'labels.group_ownership',
  fallbackTitle: 'Propiedad',
  keys: ['owner', 'linked', 'fork'],
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
    'tool',
    'knowledge',
    'connection',
    'memory',
    'workflow',
  ],
  exclusive: true,
  required: true,
);

/// Origen editorial gestionado por el sistema. Se muestra en el catálogo y
/// en las cards, pero queda fuera de `kLabelGroups` para que ningún selector
/// de usuario pueda modificarlo.
const kOriginGroup = LabelGroupDef(
  titleKey: 'labels.group_origin',
  fallbackTitle: 'Origen',
  keys: ['community', 'official'],
  exclusive: true,
  required: true,
);

const kOperationalLabelGroups = [
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

const kLanguageLabelGroup = LabelGroupDef(
  titleKey: 'labels.group_language',
  fallbackTitle: 'Idioma',
  keys: kLanguageLabelKeys,
  exclusive: false,
);

const kLabelGroups = [...kOperationalLabelGroups, kLanguageLabelGroup];
