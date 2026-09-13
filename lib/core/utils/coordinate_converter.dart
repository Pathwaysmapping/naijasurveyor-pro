import 'dart:math' as math;
import '../constants/geodetic_constants.dart';

/// Result container for Transverse Mercator Grid Coordinates (Easting, Northing)
class UTMResult {
  final double easting;
  final double northing;
  final int zone;
  final String datum;

  const UTMResult({
    required this.easting,
    required this.northing,
    required this.zone,
    required this.datum,
  });

  @override
  String toString() =>
      'Easting: ${easting.toStringAsFixed(3)} m, Northing: ${northing.toStringAsFixed(3)} m (Zone ${zone}N, $datum)';
}

/// Result container for Geographic Coordinates (Latitude, Longitude, Height)
class GeographicResult {
  final double latitude;
  final double longitude;
  final double height;
  final String datum;

  const GeographicResult({
    required this.latitude,
    required this.longitude,
    required this.height,
    required this.datum,
  });

  @override
  String toString() =>
      'Lat: ${latitude.toStringAsFixed(6)}°, Lon: ${longitude.toStringAsFixed(6)}°, H: ${height.toStringAsFixed(3)} m ($datum)';
}

/// Core Geodetic Transformation Engine for Nigerian Land Surveyors
/// Supports:
/// - WGS84 Geographic <-> Minna UTM (Zones 31N, 32N, 33N)
/// - Minna UTM (Zones 31N, 32N, 33N) <-> WGS84 Geographic
/// - Regional 3-Parameter (dx, dy, dz) overrides for local state calibrations (e.g. Lagos State GIS)
class CoordinateConverter {
  /// Converts WGS84 Geographic (Lat/Lon) to Minna Datum UTM (Zone 31N, 32N, or 33N)
  static UTMResult wgs84ToMinnaUtm({
    required double latDeg,
    required double lonDeg,
    double height = 0.0,
    int? overrideZone,
    double dx = GeodeticConstants.nationalDx,
    double dy = GeodeticConstants.nationalDy,
    double dz = GeodeticConstants.nationalDz,
  }) {
    // 1. Geographic WGS84 to 3D Cartesian
    final wgsXyz = _geographicToCartesian(
      latDeg: latDeg,
      lonDeg: lonDeg,
      h: height,
      a: GeodeticConstants.wgs84A,
      e2: GeodeticConstants.wgs84E2,
    );

    // 2. Datum shift (WGS84 -> Minna Datum Clarke 1880)
    // Note: National shift parameters are Minna -> WGS84, so we subtract to go backwards.
    final minnaX = wgsXyz[0] - dx;
    final minnaY = wgsXyz[1] - dy;
    final minnaZ = wgsXyz[2] - dz;

    // 3. 3D Cartesian to Geographic on Clarke 1880
    final minnaGeo = _cartesianToGeographic(
      x: minnaX,
      y: minnaY,
      z: minnaZ,
      a: GeodeticConstants.clarke1880A,
      b: GeodeticConstants.clarke1880B,
      e2: GeodeticConstants.clarke1880E2,
      ep2: GeodeticConstants.clarke1880Ep2,
    );

    // 4. Project Geographic Clarke 1880 onto Transverse Mercator
    final zone = overrideZone ?? GeodeticConstants.detectZoneFromLongitude(lonDeg);
    final cmDeg = GeodeticConstants.centralMeridianForZone(zone);

    final utmCoords = _geographicToTransverseMercator(
      latRad: minnaGeo['latRad']!,
      lonRad: minnaGeo['lonRad']!,
      cmRad: cmDeg * (math.pi / 180.0),
      a: GeodeticConstants.clarke1880A,
      e2: GeodeticConstants.clarke1880E2,
      k0: GeodeticConstants.utmK0,
      falseEasting: GeodeticConstants.falseEasting,
      falseNorthing: GeodeticConstants.falseNorthing,
    );

    return UTMResult(
      easting: utmCoords['easting']!,
      northing: utmCoords['northing']!,
      zone: zone,
      datum: 'MINNA_UTM',
    );
  }

