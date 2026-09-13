/// Semantic context tag for points collected in the field
enum PointType {
  BEACON,
  TRAVERSE_STATION,
  OFFSET,
  NATURAL_FEATURE,
}

/// SurveyPoint Entity representing captured coordinates in the field
class SurveyPointModel {
  final String id;
  final String jobId;
  final String ptName;
  final double easting;
  final double northing;
  final double height;
  final PointType ptType;
  final String? photoPath;
  final String createdAt;

  SurveyPointModel({
    required this.id,
    required this.jobId,
    required this.ptName,
    required this.easting,
    required this.northing,
    required this.height,
    required this.ptType,
    this.photoPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job_id': jobId,
      'pt_name': ptName,
      'easting': easting,
      'northing': northing,
      'height': height,
      'pt_type': ptType.name,
      'photo_path': photoPath,
      'created_at': createdAt,
    };
  }

  factory SurveyPointModel.fromMap(Map<String, dynamic> map) {
    return SurveyPointModel(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      ptName: map['pt_name'] as String,
      easting: (map['easting'] as num).toDouble(),
      northing: (map['northing'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      ptType: PointType.values.firstWhere(
        (e) => e.name == map['pt_type'],
        orElse: () => PointType.BEACON,
      ),
      photoPath: map['photo_path'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  SurveyPointModel copyWith({
    String? id,
    String? jobId,
    String? ptName,
    double? easting,
    double? northing,
    double? height,
    PointType? ptType,
    String? photoPath,
    String? createdAt,
  }) {
    return SurveyPointModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      ptName: ptName ?? this.ptName,
      easting: easting ?? this.easting,
      northing: northing ?? this.northing,
      height: height ?? this.height,
      ptType: ptType ?? this.ptType,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
