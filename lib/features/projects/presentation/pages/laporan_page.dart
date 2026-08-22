import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hubner/features/projects/presentation/pages/manage_attendance_page.dart';
import 'package:hubner/main.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> with TickerProviderStateMixin {
  String? _selectedProjectId;
  int? _selectedStageFilterIdx;
  int? _selectedMateriFilterIdx;
  String _selectedTypeFilter = 'all'; // 'all', 'tugas', 'quiz'

  late Stream<QuerySnapshot> _projectsStream;
  Stream<QuerySnapshot>? _progressStream;
  String? _lastLoadedProjectId;

  // Desktop split-view attendance panel
  bool _showAttendancePanel = false;
  String? _attendancePanelProjectId;
  List _attendancePanelMasterList = [];
  late AnimationController _panelAnimController;
  late Animation<double> _panelSlideAnim;

  // Soft pattern animation controller for hero background
  late AnimationController _patternAnimController;

  Widget _buildClassIcon(Map<String, dynamic> data, {double size = 26}) {
    final rawIcon = (data['icon'] ?? '').toString();
    String iconPath = 'assets/icon_pack/project/project_1.png';
    if (rawIcon.isNotEmpty) {
      if (rawIcon.startsWith('assets/')) {
        iconPath = rawIcon;
      } else {
        iconPath = 'assets/icon_pack/project/$rawIcon';
      }
    }
    return Image.asset(
      iconPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(Icons.school_rounded, color: const Color(0xFF7F52FC), size: size),
    );
  }

  Widget _buildModeCheckbox({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF97316) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  width: 1.8,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF97316),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> avatarColors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF14B8A6), // Teal
    ];
    return avatarColors[hash % avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _projectsStream = FirebaseFirestore.instance
        .collection('projects')
        .where('ownerUid', isEqualTo: currentUid)
        .snapshots();

    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelSlideAnim = CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.easeOutCubic,
    );

    _patternAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _panelAnimController.dispose();
    _patternAnimController.dispose();
    super.dispose();
  }

  void _openAttendancePanel(String projectId, List masterList) {
    setState(() {
      _showAttendancePanel = true;
      _attendancePanelProjectId = projectId;
      _attendancePanelMasterList = masterList;
    });
    _panelAnimController.forward();
  }

  void _closeAttendancePanel() {
    _panelAnimController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showAttendancePanel = false;
        });
      }
    });
  }

  Stream<QuerySnapshot> _getProgressStream(String projectId) {
    if (_progressStream == null || _lastLoadedProjectId != projectId) {
      _lastLoadedProjectId = projectId;
      _progressStream = FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('studentProgress')
          .snapshots();
    }
    return _progressStream!;
  }

  // Helper to extract filtered list of tasks for progress/column display
  List<Map<String, dynamic>> _getFilteredTasks(List stages) {
    final List<Map<String, dynamic>> list = [];
    for (int sIdx = 0; sIdx < stages.length; sIdx++) {
      if (_selectedStageFilterIdx != null && _selectedStageFilterIdx != sIdx) continue;

      final stage = stages[sIdx] as Map<String, dynamic>;
      final List rawMateris = stage['materis'] as List? ?? [];
      final List stageTasks = stage['tasks'] as List? ?? [];

      List<Map<String, dynamic>> materis = [];
      if (rawMateris.isNotEmpty) {
        materis = List<Map<String, dynamic>>.from(rawMateris);
      }

      // Collect from materis
      for (int mIdx = 0; mIdx < materis.length; mIdx++) {
        if (_selectedMateriFilterIdx != null && _selectedMateriFilterIdx != mIdx) continue;

        final m = materis[mIdx];
        final List tasks = m['tasks'] as List? ?? [];
        for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
          final type = tasks[tIdx]['type'] ?? 'tugas';
          if (type == 'pdf') continue;

          if (_selectedTypeFilter == 'tugas' && type != 'tugas') continue;
          if (_selectedTypeFilter == 'quiz' && type != 'quiz') continue;

          final String tId = tasks[tIdx]['id']?.toString() ?? '${sIdx}_${mIdx}_$tIdx';
          if (!list.any((item) => item['id'] == tId)) {
            list.add({
              'id': tId,
              'key': '${sIdx}_${mIdx}_$tIdx',
              'title': tasks[tIdx]['title'] ?? '',
              'type': type,
            });
          }
        }
      }

      // Collect direct stage tasks if any
      for (int stIdx = 0; stIdx < stageTasks.length; stIdx++) {
        final t = stageTasks[stIdx] as Map;
        final type = t['type'] ?? 'tugas';
        if (type == 'pdf') continue;

        if (_selectedTypeFilter == 'tugas' && type != 'tugas') continue;
        if (_selectedTypeFilter == 'quiz' && type != 'quiz') continue;

        final String tId = t['id']?.toString() ?? '${sIdx}_st_$stIdx';
        if (!list.any((item) => item['id'] == tId)) {
          list.add({
            'id': tId,
            'key': '${sIdx}_st_$stIdx',
            'title': t['title'] ?? '',
            'type': type,
          });
        }
      }
    }
    return list;
  }

  void _exportToCSV({
    required BuildContext context,
    required String className,
    required List masterList,
    required List stages,
    required Map<String, List<String>> studentCompletedTasks,
  }) async {
    final StringBuffer csv = StringBuffer();

    // Collect all task keys & titles
    final List<Map<String, dynamic>> allTasks = [];
    for (int sIdx = 0; sIdx < stages.length; sIdx++) {
      final stage = stages[sIdx] as Map<String, dynamic>;
      final List rawMateris = stage['materis'] as List? ?? [];
      List<Map<String, dynamic>> materis = [];
      if (rawMateris.isNotEmpty) {
        materis = List<Map<String, dynamic>>.from(rawMateris);
      } else {
        final List tasksList = stage['tasks'] as List? ?? [];
        if (tasksList.isNotEmpty) {
          materis = [
            {'title': 'Materi', 'tasks': tasksList}
          ];
        }
      }
      for (int mIdx = 0; mIdx < materis.length; mIdx++) {
        final m = materis[mIdx];
        final List tasks = m['tasks'] as List? ?? [];
        for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
          allTasks.add({
            'key': '${sIdx}_${mIdx}_$tIdx',
            'title': tasks[tIdx]['title'] ?? '',
          });
        }
      }
    }

    // CSV Header row
    csv.write('Nama Siswa,Status Join,Tugas Selesai,Persentase');
    for (var t in allTasks) {
      final cleanTitle = t['title'].toString().replaceAll('"', '""').replaceAll(',', ';');
      csv.write(',"$cleanTitle"');
    }
    csv.write('\r\n');

    // CSV Data rows
    for (var s in masterList) {
      final String sName = s['name'] ?? '';
      final String sUid = s['uid'] ?? '';
      final bool joined = s['joined'] ?? false;
      final completed = joined ? (studentCompletedTasks[sUid] ?? []) : [];

      final int totalDone = completed.length;
      final percent = allTasks.isNotEmpty ? '${((totalDone / allTasks.length) * 100).toInt()}%' : '0%';

      csv.write('"${sName.replaceAll('"', '""')}",${joined ? "Joined" : "Not Joined"},$totalDone,$percent');
      for (var t in allTasks) {
        final isDone = completed.contains(t['key']);
        csv.write(isDone ? ',1' : ',0');
      }
      csv.write('\r\n');
    }

    try {
      final fileName = 'laporan_${className.replaceAll(RegExp(r'[^\w\s-]'), '_')}.csv';
      final bytes = Uint8List.fromList(utf8.encode(csv.toString()));

      if (kIsWeb) {
        await FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('Laporan CSV kelas "$className" berhasil diunduh!'),
            ),
          );
        }
      } else {
        final String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Simpan file laporan CSV',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: bytes,
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(bytes);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text('Laporan CSV berhasil disimpan ke: $outputPath'),
              ),
            );
          }
        } else {
          Clipboard.setData(ClipboardData(text: csv.toString()));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Batal menyimpan file. Data CSV disalin ke clipboard.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: csv.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Gagal menyimpan file ($e). CSV disalin ke clipboard.'),
          ),
        );
      }
    }
  }

  void _showViewTaskSubmissionDialog(BuildContext context, String studentName, String taskTitle, Map<String, dynamic> progressData, String tKey) {
    final textAns = progressData['textAnswer_$tKey']?.toString() ?? '';
    final fileAns = progressData['fileAnswer_$tKey']?.toString() ?? '';
    final List? groupMembers = progressData['groupMembers_$tKey'] as List?;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detail Jawaban Tugas', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17.6)),
            const SizedBox(height: 4),
            Text('Siswa: $studentName', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.black54)),
            Text('Tugas: $taskTitle', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.black54, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (textAns.isNotEmpty) ...[
              Text('Jawaban Teks:', style: GoogleFonts.plusJakartaSans(fontSize: 11.7, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(textAns, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: Colors.black87)),
              ),
              const SizedBox(height: 12),
            ],
            if (fileAns.isNotEmpty) ...[
              Text('Berkas Lampiran:', style: GoogleFonts.plusJakartaSans(fontSize: 11.7, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(fileAns);
                  if (uri != null && (fileAns.startsWith('http://') || fileAns.startsWith('https://'))) {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tidak dapat membuka link lampiran.')),
                        );
                      }
                    }
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fileAns,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (groupMembers != null && groupMembers.isNotEmpty) ...[
              Text('Anggota Kelompok:', style: GoogleFonts.plusJakartaSans(fontSize: 11.7, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: groupMembers.map((uid) {
                  final displayUid = uid.toString().length > 5 ? uid.toString().substring(0, 5) : uid.toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      uid.toString() == progressData['uid'].toString() ? '$studentName (Pengirim)' : 'UID: $displayUid',
                      style: GoogleFonts.dmSans(fontSize: 11.2, color: const Color(0xFF2563EB), fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (textAns.isEmpty && fileAns.isEmpty)
              Text('Siswa belum mengunggah berkas atau jawaban.', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.black45, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.black54)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';
        final double statusBarHeight = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF26173E) : const Color(0xFF7F52FC),
          body: StreamBuilder<QuerySnapshot>(
            stream: _projectsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: isDark ? const Color(0xFF26173E) : const Color(0xFF7F52FC),
                  body: const Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              }

          final classrooms = snapshot.data?.docs ?? [];
          if (classrooms.isEmpty) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
              body: _buildEmptyState(
                title: 'Belum Ada Kelas',
                subtitle: 'Anda belum memiliki kelas yang diampu.',
                icon: Icons.school_outlined,
              ),
            );
          }

          if (_selectedProjectId == null || !classrooms.any((doc) => doc.id == _selectedProjectId)) {
            _selectedProjectId = classrooms.first.id;
          }

          final activeClassroomDoc = classrooms.firstWhere((doc) => doc.id == _selectedProjectId);
          final classroomData = activeClassroomDoc.data() as Map<String, dynamic>;
          final String className = classroomData['name'] ?? 'Classroom';
          final List masterList = classroomData['studentsMasterList'] as List? ?? [];
          final List stages = classroomData['stages'] as List? ?? [];

          return Row(
            children: [
              // Main Body with Hero & Draggable White Sheet
              Expanded(
                child: Scaffold(
                  backgroundColor: isDark ? const Color(0xFF26173E) : const Color(0xFF7F52FC),
                  body: Stack(
                    children: [
                      // ==========================================
                      // LAYER 0: FULL SCREEN ANIMATED PATTERN BACKGROUND (Sampai Ke Bawah)
                      // ==========================================
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _patternAnimController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _SoftAnimatedPatternPainter(
                                animationValue: _patternAnimController.value,
                                isDark: isDark,
                              ),
                            );
                          },
                        ),
                      ),

                      // Decorative Soft Clouds and Stars (Full Background)
                      Positioned(
                        top: statusBarHeight + 8,
                        left: -20,
                        child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.12), size: 100),
                      ),
                      Positioned(
                        top: statusBarHeight + 16,
                        right: -30,
                        child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.14), size: 120),
                      ),
                      Positioned(
                        top: statusBarHeight + 30,
                        left: 45,
                        child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: isDark ? 0.3 : 0.5), size: 14),
                      ),
                      Positioned(
                        top: statusBarHeight + 60,
                        right: 60,
                        child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: isDark ? 0.4 : 0.7), size: 18),
                      ),

                      // ==========================================
                      // LAYER 0.5: HERO HEADER CONTENT
                      // ==========================================
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                  // 1. JUDUL LEBIH BESAR + PENJELASAN DIBAWAHNYA DENGAN JEDA
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       if (Navigator.canPop(context)) ...[
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF18181B) : Colors.white.withValues(alpha: 0.92),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 17),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Laporan Perkembangan Kelas',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: -0.4,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              'Pantau presensi, progres tugas, dan evaluasi hasil belajar siswa.',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 13,
                                                color: Colors.white.withValues(alpha: 0.92),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                   // ==========================================
                                  // 2. PILIH CLASSROOM (POPUP MENU BUTTON PERSIS TAMBAH TUGAS) & ATUR PRESENSI
                                  // ==========================================
                                  Row(
                                    children: [
                                      // Pilih Kelas Selector (PopupMenuButton)
                                      Expanded(
                                        child: PopupMenuButton<String>(
                                          tooltip: '',
                                          position: PopupMenuPosition.under,
                                          offset: const Offset(0, 6),
                                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                                          elevation: 6,
                                          constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
                                          shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          onSelected: (val) {
                                            setState(() {
                                              _selectedProjectId = val;
                                              _selectedStageFilterIdx = null;
                                              _selectedMateriFilterIdx = null;
                                            });
                                          },
                                          itemBuilder: (context) => classrooms.asMap().entries.map((entry) {
                                            final int idx = entry.key;
                                            final doc = entry.value;
                                            final data = doc.data() as Map<String, dynamic>;
                                            final bool isLast = idx == classrooms.length - 1;
                                            final bool isSelected = doc.id == _selectedProjectId;

                                            return PopupMenuItem<String>(
                                              value: doc.id,
                                              padding: EdgeInsets.zero,
                                              child: Container(
                                                constraints: const BoxConstraints(minHeight: 46),
                                                alignment: Alignment.centerLeft,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: isLast
                                                          ? Colors.transparent
                                                          : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    _buildClassIcon(data, size: 28),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        data['name'] ?? 'Classroom',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 13,
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                          color: isSelected
                                                              ? const Color(0xFF60A5FA)
                                                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                        ),
                                                        softWrap: true,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          child: Container(
                                            height: 52,
                                            padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.90) : Colors.white,
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                // Real Classroom Icon (Besar & mepet batas kiri card)
                                                _buildClassIcon(classroomData, size: 44),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    className,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                      height: 1.15,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  color: isDark ? Colors.white70 : Colors.black54,
                                                  size: 22,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Atur Presensi Button
                                      GestureDetector(
                                        onTap: () {
                                          final screenWidth = MediaQuery.of(context).size.width;
                                          if (screenWidth > 900) {
                                            if (_showAttendancePanel && _attendancePanelProjectId == _selectedProjectId) {
                                              _closeAttendancePanel();
                                            } else {
                                              _openAttendancePanel(_selectedProjectId!, masterList);
                                            }
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ManageAttendancePage(
                                                  projectId: _selectedProjectId!,
                                                  currentMasterList: masterList,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          height: 52,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF18181B) : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : Colors.transparent,
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 18),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Atur Presensi',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // ==========================================
                                  // 3. TOTAL SISWA & TELAH BERGABUNG (IKON KIRI, ANGKA & TULISAN DI KANAN)
                                  // ==========================================
                                  Row(
                                    children: [
                                      // Total Siswa Card
                                      Expanded(
                                        child: Container(
                                          height: 78,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18181B).withValues(alpha: 0.88)
                                                : const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : Colors.transparent,
                                              width: 1.1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Ikon Frameless di Kiri
                                              Icon(
                                                Icons.people_alt_rounded,
                                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                                size: 28,
                                              ),
                                              const SizedBox(width: 10),
                                              // Angka & Tulisan di Kanan
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '${masterList.length}',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 24,
                                                        fontWeight: FontWeight.w900,
                                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Total Siswa',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Telah Bergabung Card
                                      Expanded(
                                        child: Container(
                                          height: 78,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF18181B).withValues(alpha: 0.88)
                                                : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : Colors.transparent,
                                              width: 1.1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Ikon Frameless di Kiri
                                              const Icon(
                                                Icons.how_to_reg_rounded,
                                                color: Color(0xFF059669),
                                                size: 28,
                                              ),
                                              const SizedBox(width: 10),
                                              // Angka & Tulisan di Kanan
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '${masterList.where((s) => s['joined'] == true).length}',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 24,
                                                        fontWeight: FontWeight.w900,
                                                        color: const Color(0xFF065F46),
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Telah Bergabung',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF047857),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // ==========================================
                                  // 4. SEMUA ELEMEN & SEMUA MATERI (POPUP MENU BUTTON PERSIS TAMBAH TUGAS)
                                  // ==========================================
                                  Row(
                                    children: [
                                      // PopupMenuButton Elemen
                                      Expanded(
                                        child: PopupMenuButton<int?>(
                                          tooltip: '',
                                          position: PopupMenuPosition.under,
                                          offset: const Offset(0, 6),
                                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                                          elevation: 6,
                                          constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
                                          shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          onSelected: (val) {
                                            setState(() {
                                              _selectedStageFilterIdx = val;
                                              _selectedMateriFilterIdx = null;
                                            });
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem<int?>(
                                              value: null,
                                              padding: EdgeInsets.zero,
                                              child: Container(
                                                constraints: const BoxConstraints(minHeight: 44),
                                                alignment: Alignment.centerLeft,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Semua Elemen',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13.5,
                                                    fontWeight: _selectedStageFilterIdx == null ? FontWeight.bold : FontWeight.w600,
                                                    color: _selectedStageFilterIdx == null
                                                        ? const Color(0xFF60A5FA)
                                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                  ),
                                                  softWrap: true,
                                                ),
                                              ),
                                            ),
                                            ...List.generate(stages.length, (sIdx) {
                                              final stage = stages[sIdx] as Map<String, dynamic>;
                                              final String sName = stage['name'] ?? 'Elemen ${sIdx + 1}';
                                              final String cleanName = sName.replaceFirst(RegExp(r'^Materi\s*\d*:\s*', caseSensitive: false), '').trim();
                                              final bool isLast = sIdx == stages.length - 1;
                                              final bool isSelected = _selectedStageFilterIdx == sIdx;

                                              return PopupMenuItem<int?>(
                                                value: sIdx,
                                                padding: EdgeInsets.zero,
                                                child: Container(
                                                  constraints: const BoxConstraints(minHeight: 44),
                                                  alignment: Alignment.centerLeft,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: isLast
                                                            ? Colors.transparent
                                                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    cleanName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13.5,
                                                      color: isSelected
                                                          ? const Color(0xFF60A5FA)
                                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                    ),
                                                    softWrap: true,
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                          child: Container(
                                            height: 52,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF18181B).withValues(alpha: 0.90) : Colors.white,
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _selectedStageFilterIdx == null
                                                        ? 'Semua Elemen'
                                                        : ((stages[_selectedStageFilterIdx!]['name'] ?? 'Elemen')
                                                            .toString()
                                                            .replaceFirst(RegExp(r'^Materi\s*\d*:\s*', caseSensitive: false), '')
                                                            .trim()),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                      height: 1.15,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  color: isDark ? Colors.white70 : Colors.black54,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // PopupMenuButton Materi
                                      Expanded(
                                        child: PopupMenuButton<int?>(
                                          tooltip: '',
                                          position: PopupMenuPosition.under,
                                          offset: const Offset(0, 6),
                                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                                          elevation: 6,
                                          constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
                                          shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                                          enabled: _selectedStageFilterIdx != null,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          onSelected: (val) {
                                            setState(() {
                                              _selectedMateriFilterIdx = val;
                                            });
                                          },
                                          itemBuilder: (context) {
                                            if (_selectedStageFilterIdx == null) return [];
                                            final stage = stages[_selectedStageFilterIdx!] as Map<String, dynamic>;
                                            final List rawMateris = stage['materis'] as List? ?? [];
                                            List<Map<String, dynamic>> materis = [];
                                            if (rawMateris.isNotEmpty) {
                                              materis = List<Map<String, dynamic>>.from(rawMateris);
                                            } else {
                                              final List tasksList = stage['tasks'] as List? ?? [];
                                              if (tasksList.isNotEmpty) {
                                                materis = [
                                                  {'title': 'Materi', 'tasks': tasksList}
                                                ];
                                              }
                                            }

                                            return [
                                              PopupMenuItem<int?>(
                                                value: null,
                                                padding: EdgeInsets.zero,
                                                child: Container(
                                                  constraints: const BoxConstraints(minHeight: 44),
                                                  alignment: Alignment.centerLeft,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: materis.isEmpty
                                                            ? Colors.transparent
                                                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Semua Materi',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13.5,
                                                      fontWeight: _selectedMateriFilterIdx == null ? FontWeight.bold : FontWeight.w600,
                                                      color: _selectedMateriFilterIdx == null
                                                          ? const Color(0xFF60A5FA)
                                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                    ),
                                                    softWrap: true,
                                                  ),
                                                ),
                                              ),
                                              ...List.generate(materis.length, (mIdx) {
                                                final m = materis[mIdx];
                                                final String mTitle = m['title'] ?? 'Materi ${mIdx + 1}';
                                                final bool isLast = mIdx == materis.length - 1;
                                                final bool isSelected = _selectedMateriFilterIdx == mIdx;

                                                return PopupMenuItem<int?>(
                                                  value: mIdx,
                                                  padding: EdgeInsets.zero,
                                                  child: Container(
                                                    constraints: const BoxConstraints(minHeight: 44),
                                                    alignment: Alignment.centerLeft,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(
                                                          color: isLast
                                                              ? Colors.transparent
                                                              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      mTitle,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 13.5,
                                                        color: isSelected
                                                            ? const Color(0xFF60A5FA)
                                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                      ),
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ];
                                          },
                                          child: Container(
                                            height: 52,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF18181B).withValues(alpha: (_selectedStageFilterIdx == null ? 0.50 : 0.90))
                                                  : (_selectedStageFilterIdx == null
                                                      ? Colors.white.withValues(alpha: 0.72)
                                                      : Colors.white),
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    (() {
                                                      if (_selectedStageFilterIdx == null) return 'Semua Materi';
                                                      if (_selectedMateriFilterIdx == null) return 'Semua Materi';
                                                      final stage = stages[_selectedStageFilterIdx!] as Map<String, dynamic>;
                                                      final List rawMateris = stage['materis'] as List? ?? [];
                                                      if (rawMateris.isNotEmpty && _selectedMateriFilterIdx! < rawMateris.length) {
                                                        return rawMateris[_selectedMateriFilterIdx!]['title'] ?? 'Materi';
                                                      }
                                                      return 'Materi';
                                                    })(),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark
                                                          ? (_selectedStageFilterIdx == null ? Colors.white38 : Colors.white)
                                                          : (_selectedStageFilterIdx == null ? Colors.black38 : Colors.black87),
                                                      height: 1.15,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  color: isDark
                                                      ? (_selectedStageFilterIdx == null ? Colors.white24 : Colors.white70)
                                                      : (_selectedStageFilterIdx == null ? Colors.black26 : Colors.black54),
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                      // ==========================================
                      // LAYER 1: DRAGGABLE SCROLLABLE SHEET PUTIH FULL KE BAWAH (Seperti Detail Classroom)
                      // ==========================================
                      DraggableScrollableSheet(
                        initialChildSize: 0.52,
                        minChildSize: 0.52,
                        maxChildSize: 0.96,
                        snap: true,
                        snapSizes: const [0.52, 0.96],
                        builder: (context, scrollController) {
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141416) : Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, -6),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Drag Handle
                                  Center(
                                    child: Container(
                                      width: 44,
                                      height: 4.5,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // ==========================================
                                  // SIMPLE TOOLBAR: CHECKBOX MODE & IKON UNDUH
                                  // ==========================================
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                    child: Row(
                                      children: [
                                        // Mode Checkbox: Semua
                                        _buildModeCheckbox(
                                          label: 'Semua',
                                          isSelected: _selectedTypeFilter == 'all',
                                          onTap: () {
                                            setState(() {
                                              _selectedTypeFilter = 'all';
                                            });
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 8),

                                        // Mode Checkbox: Tugas
                                        _buildModeCheckbox(
                                          label: 'Tugas',
                                          isSelected: _selectedTypeFilter == 'tugas',
                                          onTap: () {
                                            setState(() {
                                              _selectedTypeFilter = 'tugas';
                                            });
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 8),

                                        // Mode Checkbox: Quiz
                                        _buildModeCheckbox(
                                          label: 'Quiz',
                                          isSelected: _selectedTypeFilter == 'quiz',
                                          onTap: () {
                                            setState(() {
                                              _selectedTypeFilter = 'quiz';
                                            });
                                          },
                                          isDark: isDark,
                                        ),

                                        const Spacer(),

                                        // Simple Unduh CSV Icon Saja (Tanpa Card Tambahan)
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('projects')
                                              .doc(_selectedProjectId)
                                              .collection('studentProgress')
                                              .snapshots(),
                                          builder: (context, progressSnapshot) {
                                            final progressDocs = progressSnapshot.data?.docs ?? [];
                                            final Map<String, List<String>> studentCompletedTasks = {};

                                            for (var doc in progressDocs) {
                                              final data = doc.data() as Map<String, dynamic>;
                                              final List<String> completed = List<String>.from(data['completedTasks'] ?? []);
                                              studentCompletedTasks[doc.id] = completed;
                                            }

                                            return GestureDetector(
                                              onTap: () => _exportToCSV(
                                                context: context,
                                                className: className,
                                                masterList: masterList,
                                                stages: stages,
                                                studentCompletedTasks: studentCompletedTasks,
                                              ),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0xFF0F172A),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.14),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1.5),
                                                    ),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.file_download_rounded,
                                                  color: Colors.white,
                                                  size: 17,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // ==========================================
                                  // TABEL LAPORAN (STRUKTUR TABEL AWAL LENGKAP)
                                  // ==========================================
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Column(
                                          children: [
                                            // Table Header
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      'Nama Siswa (${masterList.length})',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Progress',
                                                      textAlign: TextAlign.center,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      _selectedTypeFilter == 'tugas'
                                                          ? 'Status Tugas'
                                                          : (_selectedTypeFilter == 'quiz' ? 'Nilai Quiz' : 'Tugas & Quiz'),
                                                      textAlign: TextAlign.center,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                            // Table Body
                                            masterList.isEmpty
                                                ? Padding(
                                                    padding: const EdgeInsets.all(32.0),
                                                    child: Center(
                                                      child: Text(
                                                        'Belum ada siswa di kelas ini.',
                                                        style: GoogleFonts.dmSans(color: Colors.black38),
                                                      ),
                                                    ),
                                                  )
                                                : StreamBuilder<QuerySnapshot>(
                                                    stream: _getProgressStream(_selectedProjectId!),
                                                    builder: (context, progressSnapshot) {
                                                      final progressDocs = progressSnapshot.data?.docs ?? [];
                                                      final Map<String, Map<String, dynamic>> studentProgressData = {};

                                                      for (var doc in progressDocs) {
                                                        final data = doc.data() as Map<String, dynamic>;
                                                        studentProgressData[doc.id] = data;
                                                      }

                                                      final List<Map<String, dynamic>> filteredTasks = _getFilteredTasks(stages);

                                                      return ListView.separated(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: masterList.length,
                                                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                                        itemBuilder: (context, index) {
                                                          final student = masterList[index] as Map<String, dynamic>;
                                                          final String sName = student['name'] ?? 'Siswa';
                                                          final String sUid = student['uid'] ?? '';
                                                          final bool joined = student['joined'] ?? false;

                                                          final Map<String, dynamic> studentData = joined ? (studentProgressData[sUid] ?? {}) : {};
                                                          final List<String> completed = joined ? List<String>.from(studentData['completedTasks'] ?? []) : [];
                                                          final String sAvatar = (studentData['avatar']?.toString().isNotEmpty == true
                                                              ? studentData['avatar'].toString()
                                                              : (student['avatar']?.toString().isNotEmpty == true
                                                                  ? student['avatar'].toString()
                                                                  : 'assets/icon_pack/avatar/avatar_2.png'));

                                                          int filteredDoneCount = 0;
                                                          for (var t in filteredTasks) {
                                                            if (completed.contains(t['key'])) {
                                                              filteredDoneCount++;
                                                            }
                                                          }
                                                          final double progressPercent = filteredTasks.isNotEmpty
                                                              ? (filteredDoneCount / filteredTasks.length) * 100
                                                              : 0.0;

                                                          final bool isEven = index % 2 == 0;

                                                          return Material(
                                                            color: isEven
                                                                ? (isDark ? const Color(0xFF1E1E24) : Colors.white)
                                                                : (isDark ? const Color(0xFF1A1A20) : const Color(0xFFFAFAFA)),
                                                            child: InkWell(
                                                              onTap: joined
                                                                  ? () => _showStudentSubmissionDetailsSheet(context, sName, sUid, stages)
                                                                  : null,
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                                child: Row(
                                                                  children: [
                                                                    // Col 1: Avatar + Name
                                                                    Expanded(
                                                                      flex: 3,
                                                                      child: Row(
                                                                        children: [
                                                                          Container(
                                                                            width: 32,
                                                                            height: 32,
                                                                            decoration: BoxDecoration(
                                                                              shape: BoxShape.circle,
                                                                              color: joined ? _getAvatarColor(sName) : Colors.red[50],
                                                                            ),
                                                                            child: StudentAvatarWidget(
                                                                              uid: sUid,
                                                                              defaultAvatar: sAvatar,
                                                                              studentName: sName,
                                                                              joined: joined,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(width: 8),
                                                                          Expanded(
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Text(
                                                                                  sName,
                                                                                  style: GoogleFonts.plusJakartaSans(
                                                                                    fontSize: 13,
                                                                                    fontWeight: FontWeight.bold,
                                                                                    color: joined
                                                                                        ? (isDark ? Colors.white : Colors.black87)
                                                                                        : (isDark ? Colors.white38 : Colors.black38),
                                                                                  ),
                                                                                  maxLines: 1,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                ),
                                                                                Text(
                                                                                  joined ? 'UID: ${sUid.length > 6 ? sUid.substring(0, 6) : sUid}' : 'Belum Bergabung',
                                                                                  style: GoogleFonts.dmSans(
                                                                                    fontSize: 10.5,
                                                                                    color: joined ? Colors.black45 : Colors.redAccent,
                                                                                    fontWeight: FontWeight.w500,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),

                                                                    // Col 2: Progress
                                                                    Expanded(
                                                                      flex: 2,
                                                                      child: Column(
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                          Text(
                                                                            filteredTasks.isNotEmpty ? '$filteredDoneCount/${filteredTasks.length}' : '-',
                                                                            style: GoogleFonts.plusJakartaSans(
                                                                              fontSize: 13,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: isDark ? Colors.white : Colors.black87,
                                                                            ),
                                                                            textAlign: TextAlign.center,
                                                                          ),
                                                                          if (filteredTasks.isNotEmpty) ...[
                                                                            const SizedBox(height: 4),
                                                                            SizedBox(
                                                                              width: 44,
                                                                              child: ClipRRect(
                                                                                borderRadius: BorderRadius.circular(4),
                                                                                child: LinearProgressIndicator(
                                                                                  value: progressPercent / 100,
                                                                                  minHeight: 3.5,
                                                                                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                                                    progressPercent == 100
                                                                                        ? const Color(0xFF10B981)
                                                                                        : const Color(0xFF7F52FC),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                    ),

                                                                    // Col 3: Task Badges
                                                                    Expanded(
                                                                      flex: 4,
                                                                      child: joined && filteredTasks.isNotEmpty
                                                                          ? SingleChildScrollView(
                                                                              scrollDirection: Axis.horizontal,
                                                                              physics: const ClampingScrollPhysics(),
                                                                              child: Row(
                                                                                children: filteredTasks.map((tInfo) {
                                                                                  final String tKey = tInfo['key'];
                                                                                  final String tTitle = tInfo['title'];
                                                                                  final String tType = tInfo['type'];
                                                                                  final bool isDone = completed.contains(tKey);

                                                                                  if (tType == 'quiz') {
                                                                                    final quizScore = studentData['quizScore_$tKey'];
                                                                                    final String displayText = quizScore != null ? quizScore.toString() : '-';
                                                                                    final bool isFinished = quizScore != null;

                                                                                    return Tooltip(
                                                                                      message: '❓ Quiz: $tTitle\nNilai: ${quizScore ?? "Belum dikerjakan"}',
                                                                                      triggerMode: TooltipTriggerMode.tap,
                                                                                      child: Container(
                                                                                        margin: const EdgeInsets.only(right: 5),
                                                                                        width: 32,
                                                                                        height: 22,
                                                                                        decoration: BoxDecoration(
                                                                                          color: isFinished ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                                                                                          borderRadius: BorderRadius.circular(6),
                                                                                          border: Border.all(
                                                                                            color: isFinished ? const Color(0xFFEA580C) : Colors.black12,
                                                                                            width: 1,
                                                                                          ),
                                                                                        ),
                                                                                        alignment: Alignment.center,
                                                                                        child: Text(
                                                                                          displayText,
                                                                                          style: GoogleFonts.plusJakartaSans(
                                                                                            fontSize: 12.5,
                                                                                            fontWeight: FontWeight.bold,
                                                                                            color: isFinished ? const Color(0xFFEA580C) : Colors.black45,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  } else {
                                                                                    return Tooltip(
                                                                                      message: '📝 Tugas: $tTitle\n${isDone ? "Sudah dikerjakan (Klik untuk lihat)" : "Belum dikerjakan"}',
                                                                                      triggerMode: TooltipTriggerMode.tap,
                                                                                      child: GestureDetector(
                                                                                        onTap: isDone
                                                                                            ? () => _showViewTaskSubmissionDialog(context, sName, tTitle, studentData, tKey)
                                                                                            : null,
                                                                                        child: Container(
                                                                                          margin: const EdgeInsets.only(right: 5),
                                                                                          width: 22,
                                                                                          height: 22,
                                                                                          decoration: BoxDecoration(
                                                                                            color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                                                                            borderRadius: BorderRadius.circular(6),
                                                                                            border: Border.all(
                                                                                              color: isDone ? const Color(0xFF10B981) : Colors.black12,
                                                                                              width: 1,
                                                                                            ),
                                                                                          ),
                                                                                          alignment: Alignment.center,
                                                                                          child: isDone
                                                                                              ? const Icon(Icons.check_rounded, size: 12, color: Color(0xFF15803D))
                                                                                              : Text(
                                                                                                  '-',
                                                                                                  style: GoogleFonts.plusJakartaSans(
                                                                                                    fontSize: 12.5,
                                                                                                    fontWeight: FontWeight.bold,
                                                                                                    color: Colors.black38,
                                                                                                  ),
                                                                                                ),
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  }
                                                                                }).toList(),
                                                                              ),
                                                                            )
                                                                          : Text(
                                                                              joined ? 'Belum ada data' : 'Belum bergabung',
                                                                              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black38, fontStyle: FontStyle.italic),
                                                                              textAlign: TextAlign.center,
                                                                            ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Animated Attendance Side Panel (Desktop only)
              if (_showAttendancePanel && MediaQuery.of(context).size.width > 900)
                SizeTransition(
                  sizeFactor: _panelSlideAnim,
                  axis: Axis.horizontal,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141416) : Colors.white,
                      border: Border(
                        left: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Panel Header with close button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                            border: Border(
                              bottom: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.manage_accounts_rounded, size: 18, color: Color(0xFF7F52FC)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Atur Presensi',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _closeAttendancePanel,
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        // Embedded ManageAttendancePage content
                        Expanded(
                          child: ManageAttendancePage(
                            key: ValueKey('attendance_$_attendancePanelProjectId'),
                            projectId: _attendancePanelProjectId!,
                            currentMasterList: _attendancePanelMasterList,
                            isEmbedded: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
      },
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle, required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(fontSize: 17.6, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(fontSize: 12.9, color: Colors.black38, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentSubmissionDetailsSheet(
    BuildContext context,
    String studentName,
    String studentUid,
    List stages,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(_selectedProjectId)
              .collection('studentProgress')
              .doc(studentUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: Colors.black)),
              );
            }

            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final List completedTasks = data['completedTasks'] as List? ?? [];
            final safeBottom = MediaQuery.of(context).padding.bottom;

            final List<Map<String, dynamic>> activities = [];
            for (int sIdx = 0; sIdx < stages.length; sIdx++) {
              final stage = stages[sIdx] as Map;
              final String stageName = stage['name'] ?? 'Elemen';
              final List rawMateris = stage['materis'] as List? ?? [];
              List<Map<String, dynamic>> materis = [];
              if (rawMateris.isNotEmpty) {
                materis = List<Map<String, dynamic>>.from(rawMateris);
              } else {
                final List tasksList = stage['tasks'] as List? ?? [];
                if (tasksList.isNotEmpty) {
                  materis = [
                    {'title': 'Materi Pembelajaran', 'tasks': tasksList}
                  ];
                }
              }

              for (int mIdx = 0; mIdx < materis.length; mIdx++) {
                final m = materis[mIdx];
                final String mTitle = m['title'] ?? 'Materi';
                final List tasks = m['tasks'] as List? ?? [];
                for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
                  activities.add({
                    'key': '${sIdx}_${mIdx}_$tIdx',
                    'title': tasks[tIdx]['title'] ?? 'Tugas',
                    'type': tasks[tIdx]['type'] ?? 'tugas',
                    'stageName': stageName,
                    'materiTitle': mTitle,
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: 24 + safeBottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Detail Aktivitas Siswa',
                      style: GoogleFonts.plusJakartaSans(fontSize: 18.7, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      studentName,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.w600, color: Colors.black45),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: activities.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada kegiatan di classroom ini.',
                                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: activities.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final act = activities[index];
                                final String key = act['key'];
                                final String title = act['title'];
                                final String type = act['type'];
                                final bool isCompleted = completedTasks.contains(key);

                                Widget detailWidget = const SizedBox();
                                if (type == 'tugas') {
                                  final textAns = data['textAnswer_$key']?.toString() ?? '';
                                  final fileAns = data['fileAnswer_$key']?.toString() ?? '';
                                  detailWidget = Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (textAns.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('Jawaban: "$textAns"', style: GoogleFonts.dmSans(fontSize: 12.9, fontStyle: FontStyle.italic, color: Colors.black87)),
                                      ],
                                      if (fileAns.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.attach_file_rounded, size: 12, color: Colors.blueAccent),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(fileAns, style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.blueAccent, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (textAns.isEmpty && fileAns.isEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('Belum mengumpulkan jawaban', style: GoogleFonts.dmSans(fontSize: 11.7, color: Colors.black38)),
                                      ]
                                    ],
                                  );
                                } else if (type == 'quiz') {
                                  final score = data['quizScore_$key'];
                                  final isLocked = data['quizLocked_$key'] == true;
                                  detailWidget = Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (score != null)
                                              Text('Nilai: $score / 100', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, fontWeight: FontWeight.bold, color: Colors.orange[800]))
                                            else
                                              Text('Belum mengerjakan kuis', style: GoogleFonts.plusJakartaSans(fontSize: 11.7, color: Colors.black38)),
                                            if (isLocked) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.lock_rounded, size: 12, color: Colors.redAccent),
                                                  const SizedBox(width: 4),
                                                  Text('Kuis Terkunci (Keluar Aplikasi)', style: GoogleFonts.plusJakartaSans(fontSize: 11.7, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                      if (isLocked)
                                        ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('projects')
                                                  .doc(_selectedProjectId)
                                                  .collection('studentProgress')
                                                  .doc(studentUid)
                                                  .update({
                                                'quizLocked_$key': FieldValue.delete(),
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Kuis berhasil dibuka kembali!'), backgroundColor: Colors.green),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Gagal membuka kuis: $e')),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          child: Text('Buka Kunci', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  );
                                }

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isCompleted ? 'Selesai' : 'Belum',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 9.4, fontWeight: FontWeight.bold, color: isCompleted ? Colors.green[800] : Colors.black45),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${act['stageName']} > ${act['materiTitle']}',
                                        style: GoogleFonts.dmSans(fontSize: 10.5, color: Colors.black38),
                                      ),
                                      const SizedBox(height: 6),
                                      detailWidget,
                                    ],
                                  ),
                                );
                              },
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
}

// Bouncy Menu Slider Card (Visual match persis ke slider menu di screenshot)
class _BouncyMenuSliderCard extends StatefulWidget {
  final IconData icon;
  final Color cardBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _BouncyMenuSliderCard({
    required this.icon,
    required this.cardBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_BouncyMenuSliderCard> createState() => _BouncyMenuSliderCardState();
}

class _BouncyMenuSliderCardState extends State<_BouncyMenuSliderCard> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _anim.forward(),
      onTapUp: (_) {
        _anim.reverse();
        widget.onTap();
      },
      onTapCancel: () => _anim.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.cardBg.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.black87,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      widget.subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Soft Animated Pattern Custom Painter
class _SoftAnimatedPatternPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  _SoftAnimatedPatternPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final whiteDotPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.08 : 0.12)
      ..style = PaintingStyle.fill;

    final greyDotPaint = Paint()
      ..color = isDark
          ? const Color(0xFF94A3B8).withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final blackDotPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = isDark
          ? const Color(0xFFCBD5E1).withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final blackRingPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double spacing = 32.0;
    final int cols = (size.width / spacing).ceil() + 1;
    final int rows = (size.height / spacing).ceil() + 1;

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        final double x = i * spacing;
        final double y = j * spacing;
        final double wave = math.sin((i * 0.4) + (j * 0.4) + (animationValue * math.pi * 2));
        final double radius = 1.5 + (wave * 0.75);
        final int patternType = (i + j) % 3;
        final Paint dotPaint = patternType == 0
            ? whiteDotPaint
            : (patternType == 1 ? greyDotPaint : blackDotPaint);

        canvas.drawCircle(Offset(x, y), math.max(0.6, radius), dotPaint);
      }
    }

    final double offset1 = math.sin(animationValue * math.pi * 2) * 12;
    final double offset2 = math.cos(animationValue * math.pi * 2) * 10;

    canvas.drawCircle(Offset(size.width * 0.2 + offset1, size.height * 0.3 + offset2), 42, ringPaint);
    canvas.drawCircle(Offset(size.width * 0.85 - offset2, size.height * 0.65 + offset1), 54, blackRingPaint);
    canvas.drawCircle(Offset(size.width * 0.5 + offset2, size.height * 0.85 - offset1), 32, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SoftAnimatedPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isDark != isDark;
  }
}

class StudentAvatarWidget extends StatefulWidget {
  final String uid;
  final String defaultAvatar;
  final String studentName;
  final bool joined;

  const StudentAvatarWidget({
    super.key,
    required this.uid,
    required this.defaultAvatar,
    required this.studentName,
    required this.joined,
  });

  @override
  State<StudentAvatarWidget> createState() => _StudentAvatarWidgetState();
}

class _StudentAvatarWidgetState extends State<StudentAvatarWidget> {
  static final Map<String, Map<String, dynamic>> _profileCache = {};
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant StudentAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (!widget.joined || widget.uid.isEmpty) return;
    if (_profileCache.containsKey(widget.uid)) {
      if (mounted) {
        setState(() {
          _profile = _profileCache[widget.uid];
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (doc.exists && doc.data() != null) {
        _profileCache[widget.uid] = doc.data()!;
        if (mounted) {
          setState(() {
            _profile = doc.data();
          });
        }
      }
    } catch (_) {}
  }

  Color _getAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> avatarColors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
    ];
    return avatarColors[hash % avatarColors.length];
  }

  String _getInitials(String name) {
    final List<String> parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length > 1 ? 2 : 1).toUpperCase();
    final firstChar = parts[0][0];
    final secondChar = parts[1].isNotEmpty ? parts[1][0] : '';
    return (firstChar + secondChar).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String avatar = _profile?['avatar']?.toString() ?? widget.defaultAvatar;
    return ClipOval(
      child: Image.asset(
        avatar,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => Container(
          alignment: Alignment.center,
          color: widget.joined ? _getAvatarColor(widget.studentName) : Colors.red[50],
          child: Text(
            widget.joined ? _getInitials(widget.studentName) : '!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.7,
              fontWeight: FontWeight.bold,
              color: widget.joined ? Colors.white : Colors.red[400],
            ),
          ),
        ),
      ),
    );
  }
}
