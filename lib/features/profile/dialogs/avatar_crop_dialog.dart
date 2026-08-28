import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../utils/avatar_compressor.dart';

/// Lo que el usuario decidió en el diálogo de ajuste: cuántos cuartos de vuelta
/// y qué trozo de la imagen se queda. Se resuelve en el isolate del compresor,
/// no aquí: esta pantalla solo enseña una vista previa reducida.
class AvatarAdjustment {
  const AvatarAdjustment({required this.quarterTurns, required this.crop});

  final int quarterTurns;
  final AvatarCrop crop;
}

/// Ajuste del avatar antes de subirlo: arrastrar para encuadrar, pellizcar o
/// usar el deslizador para acercar, y girar en pasos de 90°.
///
/// Antes de existir, la imagen elegida se subía entera y el `ClipOval` de la
/// ficha se quedaba con el centro geométrico: una foto apaisada perdía la cara
/// por los lados y una hecha en vertical con el móvil salía tumbada.
///
/// Devuelve `null` si el usuario cancela.
Future<AvatarAdjustment?> showAvatarCropDialog({
  required BuildContext context,
  required Uint8List bytes,
  required String Function(String) tx,
}) {
  return showAppDialog<AvatarAdjustment>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AvatarCropDialog(bytes: bytes, tx: tx),
  );
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.bytes, required this.tx});

  final Uint8List bytes;
  final String Function(String) tx;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  /// Lado mayor de la vista previa. La imagen original puede tener 12 MP y
  /// aquí se pinta en un cuadrado de 300 px: decodificarla entera dejaría el
  /// bitmap completo en memoria del hilo de UI para nada.
  static const _maxPreviewSide = 1400;

  static const _maxZoom = 5.0;

  ui.Image? _preview;
  bool _failed = false;

  int _turns = 0;
  double _zoom = 1;
  Offset _offset = Offset.zero;

  double _gestureStartZoom = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _decodePreview();
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _decodePreview() async {
    // `ui.ImageDescriptor` leería el tamaño sin decodificar nada, que es justo
    // lo que quiere este método. Pero **en web `descriptor.width` lanza
    // `UnsupportedError`** —medido en Chrome—, así que el diálogo se quedaba en
    // negro con «no se pudo actualizar la foto» y sin ninguna pista: aquí no
    // falla el formato de la imagen, falla la API. `instantiateImageCodec` sí
    // está en las dos plataformas.
    //
    // El precio es decodificar una vez a tamaño completo para saber cuánto
    // mide. Solo se paga con imágenes grandes, y `image_picker` ya acota a
    // 2048 px lo que entra desde el móvil.
    ui.Image? completa;
    try {
      completa = (await (await ui.instantiateImageCodec(
        widget.bytes,
      )).getNextFrame()).image;

      final longest = completa.width > completa.height
          ? completa.width
          : completa.height;
      if (longest <= _maxPreviewSide) {
        if (!mounted) return;
        setState(() => _preview = completa);
        completa = null; // lo conserva el estado; no se libera aquí
        return;
      }

      final ratio = _maxPreviewSide / longest;
      final reducida = (await (await ui.instantiateImageCodec(
        widget.bytes,
        targetWidth: (completa.width * ratio).round(),
        targetHeight: (completa.height * ratio).round(),
      )).getNextFrame()).image;
      if (!mounted) {
        reducida.dispose();
        return;
      }
      setState(() => _preview = reducida);
    } catch (error) {
      // Se registra: con el aviso a secas, un formato que el códec no sabe leer
      // y una API que no existe en la plataforma se ven exactamente igual.
      debugPrint('Avatar: no se pudo decodificar la vista previa: $error');
      if (mounted) setState(() => _failed = true);
    } finally {
      completa?.dispose();
    }
  }

  /// Tamaño de la imagen **ya girada**, que es sobre el que se calcula todo.
  Size get _rotatedSize {
    final image = _preview!;
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    return _turns.isOdd ? Size(height, width) : Size(width, height);
  }

  /// Escala mínima para que la imagen cubra el cuadro: por debajo aparecerían
  /// bandas vacías dentro del avatar.
  double _coverScale(double viewport) {
    final size = _rotatedSize;
    final shortest = size.width < size.height ? size.width : size.height;
    return viewport / shortest;
  }

  /// El encuadre no puede salirse de la imagen. Se aplica tras cada gesto y
  /// tras cada giro, porque girar cambia qué margen hay disponible.
  Offset _clampOffset(Offset offset, double viewport) {
    final scale = _coverScale(viewport) * _zoom;
    final size = _rotatedSize;
    final maxX = (size.width * scale - viewport) / 2;
    final maxY = (size.height * scale - viewport) / 2;
    return Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
  }

  void _rotate(double viewport) {
    setState(() {
      _turns = (_turns + 1) % 4;
      _offset = _clampOffset(Offset.zero, viewport);
    });
  }

  void _setZoom(double value, double viewport) {
    setState(() {
      _zoom = value;
      _offset = _clampOffset(_offset, viewport);
    });
  }

  void _confirm(double viewport) {
    final scale = _coverScale(viewport) * _zoom;
    final size = _rotatedSize;
    // Esquina superior izquierda de la imagen dentro del cuadro, en píxeles de
    // pantalla; de ahí sale qué parte de la imagen queda visible.
    final left = viewport / 2 - size.width * scale / 2 + _offset.dx;
    final top = viewport / 2 - size.height * scale / 2 + _offset.dy;
    final side = viewport / scale;
    Navigator.of(context).pop(
      AvatarAdjustment(
        quarterTurns: _turns,
        crop: AvatarCrop(
          left: (-left / scale) / size.width,
          top: (-top / scale) / size.height,
          width: side / size.width,
          height: side / size.height,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final viewport = _viewportSide(context);

    return AlertDialog(
      title: Text(tx('profile.avatar_adjust_title')),
      content: SizedBox(
        width: viewport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tx('profile.avatar_adjust_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildViewport(viewport),
            if (_preview != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.zoom_out, size: 18),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: 1,
                      max: _maxZoom,
                      label: '${_zoom.toStringAsFixed(1)}×',
                      onChanged: (value) => _setZoom(value, viewport),
                    ),
                  ),
                  const Icon(Icons.zoom_in, size: 18),
                  AppIconButton(
                    icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                    tooltip: tx('profile.avatar_adjust_rotate'),
                    onPressed: () => _rotate(viewport),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel')),
        ),
        PrimaryButton(
          onPressed: _preview == null ? null : () => _confirm(viewport),
          child: Text(tx('profile.avatar_adjust_apply')),
        ),
      ],
    );
  }

  /// Cuadrado: el avatar es circular y el recorte, cuadrado. Se acota también
  /// por el alto para que en un móvil en horizontal quepan los controles.
  double _viewportSide(BuildContext context) {
    final width = dialogContentWidth(context, 320);
    final height = dialogContentHeight(context, 320, margin: 320);
    return width < height ? width : height;
  }

  Widget _buildViewport(double viewport) {
    if (_failed) {
      return SizedBox(
        height: viewport,
        child: Center(child: Text(widget.tx('profile.avatar_error'))),
      );
    }
    final image = _preview;
    if (image == null) {
      return SizedBox(
        height: viewport,
        child: const Center(child: IAgentsLoadingMark()),
      );
    }

    final scale = _coverScale(viewport) * _zoom;
    final size = _rotatedSize;

    return GestureDetector(
      onScaleStart: (details) {
        _gestureStartZoom = _zoom;
        _gestureStartOffset = _offset;
        _gestureStartFocal = details.focalPoint;
      },
      onScaleUpdate: (details) {
        setState(() {
          _zoom = (_gestureStartZoom * details.scale).clamp(1.0, _maxZoom);
          // Desde el inicio del gesto y no acumulando `focalPointDelta`: el
          // recorte se aplica en cada paso, así que acumular deltas ya
          // recortados haría que el dedo y la imagen se separaran al volver
          // del borde.
          _offset = _clampOffset(
            _gestureStartOffset + (details.focalPoint - _gestureStartFocal),
            viewport,
          );
        });
      },
      child: ClipRect(
        child: SizedBox(
          width: viewport,
          height: viewport,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: FncColors.black),
              Center(
                child: Transform.translate(
                  offset: _offset,
                  child: SizedBox(
                    width: size.width * scale,
                    height: size.height * scale,
                    child: RotatedBox(
                      quarterTurns: _turns,
                      child: RawImage(image: image, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(painter: _CircleMaskPainter(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vela todo menos el círculo del avatar. Es solo una ayuda visual: lo que se
/// sube es el cuadrado completo, que es lo que el `ClipOval` de la ficha
/// vuelve a recortar —guardar ya recortado en círculo obligaría a un PNG con
/// transparencia y a decidir aquí el color del fondo.
class _CircleMaskPainter extends CustomPainter {
  _CircleMaskPainter(BuildContext context)
    : borde = Theme.of(context).colorScheme.primary;

  final Color borde;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circulo = Path()
      ..addOval(
        Rect.fromCircle(center: rect.center, radius: size.shortestSide / 2),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(rect), circulo),
      Paint()..color = FncColors.black.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      circulo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = borde,
    );
  }

  @override
  bool shouldRepaint(_CircleMaskPainter oldDelegate) =>
      oldDelegate.borde != borde;
}
