import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:hubner/features/projects/domain/activity_logger.dart';
import 'package:url_launcher/url_launcher.dart';

final List<Color> _classroomAccentColors = const [
  Color(0xFF009688), // 0: Teal
  Color(0xFF448AFF), // 1: Blue
  Color(0xFFE040FB), // 2: Purple/Magenta
  Color(0xFFFF4081), // 3: Pink/Rose
  Color(0xFFFFAB40), // 4: Orange/Amber
  Color(0xFF536DFE), // 5: Indigo
  Color(0xFF607D8B), // 6: Blue Grey
];

class DesktopTugasTab extends StatefulWidget {
  final String projectId;
  final String title;

  const DesktopTugasTab({
    super.key,
    required this.projectId,
    required this.title,
  });

  @override
  State<DesktopTugasTab> createState() => _DesktopTugasTabState();
}

class _DesktopTugasTabState extends State<DesktopTugasTab> {
  Map<String, dynamic>? _selectedTask;
  String? _selectedStageTitle;

  Future<void> _uploadTugasPdfToDrive(
    BuildContext context,
    TextEditingController controller,
    StateSetter setDialogState,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mengunggah berkas PDF ke Google Drive kelas...'),
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
          fileName: 'tugas_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}',
          bytes: fileBytes,
        );

