import 'package:flutter/material.dart';

/// Tabla de colores de labels, igual a GROUPS en frontend_vanilla
/// (assets/js/labels.js): 3 grupos exclusivos (visibilidad, entorno, estado).
const Map<String, Color> _labelColors = {
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
