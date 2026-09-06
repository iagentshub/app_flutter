# Auditoría visual de Flutter web

Fecha: 5 de septiembre de 2026. Alcance: aplicación Flutter, manteniendo marca, paleta y comportamiento nativo. No incluye el sitio React ni cambios de backend.

## Diagnóstico

La aplicación tiene una base compartida, pero algunas pantallas añaden sus propios anchos, cabeceras y barras de acciones. El resultado son márgenes distintos, acciones sin texto y controles que se apilan demasiado pronto. La corrección debe hacerse en los componentes compartidos y completar después las excepciones de cada pantalla.

No todos los huecos son errores: el espacio de una conversación vacía se usará al recibir mensajes; un formulario de acceso necesita un ancho de lectura limitado. Sí conviene corregir márgenes duplicados, filas de indicadores mal repartidas, botones desalineados y zonas vacías causadas por límites demasiado estrechos.

## Evidencia y límites

- **Visual**: navegación local con datos ficticios en el navegador. Dashboard y Agentes revisados en escritorio y ventanas estrechas; temas claro y oscuro en la revisión inicial. Constructor IA revisado a 1440 × 900 y 360 × 800 tras los ajustes.
- **Código**: inventario de rutas, páginas y componentes de distribución. Identifica diferencias y riesgos; no equivale a una aprobación visual de todos sus estados.
- **Pendiente**: combinaciones que requieren datos representativos, otros roles o servicios reales. No se han creado agentes reales ni ejecutado pagos, importaciones o acciones administrativas.
- Los tests de widgets ejecutados en la VM comprueban regresiones y lógica, pero no ejercitan las ramas `kIsWeb`. El arranque de tests automáticos en Chrome quedó bloqueado; las comprobaciones web indicadas son manuales.

## Sistema visual acordado

| Elemento | Criterio para web |
|---|---|
| Navegación principal | Un solo `AppShell`: mismos grupos, orden, estado activo y comportamiento de plegado. Las opciones visibles dependen del rol. |
| Cabecera de editor | Volver, título y acción principal; mismo tema de superficie, tipografía y color. La cabecera de sección del shell puede permanecer como contexto. |
| Ancho de listados | Marco máximo de 1600 px, alineado con la cabecera; adaptación al ancho disponible. |
| Constructores y formulario de agente | Máximo de 1280 px en web; mensajes con límite de lectura independiente. |
| Barras de recursos | Búsqueda, crear con etiqueta, actualizar, filtros y acciones de grupo; salto de línea cuando hace falta, conservando el foco. |
| Tarjetas | Separación web de 16 px, altura igual dentro de cada fila; acciones inferiores alineadas donde se adopta `ResourceCardBody`. |
| Iconos | Símbolos consistentes por función, tamaño y estilo comunes; tooltip en acciones que sólo llevan icono. |
| Vacíos y errores | Mensaje y acción próximos, ancho contenido; posibilidad de reintentar sin bloquear la navegación. |
| Adaptación | Decidir con el espacio del componente y la escala de texto; no asumir que toda la ventana pertenece al contenido. |
| Móvil nativo | Mantener variantes existentes; los cambios de apariencia se condicionan a `kIsWeb`. |

## Correcciones implementadas en esta revisión

| Problema | Corrección | Archivos principales |
|---|---|---|
| Cabecera y contenido sin eje común | Marco web compartido | `web_content_frame.dart`, `app_shell.dart`, `app_shell_navigation.dart` |
| Contenido comprimido durante el plegado del menú | Viewport estable para el contenido de la barra lateral | `WebSidebarViewport` |
| Controles y menús con aspecto desigual | Tema web de botones, menús emergentes y cabeceras de editor | `app/theme/web_theme.dart` |
| Iconografía heterogénea de navegación | Mapa de iconos por función para web | `app/theme/app_icons.dart` |
| Crear sólo con un símbolo + | Acción con etiqueta en las colecciones principales | `resource_create_button.dart` y páginas consumidoras |
| Buscador y acciones gastan dos filas en escritorio | Barra adaptable con identidad estable al redimensionar | `resource_toolbar.dart`, `explore_search_toolbar.dart` |
| Tarjetas con bordes inferiores desiguales | Filas de altura intrínseca común y construcción diferida | `responsive_masonry_grid.dart` |
| Acciones de agentes y conexiones a distinta altura | Cuerpo y acciones compartidos, con salto de línea | `resource_card_body.dart`, tarjetas de agentes/conexiones |
| Indicador aislado en el dashboard | Reparto equilibrado de columnas según espacio y escala | `dashboard_metrics_cards.dart` |
| Vacíos demasiado extendidos | Panel centrado de ancho limitado | `resource_collection_view.dart` |
| Agentes y skills con constructores de anchos diferentes | Ancho web de 1280 px en ambos | `agent_builder_page.dart`, `skill_builder_page.dart` |
| Conexión y modo apilados en escritorio | Selectores alineados y adaptables en el componente compartido | `builder_connection_bar.dart` |
| Sugerencias iniciales ocupan filas completas | Distribución web de una a tres columnas | `agent_builder_chat_panel.dart` |
| Formulario manual más estrecho que el constructor | Mismo máximo web de 1280 px | `agent_form_page.dart` |
| Historial del chat puede desaparecer en una zona estrecha dentro de una ventana grande | Botón y drawer web usan el mismo ancho local que la distribución del chat | `chat_page.dart` |

