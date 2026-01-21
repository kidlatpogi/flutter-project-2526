class AnalysisModel {
  final String id;
  final String userId;
  final double confidenceScore;
  final double clarityScore;
  final double paceScore;
  final DateTime timestamp;

  AnalysisModel({
    required this.id,
    required this.userId,
    required this.confidenceScore,
    required this.clarityScore,
    required this.paceScore,
    required this.timestamp,
  });

  factory AnalysisModel.fromJson(Map<String, dynamic> json) {
    return AnalysisModel(
      id: json['id'],
      userId: json['userId'],
      confidenceScore: json['confidenceScore'].toDouble(),
      clarityScore: json['clarityScore'].toDouble(),
      paceScore: json['paceScore'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'confidenceScore': confidenceScore,
      'clarityScore': clarityScore,
      'paceScore': paceScore,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}