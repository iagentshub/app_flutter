import 'backend_option.dart';

abstract final class BackendDefaults {
  static const selectedBackendId = 'iagentshub_www';
  static const customBackendId = 'custom';

  static const options = [
    BackendOption(
      id: 'iagentshub_www',
      label: 'www.iagentshub.com (default)',
      baseUrl: 'https://www.iagentshub.com',
    ),
    BackendOption(
      id: 'iagentshub_api',
      label: 'api.iagentshub.com',
      baseUrl: 'https://api.iagentshub.com',
    ),
    BackendOption(
      id: 'local',
      label: 'Local (8765)',
      baseUrl: 'http://localhost:8765',
    ),
    BackendOption(
      id: customBackendId,
      label: 'Custom',
      baseUrl: '',
      editable: true,
    ),
  ];
}