## Inventario por pantallas

Las propuestas de esta tabla son trabajo pendiente salvo cuando se indica una corrección aplicada. “Código” significa revisión estructural, no prueba de todas las interacciones.

| Pantalla o flujo | Evidencia | Estado y siguiente comprobación |
|---|---|---|
| Dashboard | Visual y código | Indicadores repartidos; marco e iconos unificados. Probar combinaciones personalizadas de widgets y datos largos. |
| Agentes: listado, búsqueda y vacío | Visual y código | Barra, crear, tarjetas y acciones corregidos. Revisar también agentes compartidos, errores y paginación real. |
| Agentes: elección de creación | Visual y código | Opciones diferenciadas y legibles. Probar teclado y texto ampliado en el diálogo. |
| Agentes: constructor IA | Visual y código | Ancho, selectores, cabecera y sugerencias corregidos. Pendientes streaming real, errores largos y borrador con textos extremos. |
| Agentes: formulario desde cero y edición | Visual de Básico y Conexión a 1440 × 900; código del resto | Ancho y cabecera unificados. Conexión deja mucho espacio vertical: proponer un grupo compacto de ajustes en esa pestaña y limitar el recorrido visual del slider. Validar Conocimiento, Avanzado, mensajes de validación y recursos asociados. |
| Agentes: revisión del borrador IA | Código | Reutiliza el formulario manual. Revisar que borrador, error y compositor simultáneos quepan en ventanas de poca altura. |
| Agentes: importar archivo/directorio | Código | Comparar diálogos de selección y previsualización con el sistema común; probar nombres largos y numerosos recursos. |
| Agentes: selector público | Código | Tiene máximo propio de 760 px. Evaluar una colección más ancha en escritorio conservando legibilidad. |
| Agentes: conversación | Código | Corregida discrepancia de ancho para el historial. Revisar markdown, adjuntos, menciones, preferencias e historial abierto. |
| Agentes: grafo, permisos e historial del recurso | Código | Revisar densidad y acciones de diálogos con relaciones numerosas; igualar iconos por función. |
| Conexiones: listado | Código; comparte componentes verificados | Crear, tarjetas y acciones alineados. Validar proveedores, conexiones desactivadas y metadatos largos. |
| Conexiones: alta, edición y selección de proveedor | Código | Revisar formularios con muchos campos y mensajes de error; conservar ancho cómodo y scroll accesible. |
| Orquestación: workflows | Código | Barra y crear compartidos. Comprobar estados vacío, ejecución e historial con datos. |
| Orquestación: conexiones LLM | Código | Crear compartido. Revisar paneles balanceado/stack con numerosos candidatos. |
| Editor de workflow | Código | Cabecera web común. Inspector de 400 px: validar que no quite demasiado espacio al lienzo en ventanas medianas. |
| Editor de orquestación LLM | Código | Cabecera común; distribución propia de dos columnas. Revisar punto de cambio, panel de 480 px y texto ampliado. |
| Ejecuciones e historial | Código | Hay paneles con 620 × 520 y detalles de 360 px. Verificar restricciones reales del diálogo antes de declararlos fallos. |
| Conocimiento: skills | Código | Barra y crear compartidos. Adoptar pie de tarjeta común para completar alineación de acciones. |
| Conocimiento: constructor de skill | Código | Comparte chat, selectores y ancho con agentes. Falta validación visual del borrador y editor final. |
| Conocimiento: prompts | Código | Crear y toolbar unificados. Revisar contenido largo y filas de acciones propias. |
| Conocimiento: tools | Código | Crear y toolbar unificados. Revisar estados de disponibilidad, chips y acciones. |
| Conocimiento: documentos, imágenes y packs | Código | Colección compartida. Revisar miniaturas, proporciones y pies propios de tarjetas. |
| Memoria, directa o dentro de Conocimiento | Código | Barra y crear compartidos. Comprobar que no se acumulen márgenes al entrar desde la pestaña. |
| Explorar | Código | Buscador comparte toolbar web. Comparar pestañas, filtros, orden y acciones de importación con recursos propios. |
| Explorar: pack oficial | Código | Máximo de 1100 px y distribución adaptable propia. Revisar cabecera extensa, recursos y origen. |
| Etiquetas: catálogo y búsqueda | Código | Colecciones comunes; pestañas con tratamiento diferente. Alinear margen y presentación con Conocimiento. |
| Gestor: grupos, miembros e invitaciones | Código | Usa cabecera propia con crear sólo icono. Migrar a la barra de recursos y acción con etiqueta. |
| Perfil y sus pestañas | Código | Máximo de lectura de 900 px. Evaluar dos columnas para ajustes independientes, manteniendo formularios legibles. |
| Perfil: sesiones, grupos y avatar | Código | Revisar diálogos, listas con altura limitada y foco al cerrar. |
| Perfil público `/u/…` | Código | Recursos usan colección común; revisar cabecera con nombres largos, avatar y ausencia de recursos. |
| Administración: general | Código | Comparar métricas y tablas con el dashboard; comprobar permisos y densidad con datos reales. |
| Administración: explorar | Código | Comparte buscador; revisar acciones por fila y selección múltiple. |
| Administración: fuentes oficiales | Código | Revisar importación, comparación y estado de revisión antes de uniformar alturas. |
| Administración: configuración | Código | Revisar agrupación de campos y alineación de acciones en todas sus secciones. |
| Administración: revisión de importación | Código | Pantalla adaptable; diálogos internos con medidas propias. Probar contenido largo y ventanas cortas. |
| Metadatos: tablas y logs | Código | Revisar scroll horizontal de tablas, anchos de filtros y legibilidad del detalle. |
| Centinel: pruebas funcionales, probe y estrés | Código | Controles/gráficos de ancho propio. Probar filtros con zoom y resultados largos antes de rediseñar. |
| Login | Código | Formulario limitado y composición propia intencionales. Verificar errores, textos largos y tema claro. |
| Registro | Código | Diseño público específico; conservar identidad y comprobar cambio alrededor de 900 px. |
| Recuperar y restablecer contraseña | Código | Máximo de 420 px apropiado para formularios breves. Comprobar validaciones y navegación por teclado. |
| Verificar cuenta | Código | Máximo de 420 px; validar mensajes de éxito/error y enlaces. |
| Aceptación legal | Código | Lectura limitada a 640 px; revisar scroll y acceso a la acción final. |
| Configurar backend | Código | Máximo de 560 px; revisar URL larga y feedback de conectividad. |
| Recuperación o indisponibilidad de sesión | Código | Máximo de 480 px; revisar reintento y vuelta al acceso. |
| Autorización VS Code | Código | Máximo de 480 px; revisar estados pendiente, éxito y error. |
| Checkout | Código | Máximo de 620 px intencional. Validar resumen, errores y contenido embebido con entorno de pago de prueba. |
| Página no encontrada | Código | Verificar vuelta al inicio y coherencia con el contexto autenticado/público. |
| Rutas públicas informativas | Router | `/about`, `/docs`, `/support`, `/pricing` redirigen al inicio público; no inventariarlas como pantallas Flutter independientes. |
| Alias de rutas | Router | `/workflows` y `/admin/logs` redirigen a sus destinos; no duplicar menús ni estilos para estos alias. |

