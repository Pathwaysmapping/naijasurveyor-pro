import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/job_model.dart';
import '../../data/models/survey_point_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/point_card.dart';
import '../widgets/zone_badge.dart';
import 'add_point_screen.dart';
import 'rtk_status_screen.dart';
import 'stakeout_screen.dart';
import '../widgets/cadastral_canvas_view.dart';

class JobDetailScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final SurveyRepository _repository = SurveyRepository();
  List<SurveyPointModel> _points = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    try {
      final points = await _repository.getPointsForJob(widget.job.id);
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_points.isEmpty) {
      _showToast('No points to export');
      return;
    }

    try {
      final file = await ExportService.saveCsvToFile(job: widget.job, points: _points);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'NaijaSurveyor Pro - Cadastral CSV (${widget.job.jobNum})',
      );
    } catch (e) {
      _showToast('Export failed: $e');
    }
  }

  Future<void> _exportDxf() async {
    if (_points.isEmpty) {
      _showToast('No points to export');
      return;
    }

    try {
      final file = await ExportService.saveDxfToFile(job: widget.job, points: _points);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'NaijaSurveyor Pro - AutoCAD DXF (${widget.job.jobNum})',
      );
    } catch (e) {
      _showToast('Export failed: $e');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.cardNavy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.jobNum),
        actions: [
          PopupMenuButton<String>(
            color: AppTheme.cardNavy,
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'csv') _exportCsv();
              if (val == 'dxf') _exportDxf();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 18, color: AppTheme.pureWhite),
                    SizedBox(width: 10),
                    Text('Export NIS Standard CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'dxf',
                child: Row(
                  children: [
                    Icon(Icons.polyline_outlined, size: 18, color: AppTheme.pureWhite),
                    SizedBox(width: 10),
                    Text('Export AutoCAD DXF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Job Metadata Header Card
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardNavy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL BEACONS: ${_points.length}',
                      style: const TextStyle(
                        color: AppTheme.crimsonAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    ZoneBadge(zone: widget.job.zone, datum: widget.job.datum),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('NIS CSV', style: TextStyle(fontSize: 12)),
                        onPressed: _exportCsv,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.satellite_alt, size: 16, color: AppTheme.crimsonAccent),
                        label: const Text('RTK ROVER', style: TextStyle(fontSize: 12, color: AppTheme.crimsonAccent)),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RtkStatusScreen(activeJob: widget.job)),
                          );
                          _loadPoints();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.navigation_outlined, size: 16, color: AppTheme.emeraldSuccess),
                        label: const Text('STAKEOUT', style: TextStyle(fontSize: 12, color: AppTheme.emeraldSuccess)),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StakeoutScreen(job: widget.job)),
                          );
                          _loadPoints();
                        },
                      ),
                    ),
                  ],
                ),
                if (_points.length >= 2) ...[
                  const SizedBox(height: 14),
                  CadastralCanvasView(points: _points),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.strokeNavy),

          // Points List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.crimsonPrimary))
                : _points.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.pin_drop_outlined, size: 48, color: AppTheme.slateMuted),
                            SizedBox(height: 12),
                            Text(
                              'No Survey Points Logged',
                              style: TextStyle(color: AppTheme.slateText, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _points.length,
                        itemBuilder: (context, index) {
                          final pt = _points[index];
                          return PointCard(
                            point: pt,
                            onDelete: () async {
                              await _repository.deletePoint(pt.id);
                              _loadPoints();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.crimsonPrimary,
        foregroundColor: AppTheme.pureWhite,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('LOG BEACON', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPointScreen(job: widget.job)),
          );
          if (result == true) {
            _loadPoints();
          }
        },
      ),
    );
  }
}
