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

## La foto de un usuario se pide en un solo sitio

`shared/widgets/user_avatar.dart` es el **único** fichero que puede llamar a
`ApiClient.authenticatedImage`; `test/feature_architecture_test.dart` lo rechaza
en cualquier otro. El widget resuelve el respaldo de iniciales, el tamaño al que
se decodifica el bitmap y el `errorBuilder`.

El mismo bloque estaba escrito a mano en tres pantallas, y no eran copias
idénticas: dos pasaban la ruta **relativa** que da el backend y la tercera una
URL absoluta, que `authenticatedImage` volvía a prefijar. Esa pantalla pedía
`http://host/http://host/api/…`, recibía un 404 y caía al respaldo sin decir
nada — y el respaldo es exactamente lo que se ve cuando no hay foto, así que el
avatar del perfil no se vio nunca y nadie lo notó.

- **Lo que se le pasa es la ruta relativa del backend** (`/api/users/…`), o
  `null`. Lleva dentro el checksum del contenido, así que cambiar la foto cambia
  la URL y la caché del navegador se entera sola. **No hace falta ningún
  contador de versión en el cliente**: hubo uno, vivía en memoria y volvía a
  cero al reconstruirse la pantalla, con lo que la URL reaparecía apuntando a la
  foto anterior.
- Los avatares del menú lateral salen de `SessionUser.avatarUrl`, y
  `SessionController.actualizarAvatar()` es lo que los refresca al cambiar la
  foto en Perfil, sin recargar la sesión entera.

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

## El movimiento vive en un sitio