## Prioridades para completar la homogeneidad

### Novena tanda: Perfil › Mi cuenta en una sola pila

- Decisión de producto: las secciones de «Mi cuenta» —resumen, identidad, preferencias, seguridad y zona de peligro— vuelven a ir en **una sola columna, de arriba abajo**, también en web. La distribución a dos columnas de la tercera tanda repartía los ajustes en varios sitios a la vez y se ha retirado a petición. La pestaña recupera el ancho de lectura común del perfil (`Breakpoints.anchoLectura`) en lugar de los 1280 px que necesitaban las dos columnas.
- `WebSettingsLayout` pasa a ser `SettingsStack` (`shared/widgets/settings_stack.dart`): el mismo apilado con 24 px entre grupos en todas las plataformas, sin rama web. Es su único uso; Administración › Configuración sigue con su rejilla.
- Validación: análisis sin incidencias en los ficheros tocados; las 86 pruebas que montan el perfil pasan. No cambia la build más allá del código retirado.

### Octava tanda: hallazgos de la pasada visual

- Dashboard a 360 px: el resumen salía en **una columna y seis filas** en web, mientras nativo —con 220 px de máximo por indicador— daba dos. Con 312 px útiles, el mínimo de 160 por indicador no dejaba sitio a dos; pasa a 140, que es lo que necesita un indicador (icono, cifra y una palabra). Comprobado tras el cambio: dos columnas y tres filas a 360; tres columnas a 1024; una fila de seis a 1360.
- Menú lateral con texto al 200 %: los 240 px recortaban los nombres de sección («Orquestaci…», «Conocimie…»). El ancho del menú crece con la escala de texto hasta 340 px en vez de recortar; plegado y viewport del menú siguen el mismo ancho.
- Falsa alarma, anotada para no repetirla: para probar el texto al 200 % la fixture envolvía la aplicación en un `MediaQuery` con `textScaler`, y con eso la transición de arranque —recuperación de sesión hacia el shell— se quedaba a medias en la build release hasta que llegaba un evento de puntero. Sin el envoltorio el arranque es limpio, y en debug lo es con y sin él. No es un fallo del producto; la fixture solo envuelve cuando se pide escala.
- Validación: análisis sin incidencias en los ficheros de esta tanda; 741 pruebas pasadas y una omitida. Build web release correcto: `main.dart.js` de 5.415.632 bytes, dentro del presupuesto. Queda un aviso `prefer_const_constructors` en `workflows_page.dart:545` que no es de esta tanda: pertenece a la migración de pestañas que avanza en paralelo.

