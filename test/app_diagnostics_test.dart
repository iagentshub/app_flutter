import 'package:app_flutter/core/diagnostics/app_diagnostics.dart';
import 'package:app_flutter/core/network/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacta el mensaje y conserva solo metadatos seguros', () {
    AppDiagnosticEvent? captured;
    AppDiagnostics.setReporter((event) => captured = event);
    addTearDown(AppDiagnostics.resetReporter);

    AppDiagnostics.report(
      'dashboard.preferences.save',
      ApiError(
        statusCode: 503,
        message: 'ga_token=secreto api_key=supersecreta',
      ),
      StackTrace.current,
    );

    expect(captured?.operation, 'dashboard.preferences.save');
    expect(captured?.errorType, 'ApiError');
    expect(captured?.statusCode, 503);
    expect(captured.toString(), isNot(contains('secreto')));
    expect(captured.toString(), isNot(contains('api_key')));
  });
}
