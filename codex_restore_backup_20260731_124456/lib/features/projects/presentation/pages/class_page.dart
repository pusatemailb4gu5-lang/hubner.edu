import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/presentation/pages/chat_room_page.dart';
import 'baca_materi_page.dart';
import 'edit_class_page.dart';
import 'manage_members_page.dart';
import 'mengerjakan_quiz_page.dart';
import 'mengerjakan_tugas_page.dart';

class ClassPage extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final bool isEmbedded;
  final ValueChanged<bool>? onFullScreenChanged;
  final Map<String, dynamic>? registrationData;

  const ClassPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.isEmbedded = false,
    this.onFullScreenChanged,
    this.registrationData,
  });

  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  final Set<int> _expandedStages = {};
  final Set<String> _expandedMateris = {};

  Future<void> _toggleCompletion(
    String key,
    List<String> currentCompleted,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updated = List<String>.from(currentCompleted);
    if (updated.contains(key)) {
      updated.remove(key);
    } else {
      updated.add(key);
    }

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('studentProgress')
        .doc(uid)
        .set({'completedTasks': updated}, SetOptions(merge: true));
  }

  Future<void> _openClassChat(Map<String, dynamic> projectData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final name = (projectData['name'] ?? widget.projectTitle).toString();
    final discussionId = 'class_${widget.projectId}';

    await FirebaseFirestore.instance
        .collection('discussions')
        .doc(discussionId)
        .set({
          'channel': '#$name',
          'projectId': widget.projectId,
          'memberUids': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          discussionId: discussionId,
          channelName: '#$name',
          projectId: widget.projectId,
        ),
      ),
    );
  }

  void _openMembers(Map<String, dynamic> projectData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageMembersPage(
          projectId: widget.projectId,
          projectName: (projectData['name'] ?? widget.projectTitle).toString(),
          ownerUid: (projectData['ownerUid'] ?? projectData['teacherUid'] ?? '')
              .toString(),
        ),
      ),
    );
  }

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditClassPage(projectId: widget.projectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _wrapPage(
            const Center(
              child: CircularProgressIndicator(color: Colors.black87),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _wrapPage(
            Center(
              child: Text(
                'Kelas tidak ditemukan.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
              ),
            ),
          );
        }

        final projectData = snapshot.data!.data() as Map<String, dynamic>;
        final title = (projectData['name'] ?? widget.projectTitle).toString();
        final ownerUid =
            (projectData['ownerUid'] ?? projectData['teacherUid'] ?? '')
                .toString();
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isTeacher = ownerUid.isNotEmpty && ownerUid == currentUid;

        return _wrapPage(
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('studentProgress')
                .doc(currentUid)
                .snapshots(),
            builder: (context, progressSnap) {
              final progressData =
                  progressSnap.data?.data() as Map<String, dynamic>?;
              final completedTasks = List<String>.from(
                progressData?['completedTasks'] ?? [],
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        title: title,
                        projectData: projectData,
                        isTeacher: isTeacher,
                      ),
                      const SizedBox(height: 18),
                      _buildInfoBand(projectData),
                      const SizedBox(height: 18),
                      _buildStages(projectData, completedTasks, isTeacher),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _wrapPage(Widget child) {
    if (widget.isEmbedded) {
      return Container(color: const Color(0xFFF8FAFC), child: child);
    }

    return Scaffold(backgroundColor: const Color(0xFFF8FAFC), body: child);
  }

  Widget _buildHeader({
    required String title,
    required Map<String, dynamic> projectData,
    required bool isTeacher,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!widget.isEmbedded)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Diskusi',
                onTap: () => _openClassChat(projectData),
              ),
              _actionChip(
                icon: Icons.groups_rounded,
                label: 'Anggota',
                onTap: () => _openMembers(projectData),
              ),
              if (isTeacher)
                _actionChip(
                  icon: Icons.edit_note_rounded,
                  label: 'Kelola',
                  onTap: _openEditor,
                  dark: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBand(Map<String, dynamic> projectData) {
    final cp =
        (projectData['cp'] ??
                projectData['capaianPembelajaran'] ??
                projectData['description'] ??
                '')
            .toString();
    final schedule = (projectData['schedule'] ?? projectData['jadwal'] ?? '')
        .toString();

    return Column(
      children: [
        _infoCard(
          icon: Icons.flag_outlined,
          title: 'Capaian Pembelajaran',
          body: cp.isEmpty ? 'Belum ada capaian pembelajaran.' : cp,
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.calendar_month_outlined,
          title: 'Jadwal',
          body: schedule.isEmpty ? 'Jadwal belum diatur.' : schedule,
        ),
      ],
    );
  }

  Widget _buildStages(
    Map<String, dynamic> projectData,
    List<String> completedTasks,
    bool isTeacher,
  ) {
    final stages = projectData['stages'] as List? ?? [];
    if (stages.isEmpty) {
      return _emptyState('Belum ada elemen pembelajaran di kelas ini.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elemen Pembelajaran',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(stages.length, (stageIdx) {
          final stage = Map<String, dynamic>.from(stages[stageIdx] as Map);
          return _stageCard(
            stage,
            stageIdx,
            completedTasks,
            isTeacher,
            projectData,
          );
        }),
      ],
    );
  }

  Widget _stageCard(
    Map<String, dynamic> stage,
    int stageIdx,
    List<String> completedTasks,
    bool isTeacher,
    Map<String, dynamic> projectData,
  ) {
    final title = (stage['title'] ?? stage['name'] ?? 'Elemen ${stageIdx + 1}')
        .toString();
    final status = (stage['status'] ?? 'akan_datang').toString();
    final expanded = _expandedStages.contains(stageIdx);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedStages.remove(stageIdx);
                } else {
                  _expandedStages.add(stageIdx);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${stageIdx + 1}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusLabel(status),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _stageContent(
                stage,
                stageIdx,
                completedTasks,
                isTeacher,
                projectData,
              ),
            ),
        ],
      ),
    );
  }

  Widget _stageContent(
    Map<String, dynamic> stage,
    int stageIdx,
    List<String> completedTasks,
    bool isTeacher,
    Map<String, dynamic> projectData,
  ) {
    final rawMateris = stage['materis'] as List? ?? [];
    final rawTasks = stage['tasks'] as List? ?? [];
    final materis = rawMateris.isNotEmpty
        ? rawMateris.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [
            if (rawTasks.isNotEmpty)
              {'title': 'Materi Pembelajaran', 'tasks': rawTasks},
          ];

    if (materis.isEmpty) {
      return _emptyState('Belum ada materi pada elemen ini.');
    }

    return Column(
      children: List.generate(materis.length, (mIdx) {
        final materi = materis[mIdx];
        final materiTitle = (materi['title'] ?? 'Materi ${mIdx + 1}')
            .toString();
        final tasks = materi['tasks'] as List? ?? [];
        final materiKey = '${stageIdx}_$mIdx';
        final materiDoneKey = 'm_${stageIdx}_$mIdx';
        final expanded = _expandedMateris.contains(materiKey);

        return Container(
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: Icon(
                  completedTasks.contains(materiDoneKey)
                      ? Icons.check_circle_rounded
                      : Icons.menu_book_outlined,
                  color: completedTasks.contains(materiDoneKey)
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0D9488),
                ),
                title: Text(
                  materiTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  tasks.isEmpty
                      ? 'Materi mandiri'
                      : '${tasks.length} aktivitas',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  onPressed: () {
                    setState(() {
                      if (expanded) {
                        _expandedMateris.remove(materiKey);
                      } else {
                        _expandedMateris.add(materiKey);
                      }
                    });
                  },
                ),
                onTap: tasks.isEmpty
                    ? () => _toggleCompletion(materiDoneKey, completedTasks)
                    : null,
              ),
              if (expanded && tasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: List.generate(tasks.length, (taskIdx) {
                      final task = Map<String, dynamic>.from(
                        tasks[taskIdx] as Map,
                      );
                      final taskKey = '${stageIdx}_${mIdx}_$taskIdx';
                      return _taskTile(
                        task: task,
                        taskKey: taskKey,
                        completedTasks: completedTasks,
                        isTeacher: isTeacher,
                        projectData: projectData,
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _taskTile({
    required Map<String, dynamic> task,
    required String taskKey,
    required List<String> completedTasks,
    required bool isTeacher,
    required Map<String, dynamic> projectData,
  }) {
    final title = (task['title'] ?? 'Aktivitas').toString();
    final type = (task['type'] ?? 'tugas').toString();
    final completed = completedTasks.contains(taskKey);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(_taskIcon(type), color: _taskColor(type), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: completed ? Colors.black38 : Colors.black87,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  _taskLabel(type),
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (completed) {
                _toggleCompletion(taskKey, completedTasks);
              } else if (type == 'pdf') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BacaMateriPage(
                      title: title,
                      docName: task['doc']?.toString() ?? '',
                      onCompleted: () =>
                          _toggleCompletion(taskKey, completedTasks),
                    ),
                  ),
                );
              } else if (type == 'quiz') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MengerjakanQuizPage(
                      title: title,
                      durationStr: task['quizDuration']?.toString() ?? '15',
                      startTime: task['quizStartTime']?.toString() ?? '',
                      projectId: widget.projectId,
                      studentUid: currentUid,
                      taskKey: taskKey,
                      onCompleted: () =>
                          _toggleCompletion(taskKey, completedTasks),
                      isTeacher: isTeacher,
                      questions: task['questions'] as List?,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MengerjakanTugasPage(
                      title: title,
                      projectId: widget.projectId,
                      studentUid: currentUid,
                      taskKey: taskKey,
                      onCompleted: () =>
                          _toggleCompletion(taskKey, completedTasks),
                      assignmentType:
                          task['assignmentType']?.toString() ?? 'individu',
                      studentsMasterList:
                          projectData['studentsMasterList'] as List? ?? [],
                      taskText: task['tugasText']?.toString() ?? '',
                      docName: task['doc']?.toString() ?? '',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: completed
                  ? const Color(0xFFD1FAE5)
                  : _taskColor(type),
              foregroundColor: completed
                  ? const Color(0xFF047857)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              completed ? 'Selesai' : 'Buka',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool dark = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? Colors.black : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: dark ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'selesai':
        return 'Selesai';
      case 'proses':
        return 'Sedang berlangsung';
      default:
        return 'Akan datang';
    }
  }

  String _taskLabel(String type) {
    switch (type) {
      case 'quiz':
        return 'Kuis evaluasi';
      case 'pdf':
        return 'Materi PDF';
      default:
        return 'Tugas';
    }
  }

  IconData _taskIcon(String type) {
    switch (type) {
      case 'quiz':
        return Icons.quiz_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _taskColor(String type) {
    switch (type) {
      case 'quiz':
        return const Color(0xFF7C3AED);
      case 'pdf':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF2563EB);
    }
  }
}

class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    switch (patternIndex % 4) {
      case 0:
        final path = Path()
          ..moveTo(size.width * 0.55, 0)
          ..quadraticBezierTo(
            size.width * 0.8,
            size.height * 0.5,
            size.width,
            size.height,
          )
          ..lineTo(size.width, 0)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case 1:
        canvas.drawCircle(
          Offset(size.width * 0.85, size.height * 0.25),
          52,
          paint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.95, size.height * 0.85),
          36,
          paint,
        );
        break;
      case 2:
        for (double x = size.width * 0.55; x < size.width; x += 22) {
          for (double y = 12; y < size.height; y += 22) {
            canvas.drawCircle(Offset(x, y), 3, paint);
          }
        }
        break;
      default:
        final path = Path()
          ..moveTo(size.width * 0.6, 0)
          ..cubicTo(
            size.width * 0.9,
            size.height * 0.25,
            size.width * 0.55,
            size.height * 0.75,
            size.width,
            size.height,
          )
          ..lineTo(size.width, 0)
          ..close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ClassroomCardPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex ||
        oldDelegate.accentColor != accentColor;
  }
}
