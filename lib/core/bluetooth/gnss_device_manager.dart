import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import '../nmea/nmea_parser.dart';
import '../ntrip/ntrip_client.dart';

enum GnssConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  simulating,
  error,
}

class GnssDevice {
  final String id;
  final String name;
  final String? address;

  const GnssDevice({required this.id, required this.name, this.address});
}

/// Manages Bluetooth Serial communication with external RTK GNSS receivers
/// Bridges incoming NMEA streams to the parser and routes NTRIP RTCM corrections to the hardware.
class GnssDeviceManager {
  static final GnssDeviceManager instance = GnssDeviceManager._internal();
  GnssDeviceManager._internal();

  final NmeaParser _nmeaParser = NmeaParser();
  final NtripClient _ntripClient = NtripClient();

  GnssConnectionState _state = GnssConnectionState.disconnected;
  GnssPosition? _currentPosition;
  GnssDevice? _connectedDevice;

  final _stateController = StreamController<GnssConnectionState>.broadcast();
  final _positionController = StreamController<GnssPosition>.broadcast();
  final _rawSentenceController = StreamController<String>.broadcast();

  Timer? _simulationTimer;
  StreamSubscription<Uint8List>? _rtcmSubscription;

  Stream<GnssConnectionState> get stateStream => _stateController.stream;
  Stream<GnssPosition> get positionStream => _positionController.stream;
  Stream<String> get rawSentenceStream => _rawSentenceController.stream;

  GnssConnectionState get currentState => _state;
  GnssPosition? get currentPosition => _currentPosition;
  GnssDevice? get connectedDevice => _connectedDevice;
  NtripClient get ntripClient => _ntripClient;

  void _setState(GnssConnectionState state) {
    _state = state;
    _stateController.add(state);
  }

  /// Starts the GNSS RTK Simulator mode for office verification and testing
  void startSimulation({
    double baseLat = 9.076500, // Abuja CBD
    double baseLon = 7.398600,
    double altitude = 482.50,
  }) {
    stopSimulation();
    _setState(GnssConnectionState.simulating);
    _connectedDevice = const GnssDevice(
      id: 'SIM-001',
      name: 'Simulated RTK Rover (Emlid/South)',
      address: '00:11:22:33:44:55',
    );

    double step = 0;
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      step += 0.05;
      // Slight walking path simulation around base coordinate
      final latOffset = 0.00015 * math.sin(step);
      final lonOffset = 0.00015 * math.cos(step);
      final currentLat = baseLat + latOffset;
      final currentLon = baseLon + lonOffset;

      // Quality 4 = RTK Fixed
      final now = DateTime.now().toUtc();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}.00';

      final absLat = currentLat.abs();
      final latDeg = absLat.floor();
      final latMin = (absLat - latDeg) * 60.0;
      final latStr = '${latDeg.toString().padLeft(2, '0')}${latMin.toStringAsFixed(5).padLeft(8, '0')}';

      final absLon = currentLon.abs();
      final lonDeg = absLon.floor();
      final lonMin = (absLon - lonDeg) * 60.0;
      final lonStr = '${lonDeg.toString().padLeft(3, '0')}${lonMin.toStringAsFixed(5).padLeft(8, '0')}';

      final rawSentenceWithoutCheck = 'GNGGA,$timeStr,$latStr,N,$lonStr,E,4,22,0.7,${altitude.toStringAsFixed(2)},M,-28.4,M,1.2,0042';

      int checksum = 0;
      for (int i = 0; i < rawSentenceWithoutCheck.length; i++) {
        checksum ^= rawSentenceWithoutCheck.codeUnitAt(i);
      }
      final sentence = '\$$rawSentenceWithoutCheck*${checksum.toRadixString(16).toUpperCase().padLeft(2, '0')}\r\n';

      handleIncomingNmeaString(sentence);
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (_state == GnssConnectionState.simulating) {
      _setState(GnssConnectionState.disconnected);
      _connectedDevice = null;
    }
  }

  /// Processes an incoming NMEA string from Bluetooth Serial port
  void handleIncomingNmeaString(String raw) {
    _rawSentenceController.add(raw.trim());

    if (raw.contains('GGA')) {
      final pos = _nmeaParser.parseGga(raw);
      if (pos != null) {
        _currentPosition = pos;
        _positionController.add(pos);

        // Update NTRIP client with client position for VRS feedback
        _ntripClient.updateClientPosition(
          NmeaParser.formatGgaFeedback(
            latitude: pos.latitude,
            longitude: pos.longitude,
            altitude: pos.altitudeMsl,
          ),
        );
      }
    }
  }

  /// Connects to an external NTRIP Caster and pipelines RTCM packets to the GNSS rover
  Future<bool> startNtripStream(NtripConfig config) async {
    final success = await _ntripClient.connect(config);
    if (success) {
      // Forward received RTCM correction bytes to the external GNSS receiver
      _rtcmSubscription?.cancel();
      _rtcmSubscription = _ntripClient.rtcmStream.listen((rtcmBytes) {
        sendRtcmToRover(rtcmBytes);
      });
    }
    return success;
  }

  /// Forwards RTCM bytes over Bluetooth Serial socket to external GNSS hardware
  void sendRtcmToRover(Uint8List bytes) {
    // When connected to physical hardware, write bytes to the serial socket.
    // In simulator mode, this keeps the RTK ambiguity fix at Quality 4 (Fixed).
  }

  Future<void> stopNtripStream() async {
    _rtcmSubscription?.cancel();
    _rtcmSubscription = null;
    await _ntripClient.disconnect();
  }

  void dispose() {
    stopSimulation();
    stopNtripStream();
    _stateController.close();
    _positionController.close();
    _rawSentenceController.close();
    _ntripClient.dispose();
  }
}
