import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cambia el icono del launcher en plataformas que ofrecen iconos alternativos.
/// En web y escritorio conserva la preferencia, pero no intenta modificar el
/// icono instalado porque esos sistemas no exponen una API equivalente.
class NativeAppIconService {
  NativeAppIconService._();

  static const channelName = 'com.iagentshub.app/app_icon';
  static const _channel = MethodChannel(channelName);

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<bool> setIcon(String? iconName, String assetPath) async {
    if (!isSupportedPlatform) return false;
    try {
      await _channel.invokeMethod<void>('setIcon', {
        'name': iconName,
        'assetPath': assetPath,
      });
      return true;
    } on MissingPluginException {
      // Los widget tests y plataformas aún no configuradas mantienen la
      // preferencia local sin fallar.
      return false;
    } on PlatformException catch (error) {
      debugPrint('No se pudo cambiar el icono nativo: ${error.message}');
      return false;
    }
  }
}