  /// Converts Minna UTM Coordinates back to Geographic WGS84 (GPS Lat/Lon)
  static GeographicResult minnaUtmToWgs84({
    required double easting,
    required double northing,
    required int zone,
    double height = 0.0,
    double dx = GeodeticConstants.nationalDx,
    double dy = GeodeticConstants.nationalDy,
    double dz = GeodeticConstants.nationalDz,
  }) {
    final cmDeg = GeodeticConstants.centralMeridianForZone(zone);
    final cmRad = cmDeg * (math.pi / 180.0);

    // 1. Inverse Transverse Mercator to Geographic Clarke 1880
    final minnaGeo = _transverseMercatorToGeographic(
      easting: easting,
      northing: northing,
      cmRad: cmRad,
      a: GeodeticConstants.clarke1880A,
      b: GeodeticConstants.clarke1880B,
      e2: GeodeticConstants.clarke1880E2,
      ep2: GeodeticConstants.clarke1880Ep2,
      k0: GeodeticConstants.utmK0,
      falseEasting: GeodeticConstants.falseEasting,
      falseNorthing: GeodeticConstants.falseNorthing,
    );

    // 2. Geographic Clarke 1880 to 3D Cartesian
    final minnaXyz = _geographicToCartesian(
      latDeg: minnaGeo['latDeg']!,
      lonDeg: minnaGeo['lonDeg']!,
      h: height,
      a: GeodeticConstants.clarke1880A,
      e2: GeodeticConstants.clarke1880E2,
    );

    // 3. Datum shift (Minna -> WGS84: Add dx, dy, dz)
    final wgsX = minnaXyz[0] + dx;
    final wgsY = minnaXyz[1] + dy;
    final wgsZ = minnaXyz[2] + dz;

    // 4. 3D Cartesian to Geographic WGS84
    final wgsGeo = _cartesianToGeographic(
      x: wgsX,
      y: wgsY,
      z: wgsZ,
      a: GeodeticConstants.wgs84A,
      b: GeodeticConstants.wgs84B,
      e2: GeodeticConstants.wgs84E2,
      ep2: GeodeticConstants.wgs84Ep2,
    );

    return GeographicResult(
      latitude: wgsGeo['latRad']! * (180.0 / math.pi),
      longitude: wgsGeo['lonRad']! * (180.0 / math.pi),
      height: wgsGeo['height']!,
      datum: 'WGS84_GEOGRAPHIC',
    );
  }

  // =========================================================================
  // INTERNAL GEODETIC TRANSFORMATION ROUTINES
  // =========================================================================

  /// Converts Geographic (Lat/Lon/H) to 3D Cartesian (X, Y, Z)
  static List<double> _geographicToCartesian({
    required double latDeg,
    required double lonDeg,
    required double h,
    required double a,
    required double e2,
  }) {
    final latRad = latDeg * (math.pi / 180.0);
    final lonRad = lonDeg * (math.pi / 180.0);
    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);

    final n = a / math.sqrt(1.0 - (e2 * sinLat * sinLat));
    final x = (n + h) * cosLat * math.cos(lonRad);
    final y = (n + h) * cosLat * math.sin(lonRad);
    final z = (n * (1.0 - e2) + h) * sinLat;

