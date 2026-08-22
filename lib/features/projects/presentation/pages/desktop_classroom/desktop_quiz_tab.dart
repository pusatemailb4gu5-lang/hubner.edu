import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:hubner/features/projects/domain/activity_logger.dart';
import 'package:hubner/features/projects/presentation/pages/mengerjakan_quiz_page.dart';

final List<Color> _classroomAccentColors = const [
  Color(0xFF009688), // 0: Teal
  Color(0xFF448AFF), // 1: Blue
  Color(0xFFE040FB), // 2: Purple/Magenta
  Color(0xFFFF4081), // 3: Pink/Rose
  Color(0xFFFFAB40), // 4: Orange/Amber
  Color(0xFF536DFE), // 5: Indigo
  Color(0xFF607D8B), // 6: Blue Grey
];

class DesktopQuizTab extends StatefulWidget {
  final String projectId;
  final String title;

  const DesktopQuizTab({
    super.key,
    required this.projectId,
    required this.title,
  });

  @override
  State<DesktopQuizTab> createState() => _DesktopQuizTabState();
}

class _DesktopQuizTabState extends State<DesktopQuizTab> {
  Map<String, dynamic>? _selectedTask;
  String? _selectedStageTitle;
  bool _isInlineEditingQuiz = false;
  List<Map<String, dynamic>> _inlineQuestions = [];

