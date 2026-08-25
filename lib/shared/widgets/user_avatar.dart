import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

/// Foto de perfil de un usuario, con su inicial de respaldo.
///
/// Existe porque el mismo bloque —`ClipOval` sobre un `Image` con
/// `ResizeImage`, `errorBuilder` y `frameBuilder`— estaba escrito a mano en
/// tres pantallas, cada una con su propio círculo de iniciales. Y no era solo
/// repetición: **dos pasaban al cliente una ruta relativa y la tercera una URL
/// absoluta**, que `ApiClient.authenticatedImage` volvía a prefijar. Esa
/// pantalla pedía `http://host/http://host/api/…`, recibía un 404 y caía al
/// respaldo sin decir nada, así que su avatar no se vio nunca. Con un solo
/// sitio que construya la imagen, esa divergencia no se puede escribir.
///
/// [avatarUrl] es la ruta **relativa** que da el backend (`/api/users/…`), o
/// `null` cuando no hay foto. Lleva dentro la versión del contenido, así que
/// cambiar la foto cambia la URL y la caché del navegador se entera sola.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.username,
    required this.avatarUrl,
    required this.apiClient,
    required this.size,
    this.gaToken,
    super.key,
  });

  final String username;
  final String? avatarUrl;
  final ApiClient apiClient;
  final double size;
  final String? gaToken;

  String get _initial {
    final limpio = username.trim();
    return limpio.isEmpty ? '?' : limpio[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null || url.isEmpty) return _fallback(context);

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image(
          // El avatar subido puede pesar lo que el administrador permita —por
          // defecto, lo que sea—; decodificar al doble del tamaño en pantalla
          // evita mantener un bitmap gigante en memoria para un círculo
          // pequeño. El factor 2 cubre las pantallas de alta densidad.
          image: ResizeImage(
            apiClient.authenticatedImage(url, gaToken: gaToken),
            width: (size * 2).round(),
            height: (size * 2).round(),
          ),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _fallback(context),
          frameBuilder: (context, child, frame, _) =>
              frame == null ? _fallback(context) : child,
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircleAvatar(
        radius: size / 2,
        child: Text(
          _initial,
          style: TextStyle(
            // Proporcional al círculo: los tres sitios que esto reemplaza
            // fijaban un tamaño distinto para el mismo componente.
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
