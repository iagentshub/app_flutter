Uri resolveApiUri({
  required String baseUrl,
  required String path,
  required bool useSameOrigin,
  Uri? browserBase,
}) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  if (useSameOrigin) {
    return (browserBase ?? Uri.base).resolve(normalizedPath);
  }
  return Uri.parse('$baseUrl$normalizedPath');
}
