class BrandPoint {
  const BrandPoint(this.x, this.y);

  final double x;
  final double y;
}

class BrandRect {
  const BrandRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Geometría normalizada compartida por el morph y los iconos rasterizados.
abstract final class BrandMarkGeometry {
  static const coordinatorLeft = [
    BrandPoint(0.50, 0.61),
    BrandPoint(0.46, 0.59),
    BrandPoint(0.42, 0.56),
    BrandPoint(0.38, 0.54),
    BrandPoint(0.34, 0.51),
    BrandPoint(0.31, 0.48),
    BrandPoint(0.28, 0.44),
    BrandPoint(0.27, 0.40),
    BrandPoint(0.27, 0.35),
    BrandPoint(0.22, 0.35),
    BrandPoint(0.22, 0.42),
    BrandPoint(0.27, 0.49),
    BrandPoint(0.36, 0.57),
    BrandPoint(0.46, 0.64),
  ];

  static const iaLeft = [
    BrandPoint(0.493, 0.678),
    BrandPoint(0.507, 0.630),
    BrandPoint(0.521, 0.582),
    BrandPoint(0.535, 0.534),
    BrandPoint(0.549, 0.486),
    BrandPoint(0.563, 0.438),
    BrandPoint(0.577, 0.390),
    BrandPoint(0.591, 0.342),
    BrandPoint(0.605, 0.305),
    BrandPoint(0.530, 0.305),
    BrandPoint(0.506, 0.370),
    BrandPoint(0.465, 0.480),
    BrandPoint(0.424, 0.590),
    BrandPoint(0.384, 0.678),
  ];

  static const coordinatorRight = [
    BrandPoint(0.50, 0.61),
    BrandPoint(0.54, 0.59),
    BrandPoint(0.58, 0.56),
    BrandPoint(0.62, 0.54),
    BrandPoint(0.66, 0.51),
    BrandPoint(0.69, 0.48),
    BrandPoint(0.72, 0.44),
    BrandPoint(0.73, 0.40),
    BrandPoint(0.73, 0.35),
    BrandPoint(0.78, 0.35),
    BrandPoint(0.78, 0.42),
    BrandPoint(0.73, 0.49),
    BrandPoint(0.64, 0.57),
    BrandPoint(0.54, 0.64),
  ];

  static const iaRight = [
    BrandPoint(0.590, 0.305),
    BrandPoint(0.638, 0.305),
    BrandPoint(0.656, 0.353),
    BrandPoint(0.674, 0.401),
    BrandPoint(0.692, 0.449),
    BrandPoint(0.710, 0.497),
    BrandPoint(0.728, 0.545),
    BrandPoint(0.746, 0.593),
    BrandPoint(0.764, 0.641),
    BrandPoint(0.780, 0.678),
    BrandPoint(0.674, 0.678),
    BrandPoint(0.642, 0.590),
    BrandPoint(0.610, 0.500),
    BrandPoint(0.580, 0.410),
  ];

  static const aiLeft = [
    BrandPoint(0.507, 0.678),
    BrandPoint(0.493, 0.630),
    BrandPoint(0.479, 0.582),
    BrandPoint(0.465, 0.534),
    BrandPoint(0.451, 0.486),
    BrandPoint(0.437, 0.438),
    BrandPoint(0.423, 0.390),
    BrandPoint(0.409, 0.342),
    BrandPoint(0.395, 0.305),
    BrandPoint(0.470, 0.305),
    BrandPoint(0.494, 0.370),
    BrandPoint(0.535, 0.480),
    BrandPoint(0.576, 0.590),
    BrandPoint(0.616, 0.678),
  ];

  static const aiRight = [
    BrandPoint(0.410, 0.305),
    BrandPoint(0.362, 0.305),
    BrandPoint(0.344, 0.353),
    BrandPoint(0.326, 0.401),
    BrandPoint(0.308, 0.449),
    BrandPoint(0.290, 0.497),
    BrandPoint(0.272, 0.545),
    BrandPoint(0.254, 0.593),
    BrandPoint(0.236, 0.641),
    BrandPoint(0.220, 0.678),
    BrandPoint(0.326, 0.678),
    BrandPoint(0.358, 0.590),
    BrandPoint(0.390, 0.500),
    BrandPoint(0.420, 0.410),
  ];

  static const coordinatorConnector = BrandRect(0.46, 0.52, 0.54, 0.60);
  static const iaConnector = BrandRect(0.50, 0.522, 0.660, 0.606);
  static const aiConnector = BrandRect(0.340, 0.522, 0.500, 0.606);

  static const coordinatorStem = BrandRect(0.455, 0.38, 0.545, 0.80);
  static const iaStem = BrandRect(0.278, 0.414, 0.365, 0.678);
  static const aiStem = BrandRect(0.635, 0.414, 0.722, 0.678);

  static const coordinatorDot = BrandPoint(0.50, 0.25);
  static const iaDot = BrandPoint(0.321, 0.346);
  static const aiDot = BrandPoint(0.679, 0.346);
  static const coordinatorDotRadius = 0.052;
  static const iaDotRadius = 0.048;
  static const aiDotRadius = 0.048;
  static const coordinatorCornerRadius = 0.045;
}
