import 'package:flutter/material.dart';
import '../../core/utils/coordinate_converter.dart';
import '../../data/models/job_model.dart';
import '../../data/models/survey_point_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../theme/app_theme.dart';

class AddPointScreen extends StatefulWidget {
  final JobModel job;

  const AddPointScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<AddPointScreen> createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final _formKey = GlobalKey<FormState>();
  final SurveyRepository _repository = SurveyRepository();

  final _nameController = TextEditingController();
  final _eastingController = TextEditingController();
  final _northingController = TextEditingController();
  final _heightController = TextEditingController(text: '0.000');

  PointType _selectedType = PointType.BEACON;
  bool _isSaving = false;

  // Real-time converted WGS84 preview
  GeographicResult? _wgs84Preview;
  String? _validationWarning;

  @override
  void initState() {
    super.initState();
    _suggestNextBeacon();
    _eastingController.addListener(_updateRealtimePreview);
    _northingController.addListener(_updateRealtimePreview);
  }

  Future<void> _suggestNextBeacon() async {
    final nextName = await _repository.getSuggestedNextBeaconName(widget.job.id);
    _nameController.text = nextName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _eastingController.dispose();
    _northingController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateRealtimePreview() {
    final easting = double.tryParse(_eastingController.text.trim());
    final northing = double.tryParse(_northingController.text.trim());

    if (easting != null && northing != null) {
      // Validate bounds for Nigerian grid
      String? warning;
      if (easting < 100000 || easting > 900000) {
        warning = 'Easting $easting is outside typical Nigerian zone width (100k - 900k m).';
      } else if (northing < 400000 || northing > 1600000) {
        warning = 'Northing $northing is outside Nigeria latitudes 4°N-14°N (400k - 1,600k m).';
      }

      try {
        final result = CoordinateConverter.minnaUtmToWgs84(
          easting: easting,
          northing: northing,
          zone: widget.job.zone,
        );
        setState(() {
          _wgs84Preview = result;
          _validationWarning = warning;
        });
      } catch (e) {
        setState(() {
          _wgs84Preview = null;
          _validationWarning = 'Calculation error with current values';
        });
      }
    } else {
      setState(() {
        _wgs84Preview = null;
        _validationWarning = null;
      });
    }
  }

  Future<void> _savePoint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final easting = double.parse(_eastingController.text.trim());
      final northing = double.parse(_northingController.text.trim());
      final height = double.tryParse(_heightController.text.trim()) ?? 0.0;

      await _repository.addPoint(
        jobId: widget.job.id,
        ptName: _nameController.text.trim(),
        easting: easting,
        northing: northing,
        height: height,
        ptType: _selectedType,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving point: $e'),
          backgroundColor: AppTheme.crimsonPrimary,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LOG BEACON (${widget.job.jobNum})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Point Designation & Type
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Beacon ID / Point Name *',
                        hintText: 'e.g. P1 or BM01',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Point ID required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<PointType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Point Classification',
                      ),
                      items: PointType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name.replaceAll('_', ' ')),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Grid Coordinates (Minna UTM)
              const Text(
                'GRID COORDINATES (METERS)',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _eastingController,
                decoration: const InputDecoration(
                  labelText: 'Easting (X Coordinate) *',
                  hintText: 'e.g. 542310.450',
                  suffixText: 'm',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Easting is required';
                  if (double.tryParse(val) == null) return 'Must be a valid decimal number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _northingController,
                decoration: const InputDecoration(
                  labelText: 'Northing (Y Coordinate) *',
                  hintText: 'e.g. 718940.120',
                  suffixText: 'm',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Northing is required';
                  if (double.tryParse(val) == null) return 'Must be a valid decimal number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Elevation / Orthometric Height (Z)',
                  hintText: 'e.g. 245.180',
                  suffixText: 'm',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),

              // Visual Range Warning Box
              if (_validationWarning != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.amberWarning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.amberWarning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.amberWarning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationWarning!,
                          style: const TextStyle(color: AppTheme.amberWarning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Real-Time WGS84 Geodetic Verification Card
              if (_wgs84Preview != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardNavy,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.strokeNavy),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.check_circle_outline, color: AppTheme.emeraldSuccess, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'WGS84 GPS EQUIVALENT (CALCULATED)',
                            style: TextStyle(
                              color: AppTheme.emeraldSuccess,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Latitude:  ${_wgs84Preview!.latitude.toStringAsFixed(7)}° N',
                        style: const TextStyle(
                          color: AppTheme.pureWhite,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Longitude: ${_wgs84Preview!.longitude.toStringAsFixed(7)}° E',
                        style: const TextStyle(
                          color: AppTheme.pureWhite,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePoint,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppTheme.pureWhite)
                      : const Text('RECORD BEACON COORDINATE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
