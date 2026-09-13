import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/client_model.dart';
import '../models/job_model.dart';
import '../models/survey_point_model.dart';
import '../models/site_recon_model.dart';

class SurveyRepository {
  final AppDatabase dbHelper;
  static const _uuid = Uuid();

  SurveyRepository({AppDatabase? databaseHelper})
      : dbHelper = databaseHelper ?? AppDatabase.instance;

  // =========================================================================
  // CLIENTS
  // =========================================================================

  Future<ClientModel> createClient({
    required String name,
    required String phone,
  }) async {
    final db = await dbHelper.database;
    final client = ClientModel(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    await db.insert('clients', client.toMap());
    return client;
  }

  Future<List<ClientModel>> getClients() async {
    final db = await dbHelper.database;
    final result = await db.query('clients', orderBy: 'created_at DESC');
    return result.map((map) => ClientModel.fromMap(map)).toList();
  }

  Future<ClientModel?> getClientById(String id) async {
    final db = await dbHelper.database;
    final result = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return ClientModel.fromMap(result.first);
    }
    return null;
  }

  // =========================================================================
  // JOBS
  // =========================================================================

  Future<JobModel> createJob({
    required String clientId,
    required String jobNum,
    required int zone,
    String datum = 'MINNA_UTM',
  }) async {
    final db = await dbHelper.database;
    final job = JobModel(
      id: _uuid.v4(),
      clientId: clientId,
      jobNum: jobNum.trim().toUpperCase(),
      zone: zone,
      datum: datum,
      createdAt: DateTime.now().toIso8601String(),
    );

    await db.insert('jobs', job.toMap());
    return job;
  }

  Future<List<JobModel>> getJobs() async {
    final db = await dbHelper.database;
    final result = await db.query('jobs', orderBy: 'created_at DESC');
    return result.map((map) => JobModel.fromMap(map)).toList();
  }

  Future<JobModel?> getJobById(String id) async {
    final db = await dbHelper.database;
    final result = await db.query('jobs', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return JobModel.fromMap(result.first);
    }
    return null;
  }

  Future<int> deleteJob(String id) async {
    final db = await dbHelper.database;
    return await db.delete('jobs', where: 'id = ?', whereArgs: [id]);
  }

  // =========================================================================
  // SURVEY POINTS
  // =========================================================================

  Future<SurveyPointModel> addPoint({
    required String jobId,
    required String ptName,
    required double easting,
    required double northing,
    required double height,
    PointType ptType = PointType.BEACON,
    String? photoPath,
  }) async {
    final db = await dbHelper.database;
    final point = SurveyPointModel(
      id: _uuid.v4(),
      jobId: jobId,
      ptName: ptName.trim().toUpperCase(),
      easting: easting,
      northing: northing,
      height: height,
      ptType: ptType,
      photoPath: photoPath,
      createdAt: DateTime.now().toIso8601String(),
    );

    await db.insert('survey_points', point.toMap());
    return point;
  }

  Future<List<SurveyPointModel>> getPointsForJob(String jobId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'survey_points',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SurveyPointModel.fromMap(map)).toList();
  }

  Future<int> deletePoint(String id) async {
    final db = await dbHelper.database;
    return await db.delete('survey_points', where: 'id = ?', whereArgs: [id]);
  }

  /// Suggests the next beacon name based on existing points (e.g., P1 -> P2 -> P3)
  Future<String> getSuggestedNextBeaconName(String jobId) async {
    final points = await getPointsForJob(jobId);
    if (points.isEmpty) return 'P1';

    final lastPoint = points.last.ptName;
    final regex = RegExp(r'^([A-Za-z]+)(\d+)$');
    final match = regex.firstMatch(lastPoint);

    if (match != null) {
      final prefix = match.group(1)!;
      final num = int.tryParse(match.group(2)!) ?? 0;
      return '$prefix${num + 1}';
    }

    return 'P${points.length + 1}';
  }

  /// Checks if a pillar name already exists in the given job to prevent duplicate entries
  Future<bool> isPillarNameDuplicate(String jobId, String ptName) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'survey_points',
      where: 'job_id = ? AND pt_name = ?',
      whereArgs: [jobId, ptName.trim().toUpperCase()],
    );
    return result.isNotEmpty;
  }

  // =========================================================================
  // SITE RECON & GEOTAGGING
  // =========================================================================

  Future<SiteReconModel> addSiteRecon({
    required String pointId,
    required MonumentIntegrity monumentIntegrity,
    required TerrainCondition terrainCondition,
    String? witnessMarks,
    String? photoPath,
    String? voiceMemoPath,
    String? recordedBy,
  }) async {
    final db = await dbHelper.database;
    final recon = SiteReconModel(
      id: _uuid.v4(),
      pointId: pointId,
      monumentIntegrity: monumentIntegrity,
      terrainCondition: terrainCondition,
      witnessMarks: witnessMarks,
      photoPath: photoPath,
      voiceMemoPath: voiceMemoPath,
      recordedBy: recordedBy,
      createdAt: DateTime.now().toIso8601String(),
    );

    await db.insert('site_recons', recon.toMap());
    return recon;
  }

  Future<SiteReconModel?> getSiteReconForPoint(String pointId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'site_recons',
      where: 'point_id = ?',
      whereArgs: [pointId],
    );
    if (result.isNotEmpty) {
      return SiteReconModel.fromMap(result.first);
    }
    return null;
  }
}
