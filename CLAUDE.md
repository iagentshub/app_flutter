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
