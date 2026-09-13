import 'dart:math' as math;
import '../constants/geodetic_constants.dart';
import '../utils/coordinate_converter.dart';

/// Fix quality indicator according to NMEA 0183 standard
enum GnssFixQuality {
  invalid,      // 0 = Fix not available / Invalid
  autonomous,   // 1 = GPS Single / Autonomous fix (~1.5m to 3m)
  dgps,         // 2 = Differential GPS fix (~0.5m to 1m)
  pps,          // 3 = PPS fix
  rtkFixed,     // 4 = Real-Time Kinematic FIXED (Centimeter / millimeter accuracy)
  rtkFloat,     // 5 = Real-Time Kinematic FLOAT (Decimeter accuracy)
  estimated,    // 6 = Dead reckoning
  manual,       // 7 = Manual input
  simulation,   // 8 = Simulation mode
}

/// Structured GNSS Position state derived from NMEA sentences
class GnssPosition {
  final double latitude;        // Decimal degrees (Positive = North)
  final double longitude;       // Decimal degrees (Positive = East)
  final double altitudeMsl;     // Orthometric height above MSL (meters)
  final double geoidalSeparation; // Height of geoid above WGS84 ellipsoid (meters)
  final double ellipsoidalHeight; // altitudeMsl + geoidalSeparation
  final GnssFixQuality fixQuality;
  final int satellitesCount;
  final double hdop;            // Horizontal Dilution of Precision
  final double? ageOfDifferential; // Seconds since last RTCM correction
  final String? diffStationId;
  final DateTime timestamp;

  // Real-time projected Minna UTM grid coordinates
  final UTMResult minnaUtm;

  GnssPosition({
    required this.latitude,
    required this.longitude,
    required this.altitudeMsl,
    required this.geoidalSeparation,
    required this.ellipsoidalHeight,
    required this.fixQuality,
    required this.satellitesCount,
    required this.hdop,
    this.ageOfDifferential,
    this.diffStationId,
    required this.timestamp,
    required this.minnaUtm,
  });

  bool get isSurveyGrade => fixQuality == GnssFixQuality.rtkFixed;

  String get fixStatusLabel {
    switch (fixQuality) {
      case GnssFixQuality.rtkFixed:
        return 'RTK FIXED';
      case GnssFixQuality.rtkFloat:
        return 'RTK FLOAT';
      case GnssFixQuality.dgps:
        return 'DGPS';
      case GnssFixQuality.autonomous:
        return 'SINGLE (3D)';
      default:
        return 'NO FIX';
    }
  }
}

/// High-throughput NMEA-0183 Parser tailored for GNSS RTK Survey Receivers
/// (South, Emlid Reach, Trimble, Stonex, CHCNAV, Hi-Target)
class NmeaParser {
  final int defaultUtmZone;
  final double dx;
  final double dy;
  final double dz;

  NmeaParser({
    this.defaultUtmZone = 32,
    this.dx = GeodeticConstants.nationalDx,
    this.dy = GeodeticConstants.nationalDy,
    this.dz = GeodeticConstants.nationalDz,
  });

  /// Validates NMEA checksum: XOR of all characters between '$' and '*'
  static bool validateChecksum(String sentence) {
    final clean = sentence.trim();
    if (!clean.startsWith(r'$') && !clean.startsWith('!')) return false;

    final starIndex = clean.lastIndexOf('*');
    if (starIndex == -1 || starIndex + 3 > clean.length) return false;

    final sentenceData = clean.substring(1, starIndex);
    final expectedHex = clean.substring(starIndex + 1, starIndex + 3);
    final expectedChecksum = int.tryParse(expectedHex, radix: 16);
    if (expectedChecksum == null) return false;

    int computedChecksum = 0;
    for (int i = 0; i < sentenceData.length; i++) {
      computedChecksum ^= sentenceData.codeUnitAt(i);
    }

    return computedChecksum == expectedChecksum;
  }

