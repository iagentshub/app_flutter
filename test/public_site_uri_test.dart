import 'package:app_flutter/core/navigation/public_site_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resuelve las páginas React en el mismo origen para Flutter web', () {
    final uri = resolvePublicSiteUri(
      path: '/docs',
      useSameOrigin: true,
      browserBase: Uri.parse('http://127.0.0.1:7357/app/dashboard'),
    );

    expect(uri.toString(), 'http://127.0.0.1:7357/docs');
  });

  test('usa la web oficial desde las aplicaciones nativas', () {
    final uri = resolvePublicSiteUri(path: 'en/about', useSameOrigin: false);

    expect(uri.toString(), 'https://www.iagentshub.com/en/about');
  });
}
