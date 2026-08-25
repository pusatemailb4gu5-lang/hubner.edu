import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
