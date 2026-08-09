abstract final class BackendUrl {
  static bool usesInsecureTransport(String? url) {
    if (url == null) return false;
    return Uri.tryParse(url)?.scheme.toLowerCase() == 'http';
  }

  static String normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';

    if (!value.contains('://')) {
      final inferred = Uri.tryParse('backend://$value');
      if (inferred == null || inferred.host.isEmpty) return '';
      final scheme = _isLocalOrPrivateHost(inferred.host) ? 'http' : 'https';
      value = '$scheme://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    if (uri.scheme != 'http' && uri.scheme != 'https') return '';
    if (uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host.contains(RegExp(r'[\s/]'))) {
      return '';
    }
    if (uri.scheme == 'http' && !_isLocalOrPrivateHost(uri.host)) return '';

    int? port;
    try {
      port = uri.hasPort ? uri.port : null;
    } on FormatException {
      return '';
    }
    if (port != null && (port < 1 || port > 65535)) return '';

    final path = (uri.path == '/' ? '' : uri.path).replaceFirst(
      RegExp(r'/$'),
      '',
    );
    final normalized = Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: port,
      path: path,
    ).toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static String composeHostAndPort(String host, String port) {
    final trimmedHost = host.trim();
    final trimmedPort = port.trim();
    if (trimmedHost.isEmpty) return '';
    if (trimmedPort.isEmpty) return trimmedHost;
    return '$trimmedHost:$trimmedPort';
  }

  static ({String host, String port}) splitHostAndPort(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return (host: url, port: '');
    return (host: uri.host, port: uri.hasPort ? '${uri.port}' : '');
  }

  static bool _isLocalOrPrivateHost(String rawHost) {
    final host = rawHost.toLowerCase();
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host == '::1' ||
        (host.contains(':') &&
            (host.startsWith('fe80:') ||
                host.startsWith('fc') ||
                host.startsWith('fd')))) {
      return true;
    }

    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((part) => part == null || part < 0 || part > 255)) {
      return false;
    }
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}
