import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/utils/validators.dart';

void main() {
  test('validators email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('invalido'), isNotNull);
    expect(Validators.email('user@example.com'), isNull);
  });
}
