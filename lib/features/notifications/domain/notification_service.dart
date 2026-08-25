import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ValueNotifier<Set<String>> readNotificationIdsNotifier =
      ValueNotifier<Set<String>>({});

  static bool _isInitialized = false;

  /// Loads read notification IDs from SharedPreferences into the reactive notifier.
  static Future<void> initReadIds() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_notifications_ids') ?? [];
      readNotificationIdsNotifier.value = list.toSet();
      _isInitialized = true;
    } catch (_) {}
  }

  /// Mark a single notification item as read
  static Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;
    final current = Set<String>.from(readNotificationIdsNotifier.value);
    if (!current.contains(id)) {
      current.add(id);
      readNotificationIdsNotifier.value = current;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('read_notifications_ids', current.toList());
      } catch (_) {}
    }
  }

  /// Mark multiple items as read
  static Future<void> markAllAsRead(Iterable<String> ids) async {
    final current = Set<String>.from(readNotificationIdsNotifier.value);
    bool changed = false;
    for (var id in ids) {
      if (id.isNotEmpty && !current.contains(id)) {
        current.add(id);
        changed = true;
      }
    }
    if (changed) {
      readNotificationIdsNotifier.value = current;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('read_notifications_ids', current.toList());
      } catch (_) {}
    }
  }

  /// Adds a new notification and automatically keeps only max 50 history items in Firestore.
  static Future<void> addNotification({
    required String text,
    required String type, // 'classroom', 'tugas', 'quiz', 'materi'
    String? projectId,
    String? targetRole, // 'all', 'Guru', 'Siswa'
    String? recipientId,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final collection = _firestore.collection('notifications');

      // 1. Insert new notification item
      await collection.add({
        'text': text,
        'type': type,
        'projectId': projectId ?? '',
        'uid': uid,
        'recipientId': recipientId ?? '',
        'targetRole': targetRole ?? 'all',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch all notification documents ordered newest first
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .get();

      // 3. Delete any documents beyond the 50th item automatically
      if (snapshot.docs.length > 50) {
        for (int i = 50; i < snapshot.docs.length; i++) {
          await snapshot.docs[i].reference.delete();
        }
      }
    } catch (_) {}
  }
}
