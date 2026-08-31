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

`core/network/page_result.dart` es el contrato común de páginas HTTP. Los
catálogos propios exigen el cuerpo v2 `items + page` (`has_more`, `next_cursor`,
`total`, `snapshot_at`); una lista legacy en una ruta v2 es un error de contrato.
Solo Chat conserva un decodificador separado para su contrato cursor mediante
cabeceras. Los repositorios exponen una
operación de página para vistas largas y recorren todas las páginas solo en
selectores que realmente necesitan el catálogo accesible completo.

Agents, Skills, Prompts, Tools, Knowledge y Knowledge Packs consumen `/api/v2`
con cursor. Las pantallas de Agents y Knowledge avanzan página a
página al acercarse al final; el Dashboard obtiene una sola muestra de hasta
100 recursos y pide el total exacto solo para sus KPI. El colector
`core/network/cursor_page_collector.dart` queda para consumidores que necesitan
el conjunto completo. El selector remoto conserva un cursor independiente por
tipo y búsqueda. Chat
carga conversaciones por cursor y antepone mensajes antiguos preservando la
posición de scroll. Los listados de servidor usan builders/slivers para
construir solo lo visible.

Explore público y la búsqueda de usuarios guardan únicamente el siguiente
cursor y deduplican cada página. El visor de logs conserva la navegación
Anterior/Siguiente con un historial local de cursores, y los borradores
oficiales grandes se hidratan con el colector cursor. Ninguno de estos clientes
envía `offset`; un cursor repetido se convierte en un error traducible.

Connections consume `/api/v2/connections` y pagina su pantalla. Los selectores
que necesitan el catálogo completo recorren los cursores con el colector común
y aplanan localmente las variantes de modelo anidadas. Admin Explore se carga
solo al abrir su pestaña, avanza incrementalmente y reinicia el cursor al
cambiar búsqueda o filtros. El visor de tablas mantiene una pila local de
cursores para Anterior/Siguiente; nunca calcula una posición global.

Las pestañas de Skills, Prompts y Tools sí recorren todas las páginas a
propósito: filtran por categoría o lenguaje en cliente, y una página suelta
daría resultados incompletos sin manera de detectarlo. Paginarlas exige antes
que esos filtros existan en el servidor.

El esqueleto de un listado —refresco, barra, rejilla perezosa, estado vacío y
carga de la página siguiente— vive en
`shared/widgets/resource_collection_view.dart` y lo usan las diez pantallas de
colección. Cuando una vista pinta varias colecciones en un mismo scroll
(conexiones por proveedor) toma solo `ResourceGridSliver`.

Un grupo plegado tampoco debe construir lo que no enseña:
`shared/widgets/lazy_expansion_tile.dart` difiere el contenido hasta la
apertura, porque el `ExpansionTile` de Material lo construye siempre y solo lo
oculta. Lo usan la revisión de importación oficial y el árbol de tests de
Centinel, donde cada grupo trae decenas de filas con desplegables.

En web hay un segundo nivel de carga incremental: **el código de las secciones
pesadas no viaja en la descarga inicial**. Administración —Centinel incluido—,
el editor visual de orquestaciones y el checkout se piden al entrar en ellas, no
al abrir la aplicación, porque son las áreas más grandes y las usa una minoría.
La primera entrada muestra un indicador de carga y, si la descarga falla, un
botón de reintento; las siguientes visitas son inmediatas. Fuera de la web no
hay nada que descargar y el comportamiento no cambia.

El estado sigue una convención única en vez de un gestor de estado: `setState` solo para
lo local del widget, un controlador por feature para lo compartido, y **nadie recarga a
mano después de mutar**. `ApiClient` invalida su caché y emite `ResourceEvents` con el
recurso tocado —derivado de la ruta—; las páginas declaran qué miran con el mixin
`WatchesResourceChanges` y recargan solas, también cuando el cambio lo hizo otra
pantalla. `test/feature_architecture_test.dart` rechaza volver a recargar a mano tras una
mutación, y `CLAUDE.md` recoge la convención.

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

La app viene en español e inglés. Los textos no están escritos dentro de las pantallas: viven en ficheros de traducción separados por idioma y por área, y se cargan bajo demanda la primera vez que hacen falta. Cambiar de idioma no requiere reiniciar. `test/i18n_claves_existentes_test.dart` verifica que las claves existan en ambos idiomas, que estén en su namespace y que los sumideros visibles (`Text`, tooltips, ayudas, diálogos, mensajes y errores) no reciban literales naturales. Los widgets reutilizables reciben sus etiquetas traducidas como parámetros obligatorios.

Las rutas en inglés llevan el prefijo `/en` , igual que en la web.

---

## Decisiones de diseño

**Sin generación de código** — no hay paso de compilación intermedio para modelos ni traducciones. Se gana en simplicidad y en tiempo de arranque del proyecto; se paga escribiendo a mano el parseo de las respuestas.

**Estado con las herramientas de la propia Flutter** — no se usa ninguna librería externa de gestión de estado. Las piezas compartidas son pocas y se pasan explícitamente allí donde hacen falta, lo que hace evidente qué depende de qué.

**Una sola puerta a la red** — concentrar todas las peticiones en un punto permite cachear listados, detectar la caída del servidor y cambiar de backend sin tocar el resto de la app.

**Caché breve de listados** — las consultas de listado se recuerdan durante un minuto para no repetirlas cada vez que se vuelve a una vista. Cualquier cambio que el usuario haga sobre ese recurso descarta lo guardado de inmediato.
