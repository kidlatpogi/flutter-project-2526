/// Utility class for time-based greetings
class GreetingUtils {
  /// Get appropriate greeting based on Philippine Standard Time (UTC+8)
  static String getGreeting() {
    // Get current time in UTC+8 (Philippine Standard Time)
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 18) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
