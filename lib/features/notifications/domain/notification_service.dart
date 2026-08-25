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

  /// Mark a single notification item as read and delete from Firestore if it exists
  static Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;
    final current = Set<String>.from(readNotificationIdsNotifier.value);
    current.add(id);
    readNotificationIdsNotifier.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_notifications_ids', current.toList());
    } catch (_) {}

    // Hapus langsung dari database Firestore agar hanya menyimpan yang belum dibaca
    if (!id.startsWith('task_') && !id.startsWith('materi_') && !id.startsWith('quiz_') && !id.startsWith('classroom_')) {
      try {
        await _firestore.collection('notifications').doc(id).delete();
      } catch (_) {}
    }
  }

  /// Mark multiple items as read and batch-delete them from Firestore database
  static Future<void> markAllAsRead(Iterable<String> ids) async {
    final current = Set<String>.from(readNotificationIdsNotifier.value);
    final List<String> firestoreIdsToDelete = [];

    for (var id in ids) {
      if (id.isNotEmpty) {
        current.add(id);
        if (!id.startsWith('task_') && !id.startsWith('materi_') && !id.startsWith('quiz_') && !id.startsWith('classroom_')) {
          firestoreIdsToDelete.add(id);
        }
      }
    }

    readNotificationIdsNotifier.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_notifications_ids', current.toList());
    } catch (_) {}

    // Hapus seluruh dokumen yang dibaca dari koleksi Firestore
    if (firestoreIdsToDelete.isNotEmpty) {
      final batch = _firestore.batch();
      for (var docId in firestoreIdsToDelete) {
        batch.delete(_firestore.collection('notifications').doc(docId));
      }
      try {
        await batch.commit();
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
