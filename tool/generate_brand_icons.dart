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
    nativeName: 'agentCoordinator',
    androidName: 'agent_coordinator',
    iosSet: 'AppIconAgentCoordinator',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_white_on_red.png',
    foreground: _white,
    background: _red,
    nativeName: 'coordinatorWhiteOnRed',
    androidName: 'coordinator_white_on_red',
    iosSet: 'AppIconCoordinatorWhiteOnRed',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_red_on_black.png',
    foreground: _red,
    background: _black,
    nativeName: 'coordinatorRedOnBlack',
    androidName: 'coordinator_red_on_black',
    iosSet: 'AppIconCoordinatorRedOnBlack',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_black_on_red.png',
    foreground: _black,
    background: _red,
    nativeName: 'coordinatorBlackOnRed',
    androidName: 'coordinator_black_on_red',
    iosSet: 'AppIconCoordinatorBlackOnRed',
  ),
  _Variant(
    asset: 'assets/icons/coordinator/coordinator_red_on_white.png',
    foreground: _red,
    background: _white,
    nativeName: 'coordinatorRedOnWhite',
    androidName: 'coordinator_red_on_white',
    iosSet: 'AppIconCoordinatorRedOnWhite',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_white_on_red.png',
    foreground: _white,
    background: _red,
    mark: _Mark.ia,
    nativeName: 'iaInterWhiteOnRed',
    androidName: 'ia_inter_white_on_red',
    iosSet: 'AppIconIaInterWhiteOnRed',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_red_on_black.png',
    foreground: _red,
    background: _black,
    mark: _Mark.ia,
    nativeName: 'iaInterRedOnBlack',
    androidName: 'ia_inter_red_on_black',
    iosSet: 'AppIconIaInterRedOnBlack',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_black_on_red.png',
    foreground: _black,
    background: _red,
    mark: _Mark.ia,
    nativeName: 'iaInterBlackOnRed',
    androidName: 'ia_inter_black_on_red',
    iosSet: 'AppIconIaInterBlackOnRed',
  ),
  _Variant(
    asset: 'assets/icons/ia/ia_inter_red_on_white.png',
    foreground: _red,
    background: _white,
    mark: _Mark.ia,
    nativeName: 'iaInterRedOnWhite',
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

  _restoreAlternateIconConfiguration();

  stdout.writeln('Todos los iconos se generaron correctamente.');
}

void _restoreAlternateIconConfiguration() {
  final androidManifest = File('android/app/src/main/AndroidManifest.xml');
  var androidContents = androidManifest.readAsStringSync();
  for (final variant in _variants) {
    final aliasPattern = RegExp(
      '(<activity-alias\\s+android:name="com\\.iagentshub\\.app\\.'
      'MainActivity\\.${variant.nativeName}"[\\s\\S]*?android:icon=")'
      '[^"]+("[\\s\\S]*?</activity-alias>)',
    );
    androidContents = androidContents.replaceFirstMapped(
      aliasPattern,
      (match) =>
          '${match.group(1)}@mipmap/ic_launcher_${variant.androidName}'
          '${match.group(2)}',
    );
  }
  androidManifest.writeAsStringSync(androidContents);

  final iosProject = File('ios/Runner.xcodeproj/project.pbxproj');
  final alternateSets = _variants.map((variant) => variant.iosSet).join(' ');
  final iosContents = iosProject.readAsStringSync().replaceAll(
    RegExp(r'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = [^;]+;'),
    'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "$alternateSets";',
  );
  iosProject.writeAsStringSync(iosContents);

  final webManifest = File('web/manifest.json');
  final webContents = webManifest.readAsStringSync();
  if (!webContents.endsWith('\n')) {
    webManifest.writeAsStringSync('$webContents\n');
  }
}

image.Image _render(_Variant variant, int size) {
  final output = image.Image(width: size, height: size, numChannels: 3);
  final background = variant.background.color;
  final foreground = variant.foreground.color;
  image.fill(output, color: background);

  final left = variant.mark == _Mark.coordinator
      ? BrandMarkGeometry.coordinatorLeft
      : BrandMarkGeometry.iaLeft;
  final right = variant.mark == _Mark.coordinator
      ? BrandMarkGeometry.coordinatorRight
      : BrandMarkGeometry.iaRight;
  final stem = variant.mark == _Mark.coordinator
      ? BrandMarkGeometry.coordinatorStem
      : BrandMarkGeometry.iaStem;
  final dot = variant.mark == _Mark.coordinator
      ? BrandMarkGeometry.coordinatorDot
      : BrandMarkGeometry.iaDot;
  final dotRadius = variant.mark == _Mark.coordinator
      ? BrandMarkGeometry.coordinatorDotRadius
      : BrandMarkGeometry.letterDotRadius;

  _drawCubic(output, left, BrandMarkGeometry.strokeWidth, foreground);
  _drawCubic(output, right, BrandMarkGeometry.strokeWidth, foreground);
  _drawLine(output, stem, BrandMarkGeometry.strokeWidth, foreground);
  if (variant.mark == _Mark.ia) {
    _drawLine(
      output,
      BrandMarkGeometry.iaConnector,
      BrandMarkGeometry.strokeWidth,
      foreground,
    );
  }

  image.fillCircle(
    output,
    x: (dot.x * size).round(),
    y: (dot.y * size).round(),
    radius: (dotRadius * size).round(),
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
    required this.nativeName,
    this.mark = _Mark.coordinator,
    this.androidName,
    this.iosSet,
  });

  final String asset;
  final _Rgb foreground;
  final _Rgb background;
  final String nativeName;
  final _Mark mark;
  final String? androidName;
  final String? iosSet;
}

enum _Mark { coordinator, ia }

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;

  image.Color get color => image.ColorRgb8(red, green, blue);
}