  /// Parses an incoming NMEA sentence (specifically $GNGGA / $GPGGA) and projects to Minna UTM
  GnssPosition? parseGga(String sentence, {int? forceZone}) {
    final clean = sentence.trim();
    if (!clean.contains('GGA')) return null;

    // Checksum verification
    if (clean.contains('*') && !validateChecksum(clean)) {
      return null;
    }

    // Split sentence tokens
    final body = clean.contains('*') ? clean.substring(0, clean.indexOf('*')) : clean;
    final tokens = body.split(',');
    if (tokens.length < 15) return null;

    // 1. UTC Time (hhmmss.ss)
    final timeStr = tokens[1];
    DateTime time = DateTime.now().toUtc();
    if (timeStr.length >= 6) {
      final h = int.tryParse(timeStr.substring(0, 2)) ?? 0;
      final m = int.tryParse(timeStr.substring(2, 4)) ?? 0;
      final s = int.tryParse(timeStr.substring(4, 6)) ?? 0;
      time = DateTime.utc(time.year, time.month, time.day, h, m, s);
    }

    // 2. Latitude (ddmm.mmmmm)
    final latStr = tokens[2];
    final latHem = tokens[3].toUpperCase();
    if (latStr.isEmpty || (latHem != 'N' && latHem != 'S')) return null;
    final latDeg = _parseNmeaCoord(latStr, 2, latHem == 'S');

    // 3. Longitude (dddmm.mmmmm)
    final lonStr = tokens[4];
    final lonHem = tokens[5].toUpperCase();
    if (lonStr.isEmpty || (lonHem != 'E' && lonHem != 'W')) return null;
    final lonDeg = _parseNmeaCoord(lonStr, 3, lonHem == 'W');

    // 4. Fix Quality (0 - 8)
    final fixIndicator = int.tryParse(tokens[6]) ?? 0;
    final fixQuality = _mapFixQuality(fixIndicator);

    // 5. Satellites in use
    final satellites = int.tryParse(tokens[7]) ?? 0;

    // 6. HDOP
    final hdop = double.tryParse(tokens[8]) ?? 99.9;

    // 7. Orthometric MSL Altitude
    final altitudeMsl = double.tryParse(tokens[9]) ?? 0.0;

    // 8. Geoidal Separation
    final geoidalSep = double.tryParse(tokens[11]) ?? 0.0;
    final ellipsoidalH = altitudeMsl + geoidalSep;

    // 9. Age of Differential corrections
    final diffAge = tokens[13].isNotEmpty ? double.tryParse(tokens[13]) : null;
    final diffStation = tokens[14].isNotEmpty ? tokens[14] : null;

    // 10. Real-time projection to Minna UTM
    final zone = forceZone ?? GeodeticConstants.detectZoneFromLongitude(lonDeg);
    final utm = CoordinateConverter.wgs84ToMinnaUtm(
      latDeg: latDeg,
      lonDeg: lonDeg,
      height: ellipsoidalH,
      overrideZone: zone,
      dx: dx,
      dy: dy,
      dz: dz,
    );

    return GnssPosition(
      latitude: latDeg,
      longitude: lonDeg,
      altitudeMsl: altitudeMsl,
      geoidalSeparation: geoidalSep,
      ellipsoidalHeight: ellipsoidalH,
      fixQuality: fixQuality,
      satellitesCount: satellites,
      hdop: hdop,
      ageOfDifferential: diffAge,
      diffStationId: diffStation,
      timestamp: time,
      minnaUtm: utm,
    );
  }

  /// Converts NMEA coordinate format (DDMM.MMMM or DDDMM.MMMM) to Decimal Degrees
  static double _parseNmeaCoord(String raw, int degreeDigits, bool isNegative) {
    if (raw.length <= degreeDigits) return 0.0;
    final deg = double.parse(raw.substring(0, degreeDigits));
    final min = double.parse(raw.substring(degreeDigits));
    final decDeg = deg + (min / 60.0);
    return isNegative ? -decDeg : decDeg;
  }

  static GnssFixQuality _mapFixQuality(int indicator) {
    switch (indicator) {
      case 1:
        return GnssFixQuality.autonomous;
      case 2:
        return GnssFixQuality.dgps;
      case 3:
        return GnssFixQuality.pps;
      case 4:
        return GnssFixQuality.rtkFixed;
      case 5:
        return GnssFixQuality.rtkFloat;
      case 6:
        return GnssFixQuality.estimated;
      case 7:
        return GnssFixQuality.manual;
      case 8:
        return GnssFixQuality.simulation;
      default:
        return GnssFixQuality.invalid;
    }
  }

  /// Formats Decimal Degrees into standard NMEA coordinate string (for sending client GGA to NTRIP Casters)
  static String formatGgaFeedback({
    required double latitude,
    required double longitude,
    double altitude = 0.0,
  }) {
    final now = DateTime.now().toUtc();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.00';

    final absLat = latitude.abs();
    final latDeg = absLat.floor();
    final latMin = (absLat - latDeg) * 60.0;
    final latStr = '${latDeg.toString().padLeft(2, '0')}${latMin.toStringAsFixed(5).padLeft(8, '0')}';
    final latHem = latitude >= 0 ? 'N' : 'S';

    final absLon = longitude.abs();
    final lonDeg = absLon.floor();
    final lonMin = (absLon - lonDeg) * 60.0;
    final lonStr = '${lonDeg.toString().padLeft(3, '0')}${lonMin.toStringAsFixed(5).padLeft(8, '0')}';
    final lonHem = longitude >= 0 ? 'E' : 'W';

    final sentenceWithoutChecksum = 'GPGGA,$timeStr,$latStr,$latHem,$lonStr,$lonHem,1,08,1.0,${altitude.toStringAsFixed(1)},M,0.0,M,,';

    int checksum = 0;
    for (int i = 0; i < sentenceWithoutChecksum.length; i++) {
      checksum ^= sentenceWithoutChecksum.codeUnitAt(i);
    }
    final hexChecksum = checksum.toRadixString(16).toUpperCase().padLeft(2, '0');

    return '\$$sentenceWithoutChecksum*$hexChecksum\r\n';
  }
}
