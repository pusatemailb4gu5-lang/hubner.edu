import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  static final ValueNotifier<Set<String>> readNotificationIdsNotifier =
      ValueNotifier<Set<String>>({});

  static bool _isInitialized = false;

  /// Initializes Android High Importance Notification Channel for WhatsApp-style popups
  static Future<void> initLocalNotifications() async {
    if (_localNotificationsInitialized || kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(initSettings);

      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'Hubner Edu Notifications',
        description: 'Channel untuk notifikasi pesan dan pengingat penting.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.requestNotificationsPermission();
      }

      _localNotificationsInitialized = true;
    } catch (_) {}
  }

  /// Trigger High Priority Pop-Up Notification (Android Banner / Heads-Up like WhatsApp)
  static Future<void> showPopUpNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_localNotificationsInitialized) {
        await initLocalNotifications();
      }

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Hubner Edu Notifications',
        channelDescription: 'Channel untuk notifikasi pesan dan pengingat penting.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Pesan Baru',
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _localNotifications.show(
        id == 0 ? DateTime.now().millisecondsSinceEpoch.remainder(100000) : id,
        title,
        body,
        details,
      );
    } catch (_) {}
  }

  /// Loads read notification IDs from SharedPreferences into the reactive notifier.
  static Future<void> initReadIds() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_notifications_ids') ?? [];
      readNotificationIdsNotifier.value = list.toSet();
      _isInitialized = true;
      await initLocalNotifications();
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

      // 2. Fetch all notification documents ordered newest first and auto-prune
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.length > 50) {
        for (int i = 50; i < snapshot.docs.length; i++) {
          await snapshot.docs[i].reference.delete();
        }
      }

      // 3. Trigger High-Priority Android Pop-Up Notification
      showPopUpNotification(
        title: type.toUpperCase(),
        body: text,
      );
    } catch (_) {}
  }
}
