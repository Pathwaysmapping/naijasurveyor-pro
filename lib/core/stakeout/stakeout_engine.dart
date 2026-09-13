import 'dart:math' as math;

/// Results of real-time stakeout calculation between Rover and Target Beacon
class StakeoutCalculation {
  final double distance;       // 2D Horizontal distance to target (meters)
  final double deltaEasting;  // Target Easting - Current Easting (meters)
  final double deltaNorthing; // Target Northing - Current Northing (meters)
  final double deltaHeight;   // Target Height - Current Height (meters) (Cut/Fill)
  final double azimuthDegrees;// Bearing to target (0° to 360°, clockwise from North)
  final bool isTargetReached; // True if within tolerance (e.g. <= 0.02m / 2cm)
  final bool isNearBullseye;  // True if within 0.50m

  const StakeoutCalculation({
    required this.distance,
    required this.deltaEasting,
    required this.deltaNorthing,
    required this.deltaHeight,
    required this.azimuthDegrees,
    required this.isTargetReached,
    required this.isNearBullseye,
  });

  /// Human-readable navigation guidance string (e.g. "GO NORTH 1.45m, GO WEST 0.32m")
  String get directionInstructions {
    if (isTargetReached) return 'ON TARGET (WITHIN 2CM TOLERANCE)';

    final nText = deltaNorthing >= 0
        ? 'GO NORTH ${deltaNorthing.abs().toStringAsFixed(3)} m'
        : 'GO SOUTH ${deltaNorthing.abs().toStringAsFixed(3)} m';

    final eText = deltaEasting >= 0
        ? 'GO EAST ${deltaEasting.abs().toStringAsFixed(3)} m'
        : 'GO WEST ${deltaEasting.abs().toStringAsFixed(3)} m';

    return '$nText | $eText';
  }

  /// Formatted Azimuth / Bearing in Degrees, Minutes, Seconds
  String get bearingDms {
    final deg = azimuthDegrees.floor();
    final minDec = (azimuthDegrees - deg) * 60.0;
    final min = minDec.floor();
    final sec = ((minDec - min) * 60.0).toStringAsFixed(1);
    return '$deg° ${min.toString().padLeft(2, '0')}\' ${sec.padLeft(4, '0')}"';
  }

  /// Calculates proximity audio tick interval in milliseconds (faster beep as distance decreases)
  int get audioBeepIntervalMs {
    if (distance <= 0.02) return 100; // Continuous rapid pulse
    if (distance <= 0.20) return 200;
    if (distance <= 0.50) return 400;
    if (distance <= 1.50) return 800;
    if (distance <= 5.00) return 1500;
    return 3000;
  }
}

/// Stakeout Geometry Engine for locating historical survey beacons and setting out coordinates
class StakeoutEngine {
  /// Standard cadastral survey stakeout tolerance (2 centimeters)
  static const double standardToleranceMeters = 0.02;

  /// Calculates real-time stakeout deltas between current rover position and target beacon
  static StakeoutCalculation calculate({
    required double currentEasting,
    required double currentNorthing,
    double currentHeight = 0.0,
    required double targetEasting,
    required double targetNorthing,
    double targetHeight = 0.0,
    double toleranceMeters = standardToleranceMeters,
  }) {
    final dE = targetEasting - currentEasting;
    final dN = targetNorthing - currentNorthing;
    final dZ = targetHeight - currentHeight;

    final distance = math.sqrt(dE * dE + dN * dN);

    // Azimuth clockwise from North (Y axis)
    // atan2(dx, dy) returns angle from +Y (North) towards +X (East)
    double angleRad = math.atan2(dE, dN);
    double azimuthDeg = angleRad * (180.0 / math.pi);
    if (azimuthDeg < 0) {
      azimuthDeg += 360.0;
    }

    return StakeoutCalculation(
      distance: distance,
      deltaEasting: dE,
      deltaNorthing: dN,
      deltaHeight: dZ,
      azimuthDegrees: azimuthDeg,
      isTargetReached: distance <= toleranceMeters,
      isNearBullseye: distance <= 0.50,
    );
  }
}
