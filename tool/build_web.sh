#!/usr/bin/env bash
# Compilación de la web con los flags que el despliegue espera.
#
# El comando vive aquí y no suelto en cada workflow porque `flutter build web`
# se invoca seis veces repartidas en cuatro repositorios: este,
# frontend_react, backend_fastapi e iAgents — los tres últimos hacen checkout
# de app_flutter para construir la imagen unificada.
#
# Eso importa porque algunos de estos flags tienen su otra mitad en la CSP que
# sirve nginx (frontend_react/nginx.react.conf, bloque `location ^~ /app/`).
# Aplicar uno en cinco de los seis sitios produce una imagen donde nginx
# prohíbe exactamente lo que la aplicación pide: pantalla en blanco, sin error
# visible para el usuario y sin ningún test que se entere. Con el comando
# centralizado, cambiar un flag vuelve a ser un solo commit.
#
# Uso:
#   tool/build_web.sh                      # sin base href (validación en CI)
#   tool/build_web.sh --base-href /app/    # como se sirve en producción
#
# Cualquier argumento extra se pasa tal cual a `flutter build web`, que es la
# forma de probar un flag candidato sin tocar este fichero.
set -euo pipefail

# --no-web-resources-cdn sirve CanvasKit desde el propio origen en vez de
# gstatic.com. No cuesta tamaño: `flutter build web` ya deja canvaskit/ dentro
# de build/web y el Dockerfile de frontend_react copia ese directorio entero a
# la imagen — hasta ahora viajaba sin que nadie lo pidiera. Lo que ahorra es
# tener que abrir script-src y connect-src a un host de Google justo en la zona
# autenticada, y de paso deja de anunciarle a Google quién abre la aplicación.
flags=(--release --no-web-resources-cdn)

# No está `--csp` a propósito. Se probó el 2026-08-16 buscando quitar
# 'unsafe-eval' de la CSP y el `main.dart.js` resultante era idéntico byte a
# byte (mismo sha256) con y sin el flag: dart2js ya no genera código dinámico
# aquí. Lo que sí obligaba a 'unsafe-eval' era el cargador de partes diferidas,
# y solo en su rama de worker (`!self.window`), que esta aplicación no toma
# porque el código Dart corre en el hilo principal. Añadirlo no arregla nada y
# sugiere una causa que no es.

raiz="$(cd "$(dirname "$0")/.." && pwd)"
cd "$raiz"

echo "flutter build web ${flags[*]} $*"
flutter build web "${flags[@]}" "$@"
