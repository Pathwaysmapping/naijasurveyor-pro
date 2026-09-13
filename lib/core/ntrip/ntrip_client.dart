import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum NtripState {
  disconnected,
  connecting,
  authorizing,
  streaming,
  reconnecting,
  error,
}

class NtripConfig {
  final String host;
  final int port;
  final String mountpoint;
  final String username;
  final String password;
  final bool sendGgaFeedback;
  final int ggaIntervalSeconds;

  const NtripConfig({
    required this.host,
    this.port = 2101,
    required this.mountpoint,
    this.username = '',
    this.password = '',
    this.sendGgaFeedback = true,
    this.ggaIntervalSeconds = 10,
  });

  Map<String, dynamic> toMap() => {
    'host': host,
    'port': port,
    'mountpoint': mountpoint,
    'username': username,
    'password': password,
    'send_gga': sendGgaFeedback ? 1 : 0,
    'gga_interval': ggaIntervalSeconds,
  };

  factory NtripConfig.fromMap(Map<String, dynamic> map) => NtripConfig(
    host: map['host'] as String,
    port: map['port'] as int,
    mountpoint: map['mountpoint'] as String,
    username: map['username'] as String? ?? '',
    password: map['password'] as String? ?? '',
    sendGgaFeedback: (map['send_gga'] as int? ?? 1) == 1,
    ggaIntervalSeconds: map['gga_interval'] as int? ?? 10,
  );
}

/// NTRIP 1.0/2.0 Client for connecting to CORS Casters
/// Streams differential RTCM 3.x correction bytes over TCP sockets
class NtripClient {
  Socket? _socket;
  NtripState _state = NtripState.disconnected;
  final _stateController = StreamController<NtripState>.broadcast();
  final _rtcmStreamController = StreamController<Uint8List>.broadcast();
  final _logController = StreamController<String>.broadcast();

  Timer? _ggaTimer;
  String? _lastGgaString;
  int _totalBytesReceived = 0;

  Stream<NtripState> get stateStream => _stateController.stream;
  Stream<Uint8List> get rtcmStream => _rtcmStreamController.stream;
  Stream<String> get logStream => _logController.stream;

  NtripState get currentState => _state;
  int get totalBytesReceived => _totalBytesReceived;

  void _setState(NtripState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _log(String msg) {
    _logController.add('[NTRIP ${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
  }

  /// Initiates connection and stream handshake with NTRIP Caster
  Future<bool> connect(NtripConfig config) async {
    if (_state == NtripState.streaming || _state == NtripState.connecting) {
      await disconnect();
    }

    _setState(NtripState.connecting);
    _log('Connecting to caster ${config.host}:${config.port}...');

    try {
      _socket = await Socket.connect(config.host, config.port, timeout: const Duration(seconds: 10));
      _setState(NtripState.authorizing);
      _log('Connected. Sending NTRIP GET request for mountpoint /${config.mountpoint}...');

      // Prepare NTRIP 1.0/2.0 GET request
      final authString = '${config.username}:${config.password}';
      final base64Auth = base64Encode(utf8.encode(authString));

      final request = StringBuffer();
      request.write('GET /${config.mountpoint} HTTP/1.0\r\n');
      request.write('User-Agent: NTRIP NaijaSurveyor/1.0\r\n');
      request.write('Accept: */*\r\n');
      request.write('Connection: close\r\n');
      if (config.username.isNotEmpty) {
        request.write('Authorization: Basic $base64Auth\r\n');
      }
      request.write('\r\n');

      _socket!.write(request.toString());
      await _socket!.flush();

      bool headerParsed = false;
      final headerBuffer = StringBuffer();

      _socket!.listen(
        (data) {
          if (!headerParsed) {
            // Read until HTTP header completion (\r\n\r\n)
            final text = latin1.decode(data);
            headerBuffer.write(text);
            final fullHeader = headerBuffer.toString();

            if (fullHeader.contains('\r\n\r\n') || fullHeader.contains('ICY 200 OK')) {
              headerParsed = true;
              _log('Handshake response: ${fullHeader.split("\r\n").first}');

              if (fullHeader.contains('200 OK')) {
                _setState(NtripState.streaming);
                _log('NTRIP Stream active. Receiving RTCM correction packets.');

                // Start periodic GGA position feedback if enabled
                if (config.sendGgaFeedback) {
                  _startGgaTimer(config.ggaIntervalSeconds);
                }

                // If data contains RTCM bytes after header, extract and emit
                final headerEndIndex = fullHeader.indexOf('\r\n\r\n');
                if (headerEndIndex != -1 && headerEndIndex + 4 < data.length) {
                  final remainingBytes = data.sublist(headerEndIndex + 4);
                  _totalBytesReceived += remainingBytes.length;
                  _rtcmStreamController.add(Uint8List.fromList(remainingBytes));
                }
              } else {
                _log('Caster rejected request: ${fullHeader.split("\r\n").first}');
                _setState(NtripState.error);
                disconnect();
              }
            }
          } else {
            // Streaming RTCM differential correction binary packets
            _totalBytesReceived += data.length;
            _rtcmStreamController.add(Uint8List.fromList(data));
          }
        },
        onError: (err) {
          _log('Socket stream error: $err');
          _setState(NtripState.error);
          disconnect();
        },
        onDone: () {
          _log('Connection closed by remote caster');
          _setState(NtripState.disconnected);
          _stopGgaTimer();
        },
      );

      return true;
    } catch (e) {
      _log('Connection failed: $e');
      _setState(NtripState.error);
      return false;
    }
  }

  /// Updates latest client position for GGA feedback reporting to Caster
  void updateClientPosition(String ggaString) {
    _lastGgaString = ggaString;
  }

  void _startGgaTimer(int intervalSeconds) {
    _stopGgaTimer();
    _ggaTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      if (_state == NtripState.streaming && _socket != null && _lastGgaString != null) {
        try {
          _socket!.write(_lastGgaString);
          _socket!.flush();
          _log('Sent GGA feedback to caster for VRS positioning.');
        } catch (e) {
          _log('Failed to send GGA feedback: $e');
        }
      }
    });
  }

  void _stopGgaTimer() {
    _ggaTimer?.cancel();
    _ggaTimer = null;
  }

  Future<void> disconnect() async {
    _stopGgaTimer();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    _totalBytesReceived = 0;
    _setState(NtripState.disconnected);
    _log('Disconnected from NTRIP caster.');
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _rtcmStreamController.close();
    _logController.close();
  }
}
