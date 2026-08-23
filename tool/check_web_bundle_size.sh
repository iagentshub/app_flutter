#!/usr/bin/env bash
# Presupuesto de tamaño del bundle web.
#
# El canal principal del producto es la web: lo que pesa `main.dart.js` es
# tiempo hasta la primera interacción, y ese peso crece solo — basta con que
# alguien importe sin `deferred` una página que sí lo estaba (admin, Centinel,
# el editor de workflows, el checkout) para que sus ~780 KB vuelvan al bundle
# principal sin que ningún test de comportamiento se entere.
#
# Se ejecuta después de `flutter build web --release`, sobre el fichero ya
# construido. Sin comprimir: gzip depende del servidor y varía entre versiones,
# así que se mide lo único que es igual en todas partes.
#
# Uso:
#   flutter build web --release
#   tool/check_web_bundle_size.sh
#
# El umbral se puede subir con MAX_MAIN_BUNDLE_BYTES=… para una prueba local,
# pero subirlo en el repositorio es una decisión: el número está aquí para que
# haya que tocarlo a mano y quede en el diff.
set -euo pipefail

# 5,25 MiB. El bundle mide ~4,98 MiB desde que admin, workflows y checkout
# viajan en partes diferidas (medido en Flutter 3.47.1, la versión que fija
# `environment: flutter:` del pubspec); el margen absorbe una feature nueva, no
# la vuelta de un módulo entero.
#
# La versión con la que se midió importa: el número cambia al subir de SDK, así
# que al tocar el pubspec hay que volver a medir y actualizar esta nota. De
# 3.44.8 a 3.47.1 el bundle no se movió; los 53 KB que separan este 4,98 del
# 4,92 anterior son de `animations` 3.x, que trae material_ui.
MAX_MAIN_BUNDLE_BYTES="${MAX_MAIN_BUNDLE_BYTES:-5500000}"

raiz="$(cd "$(dirname "$0")/.." && pwd)"
principal="$raiz/build/web/main.dart.js"

if [ ! -f "$principal" ]; then
  echo "No existe $principal — ejecuta antes 'flutter build web --release'." >&2
  exit 2
fi

tamano="$(wc -c <"$principal" | tr -d ' ')"

partes=0
partes_total=0
for parte in "$raiz"/build/web/main.dart.js_*.part.js; do
  [ -e "$parte" ] || continue
  partes=$((partes + 1))
  partes_total=$((partes_total + $(wc -c <"$parte" | tr -d ' ')))
done

mib() { awk -v b="$1" 'BEGIN { printf "%.2f", b / 1048576 }'; }

echo "main.dart.js:      $tamano B ($(mib "$tamano") MiB)"
echo "partes diferidas:  $partes ficheros, $partes_total B ($(mib "$partes_total") MiB)"
echo "presupuesto:       $MAX_MAIN_BUNDLE_BYTES B ($(mib "$MAX_MAIN_BUNDLE_BYTES") MiB)"

# Cero partes significa que el diferido dejó de aplicarse en la compilación,
# aunque el tamaño todavía entre en el presupuesto.
if [ "$partes" -eq 0 ]; then
  echo "ERROR: la build no generó ninguna parte diferida." >&2
  echo "Revisa las importaciones 'deferred as' de lib/app/router/internal_router.dart." >&2
  exit 1
fi

if [ "$tamano" -gt "$MAX_MAIN_BUNDLE_BYTES" ]; then
  exceso=$((tamano - MAX_MAIN_BUNDLE_BYTES))
  echo "ERROR: el bundle principal excede el presupuesto en $exceso B." >&2
  echo "Difiere el módulo nuevo (ver docs/adr/005-carga-diferida-en-flutter-web.md)" >&2
  echo "o sube MAX_MAIN_BUNDLE_BYTES en este script, a sabiendas." >&2
  exit 1
fi

echo "OK: dentro del presupuesto."
