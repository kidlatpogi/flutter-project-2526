import 'package:flutter/foundation.dart';

/// Utility for parsing and handling URL parameters on web
class UrlUtils {
  /// Check if the current URL contains a recovery token (password reset flow)
  /// Returns the recovery type if found, null otherwise
  static String? getRecoveryType() {
    if (!kIsWeb) return null;

    try {
      // On web, we can access the URL via dart:html
      // This is handled via the web-specific implementation
      return _getRecoveryTypeWeb();
    } catch (e) {
      return null;
    }
  }

  /// Web-specific implementation (handled in web_specific file)
  static String? _getRecoveryTypeWeb() {
    // This will be overridden in the web-specific implementation
    return null;
  }

  /// Check if we have a recovery session (user followed password reset link)
  static bool hasRecoverySession() {
    return getRecoveryType() != null;
  }
}
