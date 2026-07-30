import 'package:app_flutter/app/router/route_names.dart';
import 'package:app_flutter/utils/safe_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta rutas internas con query y fragmento', () {
    expect(safeRedirect('/agents?filter=mine#top'), '/agents?filter=mine#top');
  });

  test('rechaza destinos absolutos, protocol-relative y backslashes', () {
    expect(safeRedirect('https://evil.example'), RouteNames.dashboard);
    expect(safeRedirect('//evil.example/path'), RouteNames.dashboard);
    expect(safeRedirect(r'/\evil.example'), RouteNames.dashboard);
    expect(safeRedirect('/%2F%2Fevil.example'), RouteNames.dashboard);
  });

  test('rechaza controles, espacios externos y bucles hacia login', () {
    expect(safeRedirect('/agents\nnext'), RouteNames.dashboard);
    expect(safeRedirect(' /agents'), RouteNames.dashboard);
    expect(safeRedirect('/login?redirect=/agents'), RouteNames.dashboard);
    expect(safeRedirect('/login/again'), RouteNames.dashboard);
  });

  test('usa dashboard ante valores ausentes o malformados', () {
    expect(safeRedirect(null), RouteNames.dashboard);
    expect(safeRedirect(''), RouteNames.dashboard);
    expect(safeRedirect('%'), RouteNames.dashboard);
  });
}
