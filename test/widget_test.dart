import 'package:app_flutter/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validators email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('invalido'), isNotNull);
    expect(Validators.email('user@example.c'), isNotNull);
    expect(Validators.email('usér@example.com'), isNotNull);
    expect(Validators.email('user@example.com'), isNull);
    expect(Validators.email(' user+ventas@example.co.uk '), isNull);
  });

  test('validators username normaliza y reserva identidades invitadas', () {
    expect(Validators.isValidUsername(' Andres_01 '), isTrue);
    expect(Validators.isValidUsername('abc'), isFalse);
    expect(Validators.isValidUsername('guest'), isFalse);
    expect(Validators.isValidUsername('guest_123'), isFalse);
  });
}
