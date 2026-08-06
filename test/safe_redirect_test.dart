import 'package:app_flutter/app/router/internal_router.dart';
import 'package:app_flutter/utils/safe_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta rutas internas con query y fragmento', () {
    expect(safeRedirect('/agents?filter=mine#top'), '/agents?filter=mine#top');
  });

  test('rechaza destinos absolutos, protocol-relative y backslashes', () {
    expect(safeRedirect('https://evil.example'), InternalRoutes.dashboard);
    expect(safeRedirect('//evil.example/path'), InternalRoutes.dashboard);
    expect(safeRedirect(r'/\evil.example'), InternalRoutes.dashboard);
    expect(safeRedirect('/%2F%2Fevil.example'), InternalRoutes.dashboard);
  });

  test('rechaza controles, espacios externos y bucles hacia login', () {
    expect(safeRedirect('/agents\nnext'), InternalRoutes.dashboard);
    expect(safeRedirect(' /agents'), InternalRoutes.dashboard);
    expect(safeRedirect('/login?redirect=/agents'), InternalRoutes.dashboard);
    expect(safeRedirect('/login/again'), InternalRoutes.dashboard);
  });

  test('usa dashboard ante valores ausentes o malformados', () {
    expect(safeRedirect(null), InternalRoutes.dashboard);
    expect(safeRedirect(''), InternalRoutes.dashboard);
    expect(safeRedirect('%'), InternalRoutes.dashboard);
  });
}
