import 'package:app_flutter/app/router/external_router.dart';
import 'package:app_flutter/app/router/internal_router.dart';
import 'package:app_flutter/app/router/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bloquea rutas internas hasta aceptar la versión vigente', () {
    expect(
      legalAcceptanceRedirect(
        isLoggedIn: true,
        acceptanceRequired: true,
        location: InternalRoutes.dashboard,
      ),
      ExternalRoutes.legalAcceptance,
    );
    expect(
      legalAcceptanceRedirect(
        isLoggedIn: true,
        acceptanceRequired: true,
        location: ExternalRoutes.legalAcceptance,
      ),
      isNull,
    );
  });

  test('sale de la pantalla legal después de aceptar', () {
    expect(
      legalAcceptanceRedirect(
        isLoggedIn: true,
        acceptanceRequired: false,
        location: ExternalRoutes.legalAcceptance,
      ),
      InternalRoutes.dashboard,
    );
    expect(
      legalAcceptanceRedirect(
        isLoggedIn: false,
        acceptanceRequired: true,
        location: InternalRoutes.dashboard,
      ),
      isNull,
    );
  });
}
