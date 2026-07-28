import 'package:flutter/foundation.dart';

/// Coordina el modo "Personalizar" del Dashboard con el drawer de navegación
/// de AppShell: mientras se edita, ese mismo drawer (el que abre el botón
/// hamburguesa) deja de mostrar las secciones de la app y muestra en su
/// lugar los widgets todavía no añadidos al dashboard — igual que el
/// sidebar de edición reemplaza al nav en frontend_react.
class DashboardEditState extends ChangeNotifier {
  bool _editing = false;
  List<String> _missing = const [];
  void Function(String id)? _onAdd;
  void Function()? _onDone;

  bool get editing => _editing;
  List<String> get missing => _missing;

  void startEditing({
    required List<String> missing,
    required void Function(String id) onAdd,
    required void Function() onDone,
  }) {
    _editing = true;
    _missing = missing;
    _onAdd = onAdd;
    _onDone = onDone;
    notifyListeners();
  }

  void updateMissing(List<String> missing) {
    if (!_editing) return;
    _missing = missing;
    notifyListeners();
  }

  void stopEditing() {
    _editing = false;
    _missing = const [];
    _onAdd = null;
    _onDone = null;
    notifyListeners();
  }

  void addWidget(String id) => _onAdd?.call(id);

  void done() => _onDone?.call();
}
