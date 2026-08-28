// Service worker de notificaciones push.
//
// Va aparte del que genera Flutter (`flutter_service_worker.js`) y con un
// ámbito más estrecho —`push-sw/`, una ruta que no existe— a propósito: dos
// service workers no pueden controlar el mismo ámbito, y el de Flutter ya
// ocupa `/app/` con su caché offline. Registrar el nuestro ahí lo sustituiría
// y la aplicación perdería la carga sin red.
//
// No controlar ninguna página no impide recibir push: los eventos `push` no
// dependen del ámbito. Y para mirar si la aplicación está abierta usamos
// `includeUncontrolled`, que devuelve las ventanas del origen aunque este
// worker no las controle.
//
// Los textos viven aquí y no en el servidor porque el payload viaja con el
// tipo y los datos en crudo: así el aviso sale en el idioma del navegador que
// lo recibe, no en el que tuviera el servidor al mandarlo.

const TEXTOS = {
  es: {
    group_invite: '{actor} te ha invitado al grupo {group}',
    group_member_added: '{actor} te ha añadido al grupo {group}',
    group_member_removed: '{actor} te ha sacado del grupo {group}',
    group_role_changed: 'Ahora eres {role} en el grupo {group}',
    group_ownership_received: '{actor} te ha traspasado el grupo {group}',
    license_assigned: '{actor} te ha asignado una licencia',
    _titulo: 'iAgents Hub',
    _generico: 'Tienes un aviso nuevo',
  },
  en: {
    group_invite: '{actor} invited you to the group {group}',
    group_member_added: '{actor} added you to the group {group}',
    group_member_removed: '{actor} removed you from the group {group}',
    group_role_changed: 'You are now {role} in the group {group}',
    group_ownership_received: '{actor} transferred the group {group} to you',
    license_assigned: '{actor} assigned you a licence',
    _titulo: 'iAgents Hub',
    _generico: 'You have a new notification',
  },
};

// A dónde lleva el aviso al pulsarlo. El mismo criterio que en la aplicación:
// la invitación se resuelve en la campana, así que aterriza en el escritorio.
const DESTINOS = {
  group_invite: '/app/dashboard',
  license_assigned: '/app/profile',
};
const DESTINO_POR_DEFECTO = '/app/manager';

function idioma() {
  const codigo = (self.navigator && self.navigator.language) || 'es';
  return codigo.toLowerCase().startsWith('en') ? 'en' : 'es';
}

function texto(kind, datos) {
  const bundle = TEXTOS[idioma()];
  let plantilla = bundle[kind];
  if (!plantilla) return bundle._generico;
  for (const [clave, valor] of Object.entries(datos || {})) {
    plantilla = plantilla.split('{' + clave + '}').join(String(valor));
  }
  return plantilla;
}

// ¿Está el usuario mirando la aplicación ahora mismo?
//
// Si lo está, no se le interrumpe con una notificación del sistema: la campana
// se actualiza sola en menos de un minuto y verá el contador subir. Avisar por
// duplicado de algo que ya tienes delante es lo que hace que una aplicación
// canse. Es lo mismo que hace WhatsApp Web.
async function aplicacionVisible() {
  const ventanas = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  return ventanas.some(
    (v) => v.visibilityState === 'visible' && v.focused,
  );
}

self.addEventListener('push', (evento) => {
  evento.waitUntil(
    (async () => {
      let aviso = {};
      try {
        aviso = evento.data ? evento.data.json() : {};
      } catch (_) {
        // Un payload ilegible no debe dejar al usuario sin aviso: sale el
        // texto genérico y al abrir la aplicación verá de qué se trata.
      }
      if (await aplicacionVisible()) return;

      const kind = aviso.kind || '';
      const bundle = TEXTOS[idioma()];
      await self.registration.showNotification(bundle._titulo, {
        body: texto(kind, aviso.data),
        icon: '/app/icons/Icon-192.png',
        badge: '/app/icons/Icon-192.png',
        // Agrupa por tipo: cinco invitaciones seguidas dejan un aviso, no
        // cinco apilados. El `renotify` hace que la última sí vibre.
        tag: 'iagents-' + (kind || 'aviso'),
        renotify: true,
        data: { url: DESTINOS[kind] || DESTINO_POR_DEFECTO },
      });
    })(),
  );
});

self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const destino = (evento.notification.data && evento.notification.data.url)
    || DESTINO_POR_DEFECTO;

  evento.waitUntil(
    (async () => {
      const ventanas = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      // Reutilizar la pestaña abierta en vez de abrir otra: el usuario que ya
      // tiene la aplicación no quiere una segunda copia por cada aviso.
      for (const ventana of ventanas) {
        if (ventana.url.includes('/app/')) {
          await ventana.focus();
          if ('navigate' in ventana) {
            try {
              await ventana.navigate(destino);
            } catch (_) {
              // Algunos navegadores no permiten navegar un cliente ajeno.
              // Quedarse con el foco ya deja al usuario en la aplicación.
            }
          }
          return;
        }
      }
      await self.clients.openWindow(destino);
    })(),
  );
});
