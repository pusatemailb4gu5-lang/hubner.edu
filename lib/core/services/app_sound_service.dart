import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized sound effect service for Hubner Edu.
/// Provides snappy, low-latency audio feedback for UI actions.
class AppSoundService {
  AppSoundService._();

  static final AudioPlayer _deletePlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  static final AudioPlayer _sendPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  static final AudioPlayer _receivePlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  /// Sound effect for swiping to delete classroom / CP stage / materi ("ssssttt")
  static Future<void> playDeleteWhoosh() async {
    try {
      await _deletePlayer.stop();
      await _deletePlayer.play(
        AssetSource('sounds/delete_whoosh.wav'),
        volume: 0.85,
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AppSoundService playDeleteWhoosh error: $e');
    }
  }

  /// Sound effect for sending a chat message ("sssess")
  static Future<void> playSendSwoosh() async {
    try {
      await _sendPlayer.stop();
      await _sendPlayer.play(
        AssetSource('sounds/send_message.wav'),
        volume: 0.90,
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AppSoundService playSendSwoosh error: $e');
    }
  }

  /// Sound effect for receiving a chat message ("ting tung")
  static Future<void> playReceiveTingTung() async {
    try {
      await _receivePlayer.stop();
      await _receivePlayer.play(
        AssetSource('sounds/receive_message.wav'),
        volume: 0.95,
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AppSoundService playReceiveTingTung error: $e');
    }
  }
}
