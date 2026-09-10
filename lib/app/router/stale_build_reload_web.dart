import 'package:web/web.dart' as web;

/// Recarga la página la primera vez que falla la parte [name] en esta pestaña
/// y devuelve `true`. La segunda vez devuelve `false`: si tras recargar sigue
/// fallando, el problema no es un bundle viejo y toca enseñar el error.
///
/// La marca vive en `sessionStorage` porque tiene que sobrevivir a la propia
/// recarga y morir con la pestaña.
bool reloadOnceForStaleBuild(String name) {
  final key = 'deferred_reload.$name';
  final storage = web.window.sessionStorage;
  if (storage.getItem(key) != null) {
    storage.removeItem(key);
    return false;
  }
  storage.setItem(key, '1');
  web.window.location.reload();
  return true;
}
