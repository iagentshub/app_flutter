class BrandPoint {
  const BrandPoint(this.x, this.y);

  final double x;
  final double y;
}

class BrandCubic {
  const BrandCubic(this.start, this.control1, this.control2, this.end);

  final BrandPoint start;
  final BrandPoint control1;
  final BrandPoint control2;
  final BrandPoint end;
}

class BrandLine {
  const BrandLine(this.start, this.end);

  final BrandPoint start;
  final BrandPoint end;
}

/// Geometría normalizada de la marca coordinator.
///
/// Los brazos son curvas cúbicas con extremos redondos. Las geometrías `iA` y
/// `Ai` conservan la misma topología para que el splash pueda interpolar el
/// coordinator hacia las dos lecturas de «inteligencia artificial».
abstract final class BrandMarkGeometry {
  static const coordinatorLeft = BrandCubic(
    BrandPoint(0.245, 0.385),
    BrandPoint(0.275, 0.545),
    BrandPoint(0.375, 0.635),
    BrandPoint(0.500, 0.635),
  );
  static const coordinatorRight = BrandCubic(
    BrandPoint(0.755, 0.385),
    BrandPoint(0.725, 0.545),
    BrandPoint(0.625, 0.635),
    BrandPoint(0.500, 0.635),
  );
  static const coordinatorStem = BrandLine(
    BrandPoint(0.500, 0.435),
    BrandPoint(0.500, 0.790),
  );
  static const coordinatorConnector = BrandLine(
    BrandPoint(0.500, 0.635),
    BrandPoint(0.500, 0.635),
  );
  static const coordinatorDot = BrandPoint(0.500, 0.235);

  static const iaLeft = BrandCubic(
    BrandPoint(0.430, 0.700),
    BrandPoint(0.483, 0.570),
    BrandPoint(0.537, 0.440),
    BrandPoint(0.590, 0.310),
  );
  static const iaRight = BrandCubic(
    BrandPoint(0.780, 0.700),
    BrandPoint(0.717, 0.570),
    BrandPoint(0.653, 0.440),
    BrandPoint(0.590, 0.310),
  );
  static const iaStem = BrandLine(
    BrandPoint(0.300, 0.455),
    BrandPoint(0.300, 0.700),
  );
  static const iaConnector = BrandLine(
    BrandPoint(0.500, 0.565),
    BrandPoint(0.680, 0.565),
  );
  static const iaDot = BrandPoint(0.300, 0.320);

  static const aiLeft = BrandCubic(
    BrandPoint(0.220, 0.700),
    BrandPoint(0.283, 0.570),
    BrandPoint(0.347, 0.440),
    BrandPoint(0.410, 0.310),
  );
  static const aiRight = BrandCubic(
    BrandPoint(0.570, 0.700),
    BrandPoint(0.517, 0.570),
    BrandPoint(0.463, 0.440),
    BrandPoint(0.410, 0.310),
  );
  static const aiStem = BrandLine(
    BrandPoint(0.700, 0.455),
    BrandPoint(0.700, 0.700),
  );
  static const aiConnector = BrandLine(
    BrandPoint(0.320, 0.565),
    BrandPoint(0.500, 0.565),
  );
  static const aiDot = BrandPoint(0.700, 0.320);

  static const strokeWidth = 0.078;
  static const coordinatorDotRadius = 0.055;
  static const letterDotRadius = 0.047;
  static const tileCornerRadius = 0.22;
}
