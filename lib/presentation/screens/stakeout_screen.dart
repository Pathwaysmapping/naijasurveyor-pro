import 'package:flutter/material.dart';
import '../../core/bluetooth/gnss_device_manager.dart';
import '../../core/nmea/nmea_parser.dart';
import '../../core/stakeout/stakeout_engine.dart';
import '../../data/models/job_model.dart';
import '../../data/models/survey_point_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/stakeout_bullseye.dart';
import '../widgets/zone_badge.dart';

class StakeoutScreen extends StatefulWidget {
  final JobModel job;
  final SurveyPointModel? initialTargetPoint;

  const StakeoutScreen({
    Key? key,
    required this.job,
    this.initialTargetPoint,
  }) : super(key: key);

  @override
  State<StakeoutScreen> createState() => _StakeoutScreenState();
}

class _StakeoutScreenState extends State<StakeoutScreen> {
  final GnssDeviceManager _deviceManager = GnssDeviceManager.instance;
  final SurveyRepository _repository = SurveyRepository();

  List<SurveyPointModel> _availablePoints = [];
  SurveyPointModel? _selectedPoint;

  // Custom manual coordinate input controllers
  final _manualEastingController = TextEditingController();
  final _manualNorthingController = TextEditingController();
  final _manualHeightController = TextEditingController(text: '0.000');
  bool _isManualTarget = false;

  GnssPosition? _currentPosition;
  StakeoutCalculation? _calculation;
  bool _isSavingLog = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialTargetPoint;
    _currentPosition = _deviceManager.currentPosition;
    _loadJobPoints();

