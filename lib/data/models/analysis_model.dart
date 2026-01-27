/// Audio metrics from acoustic analysis
class AudioMetrics {
  final double pitchMean;
  final double pitchStd;
  final double jitterLocal;
  final double shimmerLocal;
  final double harmonicsToNoiseRatio;

  AudioMetrics({
    required this.pitchMean,
    required this.pitchStd,
    required this.jitterLocal,
    required this.shimmerLocal,
    required this.harmonicsToNoiseRatio,
  });

  factory AudioMetrics.fromJson(Map<String, dynamic> json) {
    return AudioMetrics(
      pitchMean: (json['pitch_mean'] ?? 0).toDouble(),
      pitchStd: (json['pitch_std'] ?? 0).toDouble(),
      jitterLocal: (json['jitter_local'] ?? 0).toDouble(),
      shimmerLocal: (json['shimmer_local'] ?? 0).toDouble(),
      harmonicsToNoiseRatio: (json['harmonics_to_noise_ratio'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'pitch_mean': pitchMean,
        'pitch_std': pitchStd,
        'jitter_local': jitterLocal,
        'shimmer_local': shimmerLocal,
        'harmonics_to_noise_ratio': harmonicsToNoiseRatio,
      };
}

/// Fluency metrics from transcription analysis
class FluencyMetrics {
  final double wordsPerMinute;
  final int fillerCount;
  final List<String> fillerWordsFound;
  final int totalWords;
  final double articulationRate;

  FluencyMetrics({
    required this.wordsPerMinute,
    required this.fillerCount,
    required this.fillerWordsFound,
    required this.totalWords,
    required this.articulationRate,
  });

  factory FluencyMetrics.fromJson(Map<String, dynamic> json) {
    return FluencyMetrics(
      wordsPerMinute: (json['words_per_minute'] ?? 0).toDouble(),
      fillerCount: json['filler_count'] ?? 0,
      fillerWordsFound: List<String>.from(json['filler_words_found'] ?? []),
      totalWords: json['total_words'] ?? 0,
      articulationRate: (json['articulation_rate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'words_per_minute': wordsPerMinute,
        'filler_count': fillerCount,
        'filler_words_found': fillerWordsFound,
        'total_words': totalWords,
        'articulation_rate': articulationRate,
      };
}

/// Pause metrics from silence analysis
class PauseMetrics {
  final double totalPauseDuration;
  final int pauseCount;
  final double pauseRatio;
  final double averagePauseDuration;
  final double longestPause;

  PauseMetrics({
    required this.totalPauseDuration,
    required this.pauseCount,
    required this.pauseRatio,
    required this.averagePauseDuration,
    required this.longestPause,
  });

  factory PauseMetrics.fromJson(Map<String, dynamic> json) {
    return PauseMetrics(
      totalPauseDuration: (json['total_pause_duration'] ?? 0).toDouble(),
      pauseCount: json['pause_count'] ?? 0,
      pauseRatio: (json['pause_ratio'] ?? 0).toDouble(),
      averagePauseDuration: (json['average_pause_duration'] ?? 0).toDouble(),
      longestPause: (json['longest_pause'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_pause_duration': totalPauseDuration,
        'pause_count': pauseCount,
        'pause_ratio': pauseRatio,
        'average_pause_duration': averagePauseDuration,
        'longest_pause': longestPause,
      };
}

/// Confidence score breakdown
class ConfidenceScore {
  final double overallScore;
  final double pitchScore;
  final double fluencyScore;
  final double voiceQualityScore;
  final double paceScore;

  ConfidenceScore({
    required this.overallScore,
    required this.pitchScore,
    required this.fluencyScore,
    required this.voiceQualityScore,
    required this.paceScore,
  });

  factory ConfidenceScore.fromJson(Map<String, dynamic> json) {
    return ConfidenceScore(
      overallScore: (json['overall_score'] ?? 0).toDouble(),
      pitchScore: (json['pitch_score'] ?? 0).toDouble(),
      fluencyScore: (json['fluency_score'] ?? 0).toDouble(),
      voiceQualityScore: (json['voice_quality_score'] ?? 0).toDouble(),
      paceScore: (json['pace_score'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'overall_score': overallScore,
        'pitch_score': pitchScore,
        'fluency_score': fluencyScore,
        'voice_quality_score': voiceQualityScore,
        'pace_score': paceScore,
      };
}

/// Complete analysis result from the backend
class AnalysisModel {
  final String sessionId;
  final String transcription;
  final double audioDuration;
  final AudioMetrics audioMetrics;
  final FluencyMetrics fluencyMetrics;
  final PauseMetrics pauseMetrics;
  final ConfidenceScore confidenceScore;
  final DateTime analyzedAt;

  AnalysisModel({
    required this.sessionId,
    required this.transcription,
    required this.audioDuration,
    required this.audioMetrics,
    required this.fluencyMetrics,
    required this.pauseMetrics,
    required this.confidenceScore,
    required this.analyzedAt,
  });

  /// Overall confidence score (0-100) - convenience getter
  double get overallScore => confidenceScore.overallScore;

  /// Words per minute - convenience getter
  double get wpm => fluencyMetrics.wordsPerMinute;

  /// Number of filler words - convenience getter
  int get fillerCount => fluencyMetrics.fillerCount;

  /// Pause ratio (0-1) - convenience getter
  double get pauseRatio => pauseMetrics.pauseRatio;

  factory AnalysisModel.fromJson(Map<String, dynamic> json) {
    return AnalysisModel(
      sessionId: json['session_id'] ?? '',
      transcription: json['transcription'] ?? '',
      audioDuration: (json['audio_duration'] ?? 0).toDouble(),
      audioMetrics: AudioMetrics.fromJson(json['audio_metrics'] ?? {}),
      fluencyMetrics: FluencyMetrics.fromJson(json['fluency_metrics'] ?? {}),
      pauseMetrics: PauseMetrics.fromJson(json['pause_metrics'] ?? {}),
      confidenceScore: ConfidenceScore.fromJson(json['confidence_score'] ?? {}),
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'transcription': transcription,
        'audio_duration': audioDuration,
        'audio_metrics': audioMetrics.toJson(),
        'fluency_metrics': fluencyMetrics.toJson(),
        'pause_metrics': pauseMetrics.toJson(),
        'confidence_score': confidenceScore.toJson(),
        'analyzed_at': analyzedAt.toIso8601String(),
      };

  @override
  String toString() {
    return 'AnalysisModel(sessionId: $sessionId, overallScore: ${confidenceScore.overallScore}, wpm: ${fluencyMetrics.wordsPerMinute})';
  }
}