import 'package:flutter/material.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../theme/app_theme.dart';

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({Key? key}) : super(key: key);

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final SurveyRepository _repository = SurveyRepository();

  final _jobNumController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();

  int _selectedZone = 32; // Default Central Zone (Abuja, Kano, etc.)
  String _selectedDatum = 'MINNA_UTM';
  bool _isSaving = false;

  final Map<int, String> _zoneDescriptions = {
    31: 'Zone 31N (0°E - 6°E): Lagos, Ogun, Oyo, Osun, Ondo, Ekiti, Kwara (West)',
    32: 'Zone 32N (6°E - 12°E): Abuja FCT, Edo, Delta, Rivers, Kano, Kaduna, Niger',
    33: 'Zone 33N (12°E - 18°E): Borno, Adamawa, Taraba, Yobe, Calabar / Cross River',
  };

  @override
  void initState() {
    super.initState();
    // Default job sequence suggestion
    final year = DateTime.now().year;
    final randNum = (100 + DateTime.now().millisecond % 900);
    _jobNumController.text = 'SURV/$year/$randNum';
  }

  @override
  void dispose() {
    _jobNumController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // 1. Create or save client
      final client = await _repository.createClient(
        name: _clientNameController.text.trim(),
        phone: _clientPhoneController.text.trim(),
      );

      // 2. Create job
      await _repository.createJob(
        clientId: client.id,
        jobNum: _jobNumController.text.trim(),
        zone: _selectedZone,
        datum: _selectedDatum,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving job: $e'),
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
        title: const Text('CREATE SURVEY JOB'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JOB DETAILS',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobNumController,
                decoration: const InputDecoration(
                  labelText: 'Job Assignment Number *',
                  hintText: 'e.g. SURV/2026/089',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Job number is mandatory' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'CLIENT INFORMATION',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Client or Company Name *',
                  hintText: 'e.g. Alhaji Musa Bello / Nestoil Ltd',
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Client name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clientPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number *',
                  hintText: 'e.g. +234 803 248 8965',
                ),
                keyboardType: TextInputType.phone,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Phone number is required' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'COORDINATE SYSTEM & UTM SECTOR',
                style: TextStyle(
                  color: AppTheme.crimsonAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Zone Selector Radio Tiles
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.strokeNavy),
                ),
                child: Column(
                  children: [31, 32, 33].map((zone) {
                    return RadioListTile<int>(
                      activeColor: AppTheme.crimsonPrimary,
                      value: zone,
                      groupValue: _selectedZone,
                      title: Text(
                        'UTM Zone ${zone}N',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        _zoneDescriptions[zone]!,
                        style: const TextStyle(color: AppTheme.slateText, fontSize: 11),
                      ),
                      onChanged: (val) => setState(() => _selectedZone = val!),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Datum Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDatum,
                decoration: const InputDecoration(
                  labelText: 'Primary Grid Datum',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'MINNA_UTM',
                    child: Text('Minna Datum (Clarke 1880 - National 1965)'),
                  ),
                  DropdownMenuItem(
                    value: 'WGS84_GEOGRAPHIC',
                    child: Text('WGS84 Geographic (GPS Standard)'),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedDatum = val!),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveJob,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppTheme.pureWhite)
                      : const Text('INITIALIZE JOB CONTAINER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