### Pasada visual en navegador

La ventana de Chrome estaba maximizada y la automatización no la redimensiona, así que los anchos se han comprobado con un marco HTML (`marco.html`, junto a la build de la fixture) que carga la aplicación en un `iframe` del tamaño pedido. La fixture admite `?route=`, `?lang=`, `?theme=` y `?scale=` para la ruta, el idioma, el tema y la escala de texto. Comprobado con la build release de `.dart_tool/ui_preview.dart` y datos ficticios:

| Comprobación | Resultado |
|---|---|
| 360 × 560: Conexiones, Agentes, Conocimiento, Dashboard | Distribución estrecha con menú en cajón; barra apilada en dos o tres filas; tarjetas a ancho completo; pestañas de sección desplazables. Sin desbordes. Dashboard corregido (dos columnas). |
| 360 × 560: recuperación de sesión | Tarjeta centrada, botones a ancho completo, sin recortes. |
| 768 × 560: Agentes, Conocimiento | Dos columnas de tarjetas; barra en dos filas; las cinco pestañas de Conocimiento caben en una fila. |
| 1024 × 560: Dashboard | Distribución ancha con menú; el menú se desplaza y el pie tapa el último elemento, que sigue accesible al desplazar; resumen en tres columnas; acciones rápidas en dos filas. |
| 1360 × 633 (pantalla del equipo): tema claro | Agentes en `light-red`: contraste y jerarquía conservados. |
| 1360 × 633: inglés | Conexiones y Dashboard en `en`: pestañas, barra, tarjetas e indicadores traducidos; misma distribución. |
| 1360 × 633: texto al 200 % | Agentes y Conexiones: barra envuelve en dos filas, tarjetas en tres columnas con títulos en dos líneas, sin desbordes. El menú recortaba nombres: corregido. |
| 1920 px | No comprobado: la pantalla del equipo mide 1360 px de ancho. |

Dentro del `iframe` la animación de arranque se queda a medias hasta que llega un evento de puntero, así que cada captura va precedida de un clic en la cabecera; fuera del marco, y sin el envoltorio de escala, el arranque es limpio.

### Séptima tanda: enlaces de salto, foco en release y anchos deliberados

