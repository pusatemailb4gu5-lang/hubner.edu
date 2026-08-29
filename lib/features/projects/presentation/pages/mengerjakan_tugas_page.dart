import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MengerjakanTugasPage extends StatefulWidget {
  final String title;
  final String projectId;
  final String studentUid;
  final String taskKey;
  final VoidCallback onCompleted;
  final String assignmentType;
  final List studentsMasterList;
  final String? taskText;
  final String? docName;

  const MengerjakanTugasPage({
    super.key,
    required this.title,
    required this.projectId,
    required this.studentUid,
    required this.taskKey,
    required this.onCompleted,
    this.assignmentType = 'mandiri',
    this.studentsMasterList = const [],
    this.taskText,
    this.docName,
  });

  @override
  State<MengerjakanTugasPage> createState() => _MengerjakanTugasPageState();
}

class _MengerjakanTugasPageState extends State<MengerjakanTugasPage> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final List<String> _selectedMembers = [];
  bool _isSubmitting = false;
  String? _existingSubmissionText;
  String? _existingLink;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingSubmission();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingSubmission() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('studentSubmissions')
          .doc('${widget.studentUid}_${widget.taskKey}')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _existingSubmissionText = data['notes'] as String? ?? '';
          _existingLink = data['fileUrl'] as String? ?? '';
          _noteController.text = _existingSubmissionText ?? '';
          _linkController.text = _existingLink ?? '';
          _hasSubmitted = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _uploadFileDirectly() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final driveFolderId = doc.data()?['driveFolderId'] as String?;
      final driveFolderUrl = doc.data()?['driveFolderUrl'] as String? ?? (driveFolderId != null ? 'https://drive.google.com/drive/folders/$driveFolderId' : '');
      final driveAccessToken = doc.data()?['driveAccessToken'] as String?;

      if (driveFolderId == null || driveFolderId.isEmpty || driveAccessToken == null || driveAccessToken.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          if (driveFolderUrl.isNotEmpty) {
            _showDriveUploadErrorDialog(context, driveFolderUrl);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal: Google Drive Guru belum tersinkronisasi. Pastikan Guru telah masuk kelas untuk mengaktifkan Google Drive.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
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
        setState(() {
          _linkController.text = uploadResult['directLink']!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berkas berhasil diunggah ke Google Drive Guru!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
        final driveFolderId = doc.data()?['driveFolderId'] as String?;
        final driveFolderUrl = doc.data()?['driveFolderUrl'] as String? ?? (driveFolderId != null ? 'https://drive.google.com/drive/folders/$driveFolderId' : '');
        if (driveFolderUrl.isNotEmpty) {
          _showDriveUploadErrorDialog(context, driveFolderUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengunggah berkas: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showDriveUploadErrorDialog(BuildContext context, String folderUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Gagal Mengunggah Otomatis',
          style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koneksi Google Drive Guru kedaluwarsa atau belum disinkronisasi.',
              style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Anda dapat mengunggah berkas secara manual ke folder kelas (Akses Bebas) berikut, lalu menempelkan tautan berkas Anda di kolom input.',
              style: AppTypography.timestamp(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: AppTypography.timestamp(color: Colors.black54)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(folderUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text('Buka Folder Google Drive', style: AppTypography.buttonLabel(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTugas() async {
    final notes = _noteController.text.trim();
    final link = _linkController.text.trim();

    if (notes.isEmpty && link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi jawaban berupa catatan/teks atau sertakan tautan berkas.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String userDisplayName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Siswa';

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('studentSubmissions')
          .doc('${widget.studentUid}_${widget.taskKey}')
          .set({
        'studentUid': widget.studentUid,
        'studentName': userDisplayName,
        'taskKey': widget.taskKey,
        'taskTitle': widget.title,
        'notes': notes,
        'fileUrl': link,
        'assignmentType': widget.assignmentType,
        'groupMembers': _selectedMembers,
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final List<String> allGroupUids = [widget.studentUid];
      if (widget.assignmentType == 'kelompok' && _selectedMembers.isNotEmpty) {
        for (var memberName in _selectedMembers) {
          final match = widget.studentsMasterList.firstWhere(
            (s) => s['name']?.toString() == memberName,
            orElse: () => null,
          );
          if (match != null && match['uid'] != null) {
            allGroupUids.add(match['uid'].toString());
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var uid in allGroupUids) {
        final docRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('studentProgress')
            .doc(uid);

        batch.set(docRef, {
          'uid': uid,
          'completedTasks': FieldValue.arrayUnion([widget.taskKey]),
          'textAnswer_${widget.taskKey}': notes,
          'fileAnswer_${widget.taskKey}': link,
          'submittedAt_${widget.taskKey}': FieldValue.serverTimestamp(),
          if (widget.assignmentType == 'kelompok')
            'groupMembers_${widget.taskKey}': allGroupUids,
        }, SetOptions(merge: true));
      }
      await batch.commit();

      widget.onCompleted();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil dikirim!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim tugas: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final bool isKelompok = widget.assignmentType == 'kelompok';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top AppBar with 52x52px Circular Buttons (Matching Login Google Button standard)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTypography.screenHorizontalMargin,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button (<) - 52x52px
                      BouncyButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                        ),
                      ),
                      Text(
                        'Mengerjakan Tugas',
                        style: AppTypography.chatHeaderTitle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      // Submit Action Button (✓) - 52x52px
                      _isSubmitting
                          ? const SizedBox(
                              width: 52,
                              height: 52,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                ),
                              ),
                            )
                          : BouncyButton(
                              onTap: _submitTugas,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _hasSubmitted
                                      ? const Color(0xFF16A34A)
                                      : (isDark ? const Color(0xFF18181B) : Colors.black),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _hasSubmitted
                                        ? const Color(0xFF16A34A)
                                        : (isDark ? const Color(0xFF27272A) : Colors.black),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                Divider(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                  height: 1,
                ),

                // Main Scrollable Body (Typography matching NoteEditorPage)
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppTypography.pagePadding(top: 20.0, bottom: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag Badge & Status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFD97706).withValues(alpha: 0.25)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isKelompok ? Icons.group_outlined : Icons.assignment_outlined,
                                    size: 14,
                                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isKelompok ? 'Tugas Kelompok' : 'Tugas Mandiri',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (_hasSubmitted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Sudah Terkumpul ✓',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Assignment Title (Matching NoteEditorPage sizePageTitle: 28px bold)
                        Text(
                          widget.title,
                          style: AppTypography.pageTitle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (widget.taskText != null && widget.taskText!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.taskText!,
                            style: AppTypography.chatBody(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              height: 1.6,
                            ),
                          ),
                        ],
                        if (widget.docName != null && widget.docName!.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.tryParse(widget.docName!);
                              if (uri != null && (widget.docName!.startsWith('http://') || widget.docName!.startsWith('https://'))) {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.inAppWebView);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Tidak dapat membuka tautan berkas.')),
                                    );
                                  }
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 16,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      widget.docName!.startsWith('http')
                                          ? 'Buka Lampiran Berkas Tugas'
                                          : widget.docName!,
                                      style: AppTypography.buttonLabel(
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Section 1: Catatan / Teks Jawaban Siswa
                        Text(
                          'Catatan Jawaban Siswa',
                          style: AppTypography.cardTitle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _noteController,
                            maxLines: 6,
                            cursorColor: isDark ? Colors.white : Colors.black,
                            style: AppTypography.chatBody(
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tulis ringkasan hasil kerja, jawaban pertanyaan, atau catatan tugas Anda di sini...',
                              hintStyle: AppTypography.chatBody(
                                color: isDark ? Colors.white30 : Colors.black26,
                                height: 1.5,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Unggah Berkas Jawaban ke Google Drive
                        Text(
                          'Lampiran Berkas Hasil Tugas',
                          style: AppTypography.cardTitle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _uploadFileDirectly,
                                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                                  label: Text(
                                    'Pilih Berkas & Unggah ke Drive',
                                    style: AppTypography.buttonLabel(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _linkController,
                                cursorColor: isDark ? Colors.white : Colors.black,
                                style: AppTypography.messageInput(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Tautan Berkas Drive / Dokumen',
                                  labelStyle: AppTypography.timestamp(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                  hintText: 'https://drive.google.com/...',
                                  hintStyle: AppTypography.timestamp(
                                    color: isDark ? Colors.white30 : Colors.black26,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.link_rounded,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF101012) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDark ? Colors.white : Colors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Bottom Submit Button (Height 52px, Radius 32)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitTugas,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF18181B) : Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF27272A) : Colors.black,
                                  width: 1.2,
                                ),
                              ),
                            ),
                            child: Text(
                              _hasSubmitted ? 'Perbarui Jawaban Tugas' : 'Kirim Jawaban Tugas',
                              style: AppTypography.buttonLabel(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
