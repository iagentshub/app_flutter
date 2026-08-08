<div align="center">
  <a href="index.md">← Índice</a> &nbsp;·&nbsp;
  <a href="../en/screens.md">🇬🇧 Read in English</a>
</div>

<br>

# Pantallas

La app cubre las mismas secciones que la web. Cada una vive en su propia dirección, igual que en el navegador.

---

## Públicas

Accesibles sin cuenta.

| Pantalla | Dirección | Qué hace |
|---|---|---|
| Portada | `/` | Presentación de la plataforma |
| Sobre el proyecto | `/about` | Qué es iAgentsHub |
| Documentación | `/docs` | Guías de uso |
| Precios | `/pricing` | Planes disponibles |
| Soporte | `/support` | Canales de ayuda |
| Perfil público | `/u/<usuario>` | Ficha pública de una persona |
| Pago | `/checkout` | Contratación de un plan |

Cada una tiene su gemela en inglés con el prefijo `/en`.

---

## Acceso

| Pantalla | Dirección | Qué hace |
|---|---|---|
| Entrar | `/login` | Acceso con cuenta, como invitado, o con GitHub (si el servidor tiene configurada la OAuth App) |
| Registro | `/register` | Alta de cuenta nueva |
| Olvidé mi contraseña | `/forgot-password` | Solicitud de recuperación |
| Nueva contraseña | `/reset-password` | Cambio con el enlace recibido |
| Verificación | `/verify` | Confirmación de la cuenta |
| Servidor | `/backend` | Elección del servidor al que conectarse |
| Enlace con VS Code | `/vscode-auth` | Autorización de la extensión de VS Code |

---

## Con sesión

| Pantalla | Dirección | Qué hace |
|---|---|---|
| Panel | `/dashboard` | Vista de inicio, con bloques reordenables |
| Agentes | `/agents` | Crear, editar y conversar con agentes |
| Orquestaciones | `/orchestrations` | Encadenar agentes en un flujo, con editor visual |
| Conexiones | `/connections` | Credenciales de IA, máquinas y bases de datos, y pestaña Proveedores para vincular cuentas externas (Anthropic, OpenAI, GitHub Copilot, Ollama, NVIDIA, Google) y elegir qué modelos traer; para Ollama se pueden descubrir modelos en vivo, y las conexiones de tipo iAgents Hub se pueden sincronizar con el hub remoto |
| Memoria | `/memory` | Lo que los agentes recuerdan |
| Conocimiento | `/knowledge` | Documentos y habilidades que los agentes consultan |
| Explorar | `/explore` | Recursos compartidos por la comunidad, con filtros de tipo, categoría, idioma y labels |
| Etiquetas | `/labels` | Catálogo plegable y búsqueda de labels de los recursos propios mediante la barra y el diálogo de filtros comunes, incluido el idioma del contenido |
| Gestión | `/manager` | Espacios de trabajo, grupos e invitaciones |
| Perfil | `/profile` | Cuenta, preferencias e idioma |

El panel permite reordenar sus bloques: al activar el modo edición, la disposición se guarda en la cuenta y viaja con el usuario a cualquier dispositivo.

Los agentes tienen su propia vista de conversación, disponible cuando el agente tiene una conexión asignada.

Los recursos textuales admiten uno o varios idiomas opcionales. El selector
compacto multiselección está disponible al editar agentes, skills, prompts,
textos, URLs o documentos de Knowledge y workflows. No seleccionar ninguno
significa que el idioma no aplica o no se ha declarado. Las herramientas
mantienen separado su lenguaje de programación (Python, Shell o C++) del idioma
del contenido. Explorar y Etiquetas reutilizan el desplegable de tipos de Admin
y muestran los filtros múltiples en desplegables en vez de filas de botones.

---

## Administración

Visibles solo para cuentas con rol de administrador.

| Pantalla | Dirección | Qué hace |
|---|---|---|
| Administración | `/admin` | Usuarios, recursos y propiedad de los mismos |
| Metadatos | `/admin/metadata` | Catálogos de la plataforma |
| Centinela | `/admin/centinel` | Vigilancia y pruebas de carga |
| Registros | `/admin/logs` | Actividad del sistema |
