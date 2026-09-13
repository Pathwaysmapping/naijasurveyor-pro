import 'package:flutter/material.dart';
import '../../core/bluetooth/gnss_device_manager.dart';
import '../../core/nmea/nmea_parser.dart';
import '../../core/ntrip/ntrip_client.dart';
import '../../data/models/job_model.dart';
import '../../data/models/survey_point_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/zone_badge.dart';
import 'ntrip_settings_screen.dart';

class RtkStatusScreen extends StatefulWidget {
  final JobModel? activeJob;

  const RtkStatusScreen({Key? key, this.activeJob}) : super(key: key);

  @override
  State<RtkStatusScreen> createState() => _RtkStatusScreenState();
}

class _RtkStatusScreenState extends State<RtkStatusScreen> {
  final GnssDeviceManager _deviceManager = GnssDeviceManager.instance;
  final SurveyRepository _repository = SurveyRepository();

  GnssPosition? _position;
  GnssConnectionState _connectionState = GnssConnectionState.disconnected;
  NtripState _ntripState = NtripState.disconnected;
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _position = _deviceManager.currentPosition;
    _connectionState = _deviceManager.currentState;
    _ntripState = _deviceManager.ntripClient.currentState;

    _deviceManager.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _deviceManager.stateStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });

    _deviceManager.ntripClient.stateStream.listen((state) {
      if (mounted) setState(() => _ntripState = state);
    });
  }

  Future<void> _logCurrentPoint() async {
    if (widget.activeJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active job container selected. Open a job to log beacons.'),
          backgroundColor: AppTheme.amberWarning,
        ),
      );
      return;
    }

    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No GNSS coordinate lock available.'),
          backgroundColor: AppTheme.crimsonPrimary,
        ),
      );
      return;
    }

    setState(() => _isLogging = true);
    try {
      final nextName = await _repository.getSuggestedNextBeaconName(widget.activeJob!.id);
      await _repository.addPoint(
        jobId: widget.activeJob!.id,
        ptName: nextName,
        easting: _position!.minnaUtm.easting,
        northing: _position!.minnaUtm.northing,
        height: _position!.altitudeMsl,
        ptType: PointType.BEACON,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beacon $nextName logged successfully at RTK precision!'),
            backgroundColor: AppTheme.emeraldSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging beacon: $e'),
            backgroundColor: AppTheme.crimsonPrimary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTK GNSS RECEIVER & NTRIP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_input_antenna),
            tooltip: 'NTRIP Caster Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NtripSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fix Quality Header Banner
            _buildFixStatusBanner(),
            const SizedBox(height: 16),

            // Real-Time Minna UTM Coordinate Display Card
            _buildMinnaCoordinateCard(),
            const SizedBox(height: 16),

            // GNSS Geodetic & Accuracy Metrics
            _buildMetricsGrid(),
            const SizedBox(height: 16),

            // Hardware & NTRIP Connection Control Card
            _buildHardwareControlCard(),
            const SizedBox(height: 24),

            // Action: Log Beacon Button
            if (widget.activeJob != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_location_alt),
                  label: _isLogging
                      ? const CircularProgressIndicator(color: AppTheme.pureWhite)
                      : Text('RECORD CURRENT RTK BEACON (${widget.activeJob!.jobNum})'),
                  onPressed: (_position != null && !_isLogging) ? _logCurrentPoint : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixStatusBanner() {
    Color bannerColor = AppTheme.slateMuted;
    String label = 'DISCONNECTED';

    if (_connectionState == GnssConnectionState.simulating ||
        _connectionState == GnssConnectionState.connected) {
      if (_position != null) {
        label = _position!.fixStatusLabel;
        switch (_position!.fixQuality) {
          case GnssFixQuality.rtkFixed:
            bannerColor = AppTheme.emeraldSuccess;
            break;
          case GnssFixQuality.rtkFloat:
            bannerColor = AppTheme.amberWarning;
            break;
          case GnssFixQuality.autonomous:
          case GnssFixQuality.dgps:
            bannerColor = const Color(0xFF3B82F6); // Blue
            break;
          default:
            bannerColor = AppTheme.crimsonPrimary;
        }
      } else {
        label = 'WAITING FOR NMEA LOCK...';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: bannerColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            _position != null ? 'HDOP: ${_position!.hdop.toStringAsFixed(1)}' : '',
            style: const TextStyle(color: AppTheme.pureWhite, fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildMinnaCoordinateCard() {
    final eastingStr = _position != null
        ? '${_position!.minnaUtm.easting.toStringAsFixed(3)} m'
        : '---.--- m';
    final northingStr = _position != null
        ? '${_position!.minnaUtm.northing.toStringAsFixed(3)} m'
        : '---.--- m';
    final heightStr = _position != null
        ? '${_position!.altitudeMsl.toStringAsFixed(3)} m'
        : '---.--- m';
    final zone = _position != null ? _position!.minnaUtm.zone : (widget.activeJob?.zone ?? 32);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MINNA DATUM 1965 GRID',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              ZoneBadge(zone: zone, datum: 'MINNA_UTM'),
            ],
          ),
          const SizedBox(height: 16),
          _buildBigCoordRow('EASTING (X)', eastingStr),
          const SizedBox(height: 12),
          _buildBigCoordRow('NORTHING (Y)', northingStr),
          const SizedBox(height: 12),
          _buildBigCoordRow('ELEVATION (MSL)', heightStr),
        ],
      ),
    );
  }

  Widget _buildBigCoordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.slateText, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.pureWhite,
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GNSS SATELLITE & FIX METRICS',
            style: TextStyle(
              color: AppTheme.slateMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'SATELLITES',
                  _position != null ? '${_position!.satellitesCount}' : '--',
                  Icons.satellite_alt_outlined,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'CORR. AGE',
                  _position?.ageOfDifferential != null
                      ? '${_position!.ageOfDifferential!.toStringAsFixed(1)}s'
                      : '--',
                  Icons.timer_outlined,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'NTRIP STATUS',
                  _ntripState.name.toUpperCase(),
                  Icons.cell_tower,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.slateMuted),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.slateMuted, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(color: AppTheme.pureWhite, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHardwareControlCard() {
    final isSimulating = _connectionState == GnssConnectionState.simulating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BLUETOOTH & RECEIVER CONTROLS',
            style: TextStyle(
              color: AppTheme.crimsonAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(isSimulating ? Icons.stop : Icons.play_arrow),
                  label: Text(isSimulating ? 'STOP SIMULATOR' : 'START SIMULATOR'),
                  onPressed: () {
                    if (isSimulating) {
                      _deviceManager.stopSimulation();
                    } else {
                      _deviceManager.startSimulation();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
