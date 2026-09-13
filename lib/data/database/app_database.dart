import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/client_model.dart';
import '../models/job_model.dart';
import '../models/survey_point_model.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('naija_surveyor_pro.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        // Enforce SQLite Foreign Key constraints
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Clients Table
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Jobs Table
    await db.execute('''
      CREATE TABLE jobs (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        job_num TEXT NOT NULL UNIQUE,
        zone INTEGER NOT NULL CHECK(zone IN (31, 32, 33)),
        datum TEXT NOT NULL CHECK(datum IN ('MINNA_UTM', 'WGS84_GEOGRAPHIC')),
        created_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    // 3. SurveyPoints Table
    await db.execute('''
      CREATE TABLE survey_points (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL,
        pt_name TEXT NOT NULL,
        easting REAL NOT NULL,
        northing REAL NOT NULL,
        height REAL NOT NULL,
        pt_type TEXT NOT NULL CHECK(pt_type IN ('BEACON', 'TRAVERSE_STATION', 'OFFSET', 'NATURAL_FEATURE')),
        photo_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE
      )
    ''');

    // 4. Site Recon & Field Geotagging Table
    await db.execute('''
      CREATE TABLE site_recons (
        id TEXT PRIMARY KEY,
        point_id TEXT NOT NULL,
        monument_integrity TEXT NOT NULL CHECK(monument_integrity IN ('INTACT', 'DISTURBED', 'DESTROYED', 'REPLACED')),
        terrain_condition TEXT NOT NULL CHECK(terrain_condition IN ('CLEARED', 'HEAVY_BUSH', 'MARSHY', 'ROCKY', 'BUILT_UP')),
        witness_marks TEXT,
        photo_path TEXT,
        voice_memo_path TEXT,
        recorded_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (point_id) REFERENCES survey_points (id) ON DELETE CASCADE
      )
    ''');

    // Create Indexes for fast lookup
    await db.execute('CREATE INDEX idx_jobs_client_id ON jobs(client_id);');
    await db.execute('CREATE INDEX idx_points_job_id ON survey_points(job_id);');
    await db.execute('CREATE INDEX idx_points_pt_name ON survey_points(pt_name);');
    await db.execute('CREATE INDEX idx_recons_point_id ON site_recons(point_id);');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