- Saltar al contenido: con teclado, Tab recorría el menú lateral entero —más de una docena de paradas— antes de llegar a la página. `SkipLink` (`shared/widgets/shell/skip_link.dart`) es un botón invisible hasta que recibe el foco, superpuesto en la esquina superior izquierda del shell ancho en web: el orden de lectura es geométrico, así que precede al menú. Al activarlo, el foco pasa al ámbito del contenido —un `FocusScope` que envuelve el Navigator del shell en un solo punto del árbol, sin duplicarlo— y vuelve al control que tuvo, o el siguiente Tab entra en la página. Sigue en la semántica: un lector de pantalla lo anuncia. Claves `skip_to_content` y `skip_to_menu` en `nav.json` (es/en).
- Hallazgo de la pasada en navegador: en la **build release web, Tab nunca salía de la página**. Daba vueltas entre sus controles y el menú no se alcanzaba con teclado. Reproducido con una build sin los cambios de esta tanda: el fallo era anterior. En debug y en la VM el mismo árbol sí sale de la página; la diferencia está en cómo ordena Flutter el ámbito de la ruta respecto a sus propios hijos, y no se ha localizado la causa en `focus_traversal.dart`. Dos medidas: el ámbito del contenido usa `TraversalEdgeBehavior.parentScope` —con el `closedLoop` por defecto atrapaba el foco también en debug— y hay un segundo enlace, «Ir al menú», dentro del ámbito de la página, que lleva al primer control del menú en orden de lectura; el menú no es un ámbito a propósito, porque uno propio atrapaba el foco entre menú y enlace.
- Comprobado en Chrome con la build release de la fixture: desde la página, Tab llega a «Saltar al contenido», al botón de plegar, a la campana y a los elementos del menú, y desde el último vuelve a la página; «Ir al menú» aparece al recibir el foco. La cuenta exacta de paradas varió entre ejecuciones según de dónde partiera el foco, así que el test no cuenta: busca.
- Administración › Configuración: verificado sin cambio. Ya reparte sus secciones con `ResponsiveSliverMasonryGrid` (tarjetas de 320 px mínimo, hasta tres columnas); no necesita el apilado del perfil.
- Selector público de agentes (760 px): se conserva. Es una lista de fichas de una columna; ensancharla al marco de 1600 px alarga la línea de lectura sin añadir contenido. Cerrado como deliberado.
- Pack oficial (1100 px): se conserva. Es una página de detalle —cabecera con descripción, procedencia y filtros— y no una colección; el marco de 1600 px está pensado para rejillas. Cerrado como deliberado.
- Guardia: `test/shared/widgets/skip_link_test.dart` reproduce la geometría del shell con un Navigator anidado —menú, ámbito del contenido, los dos enlaces— y comprueba que desde la página se llega a «Ir al menú» y Enter deja el foco en el primer elemento del menú; que desde el menú se entra en la página; y que «Saltar al contenido» precede al menú y lleva a la página.
- Validación: análisis sin incidencias; 741 pruebas pasadas y una omitida. Build web release correcto: `main.dart.js` de 5.415.568 bytes, dentro del presupuesto.

### Sexta tanda: teclado y foco

- Revisado en código, sin cambio: los controles compartidos se apoyan en `PopupMenuButton`, `IconButton`, `DropdownButtonFormField` e `InkWell`, así que entran en el recorrido con Tab; sólo quedan tres `GestureDetector` en toda la aplicación y el único con `onTap` es el lienzo del grafo, que además tiene búsqueda y lista. Las pestañas son `TabBar` (flechas). El foco se ve: los elementos del menú lateral llevan `focusColor`, los campos `focusedBorder` y los botones la capa de estado de Material 3. Escape cierra cualquier diálogo abierto con `showAppDialog` —la ruta de `animations` respeta `barrierDismissible` como `showDialog`— y el foco vuelve al botón que lo abrió.
- Login: Enter en la contraseña no hacía nada —el campo soltaba el foco y el botón seguía esperando un clic— y en el usuario cerraba el teclado en vez de pasar a la contraseña. Ahora `TextInputAction.next` en el usuario y `onFieldSubmitted` en la contraseña, con la misma condición de habilitado que el botón.
- Diálogos de formulario: diez abrían con el foco en la ruta y no en su primer campo —agente y cambio de propietario en Administración, fuente oficial, backend, conexión, texto, URL, prompt, skill y tool—. Adoptan `autofocus: true` como ya hacían invitar usuario, etiquetas, packs y ejecutar workflow. Se dejan sin autofocus a propósito los que empiezan por otro control (cuenta de proveedor: desplegable; banner: fecha), el editor de memoria (su primer campo puede ser de sólo lectura) y los buscadores. Añadir URL envía también con Enter: dos campos de una línea y el título es opcional.
- Fuera de alcance: un enlace «saltar al contenido» —hoy Tab recorre el menú lateral antes que la página— y la validación de estados deshabilitado, cargando, error y vacío con datos reales, que sigue en la lista de pendientes.
- Guardia: `test/teclado_y_foco_test.dart` abre un diálogo con `showAppDialog`, comprueba que el campo recibe el foco, que Escape lo cierra y que el foco vuelve al botón; y monta el login y verifica que Enter en la contraseña llega a `login`. Ese segundo test se ha ejecutado sin el arreglo para confirmar que fallaba (0 envíos).
- Validación: análisis sin incidencias; 738 pruebas pasadas y una omitida. Build web release correcto: `main.dart.js` de 5.415.694 bytes, dentro del presupuesto. El recorrido con Tab, el foco visible y el retorno de foco se han verificado en la VM; no en el navegador.

