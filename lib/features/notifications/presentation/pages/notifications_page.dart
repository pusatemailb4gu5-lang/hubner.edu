import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/features/notifications/domain/notification_service.dart';
import '../../../projects/presentation/pages/class_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    NotificationService.initReadIds();
  }

  Future<void> _markItemAsRead(String id) async {
    await NotificationService.markAsRead(id);
  }

  Future<void> _markAllAsRead(List<Map<String, dynamic>> items) async {
    await NotificationService.markAllAsRead(items.map((it) => it['id']?.toString() ?? ''));
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return 'Baru saja';
    DateTime dt;
    if (createdAt is Timestamp) {
      dt = createdAt.toDate();
    } else if (createdAt is DateTime) {
      dt = createdAt;
    } else {
      return 'Baru saja';
    }
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');

    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$hour:$minute';
    }
    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        body: StreamBuilder<DocumentSnapshot>(
          stream: currentUid.isNotEmpty
              ? FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots()
              : const Stream.empty(),
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
                    if (notifSnap.connectionState == ConnectionState.waiting &&
                        projSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      );
                    }

                    final notifDocs = notifSnap.data?.docs ?? [];
                    final projDocs = projSnap.data?.docs ?? [];

                    // Filter only projects belonging to this user (strictly account-isolated)
                    final userProjects = projDocs.where((doc) {
                      final pData = doc.data() as Map<String, dynamic>;
                      final pId = doc.id;
                      final creatorId = pData['creatorId'] ?? pData['ownerUid'] ?? pData['teacherId'] ?? '';
                      final members = List.from(pData['members'] ?? []);
                      final studentIds = List.from(pData['studentIds'] ?? []);

                      return creatorId == currentUid ||
                          members.contains(currentUid) ||
                          studentIds.contains(currentUid) ||
                          enrolledProjectIds.contains(pId);
                    }).toList();

                    final userProjectMap = {for (var p in userProjects) p.id: p.data() as Map<String, dynamic>};
                    final validProjectIds = userProjectMap.keys.toSet();

                    final List<Map<String, dynamic>> items = [];

                    // 1. Add direct notifications for this user or their enrolled projects
                    for (var doc in notifDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final targetUid = data['uid'] ?? data['recipientId'] ?? '';
                      final pId = data['projectId'] ?? '';
                      final targetRole = data['targetRole'] ?? 'all';

                      final bool isMyUser = targetUid == currentUid;
                      final bool isMyClass = pId.isNotEmpty && validProjectIds.contains(pId);
                      final bool isRoleMatch = targetRole == 'all' || targetRole == userRole;

                      if ((isMyUser || isMyClass) && isRoleMatch) {
                        items.add({
                          'id': doc.id,
                          'text': data['text'] ?? '',
                          'type': (data['type'] ?? 'classroom').toString(),
                          'projectId': pId,
                          'createdAt': data['createdAt'],
                        });
                      }
                    }

                    // 2. Synthesize role-specific notifications from enrolled classrooms (tugas, materi, quiz, classroom)
                    for (var entry in userProjectMap.entries) {
                      final pId = entry.key;
                      final pData = entry.value;
                      final pName = pData['name'] ?? 'Classroom';
                      final pStatus = (pData['status'] ?? '').toString();
                      final stages = List.from(pData['stages'] ?? []);

                      int totalTasks = 0;
                      int doneTasks = 0;

                      for (var st in stages) {
                        // Tugas
                        final tasks = List.from(st['tasks'] ?? st['tugas'] ?? []);
                        totalTasks += tasks.length;
                        for (var t in tasks) {
                          final tTitle = t['title'] ?? t['name'] ?? 'Tugas';
                          final isTaskDone = t['isDone'] == true || (t['progress'] ?? 0) == 100;
                          if (isTaskDone) doneTasks++;

                          final String itemId = 'task_${pId}_$tTitle';
                          final taskAlreadyInList = items.any((it) => it['id'] == itemId);

                          if (!taskAlreadyInList) {
                            String notifText;
                            if (userRole == 'Guru') {
                              notifText = 'Anda membuat tugas "$tTitle" pada $pName.';
                            } else {
                              if (isTaskDone) {
                                notifText = 'Anda telah menyelesaikan tugas "$tTitle" pada $pName.';
                              } else {
                                notifText = 'Guru mengunggah tugas baru: "$tTitle" pada $pName.';
                              }
                            }

                            items.add({
                              'id': itemId,
                              'text': notifText,
                              'type': 'tugas',
                              'projectId': pId,
                              'createdAt': t['createdAt'] ?? pData['updatedAt'] ?? pData['createdAt'] ?? DateTime.now(),
                            });
                          }
                        }

                        // Materi
                        final materis = List.from(st['materis'] ?? st['materi'] ?? st['materials'] ?? []);
                        for (var m in materis) {
                          final mTitle = m['title'] ?? m['name'] ?? 'Materi Pembelajaran';
                          final String itemId = 'materi_${pId}_$mTitle';
                          final materiAlreadyInList = items.any((it) => it['id'] == itemId);

                          if (!materiAlreadyInList) {
                            String notifText;
                            if (userRole == 'Guru') {
                              notifText = 'Anda membuat materi baru: "$mTitle" pada $pName.';
                            } else {
                              notifText = 'Guru mengunggah materi baru: "$mTitle" pada $pName.';
                            }

                            items.add({
                              'id': itemId,
                              'text': notifText,
                              'type': 'materi',
                              'projectId': pId,
                              'createdAt': m['createdAt'] ?? pData['updatedAt'] ?? pData['createdAt'] ?? DateTime.now(),
                            });
                          }
                        }

                        // Quiz
                        final quizzes = List.from(st['quizzes'] ?? st['quiz'] ?? st['soal'] ?? []);
                        for (var q in quizzes) {
                          final qTitle = q['title'] ?? q['name'] ?? 'Quiz Kelas';
                          final String itemId = 'quiz_${pId}_$qTitle';
                          final quizAlreadyInList = items.any((it) => it['id'] == itemId);

                          if (!quizAlreadyInList) {
                            String notifText;
                            if (userRole == 'Guru') {
                              notifText = 'Anda membuat kuis baru: "$qTitle" pada $pName.';
                            } else {
                              notifText = 'Guru mengunggah kuis baru: "$qTitle" pada $pName.';
                            }

                            items.add({
                              'id': itemId,
                              'text': notifText,
                              'type': 'quiz',
                              'projectId': pId,
                              'createdAt': q['createdAt'] ?? pData['updatedAt'] ?? pData['createdAt'] ?? DateTime.now(),
                            });
                          }
                        }
                      }

                      // Classroom Completion
                      final bool isDone = pStatus == 'Selesai' || (totalTasks > 0 && doneTasks == totalTasks);
                      if (isDone) {
                        final String itemId = 'classroom_done_$pId';
                        final alreadyExists = items.any((it) => it['id'] == itemId);
                        if (!alreadyExists) {
                          items.add({
                            'id': itemId,
                            'text': 'Classroom "$pName" telah 100% selesai dikerjakan.',
                            'type': 'classroom',
                            'projectId': pId,
                            'createdAt': pData['updatedAt'] ?? pData['createdAt'] ?? DateTime.now(),
                          });
                        }
                      }
                    }

                    // Sort newest first
                    items.sort((a, b) {
                      DateTime tA;
                      DateTime tB;
                      if (a['createdAt'] is Timestamp) {
                        tA = (a['createdAt'] as Timestamp).toDate();
                      } else if (a['createdAt'] is DateTime) {
                        tA = a['createdAt'];
                      } else {
                        tA = DateTime.now();
                      }

                      if (b['createdAt'] is Timestamp) {
                        tB = (b['createdAt'] as Timestamp).toDate();
                      } else if (b['createdAt'] is DateTime) {
                        tB = b['createdAt'];
                      } else {
                        tB = DateTime.now();
                      }

                      return tB.compareTo(tA);
                    });

                    return ValueListenableBuilder<Set<String>>(
                      valueListenable: NotificationService.readNotificationIdsNotifier,
                      builder: (context, readIds, _) {
                        // Filter to show ONLY unread items so read items / activities disappear immediately!
                        final unreadItems = items.where((it) => !readIds.contains(it['id'])).take(30).toList();

                        return Scaffold(
                      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
                      appBar: AppBar(
                        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        leadingWidth: 56,
                        leading: Padding(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    color: isDark ? Colors.white : Colors.black87,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        titleSpacing: 10,
                        title: Text(
                          'Notifikasi & Aktivitas',
                          style: AppTypography.chatHeaderTitle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        centerTitle: false,
                        actions: [
                          if (unreadItems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 14.0),
                              child: Center(
                                child: GestureDetector(
                                  onTap: () => _markAllAsRead(unreadItems),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(20),
                                      border: isDark
                                          ? Border.all(color: const Color(0xFF3F3F46), width: 1.0)
                                          : null,
                                    ),
                                    child: Text(
                                      'Baca Semua',
                                      style: AppTypography.buttonLabel(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(1),
                          child: Container(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            height: 1,
                          ),
                        ),
                      ),
                      body: unreadItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 54,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum Ada Notifikasi',
                                      style: AppTypography.sectionHeader(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Aktivitas kelas, tugas, materi, dan kuis Anda akan tampil di sini.',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.timestamp(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 8),
                              itemCount: unreadItems.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 14,
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, index) {
                                final item = unreadItems[index];
                                final String itemId = item['id'] ?? '';
                                final bool isRead = readIds.contains(itemId);

                                 return InkWell(
                                   onTap: () {
                                     _markItemAsRead(itemId);
                                     if (item['projectId'] != null && (item['projectId'] as String).isNotEmpty) {
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(
                                           builder: (_) => ClassPage(
                                             projectId: item['projectId'],
                                             projectTitle: 'Detail Classroom',
                                           ),
                                         ),
                                       );
                                     }
                                   },
                                   borderRadius: BorderRadius.circular(12),
                                   child: Padding(
                                     padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                                     child: Row(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         // Notification Text (Normal weight, font size 18, no icon)
                                         Expanded(
                                           child: Text(
                                             item['text'],
                                             style: AppTypography.chatBody(
                                               fontSize: 18.0,
                                               color: isDark ? Colors.white : Colors.black87,
                                               fontWeight: FontWeight.normal,
                                               height: 1.35,
                                             ),
                                           ),
                                         ),
                                         const SizedBox(width: 12),

                                         // Trailing Timestamp & Small Unread Indicator Dot
                                         Column(
                                           crossAxisAlignment: CrossAxisAlignment.end,
                                           children: [
                                             if (!isRead) ...[
                                               Container(
                                                 width: 7,
                                                 height: 7,
                                                 margin: const EdgeInsets.only(bottom: 4, top: 4),
                                                 decoration: const BoxDecoration(
                                                   shape: BoxShape.circle,
                                                   color: Color(0xFFEF4444), // Red Indicator Dot
                                                 ),
                                               ),
                                             ],
                                             Text(
                                               _formatTime(item['createdAt']),
                                               style: AppTypography.timestamp(
                                                 fontSize: 13,
                                                 color: isDark ? Colors.white38 : Colors.black38,
                                                 fontWeight: FontWeight.w500,
                                               ),
                                             ),
                                           ],
                                         ),
                                       ],
                                     ),
                                   ),
                                 );
                               },
                             ),
                     );
                   },
                 );
               },
             );
           },
         );
       },
     ),
   ),
 );
}
}
