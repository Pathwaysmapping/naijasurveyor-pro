import 'package:flutter/material.dart';
import '../../core/bluetooth/gnss_device_manager.dart';
import '../../core/ntrip/ntrip_client.dart';
import '../theme/app_theme.dart';

class NtripSettingsScreen extends StatefulWidget {
  const NtripSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NtripSettingsScreen> createState() => _NtripSettingsScreenState();
}

class _NtripSettingsScreenState extends State<NtripSettingsScreen> {
  final GnssDeviceManager _deviceManager = GnssDeviceManager.instance;

  final _hostController = TextEditingController(text: 'rtk.osgof.gov.ng');
  final _portController = TextEditingController(text: '2101');
  final _mountpointController = TextEditingController(text: 'ABUJA_RTCM32');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<String> _logs = [];
  NtripState _currentState = NtripState.disconnected;

  @override
  void initState() {
    super.initState();
    _currentState = _deviceManager.ntripClient.currentState;

    _deviceManager.ntripClient.stateStream.listen((state) {
      if (mounted) setState(() => _currentState = state);
    });

    _deviceManager.ntripClient.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.insert(0, log);
          if (_logs.length > 50) _logs.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _mountpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_currentState == NtripState.streaming || _currentState == NtripState.connecting) {
      await _deviceManager.stopNtripStream();
    } else {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 2101;
      final mount = _mountpointController.text.trim();
      final user = _usernameController.text.trim();
      final pass = _passwordController.text.trim();

      if (host.isEmpty || mount.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host and Mountpoint are required.'),
            backgroundColor: AppTheme.crimsonPrimary,
          ),
        );
        return;
      }

      final config = NtripConfig(
        host: host,
        port: port,
        mountpoint: mount,
        username: user,
        password: pass,
        sendGgaFeedback: true,
      );

      await _deviceManager.startNtripStream(config);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = _currentState == NtripState.streaming;
    final isConnecting = _currentState == NtripState.connecting || _currentState == NtripState.authorizing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NTRIP CASTER CONFIGURATION'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CORS CASTER CREDENTIALS',
              style: TextStyle(
                color: AppTheme.crimsonAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: 'Caster Host / IP *', hintText: 'e.g. 197.210.12.5'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: 'Port *', hintText: '2101'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mountpointController,
              decoration: const InputDecoration(
                labelText: 'Stream Mountpoint *',
                hintText: 'e.g. ABUJA_VRS or LAGOS_RTCM3',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Connect Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(isStreaming ? Icons.stop_circle_outlined : Icons.stream),
                label: Text(
                  isStreaming
                      ? 'DISCONNECT FROM CASTER'
                      : isConnecting
                          ? 'CONNECTING...'
                          : 'CONNECT & STREAM RTCM',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStreaming ? AppTheme.cardNavy : AppTheme.crimsonPrimary,
                ),
                onPressed: _toggleConnection,
              ),
            ),
            const SizedBox(height: 24),

            // Live Stream Monitor Log
            const Text(
              'LIVE NTRIP SOCKET MONITOR',
              style: TextStyle(
                color: AppTheme.pureWhite,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.strokeNavy),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No active NTRIP events',
                        style: TextStyle(color: AppTheme.slateMuted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: AppTheme.pureWhite,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