### Quinta tanda: diálogos con medidas fijas y tablas anchas

- Diálogos: quedaban cinco con `SizedBox` de medidas literales en su `content` —revisar herramienta (760 × 520) y editar relaciones (560 × 460) en la revisión de importación oficial, historial de ejecuciones de workflows (620 × 520), historial de Centinel (480) y la vista rápida de un nodo del grafo (320)—. Pasan por `dialogContentWidth` / `dialogContentHeight`, que ya usaban los otros cincuenta: en un móvil de 360 px y en una ventana de 600 px de alto se ajustan en vez de desbordar o recortar las acciones.
- Verificado sin cambio: el panel de detalle de 360 px del visor de ejecuciones sólo va en fila a partir de 780 px de ancho y por debajo se apila; el diálogo de datos de tabla limita con `maxWidth`/`maxHeight`, no con un tamaño fijo; las listas de 160 px de sesiones, miembros y grupos son alturas máximas de listas desplazables. No son fallos.
- Tablas anchas: metadatos, visor de logs, datos de tabla y las tablas de Centinel (probe y errores de estrés) tenían scroll horizontal sin barra permanente: la del tema sólo aparece mientras se desplaza, y con ratón no hay gesto de arrastre que la provoque, así que la tabla parecía terminar donde termina la ventana y las columnas de servicio, acción y mensaje de los logs no se veían nunca en escritorio. `WideTable` (`shared/widgets/wide_table.dart`) deja la barra siempre visible y evita la segunda que el tema añade en escritorio. Las tiras de chips de filtros (Centinel, selector de recursos) y los bloques de código del chat conservan su scroll: no son tablas y una barra permanente sería ruido.
- Guardias: `test/dialogos_sin_medidas_fijas_test.dart` recorre `lib/` y falla ante un `content: SizedBox(` con ancho o alto literal; `test/wide_table_test.dart` comprueba a 400 px, como Windows, que hay una sola barra y que el desplazamiento llega al final de la tabla.
- Validación: análisis sin incidencias; 736 pruebas pasadas y una omitida. Build web release correcto: `main.dart.js` de 5.415.365 bytes, dentro del presupuesto. Los helpers de diálogo ya estaban cubiertos por `responsive_dialog_test.dart`; la barra de las tablas se ha comprobado en la VM como escritorio, no en el navegador.

### Cuarta tanda: iconografía de acciones

- Grafo: la vista previa del grafo en la revisión de importación oficial y el grafo de un pack oficial usaban el icono de la sección Workflows; ahora comparten `AppIcons.graph` con las colecciones privadas, Explorar y Administración. Editar relaciones de una importación conserva su icono: abre un diálogo de casillas, no el grafo.
- Ejecutar y guardar: el editor de workflows y la tarjeta de workflow usaban `play_arrow_rounded` y `check_rounded`; pasan a `play_arrow` y `check`, los mismos que Centinel, el formulario de agente y el editor de orquestaciones. Añadir nodo, copiar salida y los estados de los nodos del lienzo dejan también la variante redondeada.
- Compositores de chat: el del constructor enviaba con una flecha y detenía con `stop_rounded`; ahora usa `send` y `stop` como el chat de agentes. Afecta a los constructores de agentes y de skills, que comparten el panel.
- Menor: cierre del menú lateral, enlace «Acerca de» del pie, preferencias (`tune`) y sincronizar pack (`sync`) adoptan la variante que ya usaba el resto de la aplicación.
- Comprobado sin cambios: editar (`edit_outlined`, 18 usos), eliminar (`delete_outline`, 31), compartir con grupo (`group_add_outlined`, 11) y exportar (`ios_share_outlined`) ya eran uniformes; no se han movido al mapa central porque no había variantes que resolver. El aviso de instalación en iOS conserva `ios_share` porque reproduce el botón real del sistema.
- Fuera de alcance: las familias `_rounded` que siguen en uso —campana, cerrar sesión, avisos, flechas de plegado— son un icono por función y se conservan. Los interruptores de contraseña usan `visibility` relleno y no se igualan al `visibility_outlined` de previsualizar: son funciones distintas. Centinel detiene con `stop_circle_outlined`, coherente entre sus tres pestañas y con el indicador de mensaje interrumpido.
- Guardia: `test/iconos_por_funcion_test.dart` recorre `lib/` y falla si reaparece cualquiera de las variantes retiradas, indicando la canónica de esa función.
- Validación: análisis sin incidencias; 734 pruebas pasadas y una omitida, contando la guardia nueva; cuatro tests que buscaban los iconos retirados por nombre pasan a buscar los unificados. Build web release correcto: `main.dart.js` de 5.415.341 bytes, dentro del presupuesto. Salvo `AppIcons.graph`, estos iconos no dependen de `kIsWeb`, así que la suite de VM sí los pinta; no se ha hecho revisión visual específica de esta tanda.

