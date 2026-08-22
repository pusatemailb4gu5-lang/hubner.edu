import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Adds a new notification and automatically keeps only max 20 history items in Firestore.
  static Future<void> addNotification({
    required String text,
    required String type, // 'classroom' or 'tugas'
    String? projectId,
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
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch all notification documents ordered newest first
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .get();

      // 3. Delete any documents beyond the 20th item automatically
      if (snapshot.docs.length > 20) {
        for (int i = 20; i < snapshot.docs.length; i++) {
          await snapshot.docs[i].reference.delete();
        }
      }
    } catch (_) {}
  }
}
