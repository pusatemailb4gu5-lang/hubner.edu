import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginHistoryEntry {
  final String timestamp;
  final String email;
  final String role;
  final String displayName;
  final String uid;

  LoginHistoryEntry({
    required this.timestamp,
    required this.email,
    required this.role,
    required this.displayName,
    required this.uid,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'email': email,
      'role': role,
      'displayName': displayName,
      'uid': uid,
    };
  }

  factory LoginHistoryEntry.fromMap(Map<String, dynamic> map) {
    return LoginHistoryEntry(
      timestamp: map['timestamp'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      displayName: map['displayName'] ?? '',
      uid: map['uid'] ?? '',
    );
  }
}

class LoginHistoryService {
  static const String _storageKey = 'local_login_history';

  /// Menyimpan entri login ke penyimpanan lokal (SharedPreferences)
  static Future<void> recordLogin({
    required String email,
    required String role,
    required String displayName,
    required String uid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawList = prefs.getStringList(_storageKey) ?? [];

      final newEntry = LoginHistoryEntry(
        timestamp: DateTime.now().toIso8601String(),
        email: email,
        role: role,
        displayName: displayName,
        uid: uid,
      );

      rawList.insert(0, jsonEncode(newEntry.toMap()));

      // Simpan maksimal 50 history terakhir
      if (rawList.length > 50) {
        rawList.removeRange(50, rawList.length);
      }

      await prefs.setStringList(_storageKey, rawList);
    } catch (_) {}
  }

  /// Mengambil daftar riwayat login dari local
  static Future<List<LoginHistoryEntry>> getLoginHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawList = prefs.getStringList(_storageKey) ?? [];
      return rawList
          .map((item) => LoginHistoryEntry.fromMap(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Menghapus seluruh riwayat login
  static Future<void> clearLoginHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