### Tercera tanda: Perfil, logs y orquestaciones

- Perfil: las secciones de cuenta ocupan dos columnas en web cuando el ancho local y el tamaño del texto lo permiten, con máximo de 1280 px. En ventana estrecha vuelven a una columna. La composición nativa conserva su orden y separación. Revisado a 1600 × 1000 y 360 × 800 con datos ficticios.
- Logs: sustituida la rejilla web de altura fija por la colección compartida con altura según contenido. Los indicadores quedan en el pie. La rejilla nativa conserva sus medidas. Revisado a 1280 × 800 con contadores largos.
- Editor de orquestaciones LLM: utiliza el ancho disponible dentro de la página, descontando el menú, y la escala del texto para decidir las columnas. El panel de configuración web adapta su ancho entre 360 y 480 px.
- Explorar y Administración: sus acciones de abrir grafo utilizan el mismo `AppIcons.graph` que las colecciones privadas.
- Validación: 733 pruebas pasadas, una omitida y análisis sin incidencias. La verificación visual del editor con múltiples candidatas y del perfil con otros permisos sigue pendiente.
- Logs comprobados también con texto al 200 %: los contadores largos envuelven y las tarjetas crecen sin recortes. Build release correcto; `main.dart.js` de 5.415.667 bytes, dentro del presupuesto.

### Pendientes vigentes

Las barras principales, los márgenes de pestañas, los pies de las tarjetas privadas, la iconografía de acciones, los diálogos con medidas literales, las tablas anchas y el teclado en login y diálogos y el salto al contenido ya están migrados. Lo que queda es validar y ajustar estados concretos, no volver a aplicar esos cambios:

1. Constructor: streaming, detener, borrador, error y regreso desde revisión con un servicio real; teclado y ampliación de texto con mensajes extensos.
2. Editores: varias candidatas, errores de validación y transiciones de tamaño conservando el foco. No se han ejecutado workflows reales.
3. Administración: datos representativos en tablas, Centinel y revisión de importaciones, incluidos diálogos de detalle. Sus anchos fijos se conservan cuando los padres ya los limitan.
4. Perfil: estados con cambios sin guardar, nombres largos, sesiones, grupos y errores de guardado. No se modificaron cuentas reales.
5. Acceso, recuperación y checkout: validar servicios y estados reales o de sandbox. Sus anchos de lectura pequeños son deliberados; no se ensanchan sólo por ser web.

Las tablas de inventario anteriores conservan la evidencia inicial; las tandas de esta sección registran las correcciones posteriores y este listado es la referencia de pendientes actual.

### Segunda tanda: corrección de Etiquetas y continuidad

- Reproducido un overflow al expandir un grupo dentro de una fila de altura compartida. El catálogo ahora utiliza alturas independientes (`alignRows: false`) y conserva la animación existente. El resto de colecciones mantiene su distribución alineada. Verificado en navegador desplegando Propiedad; prueba de regresión de apertura y cierre añadida.
- Imágenes de Conocimiento adopta padding web de 16 px, cuerpo común y acciones adaptables. Los permisos de sólo lectura se conservan.
- El botón compartido de grafo utiliza un icono web centralizado (`AppIcons.graph`), diferenciándolo de la navegación de orquestaciones.
- Editor de workflows: el inspector web ocupa el 30 % del ancho, entre 320 y 400 px; la decisión de usar columnas tiene en cuenta la escala de texto. La distribución nativa conserva sus medidas.
- Validación: análisis sin incidencias y suite completa con 733 pruebas pasadas y una omitida. Imágenes y editor necesitan todavía una comprobación visual de todos sus estados; estas pruebas no sustituyen los casos de servicios reales.
- Etiquetas verificada también a 360 × 800 con Propiedad expandida. Build web release correcto: `main.dart.js` de 5.415.152 bytes, dentro del presupuesto.

### Primera tanda aplicada

