const publicSiteBaseUrl = 'https://www.iagentshub.com';

Uri resolvePublicSiteUri({
  required String path,
  required bool useSameOrigin,
  Uri? browserBase,
}) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  if (useSameOrigin) {
    return (browserBase ?? Uri.base).resolve(normalizedPath);
  }
  return Uri.parse('$publicSiteBaseUrl$normalizedPath');
}
