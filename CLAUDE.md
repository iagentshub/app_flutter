# app_flutter — convenciones

Cliente autenticado de iAgents Hub (Agentes, Knowledge, Explorar, Grafos, Chat, Admin).
`frontend_react` es solo marketing: la app real es esta.

## Estado: quién carga, quién avisa

Una sola forma de cargar, refrescar e invalidar. La app no usa librería de gestión de
estado y **no se va a migrar a ninguna**: lo que aplica es esta convención.

- **`setState` solo para estado local del widget** — lo que se abre, lo que está enfocado,
  el texto de un campo. Nunca para datos del servidor compartidos con otra pantalla.
- **Un controlador por feature** para lo que se comparte entre secciones
  (`AsyncSection` para cargando/error/datos, `ChangeNotifier` cuando hace falta más).
- **Quien muta no recarga.** Toda mutación pasa por `ApiClient`, que invalida su caché y
  emite un `ResourceEvents.changed('<recurso>')` derivado de la ruta
  (`/api/agents/...` → `agents`). Nadie tiene que acordarse de avisar.
- **Quien pinta declara qué mira.** La página usa el mixin `WatchesResourceChanges`:

  ```dart
  class _MiPageState extends State<MiPage> with WatchesResourceChanges {
    @override
    Set<String> get watchedResources => const {'agents', 'sharing'};

    @override
    Future<void> onResourcesChanged(Set<String> changed) => _load();
  }
  ```

  Así una vista se entera de los cambios que hace **otra** pantalla, que es de donde
  salían las regresiones en la pantalla que nadie tocó. Añadir `await _load()` detrás de
  una mutación propia es la señal de que falta el mixin.

Excepción legítima: recargar al volver de una pantalla que muta un recurso que esta vista
no observa (el chat consume tokens del agente). Va comentada en el sitio.

## Listados

`ResourceCollectionView` (en `shared/widgets/`) es el esqueleto de cualquier listado:
refresco, barra, rejilla perezosa, estado vacío y carga de la página siguiente. Para una
vista con varias colecciones en un scroll, `ResourceGridSliver` suelto. Nunca montar el
`CustomScrollView` a mano otra vez.

Los listados largos se paginan con `listPage`; `list()` recorre todas las páginas y es
para selectores que necesitan el catálogo completo. Si un filtro se resuelve en cliente
sobre una lista paginada, hay que asegurar que la página se llene — sin elementos no hay
scroll, y sin scroll nadie pide la página siguiente.

Cuando el filtro **quita** elementos —no solo los ordena—, va en la petición, no en el
cliente: el total de la cabecera se calcula en el servidor y filtrar después lo deja
mintiendo. Y si el filtro puede vaciar la lista, el estado vacío tiene que decir que ha
sido él; un «no hay resultados» tras una búsqueda que sí encontraba algo parece un
buscador roto. Explorar es el ejemplo montado: `relation` viaja en la URL y el backend
devuelve `X-Linked-Count` para explicar el vacío.

## El grafo se arma en un solo sitio

`shared/graph/resource_graph_builder.dart` es el **único** fichero que puede
crear un `GraphNode` o un `GraphEdge`; `test/feature_architecture_test.dart` lo
rechaza en cualquier otro sitio. Armar un grafo llegó a estar escrito ocho veces
—cuatro aquí y cuatro en el backend— y las copias divergieron: el mismo agente
enseñaba conexión, skills, prompts, tools, knowledge y packs desde Agentes, pero
solo conexión, skills, knowledge y memoria, con el id crudo por etiqueta, desde
Workflows.

- Lo que la pantalla ya tiene cargado se arma aquí: `agentGraph`,
  `workflowGraph`, `knowledgePackGraph`, `officialPackGraph`…
- Lo que llega del backend entra por `fromRelations`. Los endpoints
  (`/api/…/relations`) devuelven **hechos planos** —qué cuelga de qué, con qué
  relación— y no un grafo montado: las carpetas de un pack, por ejemplo, se
  construyen aquí a partir del `path` de cada fichero.
- El backend solo interviene donde el cliente no puede: el filtro de
  dependencias públicas de un recurso publicado y los recursos de otros
  usuarios en Admin. El porqué completo está en
  `docs/adr/010-el-grafo-se-arma-en-el-cliente.md` del repo `backend_fastapi`.
- `ResourceGraphButton` recibe una función que arma el grafo, no el grafo hecho:
  la tarjeta vive en una rejilla que se reconstruye al desplazarse.
