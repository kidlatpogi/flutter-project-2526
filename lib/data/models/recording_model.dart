class RecordingModel {
  final String id;
  final String userId;
  final String fileName;
  final Duration duration;
  final DateTime recordedAt;

  RecordingModel({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.duration,
    required this.recordedAt,
  });

  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    return RecordingModel(
      id: json['id'],
      userId: json['userId'],
      fileName: json['fileName'],
      duration: Duration(milliseconds: json['duration']),
      recordedAt: DateTime.parse(json['recordedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fileName': fileName,
      'duration': duration.inMilliseconds,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }
}