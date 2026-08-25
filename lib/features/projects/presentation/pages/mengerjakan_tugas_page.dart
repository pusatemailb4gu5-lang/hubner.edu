import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
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
    required this.assignmentType,
    required this.studentsMasterList,
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
        builder: (_) => const Center(child: ThreeDotsLoader()),
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
            backgroundColor: Color(0xFF10B981),
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

      // Also write/update studentProgress for all group members so it works with LaporanPage
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
            backgroundColor: Color(0xFF10B981),
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
    final bool isKelompok = widget.assignmentType == 'kelompok';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
          ),
        ),
        title: Text(
          'Mengerjakan Tugas',
          style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Task Information Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isKelompok ? Icons.group_outlined : Icons.assignment_outlined,
                                size: 14,
                                color: const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isKelompok ? 'Tugas Kelompok' : 'Tugas Mandiri',
                                style: AppTypography.buttonLabel(color: const Color(0xFF2563EB, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_hasSubmitted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Sudah Terkumpul',
                              style: AppTypography.buttonLabel(color: const Color(0xFF059669, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    if (widget.taskText != null && widget.taskText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.taskText!,
                        style: AppTypography.timestamp(color: Colors.black54, height: 1.5),
                      ),
                    ],
                    if (widget.docName != null && widget.docName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                widget.docName!.startsWith('http')
                                    ? '📄 Buka Lampiran Berkas (Google Drive)'
                                    : widget.docName!,
                                style: AppTypography.buttonLabel(color: const Color(0xFF1E40AF, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Group Members Card if Kelompok
              if (isKelompok) ...[
                Text(
                  'Anggota Kelompok',
                  style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih anggota kelompok yang mengerjakan tugas ini:',
                        style: AppTypography.timestamp(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.studentsMasterList.map((s) {
                          final name = (s['name'] ?? 'Siswa').toString();
                          final isSelected = _selectedMembers.contains(name);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(name),
                            labelStyle: AppTypography.buttonLabel(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedMembers.add(name);
                                } else {
                                  _selectedMembers.remove(name);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Answer Input Card
              Text(
                'Jawaban & Catatan Siswa',
                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 5,
                  style: AppTypography.subtitle(),
                  decoration: InputDecoration(
                    hintText: 'Tulis uraian jawaban atau rangkuman tugas di sini...',
                    hintStyle: AppTypography.timestamp(color: Colors.black38),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // File Link & PDF Upload Card
              Text(
                'Upload Berkas PDF / Link Berkas Tugas',
                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _uploadFileDirectly,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Colors.white),
                        label: Text(
                          '📄 Unggah Berkas PDF / Dokumen',
                          style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626), // Red for PDF
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Atau tempelkan tautan berkas (Google Drive / GitHub / URL):',
                      style: AppTypography.timestamp(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _linkController,
                        style: AppTypography.subtitle(),
                        decoration: InputDecoration(
                          icon: const Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 18),
                          hintText: 'https://drive.google.com/...',
                          hintStyle: AppTypography.timestamp(color: Colors.black38),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),

                    if (_linkController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Berkas Terlampir:',
                                    style: AppTypography.buttonLabel(color: const Color(0xFF1E40AF, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _linkController.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.timestamp(color: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                              onPressed: () async {
                                final uri = Uri.tryParse(_linkController.text);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTugas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: const ThreeDotsLoader(),
                        )
                      : Text(
                          _hasSubmitted ? 'Perbarui Pengiriman' : 'Kirim Tugas',
                          style: AppTypography.cardTitle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
