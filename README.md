<div align="center">
  <a href="docs/en/index.md">🇬🇧 English</a> &nbsp;·&nbsp;
  <a href="docs/es/index.md">🇪🇸 Español</a>
</div>

<br>

<h1 align="center">iAgents — Flutter App</h1>

<p align="center">The native client for creating and managing AI agents, on mobile and desktop.</p>

---

## Quick start

```bash
flutter pub get
flutter run
```

Requires the stable Flutter SDK (Dart 3.13+). Run `flutter doctor` to check what your target platform still needs.

**Verification**

```bash
flutter analyze
flutter test
```

Para detectar antes del push páginas o componentes que superen los límites de
arquitectura, activa una vez los hooks versionados del repositorio:

```bash
git config core.hooksPath .githooks
```

El hook `pre-commit` ejecuta la comprobación rápida de arquitectura y bloquea el
commit si es necesario dividir algún componente.

---

## Platforms

Android · iOS · web · Windows · macOS · Linux, from a single codebase.

```bash
flutter build apk        # or appbundle, ipa, web, windows, macos, linux
```

---

## Backend

The app ships pointing at `www.iagentshub.com`. Any other iAgentsHub instance can be added from the server screen — no rebuild needed. If the remote backend does not resolve on your network, point it at a local one (for example `http://localhost:8765`).

> For the full stack (backend + frontend + skills), deploy from [iAgentsHub](https://github.com/iagentshub/iAgents).

---

## Web development with the official backend

Run Flutter's web server and the same-origin development proxy in separate terminals:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7359
dart run tool/dev_web_proxy.dart
```

Open `http://127.0.0.1:7357/login`. The proxy only listens on localhost and forwards `/api` to `https://www.iagentshub.com`, so browser sessions work without changing production CORS.

To use the local backend instead, start it from a third terminal:

```bash
dart run tool/run_local_backend.dart
```

Then choose `Localhost` in the server selector on the login page.

---

| | |
|---|---|
| 🇪🇸 Español | [docs/es/index.md](docs/es/index.md) |
| 🇬🇧 English | [docs/en/index.md](docs/en/index.md) |

---

## License

[GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0-only).

Free to use, modify and distribute. If you modify this code and offer the
result as a network service, section 13 requires you to make your version of
the source available to its users.
