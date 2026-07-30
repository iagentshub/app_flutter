import 'dart:io';

import 'package:app_flutter/shared/branding/brand_mark_geometry.dart';
import 'package:image/image.dart' as image;

const _red = _Rgb(0xD9, 0x04, 0x29);
const _black = _Rgb(0x00, 0x00, 0x00);
const _white = _Rgb(0xFF, 0xFF, 0xFF);

const _variants = [
  _Variant(
    asset: 'assets/icons/coordinator/agent_coordinator_icon.png',
    foreground: _white,
    background: _black,
    progress: 0,
    androidName: 'agent_coordinator',
    iosSet: 'AppIconAgentCoordinator',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_white_on_red.png',
    foreground: _white,
    background: _red,
    progress: 0,
    androidName: 'coordinator_white_on_red',
    iosSet: 'AppIconCoordinatorWhiteOnRed',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_red_on_black.png',
    foreground: _red,
    background: _black,
    progress: 0,
    androidName: 'coordinator_red_on_black',
    iosSet: 'AppIconCoordinatorRedOnBlack',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_black_on_red.png',
    foreground: _black,
    background: _red,
    progress: 0,
    androidName: 'coordinator_black_on_red',
    iosSet: 'AppIconCoordinatorBlackOnRed',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_red_on_white.png',
    foreground: _red,
    background: _white,
    progress: 0,
    androidName: 'coordinator_red_on_white',
    iosSet: 'AppIconCoordinatorRedOnWhite',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_white_on_red.png',
    foreground: _white,
    background: _red,
    progress: 1,
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_red_on_black.png',
    foreground: _red,
    background: _black,
    progress: 1,
    androidName: 'ia_inter_red_on_black',
    iosSet: 'AppIconIaInterRedOnBlack',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_black_on_red.png',
    foreground: _black,
    background: _red,
    progress: 1,
    androidName: 'ia_inter_black_on_red',
    iosSet: 'AppIconIaInterBlackOnRed',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_red_on_white.png',
    foreground: _red,
    background: _white,
    progress: 1,
    androidName: 'ia_inter_red_on_white',
    iosSet: 'AppIconIaInterRedOnWhite',
  ),
];

const _androidSizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const _iosFiles = {
  'icon-60@2x.png': 120,
  'icon-60@3x.png': 180,
  'icon-76@2x.png': 152,
  'icon-83.5@2x.png': 167,
  'icon-1024.png': 1024,
};

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Ejecuta este comando desde la raíz de app_flutter.');
    exitCode = 64;
    return;
  }

  for (final variant in _variants) {
    final master = _render(variant, 2048);
    _writePng(variant.asset, _resize(master, 512));

    if (variant.androidName case final name?) {
      for (final entry in _androidSizes.entries) {
        _writePng(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_$name.png',
          _resize(master, entry.value),
        );
      }
    }

    if (variant.iosSet case final setName?) {
      for (final entry in _iosFiles.entries) {
        _writePng(
          'ios/Runner/Assets.xcassets/$setName.appiconset/${entry.key}',
          _resize(master, entry.value),
        );
      }
    }
  }

  final launcherResult = Process.runSync(Platform.resolvedExecutable, const [
    'run',
    'flutter_launcher_icons',
  ]);
  stdout
    ..write(launcherResult.stdout)
    ..write(launcherResult.stderr);
  if (launcherResult.exitCode != 0) {
    stderr.writeln('No se pudo propagar el icono principal.');
    exitCode = launcherResult.exitCode;
    return;
  }

  stdout.writeln('Todos los iconos se generaron correctamente.');
}

image.Image _render(_Variant variant, int size) {
  final output = image.Image(width: size, height: size, numChannels: 3);
  final background = variant.background.color;
  final foreground = variant.foreground.color;
  image.fill(output, color: background);

  _fillMorphPolygon(
    output,
    BrandMarkGeometry.coordinatorLeft,
    BrandMarkGeometry.iaLeft,
    variant.progress,
    foreground,
  );
  _fillMorphPolygon(
    output,
    BrandMarkGeometry.coordinatorRight,
    BrandMarkGeometry.iaRight,
    variant.progress,
    foreground,
  );
  _fillMorphRect(
    output,
    BrandMarkGeometry.coordinatorConnector,
    BrandMarkGeometry.iaConnector,
    variant.progress,
    foreground,
    rounded: true,
  );
  _fillMorphRect(
    output,
    BrandMarkGeometry.coordinatorStem,
    BrandMarkGeometry.iaStem,
    variant.progress,
    foreground,
    rounded: true,
  );

  final dot = _point(
    BrandMarkGeometry.coordinatorDot,
    BrandMarkGeometry.iaDot,
    variant.progress,
  );
  final radius =
      BrandMarkGeometry.coordinatorDotRadius +
      ((BrandMarkGeometry.iaDotRadius -
              BrandMarkGeometry.coordinatorDotRadius) *
          variant.progress);
  image.fillCircle(
    output,
    x: (dot.x * size).round(),
    y: (dot.y * size).round(),
    radius: (radius * size).round(),
    color: foreground,
  );
  return output;
}

void _fillMorphPolygon(
  image.Image target,
  List<BrandPoint> start,
  List<BrandPoint> end,
  double progress,
  image.Color color,
) {
  image.fillPolygon(
    target,
    vertices: [
      for (var index = 0; index < start.length; index++)
        image.Point(
          (_point(start[index], end[index], progress).x * target.width).round(),
          (_point(start[index], end[index], progress).y * target.height)
              .round(),
        ),
    ],
    color: color,
  );
}

void _fillMorphRect(
  image.Image target,
  BrandRect start,
  BrandRect end,
  double progress,
  image.Color color, {
  required bool rounded,
}) {
  final rect = BrandRect(
    _lerp(start.left, end.left, progress),
    _lerp(start.top, end.top, progress),
    _lerp(start.right, end.right, progress),
    _lerp(start.bottom, end.bottom, progress),
  );
  image.fillRect(
    target,
    x1: (rect.left * target.width).round(),
    y1: (rect.top * target.height).round(),
    x2: (rect.right * target.width).round(),
    y2: (rect.bottom * target.height).round(),
    radius: rounded
        ? (BrandMarkGeometry.coordinatorCornerRadius *
                  (1 - progress) *
                  target.width)
              .round()
        : 0,
    color: color,
  );
}

BrandPoint _point(BrandPoint start, BrandPoint end, double progress) {
  return BrandPoint(
    _lerp(start.x, end.x, progress),
    _lerp(start.y, end.y, progress),
  );
}

double _lerp(double start, double end, double progress) {
  return start + ((end - start) * progress);
}

image.Image _resize(image.Image source, int size) {
  return image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.cubic,
  );
}

void _writePng(String path, image.Image value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(image.encodePng(value, level: 9));
}

class _Variant {
  const _Variant({
    required this.asset,
    required this.foreground,
    required this.background,
    required this.progress,
    this.androidName,
    this.iosSet,
  });

  final String asset;
  final _Rgb foreground;
  final _Rgb background;
  final double progress;
  final String? androidName;
  final String? iosSet;
}

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;

  image.Color get color => image.ColorRgb8(red, green, blue);
}
