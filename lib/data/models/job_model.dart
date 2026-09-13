/// Job Entity representing a Cadastral/Field Project Container
class JobModel {
  final String id;
  final String clientId;
  final String jobNum;
  final int zone; // 31, 32, or 33
  final String datum; // 'MINNA_UTM' or 'WGS84_GEOGRAPHIC'
  final String createdAt;

  JobModel({
    required this.id,
    required this.clientId,
    required this.jobNum,
    required this.zone,
    required this.datum,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'job_num': jobNum,
      'zone': zone,
      'datum': datum,
      'created_at': createdAt,
    };
  }

  factory JobModel.fromMap(Map<String, dynamic> map) {
    return JobModel(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      jobNum: map['job_num'] as String,
      zone: map['zone'] as int,
      datum: map['datum'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  JobModel copyWith({
    String? id,
    String? clientId,
    String? jobNum,
    int? zone,
    String? datum,
    String? createdAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      jobNum: jobNum ?? this.jobNum,
      zone: zone ?? this.zone,
      datum: datum ?? this.datum,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
