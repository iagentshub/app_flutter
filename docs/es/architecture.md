<div align="center">
  <a href="index.md">← Índice</a> &nbsp;·&nbsp;
  <a href="../en/architecture.md">🇬🇧 Read in English</a>
</div>

<br>

# Arquitectura de la app

---

## Visión general

La aplicación está escrita en Flutter, de modo que un solo código produce la app para Android, iOS, web, Windows, macOS y Linux. No guarda datos propios: todo lo que muestra viene del backend de iAgentsHub, y en el dispositivo solo se conserva la sesión y las preferencias.

El código se organiza por **áreas funcionales**, no por tipo de fichero. Cada área de la plataforma —agentes, conocimiento, memoria, conexiones…— es una carpeta propia dentro de `lib/features/` con sus pantallas y su acceso a datos juntos. Lo que comparten varias áreas vive en `lib/shared/`.

---

## Carga incremental

`core/network/page_result.dart` es el contrato común de páginas HTTP y lee
`X-Total-Count`, `X-Has-More` y `X-Next-Cursor`. Los repositorios exponen una
operación de página para vistas largas y recorren todas las páginas solo en
selectores que realmente necesitan el catálogo accesible completo.

Knowledge carga páginas offset al acercarse al final. Chat carga conversaciones
por cursor y antepone mensajes antiguos preservando la posición de scroll. Los
listados de servidor usan builders/slivers para construir solo lo visible.

## Las cuatro capas

**Pantallas** (`lib/features/*/pages/`) — lo que el usuario ve y toca. No hablan con la red directamente.

**Repositorios** (`lib/features/*/repositories/`) — la única puerta de salida hacia el backend. Cada uno agrupa las operaciones de su área y devuelve modelos ya listos para pintar.

**Cliente HTTP** (`lib/core/network/`) — un único punto por el que pasa toda petición. Construye la dirección, adjunta la sesión, interpreta la respuesta y avisa si el servidor no responde.

**Estado compartido** (`lib/shared/state/`) — sesión, servidor elegido, idioma y modo de edición del panel. Cada uno notifica a las pantallas interesadas cuando cambia.

---

## Arranque

Al abrir la app se restauran en paralelo tres cosas guardadas en el dispositivo: la sesión, el servidor seleccionado y el idioma. Se hace en paralelo a propósito: son independientes entre sí y encadenarlas alargaba el arranque sin motivo. Mientras tanto se muestra una pantalla de bienvenida.

Terminado eso, la app decide a dónde entrar: al panel si hay sesión válida, o a la pantalla pública si no.

---

## Navegación

Las direcciones internas replican las de la web (`/dashboard`, `/agents`, `/knowledge`…), de forma que un enlace tiene el mismo significado en el navegador y en la app.

Las rutas se dividen en **públicas** —portada, precios, documentación, soporte, perfiles públicos, y todo el flujo de acceso— y **privadas**, que exigen sesión. Entrar a una privada sin sesión redirige al acceso.

---

## Idiomas

La app viene en español e inglés. Los textos no están escritos dentro de las pantallas: viven en ficheros de traducción separados por idioma y por área, y se cargan bajo demanda la primera vez que hacen falta. Cambiar de idioma no requiere reiniciar.

Las rutas en inglés llevan el prefijo `/en` , igual que en la web.

---

## Decisiones de diseño

**Sin generación de código** — no hay paso de compilación intermedio para modelos ni traducciones. Se gana en simplicidad y en tiempo de arranque del proyecto; se paga escribiendo a mano el parseo de las respuestas.

**Estado con las herramientas de la propia Flutter** — no se usa ninguna librería externa de gestión de estado. Las piezas compartidas son pocas y se pasan explícitamente allí donde hacen falta, lo que hace evidente qué depende de qué.

**Una sola puerta a la red** — concentrar todas las peticiones en un punto permite cachear listados, detectar la caída del servidor y cambiar de backend sin tocar el resto de la app.

**Caché breve de listados** — las consultas de listado se recuerdan durante un minuto para no repetirlas cada vez que se vuelve a una vista. Cualquier cambio que el usuario haga sobre ese recurso descarta lo guardado de inmediato.
