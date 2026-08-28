import 'package:web/web.dart' as web;

/// El origen desde el que se sirve la aplicación.
String? get pageOrigin => web.window.location.origin;