Las transiciones son del paquete [`animations`](https://pub.dev/packages/animations)
(Material Motion) y se declaran en `shared/widgets/motion/`, nunca sueltas en una
pantalla. Cuatro piezas y cuándo toca cada una:

- **Cambiar de sección** dentro del shell → nada: la ponen las páginas del
  router (`fadeThroughPage` en `internal_router.dart`), no el shell.

  **El `child` que un ShellRoute entrega a su layout es el Navigator del shell,
  y lleva `GlobalKey`.** Envolverlo en algo que mantenga viva la vista saliente
  junto a la entrante —un `PageTransitionSwitcher`, un `AnimatedSwitcher`— pone
  el mismo Navigator en dos ramas del árbol. En debug salta «Duplicate GlobalKey
  detected»; **en release no hay aserción y la pantalla no se pinta hasta que
  otro evento programa un frame**, que se vive como «las vistas tardan segundos
  y no salen hasta que abro el menú». Pasó, y por eso `AppShell` entrega su
  `child` tal cual. `shell_navigation_repinta_test.dart` es el guard.

- **Abrir una página sobre otra** con `Navigator.push` → nada. La transición
  —*shared axis Z*— la pone `appPageTransitionsTheme` desde `ThemeData`, así que
  el `MaterialPageRoute` de siempre ya la hereda. Ponerla en el tema y no en cada
  `push` es también lo que conserva el gesto de retroceso de iOS, que lo aporta
  `MaterialRouteTransitionMixin` leyendo ese mismo tema. Por eso **iOS y macOS
  nativos se quedan con la transición de Cupertino**: ahí el deslizamiento no es
  decoración, es el gesto de volver atrás.
- **Rutas hermanas** —las secciones internas y también login, registro o
  recuperar contraseña— → `fadeThroughPage(key: state.pageKey, …)` en el
  `pageBuilder` de go_router. La `key` tiene que ser la `pageKey` del estado: es
  lo que le dice al Navigator que son páginas distintas.

  Su `fillColor` es el `scaffoldBackgroundColor`, **nunca el `canvasColor` que
  trae por defecto**: en el tema claro ese es blanco puro (#FFFFFF) mientras el
  fondo real de las páginas es #F5F5F7, y la diferencia se veía como un fogonazo
  blanco a mitad de transición, en los dos sentidos. Hay un test que lo fija.
- **Diálogos** → `showAppDialog`, nunca `showDialog`. Misma firma, así que migrar
  es cambiar el nombre. `feature_architecture_test.dart` rechaza la llamada
  directa: no rompe nada visible —el diálogo sale igual— y por eso solo se nota
  en el test.

  Un contenido que **ya ocupa la pantalla entera** pasa `fullscreenSurface: true`
  y toma la misma ruta que el movimiento reducido, sin escalado: la capa
  transformada del *fade through* deja, en web, la cabecera del diálogo sin
  pintar aunque sus controles sigan recibiendo eventos. Es el caso del grafo.
  La excepción vive en el parámetro y no en una lista de rutas permitidas del
  test, porque una excepción por ruta invita a la siguiente y no le explica nada
  a quien abra el fichero.

**Toda animación consulta `AppMotion.reduced(context)` y, si es cierto, se quita
entera.** No se acorta: el framework ya acelera los `AnimationController` ×20 en
ese modo y el resto —un parpadeo de 15 ms— es justo lo que molesta a quien tiene
sensibilidad vestibular. `StatusDot`, `LaunchSplash` y el grafo ya lo hacían cada
uno por su cuenta; ahora la consulta está en un sitio.

Dos cosas deliberadas. **Ninguna transición desplaza contenido**: el fundido del
shell llevaba un slide y un barrido de scanline, y se retiraron porque al
superponerse con listas que aún se maquetaban daban sensación de elementos
descuadrados. Y **`TerminalViewTransition` sigue existiendo** para los dos casos
que no son un cambio entre vistas sino una entrada sin saliente —splash → app en
`main.dart`, y la página de error del router—; ahí un switcher no tendría de qué
hacer la otra mitad.

Sobre el paquete: la **3.x** migra a `material_ui`, que es a donde Flutter está
moviendo Material. Cuesta **53 KB** medidos en el bundle web (4,98 MiB frente a
4,93) y no cambia una sola llamada de las nuestras: el changelog de 3.0.0 es esa
migración y nada más.

`OpenContainer` (el *container transform*, la tarjeta que se despliega en
pantalla) **no está integrado**, y no por olvido: exige que el widget de la
tarjeta construya la página destino, y aquí abrir un recurso lo deciden las
extensiones de acciones sobre el `State` de la página, que devuelven un payload.
Encajarlo significaría mover esa lógica a las tarjetas. El *shared axis Z* del
tema da el mismo «esto se abre hacia dentro» sin tocar nada.

## Reglas que ya vigila la suite

- **i18n**: todo texto de interfaz pasa por `_tx(clave, fallback)` y vive en
  `assets/locales/{es,en}/`. Nada de literales en el árbol de widgets. Las tres
  reglas del idioma están abajo, en su propia sección.
- **Colores y fuentes**: `app/theme/fnc_colors.dart` y `fnc_fonts.dart`. En ficheros
  `part of`, el `import` va en el padre.
- **Tamaños** (`test/feature_architecture_test.dart`): páginas ≤ 700 líneas, componentes
  de presentación ≤ 600. Diálogos y cards fuera de `pages/`.
- **Botones**: los de `shared/widgets/buttons/`, no los de Material directamente.
- **Fechas**: `formatDateTimeShort` / `formatDateShort` de `shared/utils/date_format.dart`.
  El backend manda ISO-8601 con microsegundos y zona; pintarlo crudo son veintitantos
  caracteres en UTC para decir un día, y eso es lo que salía en «Miembro desde». El
  mismo bloque de cuatro líneas llegó a estar copiado en cuatro sitios.
- **Tamaño de subida**: nunca una constante propia. El límite lo pone el administrador
  y llega en `/api/settings/platform/public`; se lee con `UploadLimits.exceeds(bytes)`,
  que con 0 —sin límite, el default— no rechaza nada. Había tres copias del número en
  Dart y ninguna coincidía con la del backend.

## El idioma: tres reglas y por qué

Hoy hay dos idiomas. Todo lo que se escriba dando por hecho que **son
exactamente dos** funciona igual de bien y de mal: al añadir el tercero no falla
nada visible, simplemente esas pantallas se quedan en español y nadie se entera.
Ese fallo silencioso ya pasó una vez —22 ternarios en login y registro, un campo
de ruta por idioma en el pie del menú— y `test/i18n_sin_literales_test.dart` lo
vigila en `features/auth`, `features/public`, `shared/widgets`, `shared/i18n` y
`shared/state`.

**1. El idioma es un código, nunca un booleano.** Ni `isEnglish`, ni
`languageCode == 'en' ? … : …`. Si hay que elegir entre valores por idioma, sale
de `LocaleController.supportedLanguageCodes` o se deriva del propio código:

```dart
// mal: al añadir 'fr' esto manda al español y no falla nada
final ruta = languageCode == 'en' ? '/en/docs' : '/docs';

// bien: el idioma base va sin prefijo, los demás se derivan
final ruta = languageCode == LocaleController.fallbackLanguageCode
    ? base
    : '/$languageCode$base';
```

**2. Un solo argumento: el identificador.** `tr('agents.publish')`, y el texto
vive en `assets/locales/`. La función está en `lib/utils/i18n.dart` para que
llegue a cualquier widget sin `BuildContext` ni pasar el bundle.

Hubo un tiempo en que cada llamada llevaba además el texto en español
—`_tx('clave', 'Publicar')`— como red por si faltaba la clave. Tenía dos costes.
El visible: cada cadena en dos sitios, y al cambiar una se olvidaba la otra. El
grave: **una clave sin declarar no se notaba**, porque salía ese texto de
respaldo y en inglés seguía saliendo en español. Se colaron 50 así, entre ellas
los botones de activar y desactivar recursos en cuatro pantallas.

Ahora, si la clave falta, se ve **el identificador** —feo a propósito— y queda un
aviso en consola (`[i18n] falta la clave «…»`). La única excepción es
`trOr(id, alternativa)`, para claves construidas en tiempo de ejecución
(`trOr('labels.$etiqueta', etiqueta)`): ahí la ausencia es normal y el
identificador sería peor que el nombre crudo.

Tres guardas cubren esto, y cada una ve lo que las otras no: que toda clave
usada exista (`i18n_claves_existentes_test.dart`), que no quede texto español
escrito en el código (`i18n_sin_literales_test.dart`) y que es/en tengan las
mismas claves. **Los mensajes de excepción se quedan en el código**: van a
`throw` y el usuario no los lee.

**3. Añadir un idioma es crear su directorio y sumar el código** a
`supportedLanguageCodes` — y su nombre nativo a `LocaleController.languageNames`,
que está justo al lado para que sea un solo sitio. Las pantallas que ofrecen el
cambio recorren esa lista; ninguna escribe una opción por idioma.

Y al revés: **un fichero de locales que no carga nadie sobra**. La app pide cinco
namespaces —`resources`, `auth`, `common`, `nav`, `pricing`— y llegó a haber 25
ficheros por idioma: 284 KB en el bundle que nadie leía, y una clave que se
escribía en el fichero equivocado la mitad de las veces.
`test/locales_sin_huerfanos_test.dart` compara los ficheros con los namespaces
que el código carga de verdad.

## La versión de Flutter la fija el pubspec

`environment: flutter:` de `pubspec.yaml` es **la** versión, exacta, y los tres
workflows que compilan esta app la leen de ahí con `flutter-version-file`: el CI
de este repo (sus dos jobs) y los `docker-publish` de `iAgents` y
`backend_fastapi`, que hacen checkout de este repositorio para construir la
imagen unificada.

Antes solo la fijaba el CI de aquí —en 3.44.8— y los otros dos instalaban
`channel: stable` sin más. Como esos dos son los que construyen **la imagen que
se despliega**, producción se compilaba con lo que hubiera ese día y el CI
validaba otra cosa. Nada fallaba: son la misma app compilada por dos SDK
distintos, y el que llegaba al usuario era el que nadie había probado.

Dos detalles que cuestan un CI rojo si se pasan por alto:

- **La versión tiene que ser exacta** (`3.47.1`, no un rango). La action exige
  una versión concreta, y un rango devolvería el problema tal cual estaba: cada
  runner resolvería la suya.
- **La ruta del fichero es relativa al workspace**, no al `working-directory`
  del paso que compila. En el job `publish-unified` de este repo, y en los dos
  `docker-publish`, es `app_flutter/pubspec.yaml`, porque ahí este repositorio
  va en un subdirectorio.

Al subir de versión: cambiar el pubspec, comprobar `flutter analyze` y
`flutter test`, y **volver a medir el bundle** —`tool/build_web.sh` y
`tool/check_web_bundle_size.sh`—, porque el presupuesto está anotado con la
versión con la que se midió. `iAgents/tests/test_docker_contexto.py` vigila que
ningún workflow vuelva a decidir la suya, y `web_bundle_budget_test.dart` que
este repo siga declarándola.

## Antes de dar algo por terminado

`flutter analyze` sin avisos y `flutter test` en verde. El repo tiene colaboración
concurrente: comprueba `git status` antes de empezar y no des por tuyo un fichero
modificado que no recuerdas haber tocado.
