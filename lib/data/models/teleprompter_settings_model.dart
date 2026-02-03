/// Model for teleprompter settings
class TeleprompterSettings {
  final double scrollSpeedWPM; // Words per minute
  final double fontSize;
  final bool enableHighlighting; // Real-time word highlighting

  const TeleprompterSettings({
    this.scrollSpeedWPM = 120.0, // Default 120 WPM
    this.fontSize = 16.0, // Default font size
    this.enableHighlighting = true,
  });

  /// Convert WPM to pixels per second for smooth scrolling
  /// Assumes average word length of 5 characters + 1 space = 6 characters
  /// And average line height of 1.8 * fontSize
  double get pixelsPerSecond {
    // Approximate calculation: WPM / 60 = words per second
    // characters per second = words per second * 6
    // Assuming ~40 characters per line at font size 16
    final wordsPerSecond = scrollSpeedWPM / 60.0;
    final charsPerSecond = wordsPerSecond * 6;
    final lineHeight = fontSize * 1.8;
    final charsPerLine = 40 * (fontSize / 16.0);
    final linesPerSecond = charsPerSecond / charsPerLine;
    return linesPerSecond * lineHeight;
  }

  TeleprompterSettings copyWith({
    double? scrollSpeedWPM,
    double? fontSize,
    bool? enableHighlighting,
  }) {
    return TeleprompterSettings(
      scrollSpeedWPM: scrollSpeedWPM ?? this.scrollSpeedWPM,
      fontSize: fontSize ?? this.fontSize,
      enableHighlighting: enableHighlighting ?? this.enableHighlighting,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scrollSpeedWPM': scrollSpeedWPM,
      'fontSize': fontSize,
      'enableHighlighting': enableHighlighting,
    };
  }

  factory TeleprompterSettings.fromJson(Map<String, dynamic> json) {
    return TeleprompterSettings(
      scrollSpeedWPM: (json['scrollSpeedWPM'] as num?)?.toDouble() ?? 120.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      enableHighlighting: json['enableHighlighting'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'TeleprompterSettings(scrollSpeedWPM: $scrollSpeedWPM, fontSize: $fontSize, enableHighlighting: $enableHighlighting)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeleprompterSettings &&
        other.scrollSpeedWPM == scrollSpeedWPM &&
        other.fontSize == fontSize &&
        other.enableHighlighting == enableHighlighting;
  }

  @override
  int get hashCode =>
      scrollSpeedWPM.hashCode ^ fontSize.hashCode ^ enableHighlighting.hashCode;
}
