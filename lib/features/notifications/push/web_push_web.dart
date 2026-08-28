/// Implementación web: registra el service worker, pide permiso y suscribe.
///
/// El ámbito del registro es `push-sw/` y no `/app/` a propósito. El de Flutter
/// ya ocupa `/app/` con su caché offline, y dos service workers no pueden
/// controlar el mismo ámbito: registrar el nuestro ahí lo sustituiría y la
/// aplicación dejaría de cargar sin red. Un ámbito que no controla ninguna
/// página sigue recibiendo los eventos `push` igual.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_push_stub.dart' show PushEstado;

export 'web_push_stub.dart' show PushEstado;

/// Ruta del worker relativa a `<base href="/app/">`.
const _rutaWorker = 'push_sw.js';

/// Ámbito estrecho para no pisar al service worker de Flutter.
const _ambito = 'push-sw/';

class WebPush {
  const WebPush();

  bool get soportado =>
      web.window.hasProperty('PushManager'.toJS).toDart &&
      (web.window.navigator as JSObject).hasProperty('serviceWorker'.toJS).toDart;

  bool get concedido => _permiso() == 'granted';

  Future<PushEstado> estado() async {
    if (!soportado) return PushEstado.noSoportado;
    switch (_permiso()) {
      case 'denied':
        return PushEstado.denegado;
      case 'granted':
        final registro = await _registroExistente();
        final suscripcion = registro == null
            ? null
            : await registro.pushManager.getSubscription().toDart;
        return suscripcion == null ? PushEstado.disponible : PushEstado.activo;
      default:
        return PushEstado.disponible;
    }
  }

  /// Pide permiso y se suscribe. **Debe llamarse desde un gesto del usuario.**
  ///
  /// Los navegadores rechazan —y penalizan— la petición de permiso que llega
  /// sin que nadie haya pulsado nada. Por eso esto cuelga de un interruptor y
  /// no del arranque de la aplicación.
  Future<PushEstado> activar(String clavePublicaVapid) async {
    if (!soportado || clavePublicaVapid.isEmpty) return PushEstado.noSoportado;

    final permiso = await web.Notification.requestPermission().toDart;
    if (permiso.toDart != 'granted') return PushEstado.denegado;

    final registro = await web.window.navigator.serviceWorker
        .register(
          _rutaWorker.toJS,
          web.RegistrationOptions(scope: _ambito),
        )
        .toDart;

    final suscripcion = await registro.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey:
                Uint8List.fromList(_claveABytes(clavePublicaVapid)).toJS,
          ),
        )
        .toDart;

    _ultimaSuscripcion = suscripcion;
    return PushEstado.activo;
  }

  /// Cancela la suscripción del navegador y devuelve su endpoint.
  ///
  /// El endpoint hace falta para que el backend borre la fila: es la clave con
  /// la que se guardó. Devolver `null` significa que no había nada suscrito.
  Future<String?> desactivar() async {
    if (!soportado) return null;
    final registro = await _registroExistente();
    if (registro == null) return null;
    final suscripcion = await registro.pushManager.getSubscription().toDart;
    if (suscripcion == null) return null;
    final endpoint = suscripcion.endpoint;
    await suscripcion.unsubscribe().toDart;
    _ultimaSuscripcion = null;
    return endpoint;
  }

  /// Los datos que el backend necesita para poder cifrar hacia este navegador.
  Future<Map<String, String>?> datosDeSuscripcion() async {
    final suscripcion = _ultimaSuscripcion ?? await _suscripcionActual();
    if (suscripcion == null) return null;
    return {
      'endpoint': suscripcion.endpoint,
      'p256dh': _clave(suscripcion, 'p256dh'),
      'auth': _clave(suscripcion, 'auth'),
    };
  }

  Future<web.PushSubscription?> _suscripcionActual() async {
    final registro = await _registroExistente();
    if (registro == null) return null;
    return (await registro.pushManager.getSubscription().toDart);
  }

  /// En iPhone, Safari solo entrega push a una web **instalada** en la
  /// pantalla de inicio (iOS 16.4+). En una pestaña normal no hay `PushManager`
  /// y no hay forma de saltárselo: es una decisión de Apple. Cuando se da ese
  /// caso conviene explicar el paso que falta en vez de esconder el interruptor
  /// sin más, que es lo que deja al usuario pensando que la función no existe.
  bool get requiereInstalarEnIOS {
    if (soportado) return false;
    final agente = web.window.navigator.userAgent.toLowerCase();
    final esIOS = agente.contains('iphone') ||
        agente.contains('ipad') ||
        agente.contains('ipod');
    return esIOS && !_instalada;
  }

  /// La aplicación corre desde la pantalla de inicio, no desde una pestaña.
  bool get _instalada {
    final consulta = web.window.matchMedia('(display-mode: standalone)');
    return consulta.matches;
  }

  Future<web.ServiceWorkerRegistration?> _registroExistente() async {
    final registro = await web.window.navigator.serviceWorker
        .getRegistration(_ambito)
        .toDart;
    return registro;
  }
}

web.PushSubscription? _ultimaSuscripcion;

String _permiso() => web.Notification.permission;

/// Las claves de cifrado llegan como ArrayBuffer y viajan en base64url.
String _clave(web.PushSubscription suscripcion, String nombre) {
  final buffer = suscripcion.getKey(nombre);
  if (buffer == null) return '';
  final bytes = buffer.toDart.asUint8List();
  return _base64Url(bytes);
}

/// base64url sin relleno, que es como viajan las claves del protocolo.
///
/// `base64Url` de `dart:convert` ya hace la codificación; lo único que hay que
/// quitarle es el relleno, que RFC 7515 omite y el backend no espera.
String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// La clave VAPID viaja en base64url y `applicationServerKey` la quiere en
/// bytes crudos. El relleno se repone porque `base64Url.decode` lo exige.
List<int> _claveABytes(String clave) {
  final limpia = clave.replaceAll('=', '');
  final relleno = '=' * ((4 - limpia.length % 4) % 4);
  return base64Url.decode(limpia + relleno);
}