    return [x, y, z];
  }

  /// Converts 3D Cartesian (X, Y, Z) to Geographic (Lat/Lon/H) using Bowring's closed algorithm
  static Map<String, double> _cartesianToGeographic({
    required double x,
    required double y,
    required double z,
    required double a,
    required double b,
    required double e2,
    required double ep2,
  }) {
    final p = math.sqrt(x * x + y * y);
    final theta = math.atan2(z * a, p * b);
    final sinTheta = math.sin(theta);
    final cosTheta = math.cos(theta);

    final latRad = math.atan2(
      z + ep2 * b * sinTheta * sinTheta * sinTheta,
      p - e2 * a * cosTheta * cosTheta * cosTheta,
    );
    final lonRad = math.atan2(y, x);

    final sinLat = math.sin(latRad);
    final n = a / math.sqrt(1.0 - e2 * sinLat * sinLat);
    final h = (p / math.cos(latRad)) - n;

    return {
      'latRad': latRad,
      'lonRad': lonRad,
      'latDeg': latRad * (180.0 / math.pi),
      'lonDeg': lonRad * (180.0 / math.pi),
      'height': h,
    };
  }

  /// Projects Geographic Coordinates (radians) to Transverse Mercator Grid (Easting, Northing)
  static Map<String, double> _geographicToTransverseMercator({
    required double latRad,
    required double lonRad,
    required double cmRad,
    required double a,
    required double e2,
    required double k0,
    required double falseEasting,
    required double falseNorthing,
  }) {
    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);
    final tanLat = math.tan(latRad);

    final n = a / math.sqrt(1.0 - e2 * sinLat * sinLat);
    final t = tanLat * tanLat;
    final ep2 = e2 / (1.0 - e2);
    final c = ep2 * cosLat * cosLat;
    final deltaLon = lonRad - cmRad;
    final aTerm = deltaLon * cosLat;

    // Meridian distance M
    final m = a * (
      (1.0 - e2 / 4.0 - 3.0 * e2 * e2 / 64.0 - 5.0 * e2 * e2 * e2 / 256.0) * latRad
      - (3.0 * e2 / 8.0 + 3.0 * e2 * e2 / 32.0 + 45.0 * e2 * e2 * e2 / 1024.0) * math.sin(2.0 * latRad)
      + (15.0 * e2 * e2 / 256.0 + 45.0 * e2 * e2 * e2 / 1024.0) * math.sin(4.0 * latRad)
      - (35.0 * e2 * e2 * e2 / 3072.0) * math.sin(6.0 * latRad)
    );

    final easting = falseEasting + k0 * n * (
      aTerm
      + (1.0 - t + c) * math.pow(aTerm, 3) / 6.0
      + (5.0 - 18.0 * t + t * t + 72.0 * c - 58.0 * ep2) * math.pow(aTerm, 5) / 120.0
    );

    final northing = falseNorthing + k0 * (
      m + n * tanLat * (
        (aTerm * aTerm / 2.0)
        + (5.0 - t + 9.0 * c + 4.0 * c * c) * math.pow(aTerm, 4) / 24.0
        + (61.0 - 58.0 * t + t * t + 600.0 * c - 330.0 * ep2) * math.pow(aTerm, 6) / 720.0
      )
    );

    return {'easting': easting, 'northing': northing};
  }

  /// Inverse Transverse Mercator: Grid (Easting, Northing) to Geographic Coordinates
  static Map<String, double> _transverseMercatorToGeographic({
    required double easting,
    required double northing,
    required double cmRad,
    required double a,
    required double b,
    required double e2,
    required double ep2,
    required double k0,
    required double falseEasting,
    required double falseNorthing,
  }) {
    final x = easting - falseEasting;
    final y = northing - falseNorthing;
    final m = y / k0;
    final mu = m / (a * (1.0 - e2 / 4.0 - 3.0 * e2 * e2 / 64.0 - 5.0 * e2 * e2 * e2 / 256.0));

    final e1 = (1.0 - math.sqrt(1.0 - e2)) / (1.0 + math.sqrt(1.0 - e2));

    final phi1 = mu
      + (3.0 * e1 / 2.0 - 27.0 * math.pow(e1, 3) / 32.0) * math.sin(2.0 * mu)
      + (21.0 * e1 * e1 / 16.0 - 55.0 * math.pow(e1, 4) / 32.0) * math.sin(4.0 * mu)
      + (151.0 * math.pow(e1, 3) / 96.0) * math.sin(6.0 * mu)
      + (1097.0 * math.pow(e1, 4) / 512.0) * math.sin(8.0 * mu);

    final sinPhi1 = math.sin(phi1);
    final cosPhi1 = math.cos(phi1);
    final tanPhi1 = math.tan(phi1);

    final n1 = a / math.sqrt(1.0 - e2 * sinPhi1 * sinPhi1);
    final r1 = a * (1.0 - e2) / math.pow(1.0 - e2 * sinPhi1 * sinPhi1, 1.5);
    final d = x / (n1 * k0);

    final t1 = tanPhi1 * tanPhi1;
    final c1 = ep2 * cosPhi1 * cosPhi1;

    final latRad = phi1 - (n1 * tanPhi1 / r1) * (
      (d * d / 2.0)
      - (5.0 + 3.0 * t1 + 10.0 * c1 - 4.0 * c1 * c1 - 9.0 * ep2) * math.pow(d, 4) / 24.0
      + (61.0 + 90.0 * t1 + 298.0 * c1 + 45.0 * t1 * t1 - 252.0 * ep2 - 3.0 * c1 * c1) * math.pow(d, 6) / 720.0
    );

    final lonRad = cmRad + (
      d
      - (1.0 + 2.0 * t1 + c1) * math.pow(d, 3) / 6.0
      + (5.0 - 2.0 * c1 + 28.0 * t1 - 3.0 * c1 * c1 + 8.0 * ep2 + 24.0 * t1 * t1) * math.pow(d, 5) / 120.0
    ) / cosPhi1;

    return {
      'latRad': latRad,
      'lonRad': lonRad,
      'latDeg': latRad * (180.0 / math.pi),
      'lonDeg': lonRad * (180.0 / math.pi),
    };
  }
}
