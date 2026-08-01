import 'backend_option.dart';

/// Backends "oficiales": vienen de fábrica con la app y no se pueden
/// eliminar desde la lista (a diferencia de los que el usuario añade a mano).
abstract final class BackendDefaults {
  static const selectedBackendId = 'iagentshub_www';

  static const options = [
    BackendOption(
      id: 'iagentshub_www',
      label: 'www.iagentshub.com',
      baseUrl: 'https://www.iagentshub.com',
    )
  ];
}
