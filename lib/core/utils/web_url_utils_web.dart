import 'dart:html' as html;

void clearWebQueryParameters() {
  final uri = Uri.base.replace(queryParameters: {});
  html.window.history.replaceState(null, '', uri.toString());
}
