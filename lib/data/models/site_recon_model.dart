enum MonumentIntegrity {
  INTACT,     // Fully upright, uncompromised boundary beacon
  DISTURBED,  // Leaning, partially displaced, or chipped
  DESTROYED,  // Completely eradicated or removed
  REPLACED,   // Re-established beacon on historical coordinate
}

enum TerrainCondition {
  CLEARED,    // Clear open site or farm
  HEAVY_BUSH, // Dense vegetation / forest requiring cutlines
  MARSHY,     // Waterlogged / mangrove / flood zone
  ROCKY,      // Hard outcrop / granite terrain
  BUILT_UP,   // Urban developed area / concrete pavement
}

class SiteReconModel {
  final String id;
  final String pointId;
  final MonumentIntegrity monumentIntegrity;
  final TerrainCondition terrainCondition;
  final String? witnessMarks;
  final String? photoPath;
  final String? voiceMemoPath;
  final String? recordedBy;
  final String createdAt;

  SiteReconModel({
    required this.id,
    required this.pointId,
    required this.monumentIntegrity,
    required this.terrainCondition,
    this.witnessMarks,
    this.photoPath,
    this.voiceMemoPath,
    this.recordedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'point_id': pointId,
      'monument_integrity': monumentIntegrity.name,
      'terrain_condition': terrainCondition.name,
      'witness_marks': witnessMarks,
      'photo_path': photoPath,
      'voice_memo_path': voiceMemoPath,
      'recorded_by': recordedBy,
      'created_at': createdAt,
    };
  }

  factory SiteReconModel.fromMap(Map<String, dynamic> map) {
    return SiteReconModel(
      id: map['id'] as String,
      pointId: map['point_id'] as String,
      monumentIntegrity: MonumentIntegrity.values.firstWhere(
        (e) => e.name == map['monument_integrity'],
        orElse: () => MonumentIntegrity.INTACT,
      ),
      terrainCondition: TerrainCondition.values.firstWhere(
        (e) => e.name == map['terrain_condition'],
        orElse: () => TerrainCondition.CLEARED,
      ),
      witnessMarks: map['witness_marks'] as String?,
      photoPath: map['photo_path'] as String?,
      voiceMemoPath: map['voice_memo_path'] as String?,
      recordedBy: map['recorded_by'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
