import 'dart:io';

Future<bool> checkIsOffline() async {
  try {
    final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return false; // Internet is active (Online)
    }
  } catch (_) {
    return true; // Internet is inactive (Offline)
  }
  return true;
}
