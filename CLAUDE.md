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
