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
    androidName: 'agent_coordinator',
    iosSet: 'AppIconAgentCoordinator',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_white_on_red.png',
    foreground: _white,
    background: _red,
    androidName: 'coordinator_white_on_red',
    iosSet: 'AppIconCoordinatorWhiteOnRed',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_red_on_black.png',
    foreground: _red,
    background: _black,
    androidName: 'coordinator_red_on_black',
    iosSet: 'AppIconCoordinatorRedOnBlack',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_black_on_red.png',
    foreground: _black,
    background: _red,
    androidName: 'coordinator_black_on_red',
    iosSet: 'AppIconCoordinatorBlackOnRed',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_red_on_white.png',
    foreground: _red,
    background: _white,
    androidName: 'coordinator_red_on_white',
    iosSet: 'AppIconCoordinatorRedOnWhite',
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

  for (final entry in const {
    'LaunchImage.png': 124,
    'LaunchImage@2x.png': 248,
    'LaunchImage@3x.png': 372,
  }.entries) {
    _writePng(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/${entry.key}',
      _renderLaunchTile(entry.value),
    );
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

  _drawCubic(
    output,
    BrandMarkGeometry.coordinatorLeft,
    BrandMarkGeometry.strokeWidth,
    foreground,
  );
  _drawCubic(
    output,
    BrandMarkGeometry.coordinatorRight,
    BrandMarkGeometry.strokeWidth,
    foreground,
  );
  _drawLine(
    output,
    BrandMarkGeometry.coordinatorStem,
    BrandMarkGeometry.strokeWidth,
    foreground,
  );

  final dot = BrandMarkGeometry.coordinatorDot;
  image.fillCircle(
    output,
    x: (dot.x * size).round(),
    y: (dot.y * size).round(),
    radius: (BrandMarkGeometry.coordinatorDotRadius * size).round(),
    color: foreground,
    antialias: true,
  );
  return output;
}

image.Image _renderLaunchTile(int size) {
  final canvasSize = size * 4;
  final output = image.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  image.fill(output, color: image.ColorRgba8(0, 0, 0, 0));
  image.fillRect(
    output,
    x1: 0,
    y1: 0,
    x2: canvasSize - 1,
    y2: canvasSize - 1,
    radius: (BrandMarkGeometry.tileCornerRadius * canvasSize).round(),
    color: _red.color,
  );
  _drawCubic(
    output,
    BrandMarkGeometry.coordinatorLeft,
    BrandMarkGeometry.strokeWidth,
    _white.color,
  );
  _drawCubic(
    output,
    BrandMarkGeometry.coordinatorRight,
    BrandMarkGeometry.strokeWidth,
    _white.color,
  );
  _drawLine(
    output,
    BrandMarkGeometry.coordinatorStem,
    BrandMarkGeometry.strokeWidth,
    _white.color,
  );
  image.fillCircle(
    output,
    x: (BrandMarkGeometry.coordinatorDot.x * canvasSize).round(),
    y: (BrandMarkGeometry.coordinatorDot.y * canvasSize).round(),
    radius: (BrandMarkGeometry.coordinatorDotRadius * canvasSize).round(),
    color: _white.color,
  );
  return _resize(output, size);
}

void _drawCubic(
  image.Image target,
  BrandCubic curve,
  double strokeWidth,
  image.Color color,
) {
  const segments = 400;
  for (var index = 0; index <= segments; index++) {
    final t = index / segments;
    final point = _cubicPoint(curve, t);
    _roundCap(target, point, strokeWidth, color);
  }
}

void _drawLine(
  image.Image target,
  BrandLine line,
  double strokeWidth,
  image.Color color,
) {
  _drawSegment(target, line.start, line.end, strokeWidth, color);
  _roundCap(target, line.start, strokeWidth, color);
  _roundCap(target, line.end, strokeWidth, color);
}

void _drawSegment(
  image.Image target,
  BrandPoint start,
  BrandPoint end,
  double strokeWidth,
  image.Color color,
) {
  image.drawLine(
    target,
    x1: (start.x * target.width).round(),
    y1: (start.y * target.height).round(),
    x2: (end.x * target.width).round(),
    y2: (end.y * target.height).round(),
    color: color,
    thickness: strokeWidth * target.width,
    antialias: false,
  );
}

void _roundCap(
  image.Image target,
  BrandPoint point,
  double strokeWidth,
  image.Color color,
) {
  image.fillCircle(
    target,
    x: (point.x * target.width).round(),
    y: (point.y * target.height).round(),
    radius: (strokeWidth * target.width / 2).round(),
    color: color,
    antialias: false,
  );
}

BrandPoint _cubicPoint(BrandCubic curve, double t) {
  final inverse = 1 - t;
  return BrandPoint(
    (inverse * inverse * inverse * curve.start.x) +
        (3 * inverse * inverse * t * curve.control1.x) +
        (3 * inverse * t * t * curve.control2.x) +
        (t * t * t * curve.end.x),
    (inverse * inverse * inverse * curve.start.y) +
        (3 * inverse * inverse * t * curve.control1.y) +
        (3 * inverse * t * t * curve.control2.y) +
        (t * t * t * curve.end.y),
  );
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
    this.androidName,
    this.iosSet,
  });

  final String asset;
  final _Rgb foreground;
  final _Rgb background;
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
