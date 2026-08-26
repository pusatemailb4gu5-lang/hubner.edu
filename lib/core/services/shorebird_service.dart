import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  static final ShorebirdCodePush _shorebirdCodePush = ShorebirdCodePush();

  /// Check whether Shorebird is available on this device/platform
  static bool get isShorebirdAvailable => _shorebirdCodePush.isShorebirdAvailable();

  /// Checks for available OTA patches in the background and downloads them automatically
  static Future<void> checkForUpdates() async {
    if (kIsWeb) return;
    try {
      if (!_shorebirdCodePush.isShorebirdAvailable()) {
        debugPrint('[ShorebirdService] Shorebird code push is not available on this build.');
        return;
      }

      final isUpdateAvailable = await _shorebirdCodePush.isNewPatchAvailableForDownload();
      if (isUpdateAvailable) {
        debugPrint('[ShorebirdService] New patch available! Downloading OTA update...');
        await _shorebirdCodePush.downloadUpdateIfAvailable();
        debugPrint('[ShorebirdService] Patch downloaded successfully. Update will take effect on next launch.');
      } else {
        debugPrint('[ShorebirdService] App is up to date.');
      }
    } catch (e, stack) {
      debugPrint('[ShorebirdService] Error checking for Shorebird update: $e\n$stack');
    }
  }

  /// Returns current installed Shorebird patch number if available
  static Future<int?> getCurrentPatchNumber() async {
    if (kIsWeb) return null;
    try {
      if (!_shorebirdCodePush.isShorebirdAvailable()) return null;
      return await _shorebirdCodePush.currentPatchNumber();
    } catch (_) {
      return null;
    }
  }
}
