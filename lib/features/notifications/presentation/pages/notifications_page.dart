import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../projects/presentation/pages/class_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedFilter = 'Semua';

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi & Aktivitas',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontSize: 21.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Classroom Selesai'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tugas Selesai'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Notifications List from Firestore Stream (Max 20 Items)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
              builder: (context, notifSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('projects').snapshots(),
                  builder: (context, projSnap) {
                    if (notifSnap.connectionState == ConnectionState.waiting &&
                        projSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    final notifDocs = notifSnap.data?.docs ?? [];
                    final projDocs = projSnap.data?.docs ?? [];

                    final List<Map<String, dynamic>> items = [];

                    // 1. Add notification documents from notifications collection
                    for (var doc in notifDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      items.add({
                        'text': data['text'] ?? '',
                        'type': data['type'] ?? 'classroom',
                        'projectId': data['projectId'] ?? '',
                        'createdAt': data['createdAt'],
                      });
                    }

                    // 2. Add completed projects and completed tasks directly from projects collection
                    for (var doc in projDocs) {
                      final pData = doc.data() as Map<String, dynamic>;
                      final pId = doc.id;
                      final pName = pData['name'] ?? 'Classroom';
                      final pStatus = (pData['status'] ?? '').toString();
                      final stages = List.from(pData['stages'] ?? []);

                      int totalTasks = 0;
                      int doneTasks = 0;
                      for (var st in stages) {
                        final tasks = List.from(st['tasks'] ?? []);
                        totalTasks += tasks.length;
                        for (var t in tasks) {
                          final isTaskDone = t['isDone'] == true || (t['progress'] ?? 0) == 100;
                          if (isTaskDone) {
                            doneTasks++;
                            final tTitle = t['title'] ?? 'Tugas';
                            final taskExists = items.any(
                              (it) => it['projectId'] == pId && it['text'].contains(tTitle),
                            );
                            if (!taskExists) {
                              items.add({
                                'text': 'Tugas "$tTitle" pada classroom "$pName" telah selesai.',
                                'type': 'tugas',
                                'projectId': pId,
                                'createdAt': pData['updatedAt'] ?? pData['createdAt'] ?? DateTime.now(),
                              });
                            }
                          }
                        }
                      }

                      final bool isDone = pStatus == 'Selesai' || (totalTasks > 0 && doneTasks == totalTasks);
                      if (isDone) {
                        final alreadyExists = items.any((it) => it['projectId'] == pId && it['type'] == 'classroom');
                        if (!alreadyExists) {
                          items.add({
                            'text': 'Classroom "$pName" telah 100% selesai dikerjakan.',
                            'type': 'classroom',
                            'projectId': pId,
                            'createdAt': pData['updatedAt'] ?? pData['createdAt'] ?? DateTime.now(),
                          });
                        }
                      }
                    }

                    // Sort items newest first
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

                    // Cap to 20 items max
                    final finalItems = items.take(20).toList();

                    // Filter items according to filter chip
                    final filteredItems = finalItems.where((item) {
                      final type = item['type'] ?? '';
                      if (_selectedFilter == 'Classroom Selesai') {
                        return type == 'classroom';
                      } else if (_selectedFilter == 'Tugas Selesai') {
                        return type == 'tugas';
                      }
                      return true;
                    }).toList();

                    if (filteredItems.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_off_outlined, size: 54, color: Colors.black26),
                              const SizedBox(height: 12),
                              Text(
                                'Belum Ada Notifikasi',
                                style: GoogleFonts.plusJakartaSans(fontSize: 17.6, fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pemberitahuan aktivitas classroom dan tugas baru akan muncul di sini.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: filteredItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return InkWell(
                          onTap: () {
                            if (item['projectId'] != null && (item['projectId'] as String).isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClassPage(
                                    projectId: item['projectId'],
                                    projectTitle: 'Detail Project',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['text'],
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15.2,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatTime(item['createdAt']),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
                                    color: Colors.black38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
      selectedColor: Colors.black,
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : Colors.black54,
      ),
      side: BorderSide(
        color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