- **El modo Galaxia agrupa por dependencia, no por tipo**, y su reparto es
  geométrico, no una simulación de fuerzas: anillo por profundidad desde la
  raíz, un sector angular por rama proporcional a su tamaño, hermanos
  escalonados en zigzag a lo largo del brazo y un giro por nivel que curva los
  radios en espiral. Sale en O(n), en el mismo frame y siempre igual para el
  mismo grafo.

  Lo que había antes era un layout de fuerzas, y con él nunca salía una
  galaxia: repartía por área, así que la densidad crecía hacia fuera, y la suma
  de repulsiones —una por cada otro nodo— acababa venciendo a la gravedad y
  aplastando el grafo contra los bordes. En un móvil, 109 de 121 nodos
  terminaban pegados al borde. También hubo un agrupamiento por familia de tipo,
  con halos de color detrás, que mezclaba recursos sin relación entre sí.

  Dos cosas que parecen detalle y no lo son: **el lienzo es cuadrado** (heredar
  el aspecto del visor estira la galaxia hasta volverla un pasillo en pantallas
  estrechas) y **se dimensiona por el anillo más poblado**, no por área media —
  si cuarenta recursos cuelgan del mismo sitio, lo que necesitan es perímetro.
  `test/shared/graph/galaxy_layout_reparto_test.dart` mide las cuatro cosas
  sobre un móvil de 360x700.

## Carga diferida en web

`internal_router.dart` importa cinco páginas con `deferred as` —admin, Centinel,
metadata, workflows y checkout— y las monta con `DeferredPage`. Son las áreas más
pesadas y las usa una minoría; sin diferirlas, su código se descargaba antes de la
pantalla de login. Ahorra 777 KB del bundle principal (−13 %).

Lo que hay que saber al tocarlas:

- **Solo el router puede importarlas.** Un `import` normal desde cualquier otro
  fichero las devuelve al bundle principal sin romper nada visible.
  `test/deferred_routes_test.dart` lo rechaza.
- **Una pantalla pesada nueva se añade diferida**, con su entrada en ese test.
- `tool/check_web_bundle_size.sh` (en CI tras `flutter build web --release`) falla
  si el bundle principal cruza el presupuesto o si la build no generó partes.

El porqué completo, con las alternativas descartadas, está en
`docs/adr/005-carga-diferida-en-flutter-web.md` del repo `backend_fastapi`.

## La sesión se renueva sola

El access token del backend dura 30 minutos y la sesión, horas. `ApiClient`
renueva ante un 401 y reintenta la petición **una vez**, con un cerrojo
(`_refreshSession`): el refresh **rota** en cada canje, así que dos renovaciones
en paralelo mandarían la segunda con un token ya rotado, que el backend lee
—correctamente— como robo y revoca la sesión entera.

Lo que hay que saber al tocar `api_client.dart`:

- **`_send` recibe una función que construye la petición**, no la petición
  hecha: un `BaseRequest` finalizado no se puede reenviar, y el reintento tiene
  que ir con el token nuevo.
- El `ga_refresh` se captura **en un solo sitio**, junto al del CSRF: llega en
  el login, el registro, el alta de invitado, la verificación de email, el login
  con GitHub y cada renovación. Recogerlo en cada uno es la forma de que al
  séptimo se le olvide.
- Fuera de web las cookies las guarda la app: `SessionController` persiste el
  refresh en el almacén seguro, y `renewAccessToken` **no** toca `_epoch` —
  renovar no es entrar, y hacerlo invalidaría toda la caché cada 30 minutos.

El porqué completo está en `docs/adr/008-sesiones-revocables.md` del repo
`backend_fastapi`.

## Reglas que ya vigila la suite

- **i18n**: todo texto de interfaz pasa por `_tx(clave, fallback)` y vive en
  `assets/locales/{es,en}/`. Nada de literales en el árbol de widgets.
- **Colores y fuentes**: `app/theme/fnc_colors.dart` y `fnc_fonts.dart`. En ficheros
  `part of`, el `import` va en el padre.
- **Tamaños** (`test/feature_architecture_test.dart`): páginas ≤ 700 líneas, componentes
  de presentación ≤ 600. Diálogos y cards fuera de `pages/`.
- **Botones**: los de `shared/widgets/buttons/`, no los de Material directamente.

## Antes de dar algo por terminado

`flutter analyze` sin avisos y `flutter test` en verde. El repo tiene colaboración
concurrente: comprueba `git status` antes de empezar y no des por tuyo un fichero
modificado que no recuerdas haber tocado.
