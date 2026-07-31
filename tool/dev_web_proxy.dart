import 'dart:async';
import 'dart:io';

const _defaultListenPort = 7357;
const _defaultFlutterPort = 7359;
const _defaultBackend = 'https://www.iagentshub.com';

Future<void> main(List<String> args) async {
  final listenPort = _intArgument(args, '--port', _defaultListenPort);
  final flutterPort = _intArgument(args, '--flutter-port', _defaultFlutterPort);
  final backend = Uri.parse(
    _stringArgument(args, '--backend', _defaultBackend),
  );
  final flutterServer = Uri.parse('http://127.0.0.1:$flutterPort');
  final client = HttpClient();
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    listenPort,
  );

  stdout.writeln(
    'Flutter Web: http://127.0.0.1:$listenPort/login\n'
    'API backend: $backend',
  );

  await for (final request in server) {
    unawaited(
      _proxyRequest(
        request,
        client: client,
        backend: backend,
        flutterServer: flutterServer,
      ),
    );
  }
}

Future<void> _proxyRequest(
  HttpRequest request, {
  required HttpClient client,
  required Uri backend,
  required Uri flutterServer,
}) async {
  final isApi =
      request.uri.path == '/api' || request.uri.path.startsWith('/api/');
  final targetBase = isApi ? backend : flutterServer;
  final target = targetBase.resolve(request.uri.toString());

  try {
    final upstream = await client.openUrl(request.method, target);
    request.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == HttpHeaders.hostHeader ||
          lower == HttpHeaders.connectionHeader ||
          lower == HttpHeaders.transferEncodingHeader ||
          (isApi && lower == 'origin')) {
        return;
      }
      upstream.headers.set(name, values);
    });

    if (isApi) {
      upstream.headers.set('x-forwarded-proto', 'https');
      upstream.headers.set('x-forwarded-host', backend.host);
    }

    await upstream.addStream(request);
    final upstreamResponse = await upstream.close();
    if (isApi) {
      stdout.writeln(
        '${request.method} ${request.uri} -> ${upstreamResponse.statusCode}',
      );
    }
    request.response.statusCode = upstreamResponse.statusCode;
    request.response.reasonPhrase = upstreamResponse.reasonPhrase;

    upstreamResponse.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == HttpHeaders.connectionHeader ||
          lower == HttpHeaders.transferEncodingHeader ||
          lower == HttpHeaders.contentLengthHeader ||
          lower == HttpHeaders.setCookieHeader) {
        return;
      }
      request.response.headers.set(name, values);
    });

    for (final cookie
        in upstreamResponse.headers[HttpHeaders.setCookieHeader] ??
            const <String>[]) {
      final localCookie = isApi
          ? cookie.replaceAll(RegExp(r';\s*Secure', caseSensitive: false), '')
          : cookie;
      request.response.headers.add(HttpHeaders.setCookieHeader, localCookie);
    }

    await request.response.addStream(upstreamResponse);
    await request.response.close();
  } catch (error) {
    request.response
      ..statusCode = HttpStatus.badGateway
      ..headers.contentType = ContentType.json
      ..write('{"detail":"Proxy local no disponible: $error"}');
    await request.response.close();
  }
}

String _stringArgument(List<String> args, String name, String fallback) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return fallback;
  return args[index + 1];
}

int _intArgument(List<String> args, String name, int fallback) {
  return int.tryParse(_stringArgument(args, name, '$fallback')) ?? fallback;
}
