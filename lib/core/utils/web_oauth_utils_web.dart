import 'dart:async';
import 'dart:html' as html;

/// Opens the OAuth URL in a centered popup window on web
void openOAuthPopup(String url) {
  final width = 500;
  final height = 700;
  final left = (html.window.screen!.width! - width) ~/ 2;
  final top = (html.window.screen!.height! - height) ~/ 2;

  html.window.open(
    url,
    'google_oauth_popup',
    'width=$width,height=$height,left=$left,top=$top,'
    'toolbar=no,menubar=no,location=yes,status=no,scrollbars=yes',
  );
}

/// Check if the current window is an OAuth popup (opened by our app)
bool isPopupWindow() {
  try {
    return html.window.opener != null && html.window.name == 'google_oauth_popup';
  } catch (e) {
    return false;
  }
}

/// Close the popup window (call from within the popup after auth completes)
void closePopupWindow() {
  try {
    html.window.close();
  } catch (e) {
    // Ignore errors
  }
}

StreamSubscription<html.MessageEvent>? _oauthMessageSub;

/// Listen for OAuth callback postMessage from the popup window.
/// The popup sends { type: 'supabase_oauth_callback', url: '...' }.
/// [onCallback] receives the full redirect URL containing the tokens in the hash.
void listenForOAuthCallback(void Function(String url) onCallback) {
  _oauthMessageSub?.cancel();
  _oauthMessageSub = html.window.onMessage.listen((event) {
    // Only accept messages from our own origin
    if (event.origin != html.window.location.origin) return;

    final data = event.data;
    if (data is Map && data['type'] == 'supabase_oauth_callback') {
      final url = data['url'];
      if (url is String && url.isNotEmpty) {
        onCallback(url);
      }
    }
  });
}

/// Cancel the OAuth callback listener
void cancelOAuthListener() {
  _oauthMessageSub?.cancel();
  _oauthMessageSub = null;
}
