<div align="center">
  <a href="index.md">← Índice</a> &nbsp;·&nbsp;
  <a href="../en/api.md">🇬🇧 Read in English</a>
</div>

<br>

# Conexión con el backend

---

## Qué servidor usa

La app no está atada a un servidor. Trae uno de fábrica —`www.iagentshub.com`— y permite añadir otros a mano desde la pantalla de servidor, indicando un nombre y una dirección. Es lo que hace posible usar la app contra una instalación propia de iAgentsHub sin recompilarla.

Los servidores de fábrica no se pueden borrar de la lista; los añadidos por el usuario sí. La elección se guarda en el dispositivo y sobrevive al cierre de la app.

---

## Comprobación de disponibilidad

Antes de guardar un servidor nuevo se puede comprobar si responde. La lista de servidores además se revisa periódicamente, de modo que el usuario ve cuál está accesible sin tener que probar entrando.

La app distingue dos situaciones que se confunden con facilidad:

- **El servidor responde con un error** (credenciales inválidas, permiso denegado, recurso inexistente). Es una respuesta legítima y se muestra como el error concreto que sea.
- **El servidor no responde** (sin red, dirección equivocada, servicio caído). Solo este caso se reporta como problema de conexión.

Separarlas evita el fallo silencioso más típico: presentar un error de permisos como si fuera una caída del servidor, o al revés.

---

## Sesión

Al entrar, el backend devuelve un testigo de sesión que la app guarda en el dispositivo y adjunta a cada petición posterior. Es el mismo mecanismo que usa la web.

Si al iniciar sesión se desmarca «recordar», la sesión vive solo mientras la app esté abierta y, además, se borra cualquier sesión anterior guardada, para no reutilizarla por error. El acceso como invitado se comporta igual.

Cerrar sesión borra el testigo y el rastro cacheado de las consultas hechas con él.

---

## Qué pide al backend

La app consume la API pública de iAgentsHub. Por familias:

| Familia | Para qué |
|---|---|
| `auth`, `users`, `settings` | Acceso, cuenta y preferencias |
| `agents`, `chats` | Agentes y sus conversaciones |
| `workflows` | Orquestaciones |
| `connections` | Credenciales de IA, máquinas y bases de datos (incluye descubrir modelos Ollama y sincronizar con otro hub) |
| `accounts` | Cuentas de proveedor vinculadas (Anthropic, OpenAI, GitHub Copilot, Ollama, NVIDIA, Google): vincular, probar y sincronizar modelos como conexiones |
| `knowledge`, `skills`, `prompts`, `tools`, `resources` | Contenido reutilizable, Tools y sus versiones |
| `memory` | Memoria de los agentes |
| `workspaces`, `sharing` | Espacios de trabajo, grupos y compartición |
| `explore`, `feed` | Descubrimiento y actividad |
| `billing` | Planes y pagos |
| `admin` | Herramientas de administración |

En Tools, la app consume `tool_runtimes` desde la configuración pública del
servidor, no mantiene una lista local de lenguajes. Los binarios se descargan en
streaming y se verifica su SHA-256. El backend nunca ejecuta la Tool y la
ejecución automática local en Flutter sigue pendiente.

---

## Caché

Las consultas de listado se guardan en memoria durante un minuto: volver a una vista recién visitada no repite la petición. Es el mismo espíritu que el tiempo de frescura del frontend web.

Dos detalles importan:

- La entrada guardada va ligada a la sesión que la pidió. Cambiar de cuenta nunca sirve datos de la anterior.
- Cualquier operación que modifique un recurso invalida lo cacheado de ese recurso al instante, así que un cambio hecho desde la app se ve reflejado de inmediato.

La caché es solo de memoria: cerrar la app la vacía por completo.
