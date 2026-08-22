import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_members_page.dart';
import 'class_statistics_page.dart';
import 'class_learning_report_page.dart';
import 'add_class_page.dart';
import 'edit_class_page.dart';
import 'edit_cp_page.dart';
import '../../../home/presentation/pages/chat_room_page.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hubner/features/notifications/domain/notification_service.dart';
import '../widgets/student_activity_dialogs.dart';
import 'mengerjakan_tugas_page.dart';
import 'mengerjakan_quiz_page.dart';
import 'baca_materi_page.dart';
import 'detail_cp_page.dart';
import 'package:hubner/core/services/classroom_export_service.dart';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class ClassPage extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final bool isEmbedded;
  final ValueChanged<bool>? onFullScreenChanged;
  final VoidCallback? onDeselectClassroom;
  const ClassPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.isEmbedded = false,
    this.onFullScreenChanged,
    this.onDeselectClassroom,
  });
  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  final TextEditingController _quickInviteController = TextEditingController();
  final FocusNode _quickInviteFocusNode = FocusNode();
  bool _isQuickInviteFocused = false;
  bool _isQuickInviting = false;
  bool _showEditCpInline = false;
  bool _showEditJadwalInline = false;
  bool _showKelolaAnggotaInline = false;
  int? _editingStageIdx;
  String? _editingActivityType;
  int? _editingActivityMateriIdx;
  Map<String, dynamic>? _editingActivityTask;
  int? _inlineElemenStageIdx;
  String? _inlineElemenMode; // 'edit_elemen' or 'add_elemen'


  Widget _buildMembersAvatarStack(
    BuildContext context,
    String projectId,
    String projectName,
    String ownerUid,
    bool isDark, {
    required List<DocumentSnapshot> studentDocs,
  }) {
    const double avatarSize = 46.0;
    const double overlap = 14.0;

    if (studentDocs.isEmpty) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ManageMembersPage(
                projectId: projectId,
                projectName: projectName,
                ownerUid: ownerUid,
              ),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.group_add_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    final int totalCount = studentDocs.length;
    final int displayCount = totalCount > 4 ? 3 : totalCount;
    final bool hasMore = totalCount > 4;
    final int extraCount = totalCount - 3;
    final int totalSlots = hasMore ? 4 : displayCount;
    final double totalWidth = totalSlots * (avatarSize - overlap) + overlap + 4.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ManageMembersPage(
              projectId: projectId,
              projectName: projectName,
              ownerUid: ownerUid,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: avatarSize,
        width: totalWidth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < displayCount; i++)
              Positioned(
                left: i * (avatarSize - overlap),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 1.45,
                      child: _buildAvatarImage(
                        studentDocs[i].data() as Map<String, dynamic>? ?? {},
                        i,
                      ),
                    ),
                  ),
                ),
              ),
            if (hasMore)
              Positioned(
                left: displayCount * (avatarSize - overlap),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '+$extraCount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
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

  Widget _buildAvatarImage(Map<String, dynamic> userData, int index) {
    final photo = (userData['profileImageUrl'] ??
            userData['photoUrl'] ??
            userData['avatarUrl'] ??
            userData['avatar'] ??
            '')
        .toString()
        .trim();
    final name = (userData['name'] ?? 'U').toString().trim();

    if (photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return Image.network(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, index),
        );
      } else {
        return Image.asset(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, index),
        );
      }
    }
    return _buildFallbackAvatar(name, index);
  }

  Widget _buildFallbackAvatar(String name, int index) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    const colors = [
      Color(0xFFFEF08A), // Light Yellow
      Color(0xFFBBF7D0), // Light Green
      Color(0xFFFBCFE8), // Light Pink
      Color(0xFFBAE6FD), // Light Blue
      Color(0xFFDDD6FE), // Light Purple
    ];
    final Color bgColor = colors[index % colors.length];

    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Future<void> _inviteMemberByUserId(BuildContext context, String inputId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: inputId)
          .get();

      if (userQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID User tidak ditemukan. Periksa kembali ID!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final targetUserDoc = userQuery.docs.first;
      final targetUid = targetUserDoc.id;
      final targetName = targetUserDoc.get('name') ?? 'User';

      final projectIds = List<String>.from(targetUserDoc.data()['projectIds'] ?? []);
      if (projectIds.contains(widget.projectId)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengguna tersebut sudah terdaftar di kelas ini.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final pendingQuery = await FirebaseFirestore.instance
          .collection('projectInvitations')
          .where('projectId', isEqualTo: widget.projectId)
          .where('invitedUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingQuery.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Undangan untuk pengguna ini masih tertunda (Pending).'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final senderName = senderDoc.exists ? (senderDoc.get('name') ?? 'Guru') : 'Guru';

      String projectIcon = 'project_1.png';
      try {
        final projDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
        if (projDoc.exists) {
          projectIcon = (projDoc.data()?['icon'] as String?) ?? 'project_1.png';
        }
      } catch (_) {}

      await FirebaseFirestore.instance.collection('projectInvitations').add({
        'projectId': widget.projectId,
        'projectName': widget.projectTitle,
        'projectIcon': projectIcon,
        'invitedUid': targetUid,
        'invitedUserId': inputId,
        'invitedName': targetName,
        'senderUid': currentUid,
        'senderName': senderName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undangan berhasil dikirim ke $targetName! Status: Pending.'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim undangan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildQuickInviteBox(
    BuildContext context,
    String projectId,
    String projectName,
    bool isDark, {
    Color accentColor = const Color(0xFF6366F1),
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      height: 46,
      padding: const EdgeInsets.fromLTRB(16, 0, 5, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _quickInviteFocusNode,
              controller: _quickInviteController,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: _isQuickInviteFocused ? 'Ketik ID pengguna...' : 'Masukkan ID...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isQuickInviting
                ? null
                : () async {
                    final text = _quickInviteController.text.trim();
                    if (text.isEmpty) return;
                    setState(() => _isQuickInviting = true);
                    await _inviteMemberByUserId(context, text);
                    _quickInviteController.clear();
                    _quickInviteFocusNode.unfocus();
                    if (mounted) setState(() => _isQuickInviting = false);
                  },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: _isQuickInviting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      )
                    : Text(
                        'Undang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassMenuSlider({
    required BuildContext context,
    required String projectId,
    required String projectName,
    required String ownerUid,
    required bool isOwner,
    required bool isDark,
    required Color accentColor,
    required String currentCp,
    required List schedules,
    required List liveStages,
    required int studentCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(left: 14, right: 14),
      child: Row(
        children: [
          // 1. Capaian Pembelajaran (2 Baris + Bounce)
          _BouncyMenuSliderCard(
            icon: Icons.auto_stories_rounded,
            cardBg: const Color(0xFFD6A5F8),
            title: 'Capaian\nPembelajaran',
            onTap: () {
              _showCPDialog(
                context: context,
                currentCp: currentCp,
                isOwner: isOwner,
                accentColor: accentColor,
                isDark: isDark,
              );
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // 2. Jadwal Pembelajaran (2 Baris + Bounce)
          _BouncyMenuSliderCard(
            icon: Icons.calendar_month_rounded,
            cardBg: const Color(0xFF9CC8FC),
            title: 'Jadwal\nPembelajaran',
            onTap: () {
              _showTeachingScheduleDialog(
                context: context,
                schedules: schedules,
                isOwner: isOwner,
                accentColor: accentColor,
                isDark: isDark,
              );
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // 3. Kelola Siswa (2 Baris + Bounce)
          _BouncyMenuSliderCard(
            icon: Icons.people_alt_rounded,
            cardBg: const Color(0xFF7DE3D0),
            title: 'Kelola\nSiswa',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageMembersPage(
                    projectId: projectId,
                    projectName: projectName,
                    ownerUid: ownerUid,
                  ),
                ),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // 4. Statistik Lengkap (2 Baris + Bounce)
          _BouncyMenuSliderCard(
            icon: Icons.insights_rounded,
            cardBg: const Color(0xFFF7BD84),
            title: 'Statistik\nLengkap',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClassStatisticsPage(
                    projectId: projectId,
                    projectName: projectName,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // 5. Laporan Hasil Belajar (2 Baris + Bounce)
          _BouncyMenuSliderCard(
            icon: Icons.assignment_outlined,
            cardBg: const Color(0xFFF794BE),
            title: 'Laporan Hasil\nBelajar',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClassLearningReportPage(
                    projectId: projectId,
                    projectName: projectName,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  void _showClassStatistics({
    required BuildContext context,
    required String projectName,
    required int studentCount,
    required List liveStages,
    required bool isDark,
    required Color accentColor,
  }) {
    int totalMateris = 0;
    int totalTasks = 0;
    for (var s in liveStages) {
      if (s is Map) {
        final materis = s['materis'] as List? ?? [];
        totalMateris += materis.length;
        for (var m in materis) {
          if (m is Map) {
            final tasks = m['tasks'] as List? ?? [];
            totalTasks += tasks.length;
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3E8FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF7E22CE), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statistik Lengkap Kelas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          projectName,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Total Siswa',
                      value: '$studentCount',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Tahapan CP',
                      value: '${liveStages.length}',
                      icon: Icons.layers_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Total Materi',
                      value: '$totalMateris',
                      icon: Icons.menu_book_rounded,
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Total Tugas',
                      value: '$totalTasks',
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFFEC4899),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLearningReport({
    required BuildContext context,
    required String projectName,
    required List liveStages,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE4E6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Hasil Belajar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          projectName,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (liveStages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Belum ada data pembelajaran untuk ditampilkan.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                )
              else
                ...liveStages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value as Map<String, dynamic>;
                  final name = s['name'] ?? 'Elemen ${idx + 1}';
                  final status = s['status'] ?? 'proses';
                  final materis = s['materis'] as List? ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE0F2FE),
                          child: Text(
                            '${idx + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${materis.length} Materi Terdaftar',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status == 'selesai'
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status == 'selesai' ? 'Selesai' : 'Aktif',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status == 'selesai'
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  bool get _hasActiveInlinePanel =>
      _showEditCpInline ||
      _showEditJadwalInline ||
      _showKelolaAnggotaInline ||
      _editingStageIdx != null ||
      _inlineElemenMode != null;
  bool get _hasSidebarContentPanel =>
      _showEditCpInline || _showEditJadwalInline || _showKelolaAnggotaInline;
  void _closeInlinePanel() {
    setState(() {
      _showEditCpInline = false;
      _showEditJadwalInline = false;
      _showKelolaAnggotaInline = false;
      _editingStageIdx = null;
      _editingActivityType = null;
      _editingActivityMateriIdx = null;
      _editingActivityTask = null;
      _inlineElemenStageIdx = null;
      _inlineElemenMode = null;
    });
    widget.onFullScreenChanged?.call(false);
  }

  void _toggleSidebarPanel(String panel) {
    final bool shouldOpen = switch (panel) {
      'cp' => !_showEditCpInline,
      'jadwal' => !_showEditJadwalInline,
      'anggota' => !_showKelolaAnggotaInline,
      _ => false,
    };
    if (!shouldOpen) {
      _closeInlinePanel();
      return;
    }
    setState(() {
      _showEditCpInline = panel == 'cp';
      _showEditJadwalInline = panel == 'jadwal';
      _showKelolaAnggotaInline = panel == 'anggota';
      _editingStageIdx = null;
      _editingActivityType = null;
      _editingActivityMateriIdx = null;
      _editingActivityTask = null;
      _inlineElemenStageIdx = null;
      _inlineElemenMode = null;
    });
  }

  void _openElemenPanel(String mode, {int? stageIdx}) {
    setState(() {
      _showEditCpInline = false;
      _showEditJadwalInline = false;
      _showKelolaAnggotaInline = false;
      _editingStageIdx = null;
      _editingActivityType = null;
      _editingActivityMateriIdx = null;
      _editingActivityTask = null;
      _inlineElemenStageIdx = stageIdx;
      _inlineElemenMode = mode;
    });
    widget.onFullScreenChanged?.call(true);
  }

  void _setEditingStage(
    int? stageIdx, {
    String? activityType,
    int? materiIdx,
    Map<String, dynamic>? task,
  }) {
    if (stageIdx == null) {
      _closeInlinePanel();
      return;
    }
    setState(() {
      _editingStageIdx = stageIdx;
      _editingActivityType = activityType;
      _editingActivityMateriIdx = materiIdx;
      _editingActivityTask = task;
      _inlineElemenStageIdx = null;
      _inlineElemenMode = null;
      _showEditCpInline = false;
      _showEditJadwalInline = false;
      _showKelolaAnggotaInline = false;
    });
    widget.onFullScreenChanged?.call(true);
    widget.onFullScreenChanged?.call(true);
  }

  @override
  void initState() {
    super.initState();
    _quickInviteFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isQuickInviteFocused = _quickInviteFocusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _quickInviteFocusNode.dispose();
    _quickInviteController.dispose();
    super.dispose();
  }

  // Stage circle colors rotating by order
  final List<Color> _stageColors = const [
    Color(0xFFFEF3C7), // Yellow
    Color(0xFFE2DCF7), // Purple/Lavender
    Color(0xFFEFF6FF), // Blue
    Color(0xFFFCE7F3), // Pink
    Color(0xFFE2ECE9), // Teal
  ];
  final List<Color> _stageAccentColors = const [
    Color(0xFFD97706), // Amber Accent
    Color(0xFF7E22CE), // Lavender Accent
    Color(0xFF0284C7), // Ocean Blue Accent
    Color(0xFFE11D48), // Rose Accent
    Color(0xFF16A34A), // Emerald Accent
  ];
  final Map<int, int> _selectedMateriIndex = {};
  final Set<int> _expandedStageIndices = {};
  final Set<String> _expandedMateriKeys = {};
  int? _activeStatusPickerIdx;
  final List<Color> _classroomCardColors = const [
    Color(0xFF7DE3D0), // 1. Fresh Teal/Mint
    Color(0xFF9CC8FC), // 2. Periwinkle Sky Blue
    Color(0xFFD6A5F8), // 3. Lilac Purple
    Color(0xFFF794BE), // 4. Bubblegum Pink
    Color(0xFFF7BD84), // 5. Warm Apricot Orange
    Color(0xFFAEB8FD), // 6. Soft Violet/Indigo
    Color(0xFFB5E284), // 7. Fresh Lime Green
  ];
  final List<Color> _classroomCardDarkColors = const [
    Color(0xFFA4EBE0), // 1. Fresh Teal/Mint (30% softer)
    Color(0xFFBAD8FD), // 2. Periwinkle Sky Blue (30% softer)
    Color(0xFFE2C0FA), // 3. Lilac Purple (30% softer)
    Color(0xFFF9B5D2), // 4. Bubblegum Pink (30% softer)
    Color(0xFFF9D2A9), // 5. Warm Apricot Orange (30% softer)
    Color(0xFFC7CEFE), // 6. Soft Violet/Indigo (30% softer)
    Color(0xFFCCEAA9), // 7. Fresh Lime Green (30% softer)
  ];
  final List<Color> _classroomAccentColors = const [
    Color(0xFF009688), // 1. Teal (ID User & School Level)
    Color(0xFF448AFF), // 2. Blue (Nama Lengkap)
    Color(0xFFE040FB), // 3. Purple/Magenta (Email)
    Color(0xFFFF4081), // 4. Pink/Rose (Jenis Kelamin & Password)
    Color(0xFFFFAB40), // 5. Orange/Amber (Zona Waktu)
    Color(0xFF536DFE), // 6. Indigo (Bahasa)
    Color(0xFF607D8B), // 7. Blue Grey (Level Akses)
  ];
  Future<void> _updateStageStatus(
    int stageIdx,
    String newStatus,
    List currentStages,
  ) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      stage['status'] = newStatus;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!mounted) return;
      final label = newStatus == 'akan_datang'
          ? 'Elemen dikunci 🔒'
          : newStatus == 'selesai'
          ? 'Elemen Selesai ✅'
          : 'Elemen dibuka (Proses) 🔓';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          backgroundColor: newStatus == 'akan_datang'
              ? Colors.black87
              : const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildInlineStatusPill({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF27272A) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStageLock({
    required int stageIdx,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      final String currentStatus = stage['status'] as String? ?? 'akan_datang';
      // Toggle: if locked (akan_datang) -> unlock (proses), else -> lock (akan_datang)
      final String newStatus = currentStatus == 'akan_datang'
          ? 'proses'
          : 'akan_datang';
      stage['status'] = newStatus;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!mounted) return;
      final label = newStatus == 'akan_datang'
          ? 'Elemen dikunci 🔒'
          : 'Elemen dibuka 🔓';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          backgroundColor: newStatus == 'akan_datang'
              ? Colors.black87
              : const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteProject(BuildContext context) async {
    final projectId = widget.projectId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    bool loaderShown = false;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      loaderShown = true;
      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (!userDocSnapshot.exists) {
        if (context.mounted && loaderShown) {
          Navigator.pop(context);
          loaderShown = false;
        }
        return;
      }
      final projectIds = List<String>.from(
        userDocSnapshot.get('projectIds') ?? [],
      );
      if (context.mounted && loaderShown) {
        Navigator.pop(context); // pop loading
        loaderShown = false;
      }
      if (projectIds.length <= 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Anda harus memiliki minimal 1 classroom. Classroom terakhir tidak dapat dihapus.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Hapus Classroom',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus classroom ini secara permanen?',
              style: GoogleFonts.dmSans(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.dmSans(color: Colors.black54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Hapus',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
          loaderShown = true;
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .delete();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .update({
                'projectIds': FieldValue.arrayRemove([projectId]),
              });
          if (context.mounted) {
            if (loaderShown) {
              Navigator.pop(context); // pop loading
              loaderShown = false;
            }
            Navigator.pop(context); // pop page
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Classroom berhasil dihapus.'),
                backgroundColor: Colors.black87,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        if (loaderShown) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus classroom: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _leaveProject(BuildContext context) async {
    final projectId = widget.projectId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
            'projectIds': FieldValue.arrayRemove([projectId]),
          });
      if (context.mounted) {
        Navigator.pop(context); // pop loading
        Navigator.pop(context); // pop page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil keluar dari Classroom.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal keluar classroom: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleTaskComplete({
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required bool isDone,
    required List<dynamic> currentStages,
    required List<String> completedTasks,
    required bool isOwner,
  }) async {
    final projectId = widget.projectId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!isOwner) {
      final String taskKey = '${stageIdx}_${materiIdx}_$taskIdx';
      final List<String> updatedCompleted = List<String>.from(completedTasks);
      if (updatedCompleted.contains(taskKey)) {
        updatedCompleted.remove(taskKey);
      } else {
        updatedCompleted.add(taskKey);
      }
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('studentProgress')
            .doc(currentUid)
            .set({
              'uid': currentUid,
              'name': FirebaseAuth.instance.currentUser?.displayName ?? 'Siswa',
              'completedTasks': updatedCompleted,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        // ignore
      }
      return;
    }
    try {
      final List<dynamic> updatedStages = List<dynamic>.from(
        currentStages.map((s) {
          final stageMap = Map<String, dynamic>.from(s as Map);
          final List rawMateris = stageMap['materis'] as List? ?? [];
          if (rawMateris.isEmpty) {
            final List tasksList = stageMap['tasks'] as List? ?? [];
            stageMap['materis'] = [
              {
                'title': 'Materi Pembelajaran',
                'tasks': tasksList
                    .map((t) => Map<String, dynamic>.from(t as Map))
                    .toList(),
              },
            ];
            stageMap['tasks'] = [];
          } else {
            stageMap['materis'] = rawMateris.map((m) {
              final mCircle = Map<String, dynamic>.from(m as Map);
              final tasksList = List<dynamic>.from(
                mCircle['tasks'] as List? ?? [],
              );
              mCircle['tasks'] = tasksList
                  .map((t) => Map<String, dynamic>.from(t as Map))
                  .toList();
              return mCircle;
            }).toList();
          }
          return stageMap;
        }),
      );
      final stage = updatedStages[stageIdx] as Map<String, dynamic>;
      final materis = stage['materis'] as List;
      final materi = materis[materiIdx] as Map<String, dynamic>;
      final task = (materi['tasks'] as List)[taskIdx] as Map<String, dynamic>;
      final bool newIsDone = !isDone;
      task['isDone'] = newIsDone;
      task['progress'] = newIsDone ? 100 : 0;
      if (newIsDone) {
        final taskTitle = task['title'] ?? 'Tugas';
        NotificationService.addNotification(
          text: 'Tugas "$taskTitle" telah selesai dikerjakan.',
          type: 'tugas',
          projectId: projectId,
        );
      }
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
    } catch (e) {
      // ignore
    }
  }

  Future<void> _approveTask({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      final List rawMateris = stage['materis'] as List? ?? [];
      final List<Map<String, dynamic>> materis =
          List<Map<String, dynamic>>.from(
            rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
          );
      final materi = Map<String, dynamic>.from(materis[materiIdx]);
      final tasks = List.from(materi['tasks'] ?? []);
      final task = Map<String, dynamic>.from(tasks[taskIdx]);
      task.remove('isPendingApproval');
      task.remove('pendingCreatedBy');
      task['progress'] = 0;
      task['isDone'] = false;
      tasks[taskIdx] = task;
      materi['tasks'] = tasks;
      materis[materiIdx] = materi;
      stage['materis'] = materis;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item berhasil disetujui!')));
    } catch (e) {
      // ignore
    }
  }

  Future<void> _rejectTask({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Tolak Usulan',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Apakah Anda yakin ingin menolak dan menghapus usulan item ini?',
            style: GoogleFonts.dmSans(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: GoogleFonts.dmSans(color: Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Tolak',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final updatedStages = List.from(currentStages);
        final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
        final List rawMateris = stage['materis'] as List? ?? [];
        final List<Map<String, dynamic>> materis =
            List<Map<String, dynamic>>.from(
              rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
            );
        final materi = Map<String, dynamic>.from(materis[materiIdx]);
        final tasks = List.from(materi['tasks'] ?? []);
        tasks.removeAt(taskIdx);
        materi['tasks'] = tasks;
        materis[materiIdx] = materi;
        stage['materis'] = materis;
        updatedStages[stageIdx] = stage;
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({'stages': updatedStages});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usulan item ditolak dan dihapus.')),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _addMateri({
    required BuildContext context,
    required int stageIdx,
    required String materiTitle,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      final List rawMateris = stage['materis'] as List? ?? [];
      final List<Map<String, dynamic>> materis =
          List<Map<String, dynamic>>.from(
            rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
          );
      materis.add({'title': materiTitle, 'tasks': []});
      stage['materis'] = materis;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materi berhasil ditambahkan!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan materi: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAddMateriDialog({
    required BuildContext context,
    required int stageIdx,
    required List currentStages,
    required Color accentColor,
  }) {
    if (widget.isEmbedded) {
      _setEditingStage(stageIdx, activityType: 'materi_baru');
      return;
    }
    String materiTitle = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_task_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tambah Materi Baru',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16.4,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Buat materi pembelajaran baru',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.7,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Judul/Nama Materi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: TextField(
                              minLines: 1,
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                              style: GoogleFonts.dmSans(fontSize: 15.2),
                              onChanged: (val) => materiTitle = val,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText:
                                    'Contoh: Materi 1.2: Pemrograman Dasar...',
                                hintStyle: GoogleFonts.dmSans(
                                  color: Colors.black26,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (materiTitle.trim().isEmpty) return;
                              _addMateri(
                                context: context,
                                stageIdx: stageIdx,
                                materiTitle: materiTitle.trim(),
                                currentStages: currentStages,
                              );
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Tambah',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
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
  }

  Future<void> _editMateri({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required String newMateriTitle,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      final List rawMateris = stage['materis'] as List? ?? [];
      final List<Map<String, dynamic>> materis =
          List<Map<String, dynamic>>.from(
            rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
          );
      materis[materiIdx]['title'] = newMateriTitle;
      stage['materis'] = materis;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Materi berhasil diubah!')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah materi: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showEditMateriDialog({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required String currentTitle,
    required List currentStages,
  }) {
    String materiTitle = currentTitle;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Nama Materi',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18.7),
        ),
        content: TextField(
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          style: GoogleFonts.dmSans(fontSize: 16.4),
          controller: TextEditingController(text: currentTitle)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: currentTitle.length),
            ),
          onChanged: (val) => materiTitle = val,
          decoration: InputDecoration(
            hintText: 'Nama Materi...',
            hintStyle: GoogleFonts.dmSans(color: Colors.black26, fontSize: 14),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.dmSans(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (materiTitle.trim().isEmpty) return;
              _editMateri(
                context: context,
                stageIdx: stageIdx,
                materiIdx: materiIdx,
                newMateriTitle: materiTitle.trim(),
                currentStages: currentStages,
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Simpan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTask({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required String taskTitle,
    required String startDate,
    required String endDate,
    required bool isOwner,
    required List currentStages,
    required String type,
    String docName = '',
    Map<String, dynamic>? extra,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      final List rawMateris = stage['materis'] as List? ?? [];
      final List<Map<String, dynamic>> materis =
          List<Map<String, dynamic>>.from(
            rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
          );
      final materi = Map<String, dynamic>.from(materis[materiIdx]);
      final tasks = List.from(materi['tasks'] ?? []);
      final Map<String, dynamic> newTask = {
        'title': taskTitle,
        'type': type,
        'start': startDate,
        'end': endDate,
        'isDone': false,
        'progress': 0,
        'doc': docName,
      };
      if (extra != null) {
        newTask.addAll(extra);
      }
      if (!isOwner) {
        newTask['isPendingApproval'] = true;
        newTask['pendingCreatedBy'] =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anggota';
      }
      tasks.add(newTask);
      materi['tasks'] = tasks;
      materis[materiIdx] = materi;
      stage['materis'] = materis;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOwner
                ? 'Item berhasil ditambahkan!'
                : 'Usulan item berhasil dikirim!',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan item: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAddActivityChoiceDialog({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required bool isOwner,
    required List currentStages,
    required Color accentColor,
  }) {
    if (widget.isEmbedded) {
      _setEditingStage(stageIdx, activityType: null, materiIdx: materiIdx);
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 24.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat Kegiatan Baru',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Pilih jenis aktivitas pembelajaran',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.7,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildChoiceButton(
                      context: ctx,
                      icon: Icons.assignment_outlined,
                      label: 'Tugas Mandiri / Kelompok',
                      description: 'Penugasan individu atau kolaboratif siswa',
                      color: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAddActivityOverlay(
                          context: context,
                          stageIdx: stageIdx,
                          materiIdx: materiIdx,
                          isOwner: isOwner,
                          currentStages: currentStages,
                          type: 'tugas',
                        );
                      },
                    ),
                    _buildChoiceButton(
                      context: ctx,
                      icon: Icons.help_outline_rounded,
                      label: 'Kuis Evaluasi (Quiz)',
                      description: 'Latihan evaluasi pemahaman interaktif',
                      color: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAddActivityOverlay(
                          context: context,
                          stageIdx: stageIdx,
                          materiIdx: materiIdx,
                          isOwner: isOwner,
                          currentStages: currentStages,
                          type: 'quiz',
                        );
                      },
                    ),
                    _buildChoiceButton(
                      context: ctx,
                      icon: Icons.description_outlined,
                      label: 'Materi Pembelajaran (PDF)',
                      description:
                          'Bahan modul bacaan, slide presentasi, atau PDF',
                      color: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAddActivityOverlay(
                          context: context,
                          stageIdx: stageIdx,
                          materiIdx: materiIdx,
                          isOwner: isOwner,
                          currentStages: currentStages,
                          type: 'pdf',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: iconColor.withValues(alpha: 0.05),
          highlightColor: iconColor.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // Glowing Icon Container
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Text Label & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.7,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF000000), // Slate 900
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.2,
                          color: const Color(0xFF000000), // Slate 500
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chevron icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddActivityOverlay({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required bool isOwner,
    required List currentStages,
    required String type,
  }) {
    if (widget.isEmbedded) {
      _setEditingStage(stageIdx, activityType: type, materiIdx: materiIdx);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AddActivityOverlayPage(
          projectId: widget.projectId,
          stageIdx: stageIdx,
          materiIdx: materiIdx,
          isOwner: isOwner,
          currentStages: currentStages,
          initialType: type,
          onSave: (title, actType, startStr, endStr, docName, extraData) {
            _addTask(
              context: context,
              stageIdx: stageIdx,
              materiIdx: materiIdx,
              taskTitle: title,
              startDate: startStr,
              endDate: endStr,
              isOwner: isOwner,
              currentStages: currentStages,
              type: actType,
              docName: docName,
              extra: extraData,
            );
          },
        ),
      ),
    );
  }

  Future<void> _editElemen({
    required BuildContext context,
    required int stageIdx,
    required String newName,
    required String newSummary,
    required bool isVisible,
    required List currentStages,
    List? newMateris,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      stage['name'] = newName;
      stage['summary'] = newSummary;
      stage['isVisible'] = isVisible;
      if (newMateris != null) {
        stage['materis'] = newMateris;
      }
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elemen berhasil diperbarui!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui elemen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteTask({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Hapus Kegiatan',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 18.7,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus kegiatan ini secara permanen?',
            style: GoogleFonts.dmSans(fontSize: 15.2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: GoogleFonts.dmSans(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: Text(
                'Hapus',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final updatedStages = List.from(currentStages);
        final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
        final List rawMateris = stage['materis'] as List? ?? [];
        final List<Map<String, dynamic>> materis =
            List<Map<String, dynamic>>.from(
              rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
            );
        final materi = Map<String, dynamic>.from(materis[materiIdx]);
        final tasks = List.from(materi['tasks'] ?? []);
        tasks.removeAt(taskIdx);
        materi['tasks'] = tasks;
        materis[materiIdx] = materi;
        stage['materis'] = materis;
        updatedStages[stageIdx] = stage;
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({'stages': updatedStages});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kegiatan berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kegiatan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteElemen({
    required BuildContext context,
    required int stageIdx,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    final updatedStages = List.from(currentStages);
    updatedStages.removeAt(stageIdx);
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elemen berhasil dihapus!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus elemen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDeleteElemen(
    BuildContext context,
    int stageIdx,
    List currentStages,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Hapus Elemen',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17.6,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus Elemen ini secara permanen? Semua materi dan tugas di dalamnya akan ikut terhapus.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.dmSans(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteElemen(
        context: context,
        stageIdx: stageIdx,
        currentStages: currentStages,
      );
      return true;
    }
    return false;
  }

  void _showEditElemenDialog({
    required BuildContext context,
    required int stageIdx,
    required String currentName,
    required String currentSummary,
    required bool isVisible,
    required List currentStages,
    required Color accentColor,
  }) {
    String name = currentName;
    String summary = currentSummary;
    bool visible = isVisible;
    if (widget.isEmbedded) {
      _openElemenPanel('edit_elemen', stageIdx: stageIdx);
      return;
    }
    final List rawMateris = currentStages[stageIdx]['materis'] as List? ?? [];
    final List<TextEditingController> materiControllers = rawMateris.map((
      materi,
    ) {
      final String mTitle = (materi['title'] ?? '').toString();
      return TextEditingController(text: mTitle);
    }).toList();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_note_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Elemen',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.4,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Ubah rincian elemen pembelajaran',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.7,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          for (var controller in materiControllers) {
                            controller.dispose();
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nama Elemen',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            minLines: 1,
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                            controller: TextEditingController(text: currentName)
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: currentName.length),
                              ),
                            onChanged: (val) => name = val,
                            style: GoogleFonts.dmSans(fontSize: 15.2),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ringkasan / Ruang Lingkup',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: TextEditingController(
                              text: currentSummary,
                            ),
                            onChanged: (val) => summary = val,
                            style: GoogleFonts.dmSans(fontSize: 15.2),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (materiControllers.isNotEmpty) ...[
                          ...List.generate(materiControllers.length, (mIdx) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nama Materi ${mIdx + 1}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: materiControllers[mIdx],
                                      style: GoogleFonts.dmSans(fontSize: 15.2),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Nama materi...',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tampilkan ke Siswa',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch.adaptive(
                              value: visible,
                              activeColor: Colors.black,
                              onChanged: (val) => setState(() => visible = val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          for (var controller in materiControllers) {
                            controller.dispose();
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Batal',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (name.trim().isEmpty) return;
                          final List<Map<String, dynamic>> updatedMateris = [];
                          for (int i = 0; i < rawMateris.length; i++) {
                            final m = Map<String, dynamic>.from(
                              rawMateris[i] as Map,
                            );
                            if (i < materiControllers.length) {
                              m['title'] = materiControllers[i].text.trim();
                            }
                            updatedMateris.add(m);
                          }
                          _editElemen(
                            context: context,
                            stageIdx: stageIdx,
                            newName: name.trim(),
                            newSummary: summary.trim(),
                            isVisible: visible,
                            currentStages: currentStages,
                            newMateris: updatedMateris,
                          );
                          for (var controller in materiControllers) {
                            controller.dispose();
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Simpan',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCPDialog({
    required BuildContext context,
    required String currentCp,
    required bool isOwner,
    required Color accentColor,
    bool? isDark,
  }) {
    final projectId = widget.projectId;
    final bool dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    const Color cpThemeColor = Color(0xFFD6A5F8);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          clipBehavior: Clip.antiAlias,
          backgroundColor: dark ? const Color(0xFF141416) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF141416) : Colors.white,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: dark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Ikon Latar Putih Warna Hitam Sama dengan di Slider)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: cpThemeColor,
                    border: Border(
                      bottom: BorderSide(
                        color: dark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFF1F5F9),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Capaian Pembelajaran',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target & Tujuan Kompetensi Siswa',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogCtx),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentCp.isNotEmpty) ...[
                          // Tombol edit diatas card text berupa ikon bolpen saja
                          if (isOwner)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, right: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Deskripsi CP',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: dark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      Navigator.pop(dialogCtx);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => EditCpPage(
                                            projectId: projectId,
                                            projectName: widget.projectTitle,
                                            initialCp: currentCp,
                                            accentColor: cpThemeColor,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                        color: dark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: dark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: dark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              currentCp,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: dark ? Colors.white70 : const Color(0xFF334155),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                            decoration: BoxDecoration(
                              color: dark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: dark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: cpThemeColor.withValues(alpha: dark ? 0.2 : 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.auto_stories_rounded,
                                      size: 24,
                                      color: Color(0xFF3B0764),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum Ada Capaian Belajar',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: dark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Target & capaian pembelajaran belum diatur untuk kelas ini.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: dark ? Colors.white38 : Colors.black45,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (isOwner) ...[
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(dialogCtx);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => EditCpPage(
                                            projectId: projectId,
                                            projectName: widget.projectTitle,
                                            initialCp: currentCp,
                                            accentColor: cpThemeColor,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: dark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Tambah CP Sekarang',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTeachingScheduleDialog({
    required BuildContext context,
    required List schedules,
    required bool isOwner,
    required Color accentColor,
    bool? isDark,
  }) {
    final bool dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    const Color scheduleThemeColor = Color(0xFF9CC8FC);

    final List<Map<String, dynamic>> localSchedules =
        List<Map<String, dynamic>>.from(
          schedules.map((e) => Map<String, dynamic>.from(e as Map)),
        );

    final Map<String, Map<String, dynamic>> dayColorsMap = {
      'senin': {'bg': const Color(0xFFFEF2F2), 'darkBg': const Color(0xFF2D1517), 'fg': const Color(0xFFEF4444)},
      'selasa': {'bg': const Color(0xFFFFF7ED), 'darkBg': const Color(0xFF2D1E12), 'fg': const Color(0xFFF97316)},
      'rabu': {'bg': const Color(0xFFF0FDF4), 'darkBg': const Color(0xFF13281B), 'fg': const Color(0xFF10B981)},
      'kamis': {'bg': const Color(0xFFEFF6FF), 'darkBg': const Color(0xFF14223B), 'fg': const Color(0xFF3B82F6)},
      'jumat': {'bg': const Color(0xFFF3E8FF), 'darkBg': const Color(0xFF25153A), 'fg': const Color(0xFF8B5CF6)},
      'sabtu': {'bg': const Color(0xFFFDF2F8), 'darkBg': const Color(0xFF2E1325), 'fg': const Color(0xFFEC4899)},
      'minggu': {'bg': const Color(0xFFF0FDFA), 'darkBg': const Color(0xFF112A29), 'fg': const Color(0xFF14B8A6)},
    };

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isEditing = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
              ),
              clipBehavior: Clip.antiAlias,
              backgroundColor: dark ? const Color(0xFF141416) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF141416) : Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: dark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header (Ikon Latar Putih Warna Hitam Sama dengan di Slider)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: scheduleThemeColor,
                        border: Border(
                          bottom: BorderSide(
                            color: dark
                                ? const Color(0xFF27272A)
                                : const Color(0xFFF1F5F9),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isEditing ? 'Kelola Jadwal Kelas' : 'Jadwal Pembelajaran',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hari & Jam Pertemuan Kelas',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isOwner)
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  isEditing = !isEditing;
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isEditing ? Icons.visibility_rounded : Icons.edit_rounded,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.black87,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body: Langsung list jadwal tanpa tab hari/semua
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (localSchedules.isEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: dark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: dark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: scheduleThemeColor.withValues(alpha: dark ? 0.2 : 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.calendar_month_rounded,
                                          size: 24,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum Ada Jadwal',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: dark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Jadwal pembelajaran belum diatur untuk kelas ini.',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: dark ? Colors.white38 : Colors.black45,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (isOwner && !isEditing) ...[
                                      const SizedBox(height: 16),
                                      GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            isEditing = true;
                                            localSchedules.add({
                                              'day': 'Senin',
                                              'time': '08:00 - 09:30',
                                              'startTime': '08:00',
                                              'endTime': '09:30',
                                              'room': 'Ruang Kelas',
                                            });
                                          });
                                        },
                                        child: Container(
                                          height: 40,
                                          padding: const EdgeInsets.symmetric(horizontal: 18),
                                          decoration: BoxDecoration(
                                            color: dark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Atur Jadwal Sekarang',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ] else ...[
                              ...List.generate(
                                localSchedules.length,
                                (idx) {
                                  final item = localSchedules[idx];
                                  final String dayStr = (item['day'] ?? 'Senin').toString();
                                  final String rawTime = (item['time'] ?? '08:00 - 09:30').toString();

                                  if (isEditing) {
                                    // Edit item card dengan dropdown hari lebih rapat
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                                      decoration: BoxDecoration(
                                        color: dark ? const Color(0xFF18181B) : Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: dark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Dropdown Hari Lebih Rapat
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: scheduleThemeColor.withValues(alpha: dark ? 0.25 : 0.3),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: [
                                                  'Senin',
                                                  'Selasa',
                                                  'Rabu',
                                                  'Kamis',
                                                  'Jumat',
                                                  'Sabtu',
                                                  'Minggu',
                                                ].contains(dayStr)
                                                    ? dayStr
                                                    : 'Senin',
                                                isDense: true,
                                                itemHeight: null,
                                                menuMaxHeight: 220,
                                                icon: Icon(
                                                  Icons.arrow_drop_down_rounded,
                                                  size: 20,
                                                  color: dark ? Colors.white70 : Colors.black87,
                                                ),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12.5,
                                                  color: dark ? Colors.white : Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                dropdownColor: dark ? const Color(0xFF1E1E22) : Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                onChanged: (newDay) {
                                                  if (newDay != null) {
                                                    setModalState(() {
                                                      localSchedules[idx]['day'] = newDay;
                                                    });
                                                  }
                                                },
                                                items: [
                                                  'Senin',
                                                  'Selasa',
                                                  'Rabu',
                                                  'Kamis',
                                                  'Jumat',
                                                  'Sabtu',
                                                  'Minggu',
                                                ].map((d) {
                                                  return DropdownMenuItem<String>(
                                                    value: d,
                                                    alignment: Alignment.centerLeft,
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Text(
                                                        d,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Time Input Field
                                          Expanded(
                                            child: TextField(
                                              controller: TextEditingController(text: rawTime)
                                                ..selection = TextSelection.fromPosition(
                                                  TextPosition(offset: rawTime.length),
                                                ),
                                              onChanged: (newTime) {
                                                localSchedules[idx]['time'] = newTime;
                                                final parts = newTime.split('-');
                                                if (parts.length == 2) {
                                                  localSchedules[idx]['startTime'] = parts[0].trim();
                                                  localSchedules[idx]['endTime'] = parts[1].trim();
                                                } else {
                                                  localSchedules[idx]['startTime'] = newTime;
                                                  localSchedules[idx]['endTime'] = '';
                                                }
                                              },
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: dark ? Colors.white : Colors.black87,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '08:00 - 09:30',
                                                hintStyle: GoogleFonts.dmSans(
                                                  fontSize: 13,
                                                  color: dark ? Colors.white30 : Colors.black38,
                                                ),
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Delete Button
                                          GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                localSchedules.removeAt(idx);
                                              });
                                            },
                                            child: Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withValues(alpha: dark ? 0.2 : 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.redAccent,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // View item card (Round & Sleek, tanpa info ruangan)
                                  String startTime = (item['startTime'] ?? item['start'] ?? '').toString();
                                  String endTime = (item['endTime'] ?? item['end'] ?? '').toString();
                                  if (startTime.isEmpty && endTime.isEmpty && rawTime.isNotEmpty) {
                                    final parts = rawTime.split('-');
                                    if (parts.length == 2) {
                                      startTime = parts[0].trim();
                                      endTime = parts[1].trim();
                                    } else {
                                      startTime = rawTime;
                                      endTime = '';
                                    }
                                  }
                                  if (startTime.isEmpty) startTime = '07:30';
                                  if (endTime.isEmpty) endTime = '09:00';
                                  final String displayTime = endTime.isNotEmpty
                                      ? '$startTime - $endTime WIB'
                                      : '$startTime WIB';
                                  final key = dayStr.toLowerCase();
                                  final colorScheme = dayColorsMap[key] ?? {
                                    'bg': const Color(0xFFEFF6FF),
                                    'darkBg': const Color(0xFF14223B),
                                    'fg': const Color(0xFF2563EB),
                                  };
                                  final Color dBg = dark ? colorScheme['darkBg']! : colorScheme['bg']!;
                                  final Color dFg = colorScheme['fg']!;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: dark ? const Color(0xFF18181B) : Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: dark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: dark ? 0.35 : 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          height: 38,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: dBg,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: dFg.withValues(alpha: 0.3),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              dayStr.toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: dFg,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 16,
                                          color: dark ? Colors.white70 : Colors.black87,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            displayTime,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: dark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],

                            if (isEditing) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    localSchedules.add({
                                      'day': 'Senin',
                                      'time': '08:00 - 09:30',
                                      'startTime': '08:00',
                                      'endTime': '09:30',
                                      'room': 'Ruang Kelas',
                                    });
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: dark ? const Color(0xFF1F1F23) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: dark ? const Color(0xFF27272A) : const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 16,
                                        color: dark ? Colors.white70 : Colors.black87,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tambah Hari / Jam Baru',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: dark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(widget.projectId)
                                        .update({
                                          'schedules': localSchedules,
                                        });
                                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Jadwal mengajar berhasil diperbarui!',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal memperbarui jadwal: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: dark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Simpan Jadwal',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;
    final projectTitle = widget.projectTitle;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('Classroom tidak ditemukan.')),
          );
        }
        final projectData = snapshot.data!.data() as Map<String, dynamic>;
        final name = projectData['name'] ?? projectTitle;
        final description = projectData['description'] ?? '';
        final stages = projectData['stages'] as List? ?? [];
        final ownerUid = projectData['ownerUid'] ?? '';
        final isOwner = currentUid == ownerUid;
        final statusStr = projectData['status'] as String? ?? 'Berjalan';
        final List masterList =
            projectData['studentsMasterList'] as List? ?? [];
        final bool needsToLink =
            !isOwner &&
            masterList.isNotEmpty &&
            !masterList.any((s) => s['uid'] == currentUid);
        if (needsToLink) {
          return _buildLinkIdentityScreen(
            context: context,
            projectId: projectId,
            masterList: masterList,
            currentUid: currentUid,
          );
        }
        if (!isOwner) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(projectId)
                .collection('studentProgress')
                .doc(currentUid)
                .snapshots(),
            builder: (context, progressSnap) {
              final List<String> completedTasks =
                  progressSnap.hasData && progressSnap.data!.exists
                  ? List<String>.from(
                      progressSnap.data!.get('completedTasks') ?? [],
                    )
                  : [];
              return _buildClassPageContent(
                context: context,
                projectData: projectData,
                name: name,
                description: description,
                stages: stages,
                isOwner: isOwner,
                statusStr: statusStr,
                completedTasks: completedTasks,
              );
            },
          );
        } else {
          return _buildClassPageContent(
            context: context,
            projectData: projectData,
            name: name,
            description: description,
            stages: stages,
            isOwner: isOwner,
            statusStr: statusStr,
            completedTasks: const [],
          );
        }
      },
    );
  }

  Widget _buildLinkIdentityScreen({
    required BuildContext context,
    required String projectId,
    required List masterList,
    required String currentUid,
  }) {
    final unlinkedStudents = masterList
        .where((s) => (s['uid'] as String? ?? '').isEmpty)
        .toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 40,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pilih Identitas Anda',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 23.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Guru Anda telah memasukkan daftar nama siswa untuk kelas ini. Silakan pilih nama Anda untuk menyelaraskan progress tugas Anda.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (unlinkedStudents.isEmpty) ...[
                  Text(
                    'Semua identitas siswa dalam daftar induk telah terpakai atau terhubung. Silakan hubungi guru Anda untuk menambahkan nama Anda ke daftar induk.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.9,
                      color: Colors.redAccent,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Kembali',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: unlinkedStudents.length,
                      separatorBuilder: (c, i) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (ctx, idx) {
                        final student =
                            unlinkedStudents[idx] as Map<String, dynamic>;
                        final String name = student['name'] ?? '';
                        return ListTile(
                          title: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.black26,
                          ),
                          onTap: () => _confirmIdentityLink(
                            context: context,
                            projectId: projectId,
                            selectedName: name,
                            currentMasterList: masterList,
                            currentUid: currentUid,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Kembali ke Beranda',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmIdentityLink({
    required BuildContext context,
    required String projectId,
    required String selectedName,
    required List currentMasterList,
    required String currentUid,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Konfirmasi Identitas',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17.6),
        ),
        content: Text(
          'Apakah Anda yakin memilih sebagai "$selectedName"? Pilihan ini tidak dapat diubah setelah dikonfirmasi.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.dmSans(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final List<Map<String, dynamic>> updatedList = currentMasterList
                    .map((e) {
                      final entry = Map<String, dynamic>.from(e as Map);
                      if (entry['name'] == selectedName) {
                        entry['uid'] = currentUid;
                        entry['joined'] = true;
                      }
                      return entry;
                    })
                    .toList();
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(projectId)
                    .update({'studentsMasterList': updatedList});
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(projectId)
                    .collection('studentProgress')
                    .doc(currentUid)
                    .set({
                      'uid': currentUid,
                      'name': selectedName,
                      'completedTasks': <String>[],
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Identitas berhasil dikaitkan sebagai $selectedName!',
                    ),
                  ),
                );
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Konfirmasi',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBarcodeDialog(BuildContext context, String projectId, String title, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          clipBehavior: Clip.antiAlias,
          backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141416) : Colors.white,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Sama Gaya dengan Dialog Atur Jadwal)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6A5F8),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Barcode Kelas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Pindai QR code di bawah ini atau salin kode kelas untuk bergabung ke dalam kelas.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // QR Code Image
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              width: 1.5,
                            ),
                          ),
                          child: SizedBox(
                            width: 180,
                            height: 180,
                            child: QrImageView(
                              data: projectId,
                              version: QrVersions.auto,
                              gapless: false,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Code display container with copy action
                      Container(
                        padding: const EdgeInsets.only(left: 18, right: 6, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF221A33) : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(32),
                          border: isDark ? Border.all(color: const Color(0xFF382952), width: 1.0) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KODE KELAS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  SelectableText(
                                    projectId,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: projectId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kode kelas berhasil disalin!'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF141416) : Colors.black,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  'Salin',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showResetStagesDialog(BuildContext context, List currentStages) async {
    final bool isDark = AppColors.isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.restart_alt_rounded, color: Color(0xFFEA580C)),
              const SizedBox(width: 10),
              Text(
                'Atur Ulang Pembelajaran?',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Semua status tahapan pembelajaran akan diatur ulang ke status awal (Akan Datang). Apakah Anda yakin?',
            style: GoogleFonts.dmSans(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Atur Ulang'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final updatedStages = currentStages.map((s) {
        if (s is Map) {
          final m = Map<String, dynamic>.from(s);
          m['status'] = 'akan_datang';
          return m;
        }
        return s;
      }).toList();
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'stages': updatedStages});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua tahapan pembelajaran berhasil diatur ulang.'),
            backgroundColor: Color(0xFFEA580C),
          ),
        );
      }
    }
  }

  Future<void> _showLeaveDialog(BuildContext context) async {
    final bool isDark = AppColors.isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? const BorderSide(color: Color(0xFF27272A), width: 1.0)
              : BorderSide.none,
        ),
        title: Text(
          'Keluar dari Classroom',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18.7,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari classroom ini?',
          style: GoogleFonts.dmSans(
            fontSize: 15.2,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.dmSans(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      _leaveProject(context);
    }
  }

  Widget _buildClassPageContent({
    required BuildContext context,
    required Map<String, dynamic> projectData,
    required String name,
    required String description,
    required List stages,
    required bool isOwner,
    required String statusStr,
    required List<String> completedTasks,
  }) {
    final projectId = widget.projectId;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('Classroom tidak ditemukan.')),
          );
        }
        final liveProjectData = snapshot.data!.data() as Map<String, dynamic>;
        final liveStages = liveProjectData['stages'] as List? ?? stages;
        final ownerUid = liveProjectData['ownerUid'] ?? projectData['ownerUid'] ?? '';
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final memberList = liveProjectData['members'] as List? ?? projectData['members'] as List? ?? [];
        final int totalSiswa = memberList.length;
        final String gradeLevel = (liveProjectData['gradeLevel'] ?? projectData['gradeLevel'] ?? '').toString();
        final String major = (liveProjectData['major'] ?? projectData['major'] ?? '').toString();
        String classLabel = gradeLevel.isNotEmpty
            ? (major.isNotEmpty ? '$gradeLevel $major' : gradeLevel)
            : (major.isNotEmpty ? major : 'Kelas');
        final String iconFileName = (liveProjectData['icon'] ?? projectData['icon'] ?? 'project_1.png').toString();
        final String iconPath = 'assets/icon_pack/project/$iconFileName';
        final String currentCp = (liveProjectData['cp'] ?? projectData['cp'] ?? '').toString();
        final List schedules = liveProjectData['schedules'] as List? ?? projectData['schedules'] as List? ?? [];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, userSnap) {
            final List<String> projectIds =
                userSnap.hasData && userSnap.data!.exists
                ? List<String>.from(userSnap.data!.get('projectIds') ?? [])
                : [];
            final dynamic rawColorIdx = liveProjectData['colorIndex'] ?? projectData['colorIndex'];
            int resolvedIdx = 0;
            if (rawColorIdx is int) {
              resolvedIdx = rawColorIdx;
            } else if (rawColorIdx is String) {
              resolvedIdx = int.tryParse(rawColorIdx) ?? 0;
            } else if (rawColorIdx is num) {
              resolvedIdx = rawColorIdx.toInt();
            } else if (projectIds.indexOf(projectId) >= 0) {
              resolvedIdx = projectIds.indexOf(projectId);
            }
            final int themeIdx = resolvedIdx % _classroomCardColors.length;
            final bool isDark = AppColors.isDarkMode;
            final List<Color> activeCardColors = isDark ? _classroomCardDarkColors : _classroomCardColors;
            final Color cardColor = activeCardColors[themeIdx];
            final Color accentColor = _classroomAccentColors[themeIdx];

            // Palet Slider (Warna Latar Mode Terang)
            final List<Color> sliderColors = const [
              Color(0xFFD6A5F8), // 1. Ungu Slider
              Color(0xFF9CC8FC), // 2. Biru Slider
              Color(0xFF7DE3D0), // 3. Tosca Slider
              Color(0xFFF7BD84), // 4. Orange Slider
              Color(0xFFF794BE), // 5. Pink Slider
            ];

            // Palet Soft Pastel (Warna Latar Mode Gelap - Terang & Bersih)
            final List<Color> softPastelColors = const [
              Color(0xFFEDE9FE), // Soft Lavender
              Color(0xFFE0F2FE), // Soft Blue
              Color(0xFFD1FAE5), // Soft Mint
              Color(0xFFFEF3C7), // Soft Kuning/Peach
              Color(0xFFFFE4E6), // Soft Pink
            ];

            final Widget stagesListWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tahapan Pembelajaran',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if (isOwner)
                      GestureDetector(
                        onTap: () {
                          if (widget.isEmbedded) {
                            _openElemenPanel('add_elemen');
                          } else {
                            _addElemen(
                              context: context,
                              name: 'Elemen ${liveStages.length + 1}',
                              summary: '',
                              isVisible: true,
                              currentStages: liveStages,
                            );
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: isDark ? Colors.black : Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (liveStages.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141416) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Belum ada tahapan capaian pembelajaran.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: liveStages.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final stage = liveStages[index] as Map<String, dynamic>;
                      final String stageName = stage['name'] ?? 'Elemen ${index + 1}';
                      final String stageDesc = (stage['summary'] ?? '').toString();
                      final String stageStatus = stage['status'] as String? ?? 'proses';
                      final bool isVisible = stage['isVisible'] ?? true;
                      final bool isLockedForStudent = !isOwner && stageStatus == 'akan_datang';
                      if (!isOwner && !isVisible) {
                        return const SizedBox.shrink();
                      }

                      final int bIdx = index % sliderColors.length;
                      // Mode Terang: Latar = Warna Slider, Angka = Putih
                      // Mode Gelap: Latar = Warna Soft Pastel Asli Terang, Angka = Warna Slider
                      final Color bBg = isDark
                          ? softPastelColors[bIdx]
                          : sliderColors[bIdx];
                      final Color bFg = isDark
                          ? (bIdx == 0
                              ? const Color(0xFF7C3AED)
                              : bIdx == 1
                                  ? const Color(0xFF2563EB)
                                  : bIdx == 2
                                      ? const Color(0xFF059669)
                                      : bIdx == 3
                                          ? const Color(0xFFEA580C)
                                          : const Color(0xFFE11D48))
                          : Colors.white;

                      final List rawMateris = stage['materis'] as List? ?? [];
                      int totalMateris = rawMateris.length;
                      int totalTasksCount = 0;
                      for (var m in rawMateris) {
                        final tasks = (m as Map)['tasks'] as List? ?? [];
                        totalTasksCount += tasks.length;
                      }

                      String statusLabel = 'Proses';
                      Color statusBg = const Color(0xFFDBEAFE);
                      Color statusFg = const Color(0xFF1D4ED8);
                      if (stageStatus == 'selesai') {
                        statusLabel = 'Selesai';
                        statusBg = const Color(0xFFD1FAE5);
                        statusFg = const Color(0xFF047857);
                      } else if (stageStatus == 'akan_datang') {
                        statusLabel = 'Akan Datang';
                        statusBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
                        statusFg = isDark ? Colors.white70 : Colors.black54;
                      }

                      Color stageCardBg = isDark ? const Color(0xFF141416) : Colors.white;
                      if (stageStatus == 'proses') {
                        stageCardBg = const Color(0xFFF7BD84); // Kuning/Orange Slider (soft light tone)
                      } else if (stageStatus == 'selesai') {
                        stageCardBg = const Color(0xFF7DE3D0); // Hijau/Tosca Slider (soft light tone)
                      }

                      final Color stageTitleColor = (stageStatus == 'proses' || stageStatus == 'selesai')
                          ? const Color(0xFF0F172A)
                          : (isDark ? Colors.white : Colors.black87);

                      final Color stageSubtitleColor = (stageStatus == 'proses')
                          ? const Color(0xFF7C2D12).withValues(alpha: 0.85)
                          : (stageStatus == 'selesai')
                              ? const Color(0xFF064E3B).withValues(alpha: 0.85)
                              : (isDark ? Colors.white54 : Colors.black45);

                      return Dismissible(
                        key: ValueKey('stage_${index}_${stageName}'),
                        direction: isOwner ? DismissDirection.endToStart : DismissDirection.none,
                        confirmDismiss: (direction) async {
                          return await _confirmDeleteElemen(context, index, liveStages);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.transparent,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                              const SizedBox(width: 4),
                              Text(
                                'Hapus',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isLockedForStudent
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Elemen "$stageName" belum dibuka oleh guru.'),
                                        backgroundColor: Colors.black87,
                                      ),
                                    );
                                  }
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailCpPage(
                                          projectId: projectId,
                                          projectTitle: name,
                                          stageIdx: index,
                                          isOwner: isOwner,
                                          accentColor: accentColor,
                                          cardColor: cardColor,
                                        ),
                                      ),
                                    );
                                  },
                            borderRadius: BorderRadius.circular(32),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                              decoration: BoxDecoration(
                                color: stageCardBg,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Circular number badge - simetris atas-bawah-kiri seukuran icon slider
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: bBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        (index + 1).toString().padLeft(2, '0'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: bFg,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Title & Subtitle
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            stageName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: stageTitleColor,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            stageDesc.isNotEmpty
                                                ? stageDesc
                                                : (totalMateris > 0
                                                    ? '$totalMateris Materi · $totalTasksCount Tugas'
                                                    : 'Atur materi & tugas'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11.5,
                                              color: stageSubtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                   // Status Dropdown Menu Mini (Tanpa ikon, tanpa celah, rata kiri, ada pembatas garis)
                                   PopupMenuButton<String>(
                                     tooltip: '',
                                     padding: EdgeInsets.zero,
                                     constraints: const BoxConstraints(minWidth: 88, maxWidth: 88),
                                     shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(10),
                                       side: isDark
                                           ? const BorderSide(color: Color(0xFF27272A), width: 1.0)
                                           : const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                     ),
                                     elevation: 4,
                                     color: isDark ? const Color(0xFF101012) : Colors.white,
                                     enabled: isOwner,
                                     onSelected: (val) {
                                       _updateStageStatus(index, val, liveStages);
                                     },
                                     itemBuilder: (context) => [
                                       PopupMenuItem(
                                         value: 'proses',
                                         height: 28,
                                         padding: EdgeInsets.zero,
                                         child: Container(
                                           height: 28,
                                           alignment: Alignment.centerLeft,
                                           padding: const EdgeInsets.symmetric(horizontal: 10),
                                           decoration: BoxDecoration(
                                             border: Border(
                                               bottom: BorderSide(
                                                 color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                 width: 1,
                                               ),
                                             ),
                                           ),
                                           child: Text(
                                             'Proses',
                                             style: GoogleFonts.plusJakartaSans(
                                               fontSize: 11.5,
                                               fontWeight: FontWeight.w700,
                                               color: isDark ? Colors.white : const Color(0xFF0F172A),
                                             ),
                                           ),
                                         ),
                                       ),
                                       PopupMenuItem(
                                         value: 'selesai',
                                         height: 28,
                                         padding: EdgeInsets.zero,
                                         child: Container(
                                           height: 28,
                                           alignment: Alignment.centerLeft,
                                           padding: const EdgeInsets.symmetric(horizontal: 10),
                                           decoration: BoxDecoration(
                                             border: Border(
                                               bottom: BorderSide(
                                                 color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                 width: 1,
                                               ),
                                             ),
                                           ),
                                           child: Text(
                                             'Selesai',
                                             style: GoogleFonts.plusJakartaSans(
                                               fontSize: 11.5,
                                               fontWeight: FontWeight.w700,
                                               color: isDark ? Colors.white : const Color(0xFF0F172A),
                                             ),
                                           ),
                                         ),
                                       ),
                                       PopupMenuItem(
                                         value: 'akan_datang',
                                         height: 28,
                                         padding: EdgeInsets.zero,
                                         child: Container(
                                           height: 28,
                                           alignment: Alignment.centerLeft,
                                           padding: const EdgeInsets.symmetric(horizontal: 10),
                                           child: Text(
                                             'Akan Datang',
                                             style: GoogleFonts.plusJakartaSans(
                                               fontSize: 11.5,
                                               fontWeight: FontWeight.w700,
                                               color: isDark ? Colors.white : const Color(0xFF0F172A),
                                             ),
                                           ),
                                         ),
                                       ),
                                     ],
                                     child: Container(
                                       width: 88,
                                       height: 26,
                                       alignment: Alignment.center,
                                       decoration: BoxDecoration(
                                         color: (stageStatus == 'proses' || stageStatus == 'selesai')
                                             ? (isDark ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.85))
                                             : (isDark ? statusFg.withValues(alpha: 0.18) : statusBg),
                                         borderRadius: BorderRadius.circular(8),
                                       ),
                                       child: Text(
                                         statusLabel,
                                         style: GoogleFonts.plusJakartaSans(
                                           fontSize: 10.5,
                                           fontWeight: FontWeight.bold,
                                           color: (stageStatus == 'proses' || stageStatus == 'selesai')
                                               ? const Color(0xFF0F172A)
                                               : (isDark ? Colors.white : statusFg),
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                   ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );

            final double screenHeight = MediaQuery.of(context).size.height;

            return Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
              body: Stack(
                children: [
                  // Layer 0: Fixed Hero Background & Header Content (Statis di belakang, tidak bergeser naik saat di-scroll)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: screenHeight * 0.65,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? _classroomCardDarkColors[themeIdx] : cardColor,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ClassroomCardPatternPainter(
                                patternIndex: themeIdx,
                                accentColor: accentColor,
                              ),
                            ),
                          ),
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 58, 14, 20),
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .where('projectIds', arrayContains: projectId)
                                    .snapshots(),
                                builder: (context, membersSnap) {
                                  final allDocs = membersSnap.data?.docs ?? [];
                                  // Anggota kelas hanya menampilkan siswa (filter out guru/pengajar/admin/owner)
                                  final studentDocs = allDocs.where((d) {
                                    final data = d.data() as Map<String, dynamic>? ?? {};
                                    final role = (data['role'] ?? '').toString().toLowerCase();
                                    if (d.id == ownerUid) return false;
                                    if (role == 'guru' ||
                                        role == 'teacher' ||
                                        role == 'pengajar' ||
                                        role == 'admin') {
                                      return false;
                                    }
                                    return true;
                                  }).toList();
                                  final int studentCount = studentDocs.length;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Row: Icon Class + Nama Mapel Lengkap & ID Kelas
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: SizedBox(
                                              width: 68,
                                              height: 68,
                                              child: Image.asset(
                                                iconPath,
                                                fit: BoxFit.contain,
                                                errorBuilder: (ctx, err, st) => const Icon(
                                                  Icons.school_rounded,
                                                  size: 48,
                                                  color: Colors.black38,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  name,
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: () {
                                                      final len = name.length;
                                                      if (len > 60) return 16.0;
                                                      if (len > 40) return 18.5;
                                                      if (len > 25) return 21.0;
                                                      if (len > 15) return 23.5;
                                                      return 26.0;
                                                    }(),
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(0xFF0F172A),
                                                    height: 1.15,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () {
                                                    Clipboard.setData(ClipboardData(text: projectId));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('ID Kelas berhasil disalin!')),
                                                    );
                                                  },
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.copy_rounded,
                                                          size: 11,
                                                          color: Colors.black87,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'ID: $projectId',
                                                          style: GoogleFonts.dmSans(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Middle Row: Slider Horizontal (Kelas, Siswa, Scanner)
                                      SizedBox(
                                        width: double.infinity,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                          clipBehavior: Clip.none,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                height: 46,
                                                padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                                                  borderRadius: BorderRadius.circular(30),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(0xFF27272A)
                                                        : const Color(0xFFF1F5F9),
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 34,
                                                      height: 34,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFFFEF3C7),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.school_rounded,
                                                          size: 17,
                                                          color: Color(0xFFD97706),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      classLabel,
                                                      maxLines: 2,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                        height: 1.15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => ManageMembersPage(
                                                        projectId: projectId,
                                                        projectName: name,
                                                        ownerUid: ownerUid,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  height: 46,
                                                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                                                    borderRadius: BorderRadius.circular(30),
                                                    border: Border.all(
                                                      color: isDark
                                                          ? const Color(0xFF27272A)
                                                          : const Color(0xFFF1F5F9),
                                                      width: 1.2,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 34,
                                                        height: 34,
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFFE0F2FE),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Center(
                                                          child: Icon(
                                                            Icons.people_alt_rounded,
                                                            size: 17,
                                                            color: accentColor,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '$studentCount Siswa',
                                                        maxLines: 1,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _showBarcodeDialog(context, projectId, name, isDark),
                                                behavior: HitTestBehavior.opaque,
                                                child: Container(
                                                  width: 46,
                                                  height: 46,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.qr_code_scanner_rounded,
                                                      color: isDark ? Colors.white : Colors.black,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Bottom Row: Members Avatar Stack + Quick Invite Box
                                      Row(
                                        children: [
                                          if (!_isQuickInviteFocused) ...[
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: (MediaQuery.of(context).size.width - 28 - 8) * 0.5,
                                              ),
                                              child: _buildMembersAvatarStack(
                                                context,
                                                projectId,
                                                name,
                                                ownerUid,
                                                isDark,
                                                studentDocs: studentDocs,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            child: _buildQuickInviteBox(
                                              context,
                                              projectId,
                                              name,
                                              isDark,
                                              accentColor: accentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Layer 1: Draggable Sheet Tahapan Pembelajaran (Meluncur Menutup Hero Saat Di-Drag/Scroll ke Atas)
                  DraggableScrollableSheet(
                    initialChildSize: 0.62,
                    minChildSize: 0.62,
                    maxChildSize: 0.95,
                    snap: true,
                    snapSizes: const [0.62, 0.95],
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141416) : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 14, 0, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 44,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .where('projectIds', arrayContains: projectId)
                                    .snapshots(),
                                builder: (context, membersSnap) {
                                  final allDocs = membersSnap.data?.docs ?? [];
                                  final studentDocs = allDocs.where((d) {
                                    final data = d.data() as Map<String, dynamic>? ?? {};
                                    final role = (data['role'] ?? '').toString().toLowerCase();
                                    if (d.id == ownerUid) return false;
                                    if (role == 'guru' ||
                                        role == 'teacher' ||
                                        role == 'pengajar' ||
                                        role == 'admin') {
                                      return false;
                                    }
                                    return true;
                                  }).toList();
                                  final int studentCount = studentDocs.length;

                                  return _buildClassMenuSlider(
                                    context: context,
                                    projectId: projectId,
                                    projectName: name,
                                    ownerUid: ownerUid,
                                    isOwner: isOwner,
                                    isDark: isDark,
                                    accentColor: accentColor,
                                    currentCp: currentCp,
                                    schedules: schedules,
                                    liveStages: liveStages,
                                    studentCount: studentCount,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: stagesListWidget,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Layer 2: Pinned Top Action Bar (Back & 3-dots) selalu di atas dan clickable
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (widget.onDeselectClassroom != null) {
                                  widget.onDeselectClassroom!();
                                } else if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.35)
                                          : Colors.white.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.6),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: isDark ? Colors.white : Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: isDark
                                    ? const BorderSide(color: Color(0xFF27272A), width: 1.0)
                                    : BorderSide.none,
                              ),
                              elevation: 8,
                              color: isDark ? const Color(0xFF101012) : Colors.white,
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.35)
                                          : Colors.white.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.6),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.more_horiz_rounded,
                                      color: isDark ? Colors.white : Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddClassPage(
                                        editProjectId: projectId,
                                        initialClassData: liveProjectData,
                                      ),
                                    ),
                                  );
                                } else if (val == 'hapus') {
                                  _deleteProject(context);
                                } else if (val == 'export') {
                                  ClassroomExportService.exportClassroom(
                                    context: context,
                                    projectData: liveProjectData,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  height: 36,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF7C3AED)),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Edit',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'hapus',
                                  height: 36,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Hapus',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'export',
                                  height: 36,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF10B981)),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Export',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClassPageTaskItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String type, // 'materi', 'tugas', 'quiz', 'pdf'
    required bool isCompleted,
    required bool isOwner,
    required VoidCallback onTapAction,
    required VoidCallback onEditAction,
    required VoidCallback onDeleteAction,
  }) {
    String buttonText;
    IconData buttonIcon;
    Color buttonColor;
    if (type == 'quiz') {
      buttonText = 'Kerjakan Quiz';
      buttonIcon = Icons.play_arrow_rounded;
      buttonColor = const Color(0xFF7C3AED);
    } else if (type == 'tugas') {
      buttonText = 'Kerjakan Tugas';
      buttonIcon = Icons.edit_note_rounded;
      buttonColor = const Color(0xFF2563EB);
    } else {
      buttonText = 'Buka PDF';
      buttonIcon = Icons.visibility_rounded;
      buttonColor = const Color(0xFF0D9488);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black38 : Colors.black87,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      type == 'quiz'
                          ? Icons.quiz_outlined
                          : type == 'pdf'
                          ? Icons.description_outlined
                          : Icons.assignment_outlined,
                      size: 11,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.2,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOwner) ...[
            GestureDetector(
              onTap: onEditAction,
              child: const Icon(
                Icons.edit_outlined,
                color: Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onDeleteAction,
              child: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
          ] else if (isCompleted)
            GestureDetector(
              onTap: onTapAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF059669),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Selesai',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.7,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                onPressed: onTapAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(buttonIcon, size: 11),
                label: Text(
                  buttonText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addElemen({
    required BuildContext context,
    required String name,
    required String summary,
    required bool isVisible,
    required List currentStages,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final newStage = {
        'id':
            '${DateTime.now().millisecondsSinceEpoch}_${updatedStages.length}',
        'name': name,
        'summary': summary,
        'status': 'akan_datang',
        'isVisible': isVisible,
        'materis': [],
      };
      updatedStages.add(newStage);
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elemen berhasil ditambahkan!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan elemen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAddElemenDialog({
    required BuildContext context,
    required List currentStages,
  }) {
    String name = '';
    String summary = '';
    bool visible = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Tambah Elemen Pembelajaran',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 18.7,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nama Elemen',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    onChanged: (val) => name = val,
                    style: GoogleFonts.dmSans(fontSize: 15.2),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Masukkan nama elemen',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ringkasan / Ruang Lingkup',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (val) => summary = val,
                    style: GoogleFonts.dmSans(fontSize: 15.2),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Masukkan ringkasan elemen',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tampilkan ke Siswa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch.adaptive(
                      value: visible,
                      activeColor: Colors.black,
                      onChanged: (val) => setState(() => visible = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: GoogleFonts.dmSans(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.trim().isEmpty) return;
                _addElemen(
                  context: context,
                  name: name.trim(),
                  summary: summary.trim(),
                  isVisible: visible,
                  currentStages: currentStages,
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Tambah',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required bool isDone,
    required int progress,
    required String start,
    required String end,
    required String type,
    required VoidCallback onCheckTap,
    bool isPending = false,
    bool isOwner = false,
    VoidCallback? onApprove,
    VoidCallback? onReject,
  }) {
    IconData typeIcon = Icons.assignment_outlined;
    String typeLabel = 'Tugas';
    Color badgeBg = const Color(0xFFEFF6FF);
    Color badgeText = const Color(0xFF2563EB);
    if (type == 'quiz') {
      typeIcon = Icons.quiz_outlined;
      typeLabel = 'Quiz';
      badgeBg = const Color(0xFFFFF7ED);
      badgeText = const Color(0xFFEA580C);
    } else if (type == 'pdf') {
      typeIcon = Icons.description_outlined;
      typeLabel = 'PDF';
      badgeBg = const Color(0xFFF0FDF4);
      badgeText = const Color(0xFF16A34A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeIcon, size: 12, color: badgeText),
                const SizedBox(width: 4),
                Text(
                  typeLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Task Title
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDone ? Colors.black38 : Colors.black87,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (isPending) ...[
            if (isOwner) ...[
              GestureDetector(
                onTap: onApprove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF137333),
                    size: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onReject,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCE8E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFC5221F),
                    size: 12,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Butuh Acc',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ] else ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? const Color(0xFF10B981)
                    : (progress > 0)
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Colors.black26,
            ),
          ],
        ],
      ),
    );
  }

  void _openEditActivityOverlay({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required Map<String, dynamic> task,
    required List currentStages,
    required bool isOwner,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AddActivityOverlayPage(
          projectId: widget.projectId,
          stageIdx: stageIdx,
          materiIdx: materiIdx,
          isOwner: isOwner,
          currentStages: currentStages,
          initialType: task['type'] ?? 'tugas',
          initialTask: task,
          onSave: (title, actType, startStr, endStr, docName, extraData) {
            _updateTaskInFirestore(
              context: context,
              stageIdx: stageIdx,
              materiIdx: materiIdx,
              taskIdx: taskIdx,
              taskTitle: title,
              startDate: startStr,
              endDate: endStr,
              type: actType,
              docName: docName,
              extra: extraData,
              currentStages: currentStages,
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateTaskInFirestore({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required String taskTitle,
    required String startDate,
    required String endDate,
    required String type,
    required String docName,
    required List currentStages,
    Map<String, dynamic>? extra,
  }) async {
    final projectId = widget.projectId;
    try {
      final updatedStages = List.from(currentStages);
      final stage = Map<String, dynamic>.from(updatedStages[stageIdx]);
      final List rawMateris = stage['materis'] as List? ?? [];
      final List<Map<String, dynamic>> materis =
          List<Map<String, dynamic>>.from(
            rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
          );
      final m = Map<String, dynamic>.from(materis[materiIdx]);
      final tasks = List.from(m['tasks'] ?? []);
      final t = Map<String, dynamic>.from(tasks[taskIdx]);
      t['title'] = taskTitle.trim();
      t['type'] = type;
      t['doc'] = docName.trim();
      t['start'] = startDate;
      t['end'] = endDate;
      // clear old extra fields first
      t.remove('tugasText');
      t.remove('questions');
      t.remove('assignmentType');
      if (extra != null) {
        t.addAll(extra);
      }
      tasks[taskIdx] = t;
      m['tasks'] = tasks;
      materis[materiIdx] = m;
      stage['materis'] = materis;
      updatedStages[stageIdx] = stage;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stages': updatedStages});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kegiatan berhasil diperbarui!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui kegiatan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildSidebarActionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? accentColor : Colors.black54,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? accentColor : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditCpInlineForm(
    String projectId,
    String currentCp,
    Color accentColor,
  ) {
    final controller = TextEditingController(text: currentCp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit Capaian Pembelajaran (CP)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.7,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Target & Tujuan Pembelajaran (CP) untuk kelas ini.',
          style: GoogleFonts.dmSans(fontSize: 12.9, color: Colors.black45),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tuliskan Capaian Pembelajaran (CP) baru...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.black26,
                ),
                contentPadding: const EdgeInsets.all(18),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _closeInlinePanel,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Batal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  final newCp = controller.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(projectId)
                        .update({'cpDescription': newCp});
                    _closeInlinePanel();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('CP Classroom berhasil diperbarui!'),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Gagal menyimpan CP: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Simpan Perubahan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditJadwalInlineForm(
    String projectId,
    List schedules,
    Color accentColor,
  ) {
    final List<Map<String, dynamic>> localSchedules =
        List<Map<String, dynamic>>.from(
          schedules.map((e) => Map<String, dynamic>.from(e as Map)),
        );
    final Map<String, Map<String, Color>> dayColorsMap = {
      'senin': {'bg': const Color(0xFFFEF2F2), 'fg': const Color(0xFFEF4444)},
      'selasa': {'bg': const Color(0xFFFFF7ED), 'fg': const Color(0xFFF97316)},
      'rabu': {'bg': const Color(0xFFF0FDF4), 'fg': const Color(0xFF10B981)},
      'kamis': {'bg': const Color(0xFFEFF6FF), 'fg': const Color(0xFF3B82F6)},
      'jumat': {'bg': const Color(0xFFF3E8FF), 'fg': const Color(0xFF8B5CF6)},
      'sabtu': {'bg': const Color(0xFFFDF2F8), 'fg': const Color(0xFFEC4899)},
      'minggu': {'bg': const Color(0xFFF0FDFA), 'fg': const Color(0xFF14B8A6)},
    };
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Jadwal Pelajaran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.7,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tentukan hari dan jam mengajar kelas ini.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.9,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  onPressed: _closeInlinePanel,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: localSchedules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 48,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada jadwal mengajar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: localSchedules.length,
                      itemBuilder: (context, idx) {
                        final item = localSchedules[idx];
                        final day =
                            item['day']?.toString().toLowerCase() ?? 'senin';
                        final colors =
                            dayColorsMap[day] ?? dayColorsMap['senin']!;
                        final timeStr = item['time']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors['bg'],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  day.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.7,
                                    fontWeight: FontWeight.bold,
                                    color: colors['fg'],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  timeStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  localSchedules.removeAt(idx);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(projectId)
                                        .update({'schedules': localSchedules});
                                    setLocalState(() {});
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal menghapus: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      String selectedDay = 'Senin';
                      final timeController = TextEditingController(
                        text: '08:00 - 09:30',
                      );
                      final res = await showDialog(
                        context: context,
                        builder: (ctx) {
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                title: Text(
                                  'Tambah Jadwal Baru',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17.6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: selectedDay,
                                      items:
                                          [
                                                'Senin',
                                                'Selasa',
                                                'Rabu',
                                                'Kamis',
                                                'Jumat',
                                                'Sabtu',
                                                'Minggu',
                                              ]
                                              .map(
                                                (e) => DropdownMenuItem(
                                                  value: e,
                                                  child: Text(e),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            selectedDay = val;
                                          });
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Hari',
                                        labelStyle: GoogleFonts.dmSans(
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: timeController,
                                      decoration: InputDecoration(
                                        labelText: 'Jam (cth: 08:00 - 09:30)',
                                        labelStyle: GoogleFonts.dmSans(
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(
                                      'Batal',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx, {
                                        'day': selectedDay.toLowerCase(),
                                        'time': timeController.text.trim(),
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      'Tambah',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                      if (res != null && res is Map<String, String>) {
                        localSchedules.add(res);
                        try {
                          await FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .update({'schedules': localSchedules});
                          setLocalState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menambah jadwal: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Tambah Jadwal Pelajaran',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveInlinePanel(
    String projectId,
    String name,
    String ownerUid,
    bool isOwner,
    Color accentColor,
    Map<String, dynamic> projectData,
    List stages,
  ) {
    if (_showEditCpInline) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _buildEditCpInlineForm(
          projectId,
          (projectData['cpDescription'] ?? '').toString(),
          accentColor,
        ),
      );
    }
    if (_showEditJadwalInline) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _buildEditJadwalInlineForm(
          projectId,
          List.from(projectData['schedules'] ?? []),
          accentColor,
        ),
      );
    }
    if (_showKelolaAnggotaInline) {
      return ManageMembersPage(
        projectId: projectId,
        projectName: name,
        ownerUid: ownerUid,
        isEmbedded: true,
        onCloseInline: _closeInlinePanel,
      );
    }
    if (_inlineElemenMode == 'edit_elemen' && _inlineElemenStageIdx != null) {
      return _buildInlineEditElemenForm(
        projectId,
        _inlineElemenStageIdx!,
        stages,
        accentColor,
      );
    }
    if (_inlineElemenMode == 'add_elemen') {
      return _buildInlineAddElemenForm(projectId, stages, accentColor);
    }
    if (_editingStageIdx != null) {
      if (_editingActivityType == 'materi_baru') {
        return _buildInlineAddMateriForm(
          projectId,
          _editingStageIdx!,
          stages,
          accentColor,
        );
      }
      if (_editingActivityType == null) {
        return _buildInlineActivityChoicePanel(
          _editingStageIdx!,
          _editingActivityMateriIdx ?? 0,
          isOwner,
          stages,
          accentColor,
        );
      }
      return AddActivityOverlayPage(
        projectId: projectId,
        stageIdx: _editingStageIdx!,
        materiIdx: _editingActivityMateriIdx ?? 0,
        isOwner: isOwner,
        currentStages: stages,
        initialType: _editingActivityType!,
        initialTask: _editingActivityTask,
        isEmbedded: true,
        onCloseInline: () {
          _setEditingStage(null);
        },
        onSave: (title, type, startDate, endDate, docName, extraData) {
          _addTask(
            context: context,
            stageIdx: _editingStageIdx!,
            materiIdx: _editingActivityMateriIdx ?? 0,
            taskTitle: title,
            startDate: startDate,
            endDate: endDate,
            isOwner: isOwner,
            currentStages: stages,
            type: type,
            docName: docName,
            extra: extraData,
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInlineAddMateriForm(
    String projectId,
    int stageIdx,
    List currentStages,
    Color accentColor,
  ) {
    String materiTitle = '';
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_task_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tambah Materi Baru',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Buat materi pembelajaran baru',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.7,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        _setEditingStage(null);
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Judul/Nama Materi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        minLines: 1,
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        style: GoogleFonts.dmSans(fontSize: 15.2),
                        onChanged: (val) => materiTitle = val,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Contoh: Materi 1.2: Pemrograman Dasar...',
                          hintStyle: GoogleFonts.dmSans(
                            color: Colors.black26,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _setEditingStage(null);
                      },
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (materiTitle.trim().isEmpty) return;
                        _addMateri(
                          context: context,
                          stageIdx: stageIdx,
                          materiTitle: materiTitle.trim(),
                          currentStages: currentStages,
                        );
                        _setEditingStage(null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Tambah',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineActivityChoicePanel(
    int stageIdx,
    int materiIdx,
    bool isOwner,
    List currentStages,
    Color accentColor,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_circle_outline_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buat Kegiatan Baru',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.4,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Pilih jenis aktivitas pembelajaran',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.7,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _closeInlinePanel,
                  child: const Icon(Icons.close_rounded, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _buildChoiceButton(
                  context: context,
                  icon: Icons.assignment_outlined,
                  label: 'Tugas Mandiri / Kelompok',
                  description: 'Penugasan individu atau kolaboratif siswa',
                  color: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  onTap: () {
                    setState(() {
                      _editingActivityType = 'tugas';
                    });
                  },
                ),
                _buildChoiceButton(
                  context: context,
                  icon: Icons.help_outline_rounded,
                  label: 'Kuis Evaluasi (Quiz)',
                  description: 'Latihan evaluasi pemahaman interaktif',
                  color: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                  onTap: () {
                    setState(() {
                      _editingActivityType = 'quiz';
                    });
                  },
                ),
                _buildChoiceButton(
                  context: context,
                  icon: Icons.description_outlined,
                  label: 'Materi Pembelajaran (PDF)',
                  description: 'Bahan modul bacaan, slide presentasi, atau PDF',
                  color: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                  onTap: () {
                    setState(() {
                      _editingActivityType = 'pdf';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEditElemenForm(
    String projectId,
    int stageIdx,
    List currentStages,
    Color accentColor,
  ) {
    final stage = currentStages[stageIdx] as Map<String, dynamic>;
    String name = (stage['name'] ?? '').toString();
    String summary = (stage['summary'] ?? '').toString();
    bool visible = stage['isVisible'] ?? true;
    final List rawMateris = stage['materis'] as List? ?? [];
    final List<TextEditingController> materiControllers = rawMateris.map((
      materi,
    ) {
      final String mTitle = (materi['title'] ?? '').toString();
      return TextEditingController(text: mTitle);
    }).toList();
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Elemen',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Ubah rincian elemen pembelajaran',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.7,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        for (var c in materiControllers) {
                          c.dispose();
                        }
                        _closeInlinePanel();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nama Elemen',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                          controller: TextEditingController(text: name)
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: name.length),
                            ),
                          onChanged: (val) => name = val,
                          style: GoogleFonts.dmSans(fontSize: 15.2),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ringkasan / Ruang Lingkup',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: TextEditingController(text: summary),
                          onChanged: (val) => summary = val,
                          style: GoogleFonts.dmSans(fontSize: 15.2),
                          maxLines: 3,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (materiControllers.isNotEmpty) ...[
                        ...List.generate(materiControllers.length, (mIdx) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nama Materi ${mIdx + 1}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: materiControllers[mIdx],
                                    style: GoogleFonts.dmSans(fontSize: 15.2),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Nama materi...',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tampilkan ke Siswa',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch.adaptive(
                            value: visible,
                            activeTrackColor: Colors.black,
                            onChanged: (val) =>
                                setLocalState(() => visible = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        for (var c in materiControllers) {
                          c.dispose();
                        }
                        _closeInlinePanel();
                      },
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (name.trim().isEmpty) return;
                        final List<Map<String, dynamic>> updatedMateris = [];
                        for (int mi = 0; mi < rawMateris.length; mi++) {
                          final m = Map<String, dynamic>.from(
                            rawMateris[mi] as Map,
                          );
                          if (mi < materiControllers.length) {
                            m['title'] = materiControllers[mi].text.trim();
                          }
                          updatedMateris.add(m);
                        }
                        _editElemen(
                          context: context,
                          stageIdx: stageIdx,
                          newName: name.trim(),
                          newSummary: summary.trim(),
                          isVisible: visible,
                          currentStages: currentStages,
                          newMateris: updatedMateris,
                        );
                        for (var c in materiControllers) {
                          c.dispose();
                        }
                        _closeInlinePanel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Simpan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineAddElemenForm(
    String projectId,
    List currentStages,
    Color accentColor,
  ) {
    String name = '';
    String summary = '';
    bool visible = true;
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tambah Elemen Pembelajaran',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Buat elemen pembelajaran baru',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.7,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        _closeInlinePanel();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama Elemen',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        minLines: 1,
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        onChanged: (val) => name = val,
                        style: GoogleFonts.dmSans(fontSize: 15.2),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Masukkan nama elemen',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ringkasan / Ruang Lingkup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) => summary = val,
                        style: GoogleFonts.dmSans(fontSize: 15.2),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Masukkan ringkasan elemen',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tampilkan ke Siswa',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch.adaptive(
                          value: visible,
                          activeTrackColor: Colors.black,
                          onChanged: (val) =>
                              setLocalState(() => visible = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _closeInlinePanel();
                          },
                          child: Text(
                            'Batal',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (name.trim().isEmpty) return;
                            _addElemen(
                              context: context,
                              name: name.trim(),
                              summary: summary.trim(),
                              isVisible: visible,
                              currentStages: currentStages,
                            );
                            _closeInlinePanel();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Tambah',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GaugePainter extends CustomPainter {
  final double donePercent;
  final double inProgressPercent;
  final double toDoPercent;
  GaugePainter({
    required this.donePercent,
    required this.inProgressPercent,
    required this.toDoPercent,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 14.0;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      (size.height * 2) - strokeWidth,
    );
    final Paint bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.14159, 3.14159, false, bgPaint);
    double startAngle = 3.14159;
    if (donePercent > 0) {
      final Paint donePaint = Paint()
        ..color = const Color(0xFFC5E1A5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final double sweepAngle = 3.14159 * donePercent;
      canvas.drawArc(rect, startAngle, sweepAngle, false, donePaint);
      startAngle += sweepAngle;
    }
    if (inProgressPercent > 0) {
      final Paint inProgressPaint = Paint()
        ..color = const Color(0xFFD1C4E9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final double sweepAngle = 3.14159 * inProgressPercent;
      canvas.drawArc(rect, startAngle, sweepAngle, false, inProgressPaint);
      startAngle += sweepAngle;
    }
    if (toDoPercent > 0) {
      final Paint toDoPaint = Paint()
        ..color = const Color(0xFF78909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final double sweepAngle = 3.14159 * toDoPercent;
      canvas.drawArc(rect, startAngle, sweepAngle, false, toDoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ProjectChatCountWidget extends StatelessWidget {
  final String projectId;
  const ProjectChatCountWidget({super.key, required this.projectId});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('discussions')
          .where('projectId', isEqualTo: projectId)
          .snapshots(),
      builder: (context, discSnap) {
        if (!discSnap.hasData || discSnap.data!.docs.isEmpty) {
          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Belum ada diskusi untuk classroom ini. Silakan buat diskusi di tab Diskusi!',
                  ),
                ),
              );
            },
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  '0',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.9,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          );
        }
        final mainDisc = discSnap.data!.docs.first;
        final mainDiscId = mainDisc.id;
        final discData = mainDisc.data() as Map<String, dynamic>? ?? {};
        final String chanName = discData['channel'] ?? '#general';
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('discussions')
              .doc(mainDiscId)
              .collection('messages')
              .snapshots(),
          builder: (context, msgSnap) {
            final count = msgSnap.data?.docs.length ?? 0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomPage(
                      discussionId: mainDiscId,
                      channelName: chanName,
                      projectId: projectId,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.9,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AddActivityOverlayPage extends StatefulWidget {
  final String projectId;
  final int stageIdx;
  final int materiIdx;
  final bool isOwner;
  final List currentStages;
  final String initialType;
  final Map<String, dynamic>? initialTask;
  final Function(
    String title,
    String type,
    String startDate,
    String endDate,
    String docName,
    Map<String, dynamic>? extraData,
  )
  onSave;
  final bool isEmbedded;
  final VoidCallback? onCloseInline;
  const AddActivityOverlayPage({
    super.key,
    required this.projectId,
    required this.stageIdx,
    required this.materiIdx,
    required this.isOwner,
    required this.currentStages,
    required this.initialType,
    this.initialTask,
    required this.onSave,
    this.isEmbedded = false,
    this.onCloseInline,
  });
  @override
  State<AddActivityOverlayPage> createState() => _AddActivityOverlayPageState();
}

class _AddActivityOverlayPageState extends State<AddActivityOverlayPage> {
  late String _type;
  final _titleController = TextEditingController();
  Future<void> _pickAndUploadFile({
    required String fileType,
    Function(String fileUrl)? onUploaded,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: fileType == 'pdf' ? FileType.custom : FileType.image,
        allowedExtensions: fileType == 'pdf' ? ['pdf'] : null,
      );
      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final driveFolderId = doc.data()?['driveFolderId'] as String?;
      final driveAccessToken = doc.data()?['driveAccessToken'] as String?;
      if (driveFolderId == null ||
          driveAccessToken == null ||
          driveFolderId.isEmpty ||
          driveAccessToken.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal: Google Drive Guru belum tersinkronisasi. Pastikan Guru telah masuk kelas untuk mengaktifkan Google Drive.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      List<int> fileBytes;
      if (kIsWeb) {
        fileBytes = pickedFile.bytes!;
      } else {
        fileBytes = await File(pickedFile.path!).readAsBytes();
      }
      final uploadResult = await GoogleDriveService.uploadFile(
        accessToken: driveAccessToken,
        folderId: driveFolderId,
        fileName: pickedFile.name,
        bytes: fileBytes,
      );
      if (mounted) {
        Navigator.pop(context);
        if (onUploaded != null) {
          onUploaded(uploadResult['directLink']!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berkas berhasil diunggah ke Google Drive Guru!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah berkas: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Date variables
  DateTime? _startDate;
  DateTime? _endDate;
  // PDF specific
  String _pdfName = '';
  // Tugas specific: Toggle between 'pdf' or 'text'
  String _tugasMode = 'text'; // 'pdf' or 'text'
  String _assignmentType = 'individu'; // 'individu' or 'kelompok'
  final _tugasTextController = TextEditingController();
  // Quiz specific: Toggle between 'manual' or 'mass'
  String _quizMode = 'manual'; // 'manual' or 'mass'
  final _quizMassController = TextEditingController();
  // Quiz dynamic questions list (manual)
  final List<Map<String, dynamic>> _questions = [];
  // Quiz time settings
  String _quizTimeMode = 'no_time'; // 'no_time' or 'set_time'
  String _quizTimeType = 'per_sesi'; // 'per_soal' or 'per_sesi'
  final _quizTimeController = TextEditingController();
  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return null;
    try {
      final parts = dateStr.toString().split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _startDate = DateTime.now();
    if (widget.initialTask != null) {
      final task = widget.initialTask!;
      _titleController.text = task['title'] ?? '';
      _pdfName = task['doc'] ?? '';
      if (task['start'].toString().isNotEmpty &&
          task['start'].toString() != 'DD/MM/YYYY') {
        _startDate = _parseDate(task['start']);
      }
      if (task['end'].toString().isNotEmpty &&
          task['end'].toString() != 'DD/MM/YYYY') {
        _endDate = _parseDate(task['end']);
      }
      _assignmentType = task['assignmentType'] ?? 'individu';
      final qList = task['questions'] as List?;
      if (qList != null && qList.isNotEmpty) {
        _questions.clear();
        for (var q in qList) {
          _questions.add(Map<String, dynamic>.from(q as Map));
        }
      } else {
        _addEmptyQuestion();
      }
      // Load quiz time settings
      if (task['quizTimeMode'] != null) {
        _quizTimeMode = task['quizTimeMode'];
      }
      if (task['quizTimeType'] != null) {
        _quizTimeType = task['quizTimeType'];
      }
      if (task['quizTimeDuration'] != null) {
        _quizTimeController.text = task['quizTimeDuration'].toString();
      }
      if (task['type'] == 'tugas') {
        _tugasTextController.text = task['tugasText'] ?? '';
        _tugasMode = task['doc'].toString().isNotEmpty ? 'pdf' : 'text';
      }
    } else {
      _addEmptyQuestion();
    }
  }

  void _addEmptyQuestion() {
    setState(() {
      _questions.add({
        'question': '',
        'a': '',
        'b': '',
        'c': '',
        'd': '',
        'correct': 'A',
        'image': '',
      });
    });
  }

  void _importMassQuiz() {
    final text = _quizMassController.text.trim();
    if (text.isEmpty) return;
    try {
      final List<Map<String, dynamic>> parsedQuestions = [];
      final blocks = text.split(RegExp(r'\n\s*\n'));
      for (var block in blocks) {
        if (block.trim().isEmpty) continue;
        final lines = block.split('\n');
        String q = '';
        String a = '';
        String b = '';
        String c = '';
        String d = '';
        String correct = 'A';
        String image = '';
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.toLowerCase().startsWith('q:') ||
              trimmed.toLowerCase().startsWith('pertanyaan:')) {
            q = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          } else if (trimmed.toLowerCase().startsWith('a:')) {
            a = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          } else if (trimmed.toLowerCase().startsWith('b:')) {
            b = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          } else if (trimmed.toLowerCase().startsWith('c:')) {
            c = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          } else if (trimmed.toLowerCase().startsWith('d:')) {
            d = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          } else if (trimmed.toLowerCase().startsWith('jawaban:') ||
              trimmed.toLowerCase().startsWith('ans:')) {
            correct = trimmed
                .substring(trimmed.indexOf(':') + 1)
                .trim()
                .toUpperCase();
          } else if (trimmed.toLowerCase().startsWith('gambar:')) {
            image = trimmed.substring(trimmed.indexOf(':') + 1).trim();
          }
        }
        if (q.isNotEmpty) {
          parsedQuestions.add({
            'question': q,
            'a': a,
            'b': b,
            'c': c,
            'd': d,
            'correct': ['A', 'B', 'C', 'D'].contains(correct) ? correct : 'A',
            'image': image,
          });
        }
      }
      if (parsedQuestions.isNotEmpty) {
        setState(() {
          _questions.clear();
          _questions.addAll(parsedQuestions);
          _quizMode =
              'manual'; // automatically switches to manual editable view
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil mengimpor ${parsedQuestions.length} pertanyaan ke editor!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mengenali format pertanyaan. Pastikan format sesuai template.',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing data: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel = _type == 'tugas'
        ? 'Tugas'
        : _type == 'quiz'
        ? 'Quiz'
        : 'Materi PDF';
    Color themeColor = _type == 'tugas'
        ? const Color(0xFF2563EB)
        : _type == 'quiz'
        ? const Color(0xFFEA580C)
        : const Color(0xFF16A34A);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () {
            if (widget.isEmbedded) {
              widget.onCloseInline?.call();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Unggah/Buat $typeLabel',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Judul tidak boleh kosong!'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              final startStr = _startDate == null
                  ? ''
                  : '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}';
              final endStr = _endDate == null
                  ? ''
                  : '${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}';
              Map<String, dynamic>? extraData;
              String docName = '';
              if (_type == 'pdf') {
                docName = _pdfName.isNotEmpty
                    ? _pdfName
                    : 'materi_pembelajaran.pdf';
              } else if (_type == 'tugas') {
                if (_tugasMode == 'pdf') {
                  docName = _pdfName.isNotEmpty ? _pdfName : 'tugas_soal.pdf';
                  extraData = {'assignmentType': _assignmentType};
                } else {
                  extraData = {
                    'tugasText': _tugasTextController.text.trim(),
                    'assignmentType': _assignmentType,
                  };
                }
              } else if (_type == 'quiz') {
                extraData = {
                  'questions': _questions,
                  'quizTimeMode': _quizTimeMode,
                  'quizTimeType': _quizTimeType,
                  'quizTimeDuration': _quizTimeMode == 'set_time'
                      ? _quizTimeController.text.trim()
                      : '',
                };
              }
              widget.onSave(title, _type, startStr, endStr, docName, extraData);
              if (widget.isEmbedded) {
                widget.onCloseInline?.call();
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Simpan',
              style: GoogleFonts.plusJakartaSans(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16.4,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Judul $typeLabel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  controller: _titleController,
                  style: GoogleFonts.dmSans(fontSize: 15.2),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Masukkan judul...',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: Colors.black26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isOwner) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Mulai',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialEntryMode: DatePickerEntryMode.input,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Colors.black87,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black87,
                                          textStyle: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      datePickerTheme: DatePickerThemeData(
                                        backgroundColor: Colors.white,
                                        headerBackgroundColor: Colors.black87,
                                        headerForegroundColor: Colors.white,
                                        dayStyle: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        headerHeadlineStyle:
                                            GoogleFonts.plusJakartaSans(
                                              fontSize: 23.4,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                        headerHelpStyle: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.7,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null)
                                setState(() => _startDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                _startDate == null
                                    ? 'Pilih tanggal'
                                    : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                                style: GoogleFonts.dmSans(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Selesai',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialEntryMode: DatePickerEntryMode.input,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Colors.black87,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black87,
                                          textStyle: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      datePickerTheme: DatePickerThemeData(
                                        backgroundColor: Colors.white,
                                        headerBackgroundColor: Colors.black87,
                                        headerForegroundColor: Colors.white,
                                        dayStyle: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        headerHeadlineStyle:
                                            GoogleFonts.plusJakartaSans(
                                              fontSize: 23.4,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                        headerHelpStyle: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.7,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null)
                                setState(() => _endDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                _endDate == null
                                    ? 'Pilih tanggal'
                                    : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                                style: GoogleFonts.dmSans(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (_type == 'pdf') ...[
                Text(
                  'Berkas Materi (PDF)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFilePickerWidget(
                  fileName: _pdfName,
                  onPick: () => _pickAndUploadFile(
                    fileType: 'pdf',
                    onUploaded: (url) {
                      setState(() => _pdfName = url);
                    },
                  ),
                ),
              ],
              if (_type == 'tugas') ...[
                Text(
                  'Opsi Pengerjaan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _assignmentType = 'individu'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _assignmentType == 'individu'
                                ? themeColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _assignmentType == 'individu'
                                  ? themeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '📝 Individu',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: _assignmentType == 'individu'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _assignmentType = 'kelompok'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _assignmentType == 'kelompok'
                                ? themeColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _assignmentType == 'kelompok'
                                  ? themeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '👥 Kelompok',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: _assignmentType == 'kelompok'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Metode Tugas',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tugasMode = 'text'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tugasMode == 'text'
                                ? themeColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _tugasMode == 'text'
                                  ? themeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Teks Pertanyaan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: _tugasMode == 'text'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tugasMode = 'pdf'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tugasMode == 'pdf'
                                ? themeColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _tugasMode == 'pdf'
                                  ? themeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Berkas PDF',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: _tugasMode == 'pdf'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_tugasMode == 'text') ...[
                  Text(
                    'Teks Soal / Pertanyaan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _tugasTextController,
                      style: GoogleFonts.dmSans(fontSize: 15.2),
                      maxLines: 6,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tulis pertanyaan tugas di sini...',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Berkas Soal PDF',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFilePickerWidget(
                    fileName: _pdfName,
                    onPick: () => _pickAndUploadFile(
                      fileType: 'pdf',
                      onUploaded: (url) {
                        setState(() => _pdfName = url);
                      },
                    ),
                  ),
                ],
              ],
              if (_type == 'quiz') ...[
                // Waktu Pengerjaan
                Text(
                  'Waktu Pengerjaan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _quizTimeMode,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      itemHeight: null,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black54,
                        size: 18,
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _quizTimeMode = val;
                          });
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'no_time',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Tidak diberi waktu',
                              style: GoogleFonts.dmSans(fontSize: 14),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'set_time',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Atur waktu',
                              style: GoogleFonts.dmSans(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_quizTimeMode == 'set_time') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Time Type dropdown (per soal / per sesi)
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _quizTimeType,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              itemHeight: null,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.black54,
                                size: 18,
                              ),
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _quizTimeType = val;
                                  });
                                }
                              },
                              items: [
                                DropdownMenuItem(
                                  value: 'per_sesi',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Per Sesi',
                                      style: GoogleFonts.dmSans(fontSize: 14),
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'per_soal',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Per Soal',
                                      style: GoogleFonts.dmSans(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time input textbox
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _quizTimeController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.dmSans(fontSize: 14),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Waktu',
                                    hintStyle: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                'menit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.9,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Metode Pembuatan Kuis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _quizMode = 'manual'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _quizMode == 'manual'
                                ? themeColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _quizMode == 'manual'
                                  ? themeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Isi Manual',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: _quizMode == 'manual'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _quizMode = 'mass'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _quizMode == 'mass'
                                ? themeColor
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _quizMode == 'mass'
                                  ? themeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Mass Upload',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.9,
                              fontWeight: FontWeight.bold,
                              color: _quizMode == 'mass'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_quizMode == 'manual') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Pertanyaan (${_questions.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addEmptyQuestion,
                        icon: const Icon(Icons.add, size: 14),
                        label: Text(
                          'Pertanyaan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_questions.length, (qIdx) {
                    final q = _questions[qIdx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No. ${qIdx + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black45,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _questions.removeAt(qIdx);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pertanyaan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.7,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: TextField(
                              controller:
                                  TextEditingController(text: q['question'])
                                    ..selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset:
                                            (q['question'] as String).length,
                                      ),
                                    ),
                              onChanged: (val) => q['question'] = val,
                              style: GoogleFonts.dmSans(fontSize: 14),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Tulis pertanyaan...',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilihan A',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller:
                                            TextEditingController(text: q['a'])
                                              ..selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset: (q['a'] as String)
                                                          .length,
                                                    ),
                                                  ),
                                        onChanged: (val) => q['a'] = val,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.9,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilihan B',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller:
                                            TextEditingController(text: q['b'])
                                              ..selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset: (q['b'] as String)
                                                          .length,
                                                    ),
                                                  ),
                                        onChanged: (val) => q['b'] = val,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.9,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilihan C',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller:
                                            TextEditingController(text: q['c'])
                                              ..selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset: (q['c'] as String)
                                                          .length,
                                                    ),
                                                  ),
                                        onChanged: (val) => q['c'] = val,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.9,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilihan D',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller:
                                            TextEditingController(text: q['d'])
                                              ..selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset: (q['d'] as String)
                                                          .length,
                                                    ),
                                                  ),
                                        onChanged: (val) => q['d'] = val,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.9,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jawaban Benar',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          dropdownColor: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          itemHeight: null,
                                          value: q['correct'],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                () => q['correct'] = val,
                                              );
                                            }
                                          },
                                          items: ['A', 'B', 'C', 'D'].map((
                                            opt,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: opt,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                child: Text(
                                                  opt,
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gambar Pertanyaan (Opsional)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => _pickAndUploadFile(
                                        fileType: 'image',
                                        onUploaded: (url) {
                                          setState(() {
                                            q['image'] = url;
                                          });
                                        },
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: 14,
                                              color: themeColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                q['image'].toString().isEmpty
                                                    ? 'Unggah Gambar'
                                                    : q['image'].toString(),
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 11.7,
                                                  color: Colors.black54,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Text(
                    'Salin & Tempel Sesuai Template',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Format Template Mass Upload:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.9,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pertanyaan: Berapa hasil 1 + 1?\n'
                          'A: 1\n'
                          'B: 2\n'
                          'C: 3\n'
                          'D: 4\n'
                          'Jawaban: B\n'
                          'Gambar: opt-link-gambar-jika-ada.png\n\n'
                          'Pertanyaan: ... (pisahkan tiap soal dengan baris kosong)',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 11.7,
                            color: const Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            _quizMassController.text =
                                'Pertanyaan: Apa nama ibukota Indonesia?\n'
                                'A: Bandung\n'
                                'B: Jakarta\n'
                                'C: Surabaya\n'
                                'D: Medan\n'
                                'Jawaban: B\n\n'
                                'Pertanyaan: Manakah yang merupakan hardware?\n'
                                'A: Windows\n'
                                'B: Monitor\n'
                                'C: Excel\n'
                                'D: Chrome\n'
                                'Jawaban: B\n';
                            setState(() {});
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: Text(
                            'Salin Contoh Data',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _quizMassController,
                      style: GoogleFonts.dmSans(fontSize: 14),
                      maxLines: 8,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tempel teks template di sini...',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 12.9,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _importMassQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Impor & Edit Pertanyaan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerWidget({
    required String fileName,
    required VoidCallback onPick,
  }) {
    String display = fileName;
    if (fileName.startsWith('http')) {
      display = '📄 Berkas Materi PDF Terunggah';
    }
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 36,
              color: Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              display.isEmpty ? 'Ketuk untuk Unggah Berkas PDF' : display,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: display.isEmpty ? Colors.black38 : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            if (display.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Berkas siap diunggah',
                style: GoogleFonts.dmSans(fontSize: 11.7, color: Colors.black26),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double borderRadius;
  DashedBorderPainter({
    this.color = Colors.black26,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.borderRadius = 16.0,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );
    final dashWidth = gap;
    final dashSpace = gap;
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final bool isDark = AppColors.isDarkMode;
    final Color primaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.08);
    final Color secondaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.30);
    final Color strokePatternColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);
    final Color ringPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.16)
        : accentColor.withValues(alpha: 0.07);
    final Color dotPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : accentColor.withValues(alpha: 0.10);

    switch (patternIndex % 5) {
      case 0:
        final paint = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final path = Path();
        path.moveTo(size.width * 0.45, 0);
        path.cubicTo(
          size.width * 0.65,
          size.height * 0.35,
          size.width * 0.35,
          size.height * 0.75,
          size.width * 0.85,
          size.height,
        );
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
        path.close();
        canvas.drawPath(path, paint);
        final paintSecondary = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathSecondary = Path();
        pathSecondary.moveTo(size.width * 0.6, 0);
        pathSecondary.cubicTo(
          size.width * 0.8,
          size.height * 0.4,
          size.width * 0.5,
          size.height * 0.8,
          size.width,
          size.height * 0.7,
        );
        pathSecondary.lineTo(size.width, 0);
        pathSecondary.close();
        canvas.drawPath(pathSecondary, paintSecondary);
        break;
      case 1:
        final paintRing = Paint()
          ..color = ringPatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        final center = Offset(size.width * 0.85, size.height * 0.3);
        canvas.drawCircle(center, 30, paintRing);
        canvas.drawCircle(center, 55, paintRing);
        final paintWave = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRing = Path();
        pathRing.moveTo(size.width * 0.55, 0);
        pathRing.quadraticBezierTo(
          size.width * 0.8,
          size.height * 0.5,
          size.width,
          size.height,
        );
        pathRing.lineTo(size.width, 0);
        pathRing.close();
        canvas.drawPath(pathRing, paintWave);
        break;
      case 2:
        final paintBubble1 = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.8, size.height * 0.2),
          45,
          paintBubble1,
        );
        final paintBubble2 = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.9, size.height * 0.75),
          35,
          paintBubble2,
        );
        break;
      case 3:
        final paintDot = Paint()
          ..color = dotPatternColor
          ..style = PaintingStyle.fill;
        for (double x = size.width * 0.5; x < size.width; x += 18) {
          for (double y = 10; y < size.height; y += 18) {
            canvas.drawCircle(Offset(x, y), 3, paintDot);
          }
        }
        break;
      case 4:
      default:
        final paintRay = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRay = Path();
        pathRay.moveTo(size.width * 0.5, 0);
        pathRay.quadraticBezierTo(
          size.width * 0.7,
          size.height * 0.5,
          size.width * 0.8,
          size.height,
        );
        pathRay.lineTo(size.width, size.height);
        pathRay.lineTo(size.width, 0);
        pathRay.close();
        canvas.drawPath(pathRay, paintRay);
        final paintStroke = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
        final pathStroke = Path();
        pathStroke.moveTo(size.width * 0.65, 0);
        pathStroke.quadraticBezierTo(
          size.width * 0.82,
          size.height * 0.45,
          size.width * 0.88,
          size.height,
        );
        canvas.drawPath(pathStroke, paintStroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ClassroomCardPatternPainter oldDelegate) =>
      oldDelegate.patternIndex != patternIndex || oldDelegate.accentColor != accentColor;
}

class _BouncyMenuSliderCard extends StatefulWidget {
  final IconData icon;
  final Color cardBg;
  final String title;
  final VoidCallback onTap;
  final bool isDark;

  const _BouncyMenuSliderCard({
    required this.icon,
    required this.cardBg,
    required this.title,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_BouncyMenuSliderCard> createState() => _BouncyMenuSliderCardState();
}

class _BouncyMenuSliderCardState extends State<_BouncyMenuSliderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (highlighted) {
            if (highlighted) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
          borderRadius: BorderRadius.circular(32),
          child: Container(
            height: 54,
            padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AutoMarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_AutoMarqueeText> createState() => _AutoMarqueeTextState();
}

class _AutoMarqueeTextState extends State<_AutoMarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  void _startAnimation() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final durationSec = (maxScroll / 25).clamp(2.0, 10.0);
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (durationSec * 1000).toInt()),
    );

    _animController!.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animController!.value * maxScroll);
      }
    });

    _animController!.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) _animController?.reverse();
      } else if (status == AnimationStatus.dismissed) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) _animController?.forward();
      }
    });

    _animController!.forward();
  }

  @override
  void didUpdateWidget(covariant _AutoMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _animController?.dispose();
      _animController = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final bool overflows = textPainter.width > constraints.maxWidth;

        if (!overflows) {
          return Text(
            widget.text,
            maxLines: 1,
            style: widget.style,
          );
        }

        return SizedBox(
          height: textPainter.height + 2,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              maxLines: 1,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}
