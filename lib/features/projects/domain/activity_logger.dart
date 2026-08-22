import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> logClassroomActivity({
  required String projectId,
  required String type, // 'tugas', 'quiz', 'materi', 'elemen', 'siswa'
  required String actor,
  required String action,
  required String target,
}) async {
  try {
    final collectionRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('activities');

    // 1. Check for duplicate: skip if the latest entry has the same action+target
    final recentSnap = await collectionRef
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (recentSnap.docs.isNotEmpty) {
      final lastEntry = recentSnap.docs.first.data();
      if (lastEntry['action'] == action &&
          lastEntry['target'] == target &&
          lastEntry['type'] == type) {
        // Duplicate detected — skip insertion
        debugPrint('Skipping duplicate activity log: $action - $target');
        return;
      }
    }

    // 2. Add activity entry
    await collectionRef.add({
      'type': type,
      'actor': actor,
      'action': action,
      'target': target,
      'timestamp': FieldValue.serverTimestamp(),
      'time': 'Baru saja',
    });

    // 3. Fetch all activity logs sorted by latest timestamp
    final querySnap =
        await collectionRef.orderBy('timestamp', descending: true).get();

    // 4. Enforce strict MAX 20 entries: Delete 21st and older items automatically
    if (querySnap.docs.length > 20) {
      for (int i = 20; i < querySnap.docs.length; i++) {
        await collectionRef.doc(querySnap.docs[i].id).delete();
      }
    }
  } catch (e) {
    debugPrint('Error logging activity: $e');
  }
}

/// Utility to clean up all duplicate activity entries in a project's activity log.
/// Call this once to purge existing duplicates from Firestore.
Future<void> cleanupDuplicateActivities({
  required String projectId,
}) async {
  try {
    final collectionRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('activities');

    final querySnap =
        await collectionRef.orderBy('timestamp', descending: true).get();

    final Set<String> seenKeys = {};
    final List<String> docsToDelete = [];

    for (var doc in querySnap.docs) {
      final data = doc.data();
      final key = '${data['action']}||${data['target']}||${data['type']}';

      if (seenKeys.contains(key)) {
        docsToDelete.add(doc.id);
      } else {
        seenKeys.add(key);
      }
    }

    for (var docId in docsToDelete) {
      await collectionRef.doc(docId).delete();
    }

    if (docsToDelete.isNotEmpty) {
      debugPrint('Cleaned up ${docsToDelete.length} duplicate activity entries');
    }
  } catch (e) {
    debugPrint('Error cleaning up duplicate activities: $e');
  }
}
