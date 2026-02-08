/// Stub implementation for non-web platforms
void openOAuthPopup(String url) {
  // No-op on non-web platforms
}

bool isPopupWindow() {
  return false;
}

void closePopupWindow() {
  // No-op on non-web platforms
}

void listenForOAuthCallback(void Function(String url) onCallback) {
  // No-op on non-web platforms
}

void cancelOAuthListener() {
  // No-op on non-web platforms
}
