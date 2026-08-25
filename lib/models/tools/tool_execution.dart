import 'tool_models.dart';

enum ToolExecutionAvailability { instructionOnly, executable }

final class ToolDeviceCapabilities {
  const ToolDeviceCapabilities({
    required this.platform,
    required this.architecture,
    required this.secureLocalExecution,
    this.availableRuntimes = const {},
  });

  final String platform;
  final String architecture;
  final bool secureLocalExecution;
  final Set<String> availableRuntimes;

  bool canExecute(ToolItem tool) {
    if (!secureLocalExecution || !tool.isReady) return false;
    if (tool.language.requiresBinary) {
      return tool.targetOs.isNotEmpty &&
          tool.targetArch.isNotEmpty &&
          tool.targetOs == platform &&
          tool.targetArch == architecture;
    }
    return availableRuntimes.contains(tool.language.apiValue);
  }
}

extension ToolExecutionAvailabilityX on ToolItem {
  ToolExecutionAvailability availabilityOn(ToolDeviceCapabilities device) =>
      device.canExecute(this)
      ? ToolExecutionAvailability.executable
      : ToolExecutionAvailability.instructionOnly;
}
