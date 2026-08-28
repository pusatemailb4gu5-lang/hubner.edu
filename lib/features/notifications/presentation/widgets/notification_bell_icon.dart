import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/features/notifications/domain/notification_service.dart';
import '../pages/notifications_page.dart';

class NotificationBellIcon extends StatefulWidget {
  final bool isDark;
  final double size;
  final bool showFrame;

  const NotificationBellIcon({
    super.key,
    required this.isDark,
    this.size = 52.0,
    this.showFrame = true,
  });

  @override
  State<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends State<NotificationBellIcon> {
  @override
  void initState() {
    super.initState();
    NotificationService.initReadIds();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) {
      return _buildBellContainer(0);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
      builder: (context, userSnap) {
        final userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
        final String userRole = (userData['role'] ?? 'Siswa').toString();
        final List enrolledProjectIds = List.from(userData['projectIds'] ?? []);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
          builder: (context, notifSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('projects').snapshots(),
              builder: (context, projSnap) {
                final notifDocs = notifSnap.data?.docs ?? [];
                final projDocs = projSnap.data?.docs ?? [];

                final userProjects = projDocs.where((doc) {
                  final pData = doc.data() as Map<String, dynamic>;
                  final pId = doc.id;
                  final creatorId = pData['creatorId'] ??
                      pData['ownerUid'] ??
                      pData['teacherId'] ??
                      pData['teacherUid'] ??
                      pData['uid'] ??
                      '';
                  final members = List.from(pData['members'] ?? []);
                  final studentIds = List.from(pData['studentIds'] ?? []);

                  return creatorId == currentUid ||
                      members.contains(currentUid) ||
                      studentIds.contains(currentUid) ||
                      enrolledProjectIds.contains(pId);
                }).toList();

                final validProjectIds = userProjects.map((p) => p.id).toSet();
                final List<String> allItemIds = [];

                // 1. Direct Notifications
                for (var doc in notifDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final targetUid = data['uid'] ?? data['recipientId'] ?? '';
                  final pId = data['projectId'] ?? '';
                  final targetRole = data['targetRole'] ?? 'all';

                  final bool isMyUser = targetUid == currentUid;
                  final bool isMyClass = pId.isNotEmpty && validProjectIds.contains(pId);
                  final bool isRoleMatch = targetRole == 'all' || targetRole == userRole;

                  if ((isMyUser || isMyClass) && isRoleMatch) {
                    allItemIds.add(doc.id);
                  }
                }

                // 2. Synthesized Tasks/Materi/Quizzes
                for (var p in userProjects) {
                  final pData = p.data() as Map<String, dynamic>;
                  final pId = p.id;
                  final stages = List.from(pData['stages'] ?? []);

                  for (var st in stages) {
                    // Tasks
                    final tasks = List.from(st['tasks'] ?? st['tugas'] ?? []);
                    for (var t in tasks) {
                      final tTitle = t['title'] ?? t['name'] ?? 'Tugas';
                      allItemIds.add('task_${pId}_$tTitle');
                    }
                    // Materis
                    final materis = List.from(st['materis'] ?? st['materi'] ?? st['materials'] ?? []);
                    for (var m in materis) {
                      final mTitle = m['title'] ?? m['name'] ?? 'Materi Pembelajaran';
                      allItemIds.add('materi_${pId}_$mTitle');
                    }
                    // Quizzes
                    final quizzes = List.from(st['quizzes'] ?? st['quiz'] ?? st['soal'] ?? []);
                    for (var q in quizzes) {
                      final qTitle = q['title'] ?? q['name'] ?? 'Quiz Kelas';
                      allItemIds.add('quiz_${pId}_$qTitle');
                    }
                  }

                  final pStatus = (pData['status'] ?? '').toString();
                  if (pStatus == 'Selesai') {
                    allItemIds.add('classroom_done_$pId');
                  }
                }

                // Cap to 30 most recent IDs
                final topIds = allItemIds.toSet().take(30).toList();

                return ValueListenableBuilder<Set<String>>(
                  valueListenable: NotificationService.readNotificationIdsNotifier,
                  builder: (context, readIds, _) {
                    final int unreadCount = topIds.where((id) => !readIds.contains(id)).length;
                    return _buildBellContainer(unreadCount);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBellContainer(int unreadCount) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationsPage(),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: widget.showFrame
            ? BoxDecoration(
                color: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              )
            : null,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: widget.isDark ? Colors.white : Colors.black87,
              size: widget.showFrame ? 24 : 26,
            ),
            if (unreadCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
