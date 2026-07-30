# app_flutter

Cliente Flutter de iAgents, basado en la estructura funcional del proyecto
frontend_react.

## Ejecutar

1. Instalar Flutter SDK (estable).
2. Desde esta carpeta:

```bash
flutter pub get
flutter run
```

Validación rápida:

```bash
flutter analyze
flutter test
```

## Arquitectura

- lib/app: arranque, tema y router.
- lib/core: red, configuración y almacenamiento.
- lib/features: vistas por dominio (auth, dashboard, agents, etc.).
- lib/models: modelos de dominio.
- lib/shared: estado global y widgets compartidos.
- lib/utils: validaciones y helpers.

## Estado actual

- Selector de backend en login (por defecto iagentshub).
- Autenticación real contra backend FastAPI:
	- login
	- guest login
	- me
	- logout
	- register
	- forgot/reset password
	- verify
- Sesión persistente con SharedPreferences (cookie ga_token y usuario).
- Rutas públicas, privadas y admin con guards de sesión/rol.
- Shell de navegación para secciones privadas.
- Dashboard con resumen real consumiendo endpoints backend.
- Módulos funcionales completos en app privada:
	- Agents: listado, crear, editar, eliminar.
	- Connections: CRUD + test individual + test masivo.
	- Knowledge: alta texto, import URL, subida documento, listado y borrado.
	- Workflows: CRUD + ejecución (run) con visualización de eventos.
	- Memory: CRUD de archivos markdown con editor integrado.
	- Explore: filtros, preview, star/unstar y link de recursos públicos.
	- Labels: agregación y filtrado por etiquetas reales del catálogo.
	- Manager: gestión de workspaces (crear, renombrar, eliminar, activar).
	- Profile: settings, perfil público, cambio contraseña, solicitud de eliminación.
- Área admin funcional:
	- Admin: estadísticas, gestión rápida de usuarios y workspaces.
	- Metadata: exploración de tablas y datos paginados.
	- Centinel: estado, ejecución/aborto de runs e historial.
- Perfil público funcional con follow/unfollow y recursos del usuario.

## Rutas principales

Públicas:

- /
- /en/
- /about
- /en/about
- /docs
- /en/docs
- /support
- /en/support
- /pricing/
- /en/pricing/
- /checkout/
- /login/
- /register/
- /forgot-password/
- /reset-password/?token=...
- /verify/?token=...

Privadas:

- /dashboard/
- /agents/
- /orchestrations/
- /connections/
- /memory/
- /knowledge/
- /explore/
- /labels/
- /manager/
- /profile/
- /vscode-auth/
- /u/:username

Admin:

- /admin/
- /admin/metadata/
- /admin/centinel/

## Nota de conectividad

Si el backend remoto no resuelve en tu red, usa el selector de backend para
apuntar a una instancia local (ejemplo: http://localhost:8765).
