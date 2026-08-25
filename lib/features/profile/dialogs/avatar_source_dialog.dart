import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';

/// Qué hacer con la foto de perfil.
enum AvatarSource { camera, gallery, remove }

/// Imagen elegida, ya en memoria. El nombre solo se usa para el mensaje de
/// error: lo que se sube siempre es el JPEG que produce el compresor.
class PickedAvatar {
  const PickedAvatar(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;
}

/// Solo Android e iOS tienen una cámara que el sistema sepa abrir y una
/// galería distinta del explorador de archivos. En escritorio y en web las dos
/// opciones abrirían exactamente el mismo diálogo, así que preguntar sobra.
bool get _hayVariosOrigenes =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Si hace falta preguntar antes de abrir nada. Con foto puesta siempre, aunque
/// haya un solo origen: es donde vive «quitar la foto».
bool avatarNeedsSourceDialog({required bool canRemove}) =>
    _hayVariosOrigenes || canRemove;

/// Pregunta qué hacer. Devuelve `null` si el usuario cierra.
Future<AvatarSource?> showAvatarSourceDialog({
  required BuildContext context,
  required String Function(String) tx,
  required bool canRemove,
}) {
  return showAppDialog<AvatarSource>(
    context: context,
    builder: (context) {
      final opciones = <Widget>[
        if (_hayVariosOrigenes)
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tx('profile.avatar_source_camera')),
            onTap: () => Navigator.of(context).pop(AvatarSource.camera),
          ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(
            _hayVariosOrigenes
                ? tx('profile.avatar_source_gallery')
                : tx('profile.avatar_source_file'),
          ),
          onTap: () => Navigator.of(context).pop(AvatarSource.gallery),
        ),
        if (canRemove)
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              tx('profile.avatar_remove'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(AvatarSource.remove),
          ),
      ];

      return AlertDialog(
        title: Text(tx('profile.avatar_source_title')),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: dialogContentWidth(context, 320),
          child: Column(mainAxisSize: MainAxisSize.min, children: opciones),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tx('common.cancel')),
          ),
        ],
      );
    },
  );
}

/// Abre el selector nativo y devuelve los bytes. `null` si el usuario cancela.
///
/// La ruta de escritorio y web sigue siendo `file_picker`, que es lo que había:
/// filtra por extensión y devuelve los bytes de una vez. En móvil va por
/// `image_picker`, que es el único que abre la cámara y el que da acceso al
/// selector de fotos del sistema —el de archivos, en un móvil, obliga a
/// rebuscar en carpetas para encontrar una foto.
Future<PickedAvatar?> pickAvatarImage(AvatarSource? source) async {
  if (_hayVariosOrigenes && source != null && source != AvatarSource.remove) {
    final picked = await ImagePicker().pickImage(
      source: source == AvatarSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // El recorte y la compresión los hace el diálogo de ajuste; aquí solo se
      // acota lo que entra en memoria, que en un móvil moderno son 12 MP.
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;
    return PickedAvatar(await picked.readAsBytes(), picked.name);
  }

  final result = await FilePicker.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) return null;
  return PickedAvatar(bytes, file.name);
}