  Future<void> _uploadQuestionImage(
    BuildContext context,
    Map question,
    StateSetter setDialogState,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mengunggah gambar ke Google Drive kelas...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final data = doc.data() ?? {};
      final driveFolderId = data['driveFolderId'] as String?;
      final driveAccessToken = data['driveAccessToken'] as String?;

      if (driveFolderId != null &&
          driveFolderId.isNotEmpty &&
          driveAccessToken != null &&
          driveAccessToken.isNotEmpty) {
        List<int> fileBytes;
        if (kIsWeb) {
          fileBytes = pickedFile.bytes!;
        } else {
          fileBytes = await File(pickedFile.path!).readAsBytes();
        }

        final uploadResult = await GoogleDriveService.uploadFile(
          accessToken: driveAccessToken,
          folderId: driveFolderId,
          fileName: 'quiz_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}',
          bytes: fileBytes,
        );

        final String fileUrl = uploadResult['directLink'] ?? uploadResult['webViewLink'] ?? '';
        setDialogState(() {
          question['image'] = fileUrl;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar berhasil diunggah ke Google Drive kelas!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive Kelas belum tersambung. Berkas tidak dapat diunggah.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah gambar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String ownerUid = data['ownerUid'] as String? ?? '';
        final bool isOwner =
            ownerUid == (FirebaseAuth.instance.currentUser?.uid ?? '');

        final Color heroColor = const Color(0xFFD97706); // Amber for Quiz
        final List stages = data['stages'] as List? ?? [];

        // Auto-select first quiz for right column preview if none selected
        if (_selectedTask == null && stages.isNotEmpty) {
          for (var stage in stages) {
            final materis = (stage as Map)['materis'] as List? ?? [];
            for (var m in materis) {
              final tasks = (m as Map)['tasks'] as List? ?? [];
              for (var t in tasks) {
                final tMap = Map<String, dynamic>.from(t as Map);
                if ((tMap['type'] ?? 'tugas') == 'quiz') {
                  _selectedTask = tMap;
                  _selectedStageTitle = stage['name'] ?? stage['title'] ?? 'Elemen';
                  break;
                }
              }
              if (_selectedTask != null) break;
            }
            if (_selectedTask != null) break;
          }
        }

        return SingleChildScrollView(
          key: const PageStorageKey('QuizScroll'),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. TOP HERO BANNER ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: heroColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: heroColor.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.quiz_rounded,
                          color: heroColor,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 23.4,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelola & Evaluasi Quiz Siswa secara Fleksibel',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      ElevatedButton.icon(
                        onPressed: () => _showAddTaskDialog(
                            context, stages, heroColor),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Buat Quiz Baru',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBBF24),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── 2. 2-COLUMN DESKTOP MAIN VIEW ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 45,
                    child: _buildLeftColumnTaskList(
                      context: context,
                      stages: stages,
                      accentColor: heroColor,
                      isOwner: isOwner,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 55,
                    child: _buildRightColumnTaskPreview(
                      context: context,
                      accentColor: heroColor,
                      isOwner: isOwner,
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

  // ─── LEFT COLUMN (45%): ELEMEN & TASK LIST ───
  Widget _buildLeftColumnTaskList({
    required BuildContext context,
    required List stages,
    required Color accentColor,
    required bool isOwner,
  }) {
    if (stages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz_rounded,
                size: 44,
                color: accentColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada elemen pembelajaran di kelas ini.',
                style: GoogleFonts.dmSans(
                  fontSize: 15.2,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Elemen & Quiz',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.7,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stages.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, sIndex) {
              final stage = stages[sIndex] as Map;
              final String stageTitle = stage['name'] ?? stage['title'] ?? 'Elemen ${sIndex + 1}';
              final List materis = stage['materis'] as List? ?? [];
              final Color badgeColor = _classroomAccentColors[sIndex % _classroomAccentColors.length];

              // Collect all quizzes inside this stage
              final List<Map<String, dynamic>> stageTasks = [];
              for (var m in materis) {
                final mMap = m as Map;
                final String mTitle = mMap['title'] ?? 'Materi';
                final tasks = mMap['tasks'] as List? ?? [];
                for (var t in tasks) {
                  final tMap = Map<String, dynamic>.from(t as Map);
                  final String type = tMap['type'] ?? 'tugas';
                  if (type == 'quiz') {
                    tMap['materiTitle'] = mTitle;
                    stageTasks.add(tMap);
                  }
                }
              }

              return Column(
                children: [
                  // Stage Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${sIndex + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stageTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${materis.length} Materi • ${stageTasks.length} Quiz',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stage Children (always expanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                    child: Column(
                      children: [
                        if (stageTasks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Belum ada quiz di elemen ini.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: stageTasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, tIndex) {
                              final t = stageTasks[tIndex];
                              final bool isSelected = _selectedTask != null &&
                                  _selectedTask!['id'] == t['id'];

                              bool isHovered = false;
                              return StatefulBuilder(
                                builder: (context, setStateBuilder) {
                                  final bool isTitleHighlighted = isSelected || isHovered;
                                  return InkWell(
                                    onHover: (hovered) {
                                      setStateBuilder(() {
                                        isHovered = hovered;
                                      });
                                    },
                                    onTap: () {
                                      setState(() {
                                        _selectedTask = t;
                                        _selectedStageTitle = stageTitle;
                                        _isInlineEditingQuiz = false;
                                      });
                                    },
                                    onDoubleTap: isOwner
                                        ? () {
                                            _showAddTaskDialog(
                                              context,
                                              stages,
                                              accentColor,
                                              taskToEdit: t,
                                            );
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFD97706).withValues(alpha: 0.25),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.04),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.quiz_rounded,
                                              color: Color(0xFFD97706),
                                              size: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  t['title'] ?? 'Tanpa Judul',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13.5,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: isTitleHighlighted
                                                        ? accentColor
                                                        : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Text(
                                                  'Materi: ${t['materiTitle'] ?? '-'}',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 11.5,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _selectedTask = t;
                                                _selectedStageTitle = stageTitle;
                                                _isInlineEditingQuiz = false;
                                              });
                                              final extraData = t['extraData'] as Map? ?? {};
                                              final List questions = extraData['questions'] as List? ?? [];
                                              _showQuizPreviewModal(context, t['title'] ?? 'Quiz', questions, isOwner);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: accentColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.remove_red_eye_rounded, size: 13, color: accentColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Preview',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: accentColor,
                                                    ),
                                                  ),
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
                          ),
                      ],
                    ),
                  ),
                  if (sIndex < stages.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── RIGHT COLUMN (55%): PREVIEW & INLINE EDIT PANEL ───
  Widget _buildRightColumnTaskPreview({
    required BuildContext context,
    required Color accentColor,
    required bool isOwner,
  }) {
    if (_selectedTask == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.touch_app_rounded, size: 40, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Pilih salah satu quiz di kolom kiri untuk melihat preview.',
                style: GoogleFonts.dmSans(
                  fontSize: 15.2,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final task = _selectedTask!;
    final String title = task['title'] ?? 'Tanpa Judul';
    final String materiTitle = task['materiTitle'] ?? 'Materi';
    final String startDateStr = task['startDate'] ?? '';
    final String endDateStr = task['endDate'] ?? '';
    final Map extraData = task['extraData'] as Map? ?? {};
    final List questions = extraData['questions'] as List? ?? [];
    final List submissions = task['submissions'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                '$_selectedStageTitle • $materiTitle',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (startDateStr.isNotEmpty || endDateStr.isNotEmpty)
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Tenggat: ${startDateStr.isNotEmpty ? startDateStr : '-'} s/d ${endDateStr.isNotEmpty ? endDateStr : 'Selesai'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // ─── INLINE EDITABLE QUESTIONS AREA ───
          Row(
            children: [
              Text(
                'Pertanyaan Kuis (${questions.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.2,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (isOwner) ...[
                if (!_isInlineEditingQuiz)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isInlineEditingQuiz = true;
                        _inlineQuestions = List<Map<String, dynamic>>.from(
                          questions.map((q) => Map<String, dynamic>.from(q as Map)),
                        );
                      });
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF7C3AED)),
                    label: Text(
                      'Edit Soal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isInlineEditingQuiz = false;
                      });
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                    label: Text(
                      'Batal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleSaveInlineQuizQuestions(task),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Simpan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 12),

          ...List.generate(
            _isInlineEditingQuiz ? _inlineQuestions.length : questions.length,
            (qIdx) {
              final q = _isInlineEditingQuiz ? _inlineQuestions[qIdx] : (questions[qIdx] as Map);
              final String qText = q['question'] ?? '';
              final String optA = q['a'] ?? '';
              final String optB = q['b'] ?? '';
              final String optC = q['c'] ?? '';
              final String optD = q['d'] ?? '';
              final String correctOpt = q['correct'] ?? 'A';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Soal ${qIdx + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const Spacer(),
                        if (_isInlineEditingQuiz && _inlineQuestions.length > 1)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _inlineQuestions.removeAt(qIdx);
                              });
                            },
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_isInlineEditingQuiz) ...[
                      Text(
                        qText.isNotEmpty ? qText : '(Teks soal kosong)',
                        style: GoogleFonts.dmSans(
                          fontSize: 14.2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (q['image'] != null && (q['image'] as String).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              q['image'],
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => Container(
                                padding: const EdgeInsets.all(12),
                                color: const Color(0xFFF8FAFC),
                                child: Row(
                                  children: [
                                    const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Gambar: ${q['image']}',
                                        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildInlineOptionView('A', optA, correctOpt == 'A', accentColor),
                      _buildInlineOptionView('B', optB, correctOpt == 'B', accentColor),
                      _buildInlineOptionView('C', optC, correctOpt == 'C', accentColor),
                      _buildInlineOptionView('D', optD, correctOpt == 'D', accentColor),
                    ] else ...[
                      TextFormField(
                        initialValue: qText,
                        onChanged: (val) => q['question'] = val,
                        style: GoogleFonts.dmSans(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Tulis pertanyaan soal...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ─── KOTAK SKELETON ABU PUTIH PILIH GAMBAR SOAL ───
                      _buildImagePickerSkeletonBox(q),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildInlineOptionEdit('A', optA, q)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildInlineOptionEdit('B', optB, q)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildInlineOptionEdit('C', optC, q)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildInlineOptionEdit('D', optD, q)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Jawaban Benar: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: correctOpt,
                            items: ['A', 'B', 'C', 'D'].map((opt) {
                              return DropdownMenuItem(
                                value: opt,
                                child: Text(
                                  opt,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  q['correct'] = val;
                                });
                                // Keep state updated for local preview
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_isInlineEditingQuiz) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _inlineQuestions.add({
                      'question': '',
                      'a': '',
                      'b': '',
                      'c': '',
                      'd': '',
                      'correct': 'A',
                      'image': '',
                    });
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Tambah Pertanyaan Baru',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showQuizPreviewModal(context, title, questions, isOwner),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: Text(
                'Preview',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (isOwner) ...[
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: OutlinedButton.icon(
                    onPressed: () => _showStudentSubmissionsOverlayDialog(
                      context: context,
                      task: task,
                      stageTitle: _selectedStageTitle ?? 'Elemen',
                      accentColor: accentColor,
                    ),
                    icon: const Icon(Icons.people_alt_rounded, size: 18, color: Colors.black87),
                    label: Text(
                      'Lihat Pekerjaan Siswa (${submissions.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3E8FF),
                      side: const BorderSide(color: Color(0xFFD8B4FE)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDeleteQuiz(task),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    label: Text(
                      'Hapus',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.normal,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showStudentSubmissionsOverlayDialog(
                  context: context,
                  task: task,
                  stageTitle: _selectedStageTitle ?? 'Elemen',
                  accentColor: accentColor,
                ),
                icon: const Icon(Icons.people_alt_rounded, size: 18, color: Colors.black87),
                label: Text(
                  'Lihat Pekerjaan Siswa (${submissions.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3E8FF),
                  side: const BorderSide(color: Color(0xFFD8B4FE)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleDeleteQuiz(Map task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Quiz', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus "${task['title']}"? Tindakan ini tidak dapat dibatalkan.', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: Text('Hapus', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final DocumentSnapshot doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
    if (!doc.exists) return;

    final List stages = doc.get('stages') as List? ?? [];
    final List updatedStages = List.from(stages);

    int targetStageIdx = -1;
    int targetMateriIdx = -1;

    for (int s = 0; s < updatedStages.length; s++) {
      final stageMap = updatedStages[s] as Map;
      final List materis = stageMap['materis'] as List? ?? [];
      for (int m = 0; m < materis.length; m++) {
        final mItem = materis[m] as Map;
        final List tasks = mItem['tasks'] as List? ?? [];
        for (var t in tasks) {
          if (t is Map && t['id'] == task['id']) {
            targetStageIdx = s;
            targetMateriIdx = m;
            break;
          }
        }
      }
    }

    if (targetStageIdx != -1 && targetMateriIdx != -1) {
      final Map targetStage = Map.from(updatedStages[targetStageIdx] as Map);
      final List targetMateris = List.from(targetStage['materis'] as List? ?? []);
      final Map targetMateri = Map.from(targetMateris[targetMateriIdx] as Map);

      final List currentMateriTasks = List.from(targetMateri['tasks'] as List? ?? []);
      currentMateriTasks.removeWhere((t) => t['id'] == task['id']);
      targetMateri['tasks'] = currentMateriTasks;
      targetMateris[targetMateriIdx] = targetMateri;
      targetStage['materis'] = targetMateris;

      final List currentStageTasks = List.from(targetStage['tasks'] as List? ?? []);
      currentStageTasks.removeWhere((t) => t['id'] == task['id']);
      targetStage['tasks'] = currentStageTasks;

      updatedStages[targetStageIdx] = targetStage;

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'stages': updatedStages,
      });

      await logClassroomActivity(
        projectId: widget.projectId,
        type: 'quiz',
        actor: 'Guru Pengajar',
        action: 'menghapus quiz',
        target: task['title'] ?? '',
      );

      setState(() {
        _selectedTask = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil menghapus Quiz!'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleSaveInlineQuizQuestions(Map task) async {
    final DocumentSnapshot doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
    if (!doc.exists) return;

    final List stages = doc.get('stages') as List? ?? [];
    final List updatedStages = List.from(stages);

    int targetStageIdx = -1;
    int targetMateriIdx = -1;

    for (int s = 0; s < updatedStages.length; s++) {
      final stageMap = updatedStages[s] as Map;
      final List materis = stageMap['materis'] as List? ?? [];
      for (int m = 0; m < materis.length; m++) {
        final mItem = materis[m] as Map;
        final List tasks = mItem['tasks'] as List? ?? [];
        for (var t in tasks) {
          if (t is Map && t['id'] == task['id']) {
            targetStageIdx = s;
            targetMateriIdx = m;
            break;
          }
        }
      }
    }

    if (targetStageIdx != -1 && targetMateriIdx != -1) {
      final Map targetStage = Map.from(updatedStages[targetStageIdx] as Map);
      final List targetMateris = List.from(targetStage['materis'] as List? ?? []);
      final Map targetMateri = Map.from(targetMateris[targetMateriIdx] as Map);

      final List currentMateriTasks = List.from(targetMateri['tasks'] as List? ?? []);
      final int tIdx = currentMateriTasks.indexWhere((t) => t['id'] == task['id']);

      if (tIdx != -1) {
        final Map editedTask = Map.from(currentMateriTasks[tIdx] as Map);
        final Map extraData = Map.from(editedTask['extraData'] as Map? ?? {});
        extraData['questions'] = _inlineQuestions;
        editedTask['extraData'] = extraData;

        currentMateriTasks[tIdx] = editedTask;
        targetMateri['tasks'] = currentMateriTasks;
        targetMateris[targetMateriIdx] = targetMateri;
        targetStage['materis'] = targetMateris;

        final List currentStageTasks = List.from(targetStage['tasks'] as List? ?? []);
        final int stIdx = currentStageTasks.indexWhere((t) => t['id'] == task['id']);
        if (stIdx != -1) {
          currentStageTasks[stIdx] = editedTask;
        }
        targetStage['tasks'] = currentStageTasks;

        updatedStages[targetStageIdx] = targetStage;

        await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
          'stages': updatedStages,
        });

        await logClassroomActivity(
          projectId: widget.projectId,
          type: 'quiz',
          actor: 'Guru Pengajar',
          action: 'memperbarui kuis (edit inline)',
          target: task['title'] ?? '',
        );

        setState(() {
          _selectedTask = Map<String, dynamic>.from(editedTask);
          _isInlineEditingQuiz = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil memperbarui soal kuis!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    }
  }

  Widget _buildInlineOptionView(String key, String text, bool isCorrect, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCorrect
            ? const Color(0xFFD1FAE5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Text(
              key,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : '(Opsi kosong)',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineOptionEdit(String key, String initialValue, Map q) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: (val) => q[key.toLowerCase()] = val,
      style: GoogleFonts.dmSans(fontSize: 13),
      decoration: InputDecoration(
        prefixText: '$key: ',
        prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  // ─── ADD/EDIT QUIZ DIALOG ───
  void _showAddTaskDialog(
    BuildContext context,
    List stages,
    Color accentColor, {
    Map? taskToEdit,
  }) {
    if (stages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buat elemen terlebih dahulu di Tahapan Belajar!'),
        ),
      );
      return;
    }

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = 0;
    int selectedMateriIdx = 0;

    if (isEditMode) {
      for (int s = 0; s < stages.length; s++) {
        final stageMap = stages[s] as Map;
        final List materis = stageMap['materis'] as List? ?? [];
        for (int m = 0; m < materis.length; m++) {
          final mItem = materis[m] as Map;
          final List tasks = mItem['tasks'] as List? ?? [];
          for (var t in tasks) {
            if (t is Map && t['id'] == taskToEdit['id']) {
              selectedStageIdx = s;
              selectedMateriIdx = m;
              break;
            }
          }
        }
      }
    }

    final titleController = TextEditingController(text: isEditMode ? (taskToEdit['title'] ?? '') : '');

    // Date controllers with DD/MM/YYYY format
    String _initDateStr(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      return raw; // already DD/MM/YYYY
    }
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final startDateController = TextEditingController(
      text: isEditMode ? _initDateStr(taskToEdit['startDate'] as String?) : todayStr,
    );
    final endDateController = TextEditingController(
      text: isEditMode ? _initDateStr(taskToEdit['endDate'] as String?) : '',
    );

    // Auto-format DD/MM/YYYY: inserts '/' after DD and MM as user types
    void _formatDateInput(TextEditingController ctrl) {
      String text = ctrl.text.replaceAll('/', '');
      if (text.length > 8) text = text.substring(0, 8);
      String formatted = '';
      for (int i = 0; i < text.length; i++) {
        formatted += text[i];
        if ((i == 1 || i == 3) && i < text.length - 1) formatted += '/';
      }
      if (formatted != ctrl.text) {
        ctrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    final Map extraDataEdit = isEditMode ? (taskToEdit['extraData'] as Map? ?? {}) : {};
    List questionsList = isEditMode ? List.from(extraDataEdit['questions'] as List? ?? []) : [
      {
        'question': '',
        'a': '',
        'b': '',
        'c': '',
        'd': '',
        'correct': 'A',
        'image': '',
      }
    ];

    String quizTimeMode = isEditMode ? (extraDataEdit['quizTimeMode'] ?? 'no_limit') : 'no_limit';
    String quizTimeType = isEditMode ? (extraDataEdit['quizTimeType'] ?? 'per_quiz') : 'per_quiz';
    final quizTimeController = TextEditingController(text: isEditMode ? (extraDataEdit['quizTimeDuration'] ?? '') : '');
    String creationMethod = isEditMode ? (extraDataEdit['creationMethod'] ?? 'manual') : 'manual';

    final Color mainThemeColor = const Color(0xFFD97706);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final List materis = (stages[selectedStageIdx] as Map)['materis'] as List? ?? [];

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: screenWidth * 0.82,
                height: screenHeight * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 18.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditMode ? 'Edit Quiz' : 'Unggah/Buat Quiz',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 23.4,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  if (isSubmitting) return;
                                  final title = titleController.text.trim();
                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Judul tidak boleh kosong!'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  final startStr = startDateController.text.trim();
                                  final endStr = endDateController.text.trim();

                                  final extraData = {
                                    'questions': questionsList,
                                    'quizTimeMode': quizTimeMode,
                                    'quizTimeType': quizTimeType,
                                    'quizTimeDuration': quizTimeMode == 'set_time'
                                        ? quizTimeController.text.trim()
                                        : '',
                                    'creationMethod': creationMethod,
                                  };

                                  final newTask = {
                                    'id': isEditMode ? taskToEdit['id'] : 'task_${DateTime.now().millisecondsSinceEpoch}',
                                    'type': 'quiz',
                                    'title': title,
                                    'startDate': startStr,
                                    'endDate': endStr,
                                    'docName': '',
                                    'extraData': extraData,
                                    'submissions': isEditMode ? (taskToEdit['submissions'] ?? []) : [],
                                  };

                                  setDialogState(() {
                                    isSubmitting = true;
                                  });

                                  final List updatedStages = List.from(stages);
                                  final Map targetStage =
                                      Map.from(updatedStages[selectedStageIdx] as Map);
                                  final List targetMateris =
                                      List.from(targetStage['materis'] as List? ?? []);

                                  if (selectedMateriIdx < targetMateris.length) {
                                    final Map targetMateri =
                                        Map.from(targetMateris[selectedMateriIdx] as Map);

                                    final List currentMateriTasks =
                                        List.from(targetMateri['tasks'] as List? ?? []);
                                    if (isEditMode) {
                                      final int tIdx = currentMateriTasks.indexWhere((t) => t['id'] == taskToEdit['id']);
                                      if (tIdx != -1) {
                                        currentMateriTasks[tIdx] = newTask;
                                      } else {
                                        currentMateriTasks.add(newTask);
                                      }
                                    } else {
                                      currentMateriTasks.add(newTask);
                                    }
                                    targetMateri['tasks'] = currentMateriTasks;
                                    targetMateris[selectedMateriIdx] = targetMateri;
                                    targetStage['materis'] = targetMateris;

                                    final List currentStageTasks =
                                        List.from(targetStage['tasks'] as List? ?? []);
                                    if (isEditMode) {
                                      final int stIdx = currentStageTasks.indexWhere((t) => t['id'] == taskToEdit['id']);
                                      if (stIdx != -1) {
                                        currentStageTasks[stIdx] = newTask;
                                      } else {
                                        currentStageTasks.add(newTask);
                                      }
                                    } else {
                                      currentStageTasks.add(newTask);
                                    }
                                    targetStage['tasks'] = currentStageTasks;

                                    updatedStages[selectedStageIdx] = targetStage;

                                    await FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(widget.projectId)
                                        .update({'stages': updatedStages});

                                    await logClassroomActivity(
                                      projectId: widget.projectId,
                                      type: 'quiz',
                                      actor: 'Guru Pengajar',
                                      action: isEditMode ? 'memperbarui kuis' : 'membuat quiz baru',
                                      target: title,
                                    );
                                  }

                                  if (mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    isEditMode ? 'Perbarui' : 'Simpan',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 46,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pilih Elemen Pembelajaran',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedStageIdx,
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45, size: 18),
                                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
                                        items: List.generate(stages.length, (idx) {
                                          final st = stages[idx] as Map;
                                          return DropdownMenuItem<int>(
                                            value: idx,
                                            child: Text(
                                              st['name'] ?? st['title'] ?? 'Elemen ${idx + 1}',
                                              style: GoogleFonts.dmSans(fontSize: 14),
                                            ),
                                          );
                                        }),
                                        onChanged: isEditMode
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  setDialogState(() {
                                                    selectedStageIdx = val;
                                                    selectedMateriIdx = 0;
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Text(
                                    'Pilih Materi',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: materis.isNotEmpty ? selectedMateriIdx : null,
                                        hint: Text('Pilih Materi', style: GoogleFonts.dmSans(fontSize: 14)),
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45, size: 18),
                                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
                                        items: List.generate(materis.length, (mIdx) {
                                          final m = materis[mIdx] as Map;
                                          return DropdownMenuItem<int>(
                                            value: mIdx,
                                            child: Text(
                                              m['title'] ?? 'Materi ${mIdx + 1}',
                                              style: GoogleFonts.dmSans(fontSize: 14),
                                            ),
                                          );
                                        }),
                                        onChanged: isEditMode
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  setDialogState(() {
                                                    selectedMateriIdx = val;
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  Text(
                                    'Judul Quiz',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: titleController,
                                    style: GoogleFonts.dmSans(fontSize: 14.5),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan judul...',
                                      hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      fillColor: const Color(0xFFF8FAFC),
                                      filled: true,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tanggal Mulai',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: startDateController,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.dmSans(fontSize: 14.5),
                                              onChanged: (_) => _formatDateInput(startDateController),
                                              decoration: InputDecoration(
                                                hintText: 'HH/BB/TTTT',
                                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
                                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: mainThemeColor),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                fillColor: const Color(0xFFF8FAFC),
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(24),
                                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(24),
                                                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tanggal Selesai / Tenggat',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: endDateController,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.dmSans(fontSize: 14.5),
                                              onChanged: (_) => _formatDateInput(endDateController),
                                              decoration: InputDecoration(
                                                hintText: 'HH/BB/TTTT',
                                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
                                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: mainThemeColor),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                fillColor: const Color(0xFFF8FAFC),
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(24),
                                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(24),
                                                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  Text(
                                    'Batasan Waktu Pengerjaan',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Tanpa Batas'),
                                        selected: quizTimeMode == 'no_limit',
                                        selectedColor: mainThemeColor.withValues(alpha: 0.15),
                                        checkmarkColor: mainThemeColor,
                                        onSelected: (_) => setDialogState(() => quizTimeMode = 'no_limit'),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('Set Batas Waktu'),
                                        selected: quizTimeMode == 'set_time',
                                        selectedColor: mainThemeColor.withValues(alpha: 0.15),
                                        checkmarkColor: mainThemeColor,
                                        onSelected: (_) => setDialogState(() => quizTimeMode = 'set_time'),
                                      ),
                                    ],
                                  ),
                                  if (quizTimeMode == 'set_time') ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: quizTimeController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: 'Durasi (menit)',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              fillColor: const Color(0xFFF8FAFC),
                                              filled: true,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(24),
                                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(24),
                                                borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        DropdownButton<String>(
                                          value: quizTimeType,
                                          items: const [
                                            DropdownMenuItem(value: 'per_quiz', child: Text('Menit per Quiz')),
                                            DropdownMenuItem(value: 'per_question', child: Text('Detik per Soal')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => quizTimeType = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(width: 32),

                            Expanded(
                              flex: 54,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daftar Pertanyaan Quiz',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                  const SizedBox(height: 14),

                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: questionsList.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                                    itemBuilder: (context, qIdx) {
                                      final q = questionsList[qIdx];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                                Text('Soal ${qIdx + 1}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF475569))),
                                                if (questionsList.length > 1)
                                                  GestureDetector(
                                                    onTap: () {
                                                      setDialogState(() => questionsList.removeAt(qIdx));
                                                    },
                                                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),

                                            TextFormField(
                                              initialValue: q['question'],
                                              onChanged: (v) => q['question'] = v,
                                              maxLines: null,
                                              minLines: 1,
                                              keyboardType: TextInputType.multiline,
                                              style: GoogleFonts.dmSans(fontSize: 13.5),
                                              decoration: InputDecoration(
                                                hintText: 'Pertanyaan...',
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                fillColor: Colors.white,
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: q['a'],
                                                    onChanged: (v) => q['a'] = v,
                                                    maxLines: null,
                                                    minLines: 1,
                                                    keyboardType: TextInputType.multiline,
                                                    style: GoogleFonts.dmSans(fontSize: 13),
                                                    decoration: InputDecoration(
                                                      hintText: 'Pilihan A',
                                                      prefixText: 'A. ',
                                                      prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 13),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      fillColor: (q['correct'] ?? 'A') == 'A' ? const Color(0xFFF0FDF4) : Colors.white,
                                                      filled: true,
                                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'A' ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0), width: 1.5)),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: q['b'],
                                                    onChanged: (v) => q['b'] = v,
                                                    maxLines: null,
                                                    minLines: 1,
                                                    keyboardType: TextInputType.multiline,
                                                    style: GoogleFonts.dmSans(fontSize: 13),
                                                    decoration: InputDecoration(
                                                      hintText: 'Pilihan B',
                                                      prefixText: 'B. ',
                                                      prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 13),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      fillColor: (q['correct'] ?? 'A') == 'B' ? const Color(0xFFF0FDF4) : Colors.white,
                                                      filled: true,
                                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'B' ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0), width: 1.5)),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: q['c'],
                                                    onChanged: (v) => q['c'] = v,
                                                    maxLines: null,
                                                    minLines: 1,
                                                    keyboardType: TextInputType.multiline,
                                                    style: GoogleFonts.dmSans(fontSize: 13),
                                                    decoration: InputDecoration(
                                                      hintText: 'Pilihan C',
                                                      prefixText: 'C. ',
                                                      prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 13),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      fillColor: (q['correct'] ?? 'A') == 'C' ? const Color(0xFFF0FDF4) : Colors.white,
                                                      filled: true,
                                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'C' ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0), width: 1.5)),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: q['d'],
                                                    onChanged: (v) => q['d'] = v,
                                                    maxLines: null,
                                                    minLines: 1,
                                                    keyboardType: TextInputType.multiline,
                                                    style: GoogleFonts.dmSans(fontSize: 13),
                                                    decoration: InputDecoration(
                                                      hintText: 'Pilihan D',
                                                      prefixText: 'D. ',
                                                      prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 13),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      fillColor: (q['correct'] ?? 'A') == 'D' ? const Color(0xFFF0FDF4) : Colors.white,
                                                      filled: true,
                                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'D' ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0), width: 1.5)),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Bottom Row: Kunci Jawaban (Left) & Upload Gambar (Right)
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text('Kunci Jawaban: ', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF8FAFC),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                                      ),
                                                      child: DropdownButtonHideUnderline(
                                                        child: DropdownButton<String>(
                                                          value: q['correct'] ?? 'A',
                                                          dropdownColor: Colors.white,
                                                          borderRadius: BorderRadius.circular(12),
                                                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                          items: ['A', 'B', 'C', 'D'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                                          onChanged: (v) {
                                                            if (v != null) setDialogState(() => q['correct'] = v);
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Upload Gambar (Google Drive Kelas) Button / Status
                                                if (q['image'] == null || (q['image'] as String).isEmpty)
                                                  InkWell(
                                                    onTap: () => _uploadQuestionImage(context, q, setDialogState),
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.add_photo_alternate_rounded, size: 16, color: Color(0xFF475569)),
                                                          const SizedBox(width: 6),
                                                          Text('Upload Gambar', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEFF6FF),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: const Color(0xFF93C5FD)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.image_rounded, size: 15, color: Color(0xFF2563EB)),
                                                        const SizedBox(width: 6),
                                                        Text('Gambar Ada', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8))),
                                                        const SizedBox(width: 6),
                                                        InkWell(
                                                          onTap: () => setDialogState(() => q['image'] = ''),
                                                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          questionsList.add({
                                            'question': '',
                                            'a': '',
                                            'b': '',
                                            'c': '',
                                            'd': '',
                                            'correct': 'A',
                                            'image': '',
                                          });
                                        });
                                      },
                                      icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF0F172A)),
                                      label: Text('Tambah Soal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFBBF24),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── STUDENT SUBMISSIONS OVERLAY DIALOG ───
  void _showStudentSubmissionsOverlayDialog({
    required BuildContext context,
    required Map<String, dynamic> task,
    required String stageTitle,
    required Color accentColor,
  }) {
    final String title = task['title'] ?? 'Hasil Siswa';
    final List submissions = task['submissions'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 750,
            height: 600,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  color: accentColor,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18.7,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${submissions.length} Percobaan Siswa',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: submissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_late_outlined, size: 48, color: const Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              Text('Belum ada siswa yang mengerjakan quiz ini.', style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFF64748B))),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: submissions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sub = submissions[index] as Map;
                            final String studentName = sub['studentName'] ?? 'Siswa ${index + 1}';
                            final String score = sub['score']?.toString() ?? 'Belum Dinilai';
                            final String completedAt = sub['submittedAt'] ?? 'Baru saja';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: accentColor.withValues(alpha: 0.15),
                                    child: Text(
                                      studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16.4,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold, color: const Color(0xFF000000)),
                                        ),
                                        Text('Dikerjakan pada: $completedAt', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Skor: $score',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                    ),
                                  ),
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
  }

  // ─── PREVIEW OVERLAY FOR QUIZ (GURU MODES TO MENGERJAKAN QUIZ PAGE) ───
  void _showQuizPreviewModal(
    BuildContext context,
    String title,
    List questions,
    bool isOwner,
  ) {
    final Map extraData = _selectedTask?['extraData'] as Map? ?? {};
    final String durationStr = extraData['quizTimeDuration'] != null && extraData['quizTimeDuration'].toString().isNotEmpty
        ? '${extraData['quizTimeDuration']} Menit'
        : '15 Menit';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MengerjakanQuizPage(
          title: title,
          durationStr: durationStr,
          startTime: 'Sekarang',
          projectId: widget.projectId,
          studentUid: FirebaseAuth.instance.currentUser?.uid ?? 'preview_guru',
          taskKey: _selectedTask?['id'] ?? 'preview',
          isTeacher: isOwner,
          questions: questions,
          onCompleted: () {},
        ),
      ),
    );
  }

  Widget _buildPreviewOptionRow(String key, String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD97706) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1)),
              ),
              child: Text(
                key,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF334155)))),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionResultWidget(List questions, Map<int, String> userAnswers) {
    int scoreSum = 0;
    for (int i = 0; i < questions.length; i++) {
      final String correct = (questions[i] as Map)['correct'] ?? 'A';
      if (userAnswers[i] == correct) scoreSum++;
    }
    final int finalScore = ((scoreSum / questions.length) * 100).round();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text('Uji Coba Selesai!', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Anda menjawab benar $scoreSum dari ${questions.length} soal kuis.',
              style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
              child: Text(
                'Skor: $finalScore / 100',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── KOTAK SKELETON ABU PUTIH UNTUK PILIH GAMBAR SOAL ───
  Widget _buildImagePickerSkeletonBox(Map q, {VoidCallback? setModalState}) {
    final String currentImage = (q['image'] ?? q['imageUrl'] ?? '').toString();

    if (currentImage.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // White gray background skeleton card
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                currentImage,
                width: 60,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 48,
                  color: const Color(0xFFE2E8F0),
                  child: const Icon(Icons.broken_image_rounded, size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gambar Soal Terpasang',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    currentImage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
              onPressed: () {
                setState(() {
                  q['image'] = '';
                });
                if (setModalState != null) setModalState();
              },
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _showImageSourceDialog(q, setModalState: setModalState);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // White gray skeleton box
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+ Pilih / Upload Gambar Soal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  'Unggah berkas dari perangkat atau masukkan URL gambar',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(Map q, {VoidCallback? setModalState}) {
    final urlController = TextEditingController(text: (q['image'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pilih Gambar Soal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(type: FileType.image);
                  if (result != null && result.files.isNotEmpty) {
                    final file = result.files.first;
                    setState(() {
                      q['image'] = file.name;
                    });
                    if (mounted) Navigator.pop(ctx);
                    if (setModalState != null) setModalState();
                  }
                },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text('Upload Berkas Dari Komputer', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Atau Tempelkan URL Gambar:', style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://example.com/image.png',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: const Color(0xFFF8FAFC),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.dmSans(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                q['image'] = urlController.text.trim();
              });
              Navigator.pop(ctx);
              if (setModalState != null) setModalState();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Gunakan URL', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
