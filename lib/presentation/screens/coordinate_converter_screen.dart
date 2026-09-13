import 'package:flutter/material.dart';
import '../../core/constants/geodetic_constants.dart';
import '../../core/utils/coordinate_converter.dart';
import '../theme/app_theme.dart';

class CoordinateConverterScreen extends StatefulWidget {
  const CoordinateConverterScreen({Key? key}) : super(key: key);

  @override
  State<CoordinateConverterScreen> createState() => _CoordinateConverterScreenState();
}

class _CoordinateConverterScreenState extends State<CoordinateConverterScreen> {
  bool _isWgsToMinna = true; // true: WGS84 -> Minna UTM, false: Minna UTM -> WGS84

  // Inputs for WGS84 -> Minna
  final _latController = TextEditingController(text: '9.076500'); // Abuja FCT default
  final _lonController = TextEditingController(text: '7.398600');
  final _hController = TextEditingController(text: '480.0');

  // Inputs for Minna -> WGS84
  final _eastingController = TextEditingController(text: '323945.120');
  final _northingController = TextEditingController(text: '1003620.450');
  int _selectedZone = 32;

  // Custom Datum Shifts (Default: National Nigerian Shifts)
  double _dx = GeodeticConstants.nationalDx;
  double _dy = GeodeticConstants.nationalDy;
  double _dz = GeodeticConstants.nationalDz;

  String? _outputResult;

  @override
  void initState() {
    super.initState();
    _performConversion();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _hController.dispose();
    _eastingController.dispose();
    _northingController.dispose();
    super.dispose();
  }

  void _performConversion() {
    try {
      if (_isWgsToMinna) {
        final lat = double.parse(_latController.text.trim());
        final lon = double.parse(_lonController.text.trim());
        final h = double.tryParse(_hController.text.trim()) ?? 0.0;

        final result = CoordinateConverter.wgs84ToMinnaUtm(
          latDeg: lat,
          lonDeg: lon,
          height: h,
          dx: _dx,
          dy: _dy,
          dz: _dz,
        );

        setState(() {
          _outputResult = '''
PROJECTION: Transverse Mercator
DATUM: Minna Datum 1965 (Clarke 1880 RGS)
UTM ZONE: ${result.zone}N (Central Meridian: ${GeodeticConstants.centralMeridianForZone(result.zone)}°E)

EASTING (X):  ${result.easting.toStringAsFixed(3)} m
NORTHING (Y): ${result.northing.toStringAsFixed(3)} m

DATUM SHIFT APPLIED:
ΔX: ${_dx.toStringAsFixed(1)} m | ΔY: ${_dy.toStringAsFixed(1)} m | ΔZ: ${_dz.toStringAsFixed(1)} m
''';
        });
      } else {
        final easting = double.parse(_eastingController.text.trim());
        final northing = double.parse(_northingController.text.trim());

        final result = CoordinateConverter.minnaUtmToWgs84(
          easting: easting,
          northing: northing,
          zone: _selectedZone,
          dx: _dx,
          dy: _dy,
          dz: _dz,
        );

        setState(() {
          _outputResult = '''
COORDINATE SYSTEM: WGS84 Geographic (GPS)
DATUM: WGS84 (EPSG:4326)

LATITUDE:  ${result.latitude.toStringAsFixed(7)}° N
LONGITUDE: ${result.longitude.toStringAsFixed(7)}° E
HEIGHT:    ${result.height.toStringAsFixed(3)} m

DATUM SHIFT APPLIED:
ΔX: ${_dx.toStringAsFixed(1)} m | ΔY: ${_dy.toStringAsFixed(1)} m | ΔZ: ${_dz.toStringAsFixed(1)} m
''';
        });
      }
    } catch (e) {
      setState(() {
        _outputResult = 'Error calculating coordinates: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COORDINATE CONVERTER'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Toggle Switch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.strokeNavy),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isWgsToMinna = true);
                        _performConversion();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isWgsToMinna ? AppTheme.crimsonPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'WGS84 -> MINNA UTM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.pureWhite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isWgsToMinna = false);
                        _performConversion();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isWgsToMinna ? AppTheme.crimsonPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'MINNA UTM -> WGS84',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.pureWhite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isWgsToMinna) ...[
              const Text(
                'INPUT WGS84 GPS COORDINATES (DECIMAL DEGREES)',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _latController,
                decoration: const InputDecoration(labelText: 'Latitude (° N)', hintText: 'e.g. 9.076500'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _lonController,
                decoration: const InputDecoration(labelText: 'Longitude (° E)', hintText: 'e.g. 7.398600'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _hController,
                decoration: const InputDecoration(labelText: 'Ellipsoidal Height (m)', hintText: 'e.g. 480.0'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ] else ...[
              const Text(
                'INPUT MINNA UTM GRID COORDINATES',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _selectedZone,
                decoration: const InputDecoration(labelText: 'UTM Zone Sector'),
                items: const [
                  DropdownMenuItem(value: 31, child: Text('Zone 31N (CM: 3°E - Western Nigeria)')),
                  DropdownMenuItem(value: 32, child: Text('Zone 32N (CM: 9°E - Central Nigeria)')),
                  DropdownMenuItem(value: 33, child: Text('Zone 33N (CM: 15°E - Eastern Nigeria)')),
                ],
                onChanged: (val) => setState(() => _selectedZone = val!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _eastingController,
                decoration: const InputDecoration(labelText: 'Easting (m)', hintText: 'e.g. 323945.120'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _northingController,
                decoration: const InputDecoration(labelText: 'Northing (m)', hintText: 'e.g. 1003620.450'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync_alt),
                label: const Text('CALCULATE TRANSFORMATION'),
                onPressed: _performConversion,
              ),
            ),
            const SizedBox(height: 24),

            // Results Display Card
            if (_outputResult != null) ...[
              const Text(
                'TRANSFORMATION OUTPUT',
                style: TextStyle(
                  color: AppTheme.pureWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.strokeNavy),
                ),
                child: Text(
                  _outputResult!,
                  style: const TextStyle(
                    color: AppTheme.pureWhite,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
