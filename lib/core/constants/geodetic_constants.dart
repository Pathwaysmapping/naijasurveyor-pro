import 'dart:math' as math;

/// Geodetic Constants for the Nigerian Coordinate Reference System
/// - Ellipsoid: Clarke 1880 (RGS)
/// - Local Datum: Minna Datum (1965), Origin: Station L40 (Minna, Niger State)
/// - Global Datum: WGS84 (EPSG:4326)
/// - Projection: Transverse Mercator (UTM Zones 31N, 32N, 33N)
class GeodeticConstants {
  // =========================================================================
  // CLARKE 1880 (RGS) ELLIPSOID DEFINITION
  // =========================================================================
  /// Semi-major axis (meters)
  static const double clarke1880A = 6378249.145;

  /// Inverse flattening (1/f)
  static const double clarke1880InvF = 293.465;

  /// Flattening (f)
  static double get clarke1880F => 1.0 / clarke1880InvF;

  /// Semi-minor axis (b)
  static double get clarke1880B => clarke1880A * (1.0 - clarke1880F); // ~6356514.86955 m

  /// First eccentricity squared (e^2)
  static double get clarke1880E2 => (2.0 * clarke1880F) - (clarke1880F * clarke1880F); // ~0.006803511283

  /// Second eccentricity squared (e'^2)
  static double get clarke1880Ep2 => (clarke1880A * clarke1880A - clarke1880B * clarke1880B) / (clarke1880B * clarke1880B);

  // =========================================================================
  // WGS84 ELLIPSOID DEFINITION (GPS STANDARD)
  // =========================================================================
  /// Semi-major axis (meters)
  static const double wgs84A = 6378137.0;

  /// Inverse flattening (1/f)
  static const double wgs84InvF = 298.257223563;

  /// Flattening (f)
  static double get wgs84F => 1.0 / wgs84InvF;

  /// Semi-minor axis (b)
  static double get wgs84B => wgs84A * (1.0 - wgs84F); // ~6356752.3142 m

  /// First eccentricity squared (e^2)
  static double get wgs84E2 => (2.0 * wgs84F) - (wgs84F * wgs84F); // ~0.00669437999014

  /// Second eccentricity squared (e'^2)
  static double get wgs84Ep2 => (wgs84A * wgs84A - wgs84B * wgs84B) / (wgs84B * wgs84B);

  // =========================================================================
  // NATIONAL NIGERIAN 3-PARAMETER DATUM SHIFTS (Minna -> WGS84)
  // Source: DMA / Federal Surveys of Nigeria
  // =========================================================================
  static const double nationalDx = -92.0; // meters (±3m)
  static const double nationalDy = -93.0; // meters (±6m)
  static const double nationalDz = 122.0; // meters (±5m)

  // =========================================================================
  // UTM PROJECTION PARAMETERS (NIGERIAN ZONES)
  // =========================================================================
  /// Central scale factor (k0)
  static const double utmK0 = 0.9996;

  /// False Easting (meters)
  static const double falseEasting = 500000.0;

  /// False Northing (meters) - Northern hemisphere
  static const double falseNorthing = 0.0;

  /// Central Meridians (degrees East)
  static const double centralMeridianZone31 = 3.0;  // Zone 31N: 0°E - 6°E (Lagos, Ogun, Oyo, Osun, Ondo, Ekiti, Kwara)
  static const double centralMeridianZone32 = 9.0;  // Zone 32N: 6°E - 12°E (Abuja, Edo, Delta, Rivers, Kano, Kaduna, Niger)
  static const double centralMeridianZone33 = 15.0; // Zone 33N: 12°E - 18°E (Maiduguri, Adamawa, Taraba, Calabar)

  /// Returns the Central Meridian (in degrees East) for a given UTM Zone
  static double centralMeridianForZone(int zone) {
    switch (zone) {
      case 31: return centralMeridianZone31;
      case 32: return centralMeridianZone32;
      case 33: return centralMeridianZone33;
      default: throw ArgumentError('Invalid Nigerian UTM Zone: $zone. Supported zones are 31, 32, and 33.');
    }
  }

  /// Automatically identifies the UTM zone from longitude
  static int detectZoneFromLongitude(double longitude) {
    if (longitude < 6.0) return 31;
    if (longitude < 12.0) return 32;
    return 33;
  }
}
