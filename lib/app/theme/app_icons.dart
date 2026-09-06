import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Iconos de las secciones web; las aplicaciones nativas conservan los suyos.
abstract final class AppIcons {
  static const dashboard = kIsWeb
      ? Icons.space_dashboard_outlined
      : Icons.dashboard_outlined;
  static const explore = kIsWeb
      ? Icons.explore_outlined
      : Icons.travel_explore_outlined;
  // Sin rama por plataforma a propósito: las chispas de auto_awesome son el
  // icono de Skills en nativo, así que en web Agentes y Skills se parecían.
  static const agents = Icons.smart_toy_outlined;
  static const workflows = kIsWeb
      ? Icons.account_tree_outlined
      : Icons.hub_outlined;
  static const knowledge = kIsWeb
      ? Icons.folder_open_outlined
      : Icons.school_outlined;
  static const connections = kIsWeb
      ? Icons.electrical_services_outlined
      : Icons.cable_outlined;
  static const skills = kIsWeb
      ? Icons.extension_outlined
      : Icons.auto_awesome_outlined;
  static const more = kIsWeb ? Icons.more_horiz : Icons.more_vert;
  static const graph = kIsWeb ? Icons.schema_outlined : Icons.hub_outlined;
}
