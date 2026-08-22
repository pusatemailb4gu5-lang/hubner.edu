import 'dart:html' as html;

Future<bool> checkIsOffline() async {
  // html.window.navigator.onLine returns true if browser is online, false if offline
  return html.window.navigator.onLine == false;
}
