import 'package:flutter/material.dart';
import '../../data/models/job_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/zone_badge.dart';
import 'new_job_screen.dart';
import 'job_detail_screen.dart';
import 'coordinate_converter_screen.dart';
import 'rtk_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SurveyRepository _repository = SurveyRepository();
  List<JobModel> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await _repository.getJobs();
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'NAIJASURVEYOR PRO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'Nigerian Cadastral & Geodetic System',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.slateText,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.satellite_alt_outlined, color: AppTheme.pureWhite),
            tooltip: 'RTK Receiver & NTRIP',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RtkStatusScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: AppTheme.pureWhite),
            tooltip: 'Minna <-> WGS84 Converter',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoordinateConverterScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.pureWhite),
            tooltip: 'Refresh',
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.crimsonPrimary))
          : _jobs.isEmpty
              ? _buildEmptyState()
              : _buildJobList(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.crimsonPrimary,
        foregroundColor: AppTheme.pureWhite,
        icon: const Icon(Icons.add),
        label: const Text('NEW SURVEY JOB', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewJobScreen()),
          );
          if (result == true) {
            _loadJobs();
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.strokeNavy),
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: AppTheme.slateMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Survey Jobs Recorded',
              style: TextStyle(
                color: AppTheme.pureWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a job container to begin logging beacons in Minna UTM Zone 31N, 32N, or 33N.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.slateText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('CREATE FIRST JOB'),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewJobScreen()),
                );
                if (result == true) _loadJobs();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobList() {
    return RefreshIndicator(
      onRefresh: _loadJobs,
      color: AppTheme.crimsonPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardNavy,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.strokeNavy),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Text(
                    job.jobNum,
                    style: const TextStyle(
                      color: AppTheme.pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  ZoneBadge(zone: job.zone, datum: job.datum),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.slateMuted),
                    const SizedBox(width: 4),
                    Text(
                      job.createdAt.substring(0, 10),
                      style: const TextStyle(color: AppTheme.slateMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.slateMuted),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
                );
                _loadJobs();
              },
            ),
          );
        },
      ),
    );
  }
}