    _deviceManager.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _updateCalculation();
        });
      }
    });

    _updateCalculation();
  }

  @override
  void dispose() {
    _manualEastingController.dispose();
    _manualNorthingController.dispose();
    _manualHeightController.dispose();
    super.dispose();
  }

  Future<void> _loadJobPoints() async {
    final points = await _repository.getPointsForJob(widget.job.id);
    if (mounted) {
      setState(() {
        _availablePoints = points;
        if (_selectedPoint == null && points.isNotEmpty) {
          _selectedPoint = points.first;
          _updateCalculation();
        }
      });
    }
  }

  void _updateCalculation() {
    if (_currentPosition == null) return;

    double targetE = 0;
    double targetN = 0;
    double targetH = 0;

    if (_isManualTarget) {
      targetE = double.tryParse(_manualEastingController.text.trim()) ?? 0;
      targetN = double.tryParse(_manualNorthingController.text.trim()) ?? 0;
      targetH = double.tryParse(_manualHeightController.text.trim()) ?? 0;
    } else if (_selectedPoint != null) {
      targetE = _selectedPoint!.easting;
      targetN = _selectedPoint!.northing;
      targetH = _selectedPoint!.height;
    } else {
      return;
    }

    final calc = StakeoutEngine.calculate(
      currentEasting: _currentPosition!.minnaUtm.easting,
      currentNorthing: _currentPosition!.minnaUtm.northing,
      currentHeight: _currentPosition!.altitudeMsl,
      targetEasting: targetE,
      targetNorthing: targetN,
      targetHeight: targetH,
    );

    setState(() => _calculation = calc);
  }

  Future<void> _recordStakeoutLog() async {
    if (_currentPosition == null || _calculation == null) return;

    setState(() => _isSavingLog = true);
    try {
      final name = _isManualTarget ? 'STK_CUSTOM' : 'STK_${_selectedPoint!.ptName}';
      await _repository.addPoint(
        jobId: widget.job.id,
        ptName: name,
        easting: _currentPosition!.minnaUtm.easting,
        northing: _currentPosition!.minnaUtm.northing,
        height: _currentPosition!.altitudeMsl,
        ptType: PointType.OFFSET,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stakeout point $name logged with residual of ${_calculation!.distance.toStringAsFixed(3)} m!'),
            backgroundColor: AppTheme.emeraldSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.crimsonPrimary),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingLog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PILLAR TRACING & STAKEOUT'),
        actions: [
          IconButton(
            icon: Icon(_isManualTarget ? Icons.list_alt : Icons.edit_note),
            tooltip: _isManualTarget ? 'Pick From Job Beacons' : 'Enter Manual Coordinate',
            onPressed: () {
              setState(() {
                _isManualTarget = !_isManualTarget;
                _updateCalculation();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Selection Bar
            _buildTargetSelector(),
            const SizedBox(height: 16),

            // Stakeout Bullseye Compass Canvas
            if (_calculation != null)
              StakeoutBullseye(calculation: _calculation!, size: 260)
            else
              _buildNoFixPlaceholder(),
            const SizedBox(height: 20),

            // Main Distance & Navigation Metrics
            if (_calculation != null) ...[
              _buildDistanceReadoutCard(),
              const SizedBox(height: 14),
              _buildDeltaOffsetsGrid(),
              const SizedBox(height: 20),

              // Log Stakeout Verification Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.verified),
                  label: _isSavingLog
                      ? const CircularProgressIndicator(color: AppTheme.pureWhite)
                      : Text(
                          _calculation!.isTargetReached
                              ? 'CONFIRM PILLAR PLACED / LOG (2CM TOLERANCE)'
                              : 'LOG STAKEOUT RECORD (RESIDUAL: ${_calculation!.distance.toStringAsFixed(2)}m)',
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _calculation!.isTargetReached
                        ? AppTheme.emeraldSuccess
                        : AppTheme.crimsonPrimary,
                  ),
                  onPressed: _isSavingLog ? null : _recordStakeoutLog,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isManualTarget ? 'MANUAL TARGET INPUT' : 'TARGET BEACON MONUMENT',
                style: const TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              ZoneBadge(zone: widget.job.zone, datum: widget.job.datum),
            ],
          ),
          const SizedBox(height: 10),
          if (!_isManualTarget) ...[
            if (_availablePoints.isEmpty)
              const Text(
                'No beacons in active job. Switch to manual coordinate entry above.',
                style: TextStyle(color: AppTheme.slateMuted, fontSize: 12),
              )
            else
              DropdownButtonFormField<SurveyPointModel>(
                value: _selectedPoint,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _availablePoints.map((pt) {
                  return DropdownMenuItem(
                    value: pt,
                    child: Text(
                      '${pt.ptName} — E: ${pt.easting.toStringAsFixed(1)}m, N: ${pt.northing.toStringAsFixed(1)}m',
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedPoint = val;
                    _updateCalculation();
                  });
                },
              ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _manualEastingController,
                    decoration: const InputDecoration(labelText: 'Target Easting (m)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _updateCalculation(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _manualNorthingController,
                    decoration: const InputDecoration(labelText: 'Target Northing (m)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _updateCalculation(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoFixPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.satellite_alt_outlined, size: 48, color: AppTheme.slateMuted),
            SizedBox(height: 12),
            Text(
              'Awaiting GNSS Rover Position...',
              style: TextStyle(color: AppTheme.slateText, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Ensure Bluetooth RTK receiver or Simulator is active.',
              style: TextStyle(color: AppTheme.slateMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceReadoutCard() {
    final reached = _calculation!.isTargetReached;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: reached ? AppTheme.emeraldSuccess.withOpacity(0.15) : AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: reached ? AppTheme.emeraldSuccess : AppTheme.strokeNavy,
          width: reached ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            reached ? 'TARGET MONUMENT REACHED' : 'HORIZONTAL DISTANCE TO TARGET',
            style: TextStyle(
              color: reached ? AppTheme.emeraldSuccess : AppTheme.slateMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_calculation!.distance.toStringAsFixed(3)} m',
            style: TextStyle(
              color: reached ? AppTheme.emeraldSuccess : AppTheme.pureWhite,
              fontFamily: 'monospace',
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _calculation!.directionInstructions,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: reached ? AppTheme.emeraldSuccess : AppTheme.crimsonAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaOffsetsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildOffsetTile('DELTA NORTH (ΔN)', '${_calculation!.deltaNorthing.toStringAsFixed(3)} m'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildOffsetTile('DELTA EAST (ΔE)', '${_calculation!.deltaEasting.toStringAsFixed(3)} m'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildOffsetTile('BEARING (AZIMUTH)', _calculation!.bearingDms),
        ),
      ],
    );
  }

  Widget _buildOffsetTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.slateMuted, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.pureWhite,
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
