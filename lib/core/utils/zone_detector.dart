import '../constants/geodetic_constants.dart';

class ZoneDetector {
  /// Detects the UTM zone from longitude and returns information about coverage
  static Map<String, dynamic> getZoneDetails(double longitude) {
    final zone = GeodeticConstants.detectZoneFromLongitude(longitude);
    final cm = GeodeticConstants.centralMeridianForZone(zone);

    String states = '';
    switch (zone) {
      case 31:
        states = 'Lagos, Ogun, Oyo, Osun, Ondo, Ekiti, Kwara (West)';
        break;
      case 32:
        states = 'Abuja FCT, Edo, Delta, Rivers, Kano, Kaduna, Niger, Plateau, Enugu, Imo, Anambra';
        break;
      case 33:
        states = 'Borno, Adamawa, Taraba, Yobe, Cross River (East), Calabar';
        break;
    }

    return {
      'zone': zone,
      'centralMeridian': cm,
      'epsg': 'EPSG:263$zone',
      'commonStates': states,
      'meridianRange': '${zone == 31 ? 0 : (zone == 32 ? 6 : 12)}°E to ${zone == 31 ? 6 : (zone == 32 ? 12 : 18)}°E',
    };
  }
}
