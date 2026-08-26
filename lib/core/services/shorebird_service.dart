import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Checks for available OTA patches in the background and downloads them automatically
  static Future<void> checkForUpdates() async {
    if (kIsWeb) return;
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('[ShorebirdService] New patch available! Downloading OTA update...');
        await _updater.update();
        debugPrint('[ShorebirdService] Patch downloaded successfully. Update will take effect on next launch.');
      } else {
        debugPrint('[ShorebirdService] App status: $status.');
      }
    } catch (e, stack) {
      debugPrint('[ShorebirdService] Error checking for Shorebird update: $e\n$stack');
    }
  }
}