- Gestor: barra de recursos común, creación con etiqueta y contador integrado; variante nativa conservada.
- Etiquetas y Perfil: margen web de pestañas igual al de Conocimiento y Administración. Etiquetas pasa a pestañas desplazables en web para admitir texto ampliado.
- Skills, prompts, tools, documentos, packs y memoria: cuerpo compartido, padding web de 16 px y acciones inferiores alineadas, con salto de línea cuando falta espacio. Las tarjetas de etiquetas no tienen un pie de acciones equivalente; no se ha forzado esa composición. Imágenes mantiene su variante y queda pendiente.
- Formulario de agente, pestaña Conexión: ajustes agrupados en un panel web de hasta 760 px para limitar el ancho del selector y del slider.
- Chat constructor de agentes y skills: compacidad según ancho/alto local; borrador y error web comparten una zona desplazable limitada al 32 % del panel para reservar espacio a conversación y compositor.
- Documentación: añadida la página equivalente en inglés, requerida por los tests del repositorio.

Comprobación de esta tanda: análisis sin incidencias. La suite terminó con 731 pruebas correctas, una omitida y un fallo por la página inglesa que faltaba; después de añadirla pasaron las cuatro pruebas de documentación. Revisión manual con datos ficticios: skills a 1439 × 900 y prompts a 768 × 800. Esto no valida todavía streaming real, todos los roles, todos los diálogos ni el resto de estados de la tabla anterior.

Las prioridades siguientes describen el alcance total: los puntos anteriores ya están implementados; sus casos de datos reales y las excepciones indicadas siguen abiertos.

También comprobadas las tarjetas de herramientas a 360 × 800 y 1440 × 900: barra y acciones accesibles, sin overflow visible. Compilación release de esta tanda correcta; `main.dart.js` ocupa 5.407.395 bytes y sigue dentro del presupuesto de 5.500.000.

Formulario Conexión comprobado a 1440 × 900: selector y slider quedan dentro del panel compacto. La superficie inferior de la pestaña sigue libre; esta tanda limita el recorrido de los controles, no rediseña las cuatro pestañas en una sola pantalla.

1. **P1 — Uso real del constructor:** probar envío, detener, streaming, revisión y vuelta; incluir error largo, borrador largo y poca altura. La apariencia inicial ya está ajustada, pero no acredita el flujo de IA completo.
2. **P1 — Menús secundarios:** adoptar la misma barra en Gestor y el mismo margen de pestañas en Etiquetas, Perfil y administración. Mantener diferencias de permisos.
3. **P1 — Pies de tarjetas:** extender `ResourceCardBody` y `ResourceCardActions` a skills, prompts, tools, packs, memoria y etiquetas, verificando cada conjunto de acciones.
4. **P2 — Editores y diálogos densos:** validar inspectores, tablas, importaciones y paneles con medidas fijas. Sustituir una medida sólo cuando las restricciones del padre no garanticen adaptación.
5. **P2 — Iconografía restante:** eliminar variantes del mismo significado en acciones internas; un icono para editar, otro para grafo, otro para compartir. El mapa central ya cubre navegación y algunos recursos.
6. **P2 — Teclado y estados:** recorrer menús, dropdowns y pestañas con Tab; verificar foco visible, Escape y retorno de foco. Contrastar estados disabled, loading, error y vacío.

## Criterios de aceptación

- Revisar 360, 768, 1024, 1440 y 1920 px, más una ventana de 600 px de alto; temas claro y oscuro, español e inglés y texto al 200 %.
- Ningún overflow, botón inaccesible ni scroll horizontal de página. Tablas y lienzos pueden tener scroll propio deliberado.
- Menú principal estable al navegar; mismo orden de acciones equivalentes.
- Campo y foco conservados al redimensionar, sin duplicar el Navigator ni desmontar el contenido.
- Listas largas construidas de forma diferida; última fila no estirada artificialmente.
- Pruebas nativas sin regresiones y build web dentro del presupuesto de tamaño del proyecto.
- Cerrar cada pendiente con evidencia visual del estado afectado; no dar por validada una pantalla sólo porque comparte tema.

## Reproducción de las comprobaciones

Resultado final de esta revisión: análisis sin incidencias; 732 pruebas pasadas y una omitida; compilación web release correcta. `main.dart.js`: 5.406.810 bytes, por debajo del límite de 5.500.000. La compilación no sustituye las comprobaciones visuales pendientes ni acredita la ejecución en Wasm.

Desde `app_flutter`:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-web-resources-cdn
```

La previsualización local emplea `.dart_tool/ui_preview.dart`, una fixture temporal ignorada por Git con clientes y sesión ficticios. No forma parte del producto ni certifica la conexión con servicios reales. Los tests portables adicionales se encuentran en `test/web/`.
