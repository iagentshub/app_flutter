import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/state/session_controller.dart';
import '../../manager/repositories/manager_repository.dart';
import '../push/web_push.dart';
import '../repositories/notifications_repository.dart';

/// Estado de la campana: qué avisos hay, cuántos sin leer y qué se puede hacer
/// con ellos.
///
/// Lo instancia el `AppShell` una sola vez y lo comparten las dos barras
/// superiores —la ancha y la del layout estrecho—, que son montajes distintos.
///
/// Aceptar y rechazar delegan en [ManagerRepository]: esos dos endpoints ya
/// existían para la pestaña de grupos del perfil y no se duplican aquí.
class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required this._repository,
    required this._manager,
    required this._session,
  });

  final NotificationsRepository _repository;
  final ManagerRepository _manager;
  final SessionController _session;

  bool _disposed = false;
  List<Map<String, dynamic>> _items = const [];
  int _unread = 0;

  final WebPush _push = const WebPush();
  Map<String, Map<String, bool>> _categorias = const {};
  bool _correoGeneral = true;
  PushEstado _estadoPush = PushEstado.noSoportado;
  String _clavePush = '';

  List<Map<String, dynamic>> get items => _items;
  int get unread => _unread;

  PushEstado get estadoPush => _estadoPush;

  /// Categorías publicadas por el servidor, con su estado por canal.
  Map<String, Map<String, bool>> get categorias => _categorias;

  bool get correoGeneral => _correoGeneral;

  /// Hay algo que ofrecer: el navegador sabe y la instalación tiene claves.
  bool get puedeOfrecerPush =>
      _estadoPush != PushEstado.noSoportado && _clavePush.isNotEmpty;

  /// iPhone sin instalar: el push existe, pero no en una pestaña suelta.
  bool get requiereInstalarEnIOS => _push.requiereInstalarEnIOS;

  String? get _token => _session.gaToken;

  /// El invitado no tiene avisos: `/api/notifications` usa `require_auth` y le
  /// responde 403. Se oculta aquí, en el cliente, que es donde este repo
  /// resuelve lo que un invitado no puede usar — nunca abriendo el endpoint.
  bool get enabled => _session.user?.role != 'guest';

  /// Recarga la lista. **No propaga nunca.**
  ///
  /// La llama un `Timer.periodic` del shell, así que un backend caído —o uno
  /// anterior a estas rutas, que responde 404— no puede tumbar el layout
  /// entero de la aplicación. En ese caso se queda con lo último que tenía.
  Future<void> load() async {
    final token = _token;
    if (token == null || !enabled) return;
    try {
      final data = await _repository.list(token);
      _items = data.items;
      _unread = data.unread;
      _notify();
    } catch (_) {
      // Silencio deliberado: la campana es accesoria, no puede romper nada.
    }
  }

  Future<void> markRead(String id) async {
    final token = _token;
    if (token == null) return;
    try {
      _unread = await _repository.markRead(token, id: id);
      _items = [
        for (final item in _items)
          if (item['id'] == id) {...item, 'read': true} else item,
      ];
      _notify();
    } catch (_) {
      // Igual que en load(): marcar leído no vale un error en pantalla.
    }
  }

  Future<void> markAllRead() async {
    final token = _token;
    if (token == null) return;
    try {
      _unread = await _repository.markRead(token);
      _items = [
        for (final item in _items) {...item, 'read': true},
      ];
      _notify();
    } catch (_) {}
  }

  Future<void> accept(String notificationId, String invitationId) =>
      _responder(notificationId, () => _manager.acceptInvitation(_token!, invitationId));

  Future<void> reject(String notificationId, String invitationId) =>
      _responder(notificationId, () => _manager.rejectInvitation(_token!, invitationId));

  /// Responde a una invitación y deja el aviso leído pase lo que pase.
  ///
  /// Un 404 significa que la invitación se canceló entre el sondeo y el clic.
  /// Marcarla leída igualmente es lo correcto: dejarla ahí sería un botón que
  /// ya no lleva a ninguna parte, y volver a pulsarlo daría el mismo error.
  Future<void> _responder(
    String notificationId,
    Future<void> Function() accion,
  ) async {
    if (_token == null) return;
    try {
      await accion();
    } on ApiError catch (error) {
      if (error.statusCode != 404) rethrow;
    }
    await markRead(notificationId);
    await load();
  }

  // ── Preferencias ────────────────────────────────────────────────────────

  Future<void> cargarPreferencias() async {
    final token = _token;
    if (token == null || !enabled) return;
    try {
      final prefs = await _repository.preferences(token);
      _categorias = prefs.categorias;
      _correoGeneral = prefs.email;
      _notify();
    } catch (_) {
      // Sin preferencias legibles la pantalla no se abre; nada más se rompe.
    }
  }

  /// Cambia un interruptor y se queda con lo que devuelva el servidor.
  ///
  /// No se pinta el valor optimista: el backend fusiona y puede corregir —una
  /// categoría que ya no existe se descarta—, y enseñar un estado que el
  /// servidor no tiene es peor que esperar cien milisegundos.
  Future<void> cambiarCategoria(
    String categoria,
    String canal,
    bool valor,
  ) async {
    final token = _token;
    if (token == null) return;
    try {
      _categorias = await _repository.setCategory(
        token,
        categoria: categoria,
        canal: canal,
        valor: valor,
      );
      _notify();
    } catch (_) {}
  }

  // ── Push ────────────────────────────────────────────────────────────────

  /// Averigua si este navegador puede recibir push y si ya lo hace.
  ///
  /// No pide permiso: solo mira. Preguntar sin que el usuario haya pulsado
  /// nada es lo que hace que los navegadores penalicen al sitio, y además
  /// gasta la única oportunidad de preguntar que hay.
  Future<void> cargarEstadoPush() async {
    final token = _token;
    if (token == null || !enabled) return;
    try {
      _estadoPush = await _push.estado();
      if (_estadoPush != PushEstado.noSoportado) {
        _clavePush = await _repository.pushKey(token);
      }
      _notify();
    } catch (_) {
      _estadoPush = PushEstado.noSoportado;
    }
  }

  /// Activa el push en este navegador. **Solo desde un gesto del usuario.**
  ///
  /// Devuelve el estado en que queda, que la pantalla usa para explicar el
  /// «denegado»: a partir de ahí el navegador no vuelve a preguntar y hay que
  /// cambiarlo a mano desde el candado de la barra de direcciones.
  Future<PushEstado> activarPush() async {
    final token = _token;
    if (token == null || _clavePush.isEmpty) return PushEstado.noSoportado;
    try {
      _estadoPush = await _push.activar(_clavePush);
      if (_estadoPush == PushEstado.activo) {
        final datos = await _push.datosDeSuscripcion();
        if (datos != null) {
          await _repository.subscribePush(token, datos);
        }
      }
    } catch (_) {
      // Un fallo al suscribir deja el permiso concedido pero sin destino: se
      // refleja como «disponible» para que el usuario pueda reintentarlo.
      _estadoPush = PushEstado.disponible;
    }
    _notify();
    return _estadoPush;
  }

  /// Baja de este navegador. Los demás dispositivos siguen recibiendo.
  Future<void> desactivarPush() async {
    final token = _token;
    if (token == null) return;
    try {
      final endpoint = await _push.desactivar();
      if (endpoint != null) {
        await _repository.unsubscribePush(token, endpoint);
      }
      _estadoPush = PushEstado.disponible;
    } catch (_) {
      // Si la baja remota falla, el backend lo descubrirá en el primer envío:
      // el servicio push responde 410 y la fila se borra sola.
    }
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
