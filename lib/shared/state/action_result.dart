/// Mensaje que una acción de controller quiere mostrar al usuario.
///
/// Los controllers no pueden llamar a `showMessage` porque el SnackBar
/// necesita un `BuildContext` y ellos no lo tienen: devuelven este resultado
/// y la página decide cómo presentarlo. `null` significa "no hay nada que
/// decir" (la acción terminó bien y en silencio, o se abortó sin sesión).
class ActionResult {
  const ActionResult(this.message, {this.isError = false});

  const ActionResult.error(this.message) : isError = true;

  final String message;
  final bool isError;
}
