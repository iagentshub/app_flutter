import 'package:flutter/foundation.dart';

import '../network/api_error.dart';

typedef AppDiagnosticReporter = void Function(AppDiagnosticEvent event);

@immutable
class AppDiagnosticEvent {
  const AppDiagnosticEvent({
    required this.operation,
    required this.errorType,
    required this.stackTrace,
    this.statusCode,
  });

  factory AppDiagnosticEvent.redacted(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    return AppDiagnosticEvent(
      operation: operation,
      errorType: error.runtimeType.toString(),
      statusCode: error is ApiError ? error.statusCode : null,
      stackTrace: stackTrace,
    );
  }

  final String operation;
  final String errorType;
  final int? statusCode;
  final StackTrace stackTrace;

  @override
  String toString() {
    final status = statusCode == null ? '' : ', status=$statusCode';
    return 'AppDiagnosticEvent($operation, type=$errorType$status)';
  }
}

abstract final class AppDiagnostics {
  static AppDiagnosticReporter _reporter = _defaultReporter;

  static void report(String operation, Object error, StackTrace stackTrace) {
    _reporter(AppDiagnosticEvent.redacted(operation, error, stackTrace));
  }

  @visibleForTesting
  static void setReporter(AppDiagnosticReporter reporter) {
    _reporter = reporter;
  }

  @visibleForTesting
  static void resetReporter() {
    _reporter = _defaultReporter;
  }

  static void _defaultReporter(AppDiagnosticEvent event) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: event,
        stack: event.stackTrace,
        library: 'iAgents diagnostics',
        context: ErrorDescription(event.operation),
        silent: true,
      ),
    );
  }
}
