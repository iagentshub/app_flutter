import 'dart:io';

Future<void> main() async {
  final backendDirectory = Directory('../backend_fastapi').absolute;
  final python = Platform.isWindows
      ? '${backendDirectory.path}/.venv/Scripts/python.exe'
      : '${backendDirectory.path}/.venv/bin/python';

  if (!File(python).existsSync()) {
    stderr.writeln(
      'No existe el entorno Python local en ${backendDirectory.path}/.venv',
    );
    exitCode = 1;
    return;
  }

  final process = await Process.start(
    python,
    ['main.py'],
    workingDirectory: backendDirectory.path,
    environment: {
      ...Platform.environment,
      'GAIA_AGENTS_SECRET': 'local-development-only',
      'GAIA_CORS_ORIGINS': 'http://127.0.0.1:7357',
      'GAIA_FRONTEND_URL': 'http://127.0.0.1:7357',
      'GAIA_HOST': '127.0.0.1',
      'GAIA_PORT': '8765',
      'GAIA_RELOAD': 'false',
      'GAIA_WORKERS': '1',
    },
  );

  stdout.writeln('Backend local: http://127.0.0.1:8765');
  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);
  exitCode = await process.exitCode;
}