        final String fileUrl = uploadResult['directLink'] ?? uploadResult['webViewLink'] ?? '';
        setDialogState(() {
          controller.text = fileUrl;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Berkas PDF berhasil diunggah ke Google Drive kelas!'),
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
            content: Text('Gagal mengunggah PDF: $e'),
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
          return const Center(child: ThreeDotsLoader());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String ownerUid = data['ownerUid'] as String? ?? '';
        final bool isOwner =
            ownerUid == (FirebaseAuth.instance.currentUser?.uid ?? '');

        final Color heroColor = const Color(0xFFE11D48); // Rose for Tugas
        final List stages = data['stages'] as List? ?? [];

        // Auto-select first task for right column preview if none selected
        if (_selectedTask == null && stages.isNotEmpty) {
          for (var stage in stages) {
            final materis = (stage as Map)['materis'] as List? ?? [];
            for (var m in materis) {
              final tasks = (m as Map)['tasks'] as List? ?? [];
              for (var t in tasks) {
                final tMap = Map<String, dynamic>.from(t as Map);
                if ((tMap['type'] ?? 'tugas') == 'tugas') {
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
          key: const PageStorageKey('TugasScroll'),
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
                          Icons.assignment_rounded,
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
                            style: AppTypography.pageTitle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelola & Evaluasi Tugas Siswa per Elemen Pembelajaran',
                            style: AppTypography.timestamp(color: Colors.white.withValues(alpha: 0.85),
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
                          'Buat Tugas Baru',
                          style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
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
                Icons.assignment_late_rounded,
                size: 44,
                color: accentColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada elemen pembelajaran di kelas ini.',
                style: AppTypography.subtitle(color: const Color(0xFF64748B),
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
          'Daftar Elemen & Tugas',
          style: AppTypography.chatHeaderTitle(color: const Color(0xFF0F172A, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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

              // Collect all tasks inside this stage
              final List<Map<String, dynamic>> stageTasks = [];
              for (var m in materis) {
                final mMap = m as Map;
                final String mTitle = mMap['title'] ?? 'Materi';
                final tasks = mMap['tasks'] as List? ?? [];
                for (var t in tasks) {
                  final tMap = Map<String, dynamic>.from(t as Map);
                  final String type = tMap['type'] ?? 'tugas';
                  if (type == 'tugas') {
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
                            style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stageTitle,
                                style: AppTypography.buttonLabel(color: const Color(0xFF0F172A, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${materis.length} Materi • ${stageTasks.length} Tugas',
                                style: AppTypography.timestamp(color: const Color(0xFF64748B),
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
                                'Belum ada tugas di elemen ini.',
                                style: AppTypography.timestamp(color: const Color(0xFF94A3B8),
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

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTask = t;
                                    _selectedStageTitle = stageTitle;
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
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accentColor.withValues(alpha: 0.08)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor.withValues(alpha: 0.4)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
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
                                            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.assignment_rounded,
                                          color: Color(0xFFE11D48),
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
                                              style: AppTypography.buttonLabel(color: isSelected, fontWeight: isSelected),
                                            ),
                                            Text(
                                              'Materi: ${t['materiTitle'] ?? '-'}',
                                              style: AppTypography.timestamp(color: const Color(0xFF64748B),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ),
                                ),
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

  // ─── RIGHT COLUMN (55%): PREVIEW PANEL ───
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
                'Pilih salah satu tugas di kolom kiri untuk melihat preview.',
                style: AppTypography.subtitle(color: const Color(0xFF64748B),
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
    final String docName = task['docName'] ?? '';
    final Map extraData = task['extraData'] as Map? ?? {};
    final List submissions = task['submissions'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.pageTitle(color: const Color(0xFF0F172A, fontWeight: FontWeight.bold, height: 1.25),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                '$_selectedStageTitle • $materiTitle',
                style: AppTypography.timestamp(color: const Color(0xFF475569),
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
                  style: AppTypography.timestamp(color: const Color(0xFF475569),
                ),
              ],
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // ─── DIRECT TASK CONTENT DISPLAY ───
          if ((extraData['tugasMode'] ?? 'text') == 'pdf') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dokumen Soal PDF',
                          style: AppTypography.buttonLabel(color: const Color(0xFF9F1239, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          docName.isNotEmpty ? docName : 'tugas_soal.pdf',
                          style: AppTypography.timestamp(color: const Color(0xFFBE123C),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (docName.isNotEmpty && docName.startsWith('http'))
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFFE11D48)),
                      onPressed: () async {
                        final uri = Uri.parse(docName);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      tooltip: 'Buka PDF di Tab Baru',
                    ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pertanyaan / Instruksi Tugas:',
                    style: AppTypography.buttonLabel(color: const Color(0xFF64748B, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    docName.isNotEmpty ? docName : 'Teks pertanyaan kosong.',
                    style: AppTypography.subtitle(color: const Color(0xFF1E293B, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

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
                      style: AppTypography.buttonLabel(color: Colors.black),
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
                    onPressed: () => _handleDeleteTask(task),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    label: Text(
                      'Hapus',
                      style: AppTypography.buttonLabel(color: const Color(0xFFEF4444),
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
                  style: AppTypography.buttonLabel(color: Colors.black),
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

  Future<void> _handleDeleteTask(Map task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Tugas', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus "${task['title']}"? Tindakan ini tidak dapat dibatalkan.', style: AppTypography.timestamp()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: AppTypography.buttonLabel(color: const Color(0xFF64748B)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: Text('Hapus', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
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
        type: 'tugas',
        actor: 'Guru Pengajar',
        action: 'menghapus tugas',
        target: task['title'] ?? '',
      );

      setState(() {
        _selectedTask = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil menghapus Tugas!'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  // ─── ADD/EDIT TASK DIALOG ───
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
    String assignmentType = isEditMode ? (extraDataEdit['assignmentType'] ?? 'individu') : 'individu';
    String tugasMode = isEditMode ? (extraDataEdit['tugasMode'] ?? 'text') : 'text';
    final taskTextController = TextEditingController(text: isEditMode && tugasMode == 'text' ? (taskToEdit['docName'] ?? '') : '');
    final taskPdfController = TextEditingController(text: isEditMode && tugasMode == 'pdf' ? (taskToEdit['docName'] ?? '') : '');

    final Color mainThemeColor = const Color(0xFFE11D48);
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
                            isEditMode ? 'Edit Tugas' : 'Unggah/Buat Tugas',
                            style: AppTypography.pageTitle(color: Colors.black, fontWeight: FontWeight.bold),
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

                                  Map<String, dynamic> extraData = {};
                                  String docName = '';

                                  if (tugasMode == 'pdf') {
                                    docName = taskPdfController.text.trim().isNotEmpty
                                        ? taskPdfController.text.trim()
                                        : 'tugas_soal.pdf';
                                    extraData = {
                                      'assignmentType': assignmentType,
                                      'tugasMode': 'pdf',
                                    };
                                  } else {
                                    extraData = {
                                      'tugasText': taskTextController.text.trim(),
                                      'assignmentType': assignmentType,
                                      'tugasMode': 'text',
                                    };
                                    docName = taskTextController.text.trim();
                                  }

                                  final newTask = {
                                    'id': isEditMode ? taskToEdit['id'] : 'task_${DateTime.now().millisecondsSinceEpoch}',
                                    'type': 'tugas',
                                    'title': title,
                                    'startDate': startStr,
                                    'endDate': endStr,
                                    'docName': docName,
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
                                      type: 'tugas',
                                      actor: 'Guru Pengajar',
                                      action: isEditMode ? 'memperbarui tugas' : 'menambahkan tugas baru',
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
                                    style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
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
                                    style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
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
                                        style: AppTypography.timestamp(color: Colors.black87),
                                        items: List.generate(stages.length, (idx) {
                                          final st = stages[idx] as Map;
                                          return DropdownMenuItem<int>(
                                            value: idx,
                                            child: Text(
                                              st['name'] ?? st['title'] ?? 'Elemen ${idx + 1}',
                                              style: AppTypography.timestamp(),
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
                                    style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
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
                                        hint: Text('Pilih Materi', style: AppTypography.timestamp()),
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45, size: 18),
                                        style: AppTypography.timestamp(color: Colors.black87),
                                        items: List.generate(materis.length, (mIdx) {
                                          final m = materis[mIdx] as Map;
                                          return DropdownMenuItem<int>(
                                            value: mIdx,
                                            child: Text(
                                              m['title'] ?? 'Materi ${mIdx + 1}',
                                              style: AppTypography.timestamp(),
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
                                    'Judul Tugas',
                                    style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: titleController,
                                    style: AppTypography.subtitle(),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan judul...',
                                      hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8),
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
                                              style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: startDateController,
                                              keyboardType: TextInputType.number,
                                              style: AppTypography.subtitle(),
                                              onChanged: (_) => _formatDateInput(startDateController),
                                              decoration: InputDecoration(
                                                hintText: 'HH/BB/TTTT',
                                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8),
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
                                              style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: endDateController,
                                              keyboardType: TextInputType.number,
                                              style: AppTypography.subtitle(),
                                              onChanged: (_) => _formatDateInput(endDateController),
                                              decoration: InputDecoration(
                                                hintText: 'HH/BB/TTTT',
                                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8),
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
                                    'Pengaturan Jenis & Mode Tugas',
                                    style: AppTypography.buttonLabel(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setDialogState(() => assignmentType = 'individu'),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: assignmentType == 'individu' ? mainThemeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: assignmentType == 'individu' ? mainThemeColor : const Color(0xFFE2E8F0)),
                                            ),
                                            child: Center(
                                              child: Text('Tugas Individu', style: AppTypography.buttonLabel(color: assignmentType == 'individu' ? mainThemeColor : const Color(0xFF475569, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setDialogState(() => assignmentType = 'kelompok'),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: assignmentType == 'kelompok' ? mainThemeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: assignmentType == 'kelompok' ? mainThemeColor : const Color(0xFFE2E8F0)),
                                            ),
                                            child: Center(
                                              child: Text('Tugas Kelompok', style: AppTypography.buttonLabel(color: assignmentType == 'kelompok' ? mainThemeColor : const Color(0xFF475569, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  Row(
                                    children: [
                                      Text(
                                        'Mode Pengumpulan Tugas: ',
                                        style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 14),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'text',
                                            groupValue: tugasMode,
                                            activeColor: mainThemeColor,
                                            onChanged: (v) {
                                              if (v != null) setDialogState(() => tugasMode = v);
                                            },
                                          ),
                                          Text('Jawaban Teks', style: AppTypography.timestamp()),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'pdf',
                                            groupValue: tugasMode,
                                            activeColor: mainThemeColor,
                                            onChanged: (v) {
                                              if (v != null) setDialogState(() => tugasMode = v);
                                            },
                                          ),
                                          Text('File PDF', style: AppTypography.timestamp()),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  if (tugasMode == 'text') ...[
                                    Text(
                                      'Teks Soal / Pertanyaan Tugas',
                                      style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: taskTextController,
                                      maxLines: 10,
                                      style: AppTypography.timestamp(),
                                      decoration: InputDecoration(
                                        hintText: 'Tulis pertanyaan / instruksi tugas di sini...',
                                        hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8),
                                        contentPadding: const EdgeInsets.all(14),
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
                                  ] else ...[
                                    Text(
                                      'Link / Berkas Soal PDF',
                                      style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: taskPdfController,
                                            style: AppTypography.timestamp(),
                                            decoration: InputDecoration(
                                              hintText: 'Masukkan link/nama file PDF tugas...',
                                              hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8),
                                              prefixIcon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFFE11D48)),
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
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () => _uploadTugasPdfToDrive(context, taskPdfController, setDialogState),
                                          icon: const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white),
                                          label: Text('Upload PDF', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE11D48),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            elevation: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                              style: AppTypography.chatHeaderTitle(color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${submissions.length} Pengumpulan Siswa',
                              style: AppTypography.timestamp(color: Colors.white.withValues(alpha: 0.85),
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
                              Text('Belum ada siswa yang mengumpulkan tugas ini.', style: AppTypography.subtitle(color: const Color(0xFF64748B)),
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
                            final String answerText = sub['answerText'] ?? 'Siswa telah mengumpulkan jawaban.';
                            final String? fileUrl = sub['fileUrl'] as String?;
                            final String submittedAt = sub['submittedAt'] ?? 'Baru saja';
                            final String score = sub['score']?.toString() ?? 'Belum Dinilai';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: accentColor.withValues(alpha: 0.15),
                                    child: Text(
                                      studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                      style: AppTypography.cardTitle(color: accentColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              studentName,
                                              style: AppTypography.cardTitle(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF059669).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Nilai: $score',
                                                style: AppTypography.buttonLabel(color: const Color(0xFF059669, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text('Dikumpulkan: $submittedAt', style: AppTypography.timestamp(color: const Color(0xFF64748B)),
                                        const SizedBox(height: 8),

                                        if (fileUrl != null && fileUrl.isNotEmpty) ...[
                                          InkWell(
                                            onTap: () async {
                                              final uri = Uri.parse(fileUrl);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0284C7), size: 16),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Buka File Lampiran Tugas',
                                                    style: AppTypography.buttonLabel(color: const Color(0xFF0284C7, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          Text(answerText, style: AppTypography.timestamp(color: const Color(0xFF334155)),
                                        ],
                                      ],
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

  // ─── PREVIEW OVERLAY MODAL FOR TASK ───
  void _showTaskPreviewModal(
    BuildContext context,
    String title,
    Map task,
  ) {
    final Map extraData = task['extraData'] as Map? ?? {};
    final String mode = extraData['tugasMode'] ?? 'text';
    final String content = mode == 'pdf' ? (task['docName'] ?? '') : (extraData['tugasText'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 700,
            height: 520,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  color: const Color(0xFFE11D48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Preview Tugas: $title',
                        style: AppTypography.chatHeaderTitle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pertanyaan / Instruksi Tugas:',
                          style: AppTypography.buttonLabel(color: const Color(0xFF475569, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        if (mode == 'pdf') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    content.isNotEmpty ? content : 'berkas_soal.pdf',
                                    style: AppTypography.timestamp(color: const Color(0xFF9F1239, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              content.isNotEmpty ? content : 'Teks pertanyaan kosong.',
                              style: AppTypography.subtitle(color: const Color(0xFF334155, height: 1.5),
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
}
