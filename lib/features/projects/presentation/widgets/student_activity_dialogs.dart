import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------
// 1. PDF / MATERI PREVIEW DIALOG
// ---------------------------------------------------------
void showMateriPreviewDialog({
  required BuildContext context,
  required String title,
  required String docName,
  required VoidCallback onCompleted,
  bool isTeacher = false,
  VoidCallback? onEdit,
}) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Preview Modul PDF',
                    style: AppTypography.chatHeaderTitle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isTeacher && onEdit != null) ...[
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mock PDF Document Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          docName.isNotEmpty ? docName : 'modul_pembelajaran.pdf',
                          style: AppTypography.timestamp(color: Colors.black45),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Simulated Page View Preview
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_rounded, color: Colors.black26, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Preview Halaman 1 dari 12',
                    style: AppTypography.buttonLabel(color: Colors.black45, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                onCompleted();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File "$title" berhasil diunduh!'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                'Unduh File',
                style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------
// 2. TUGAS SUBMISSION DIALOG
// ---------------------------------------------------------
void showTugasSubmissionDialog({
  required BuildContext context,
  required String title,
  required String projectId,
  required String studentUid,
  required String taskKey,
  required VoidCallback onCompleted,
  bool isTeacher = false,
  VoidCallback? onEdit,
  String assignmentType = 'individu',
  List studentsMasterList = const [],
}) {
  showDialog(
    context: context,
    builder: (ctx) {
      return TugasSubmissionDialogContent(
        title: title,
        projectId: projectId,
        studentUid: studentUid,
        taskKey: taskKey,
        onCompleted: onCompleted,
        isTeacher: isTeacher,
        onEdit: onEdit,
        assignmentType: assignmentType,
        studentsMasterList: studentsMasterList,
      );
    },
  );
}

class TugasSubmissionDialogContent extends StatefulWidget {
  final String title;
  final String projectId;
  final String studentUid;
  final String taskKey;
  final VoidCallback onCompleted;
  final bool isTeacher;
  final VoidCallback? onEdit;
  final String assignmentType;
  final List studentsMasterList;

  const TugasSubmissionDialogContent({
    super.key,
    required this.title,
    required this.projectId,
    required this.studentUid,
    required this.taskKey,
    required this.onCompleted,
    this.isTeacher = false,
    this.onEdit,
    this.assignmentType = 'individu',
    this.studentsMasterList = const [],
  });

  @override
  State<TugasSubmissionDialogContent> createState() => _TugasSubmissionDialogContentState();
}

class _TugasSubmissionDialogContentState extends State<TugasSubmissionDialogContent> {
  final _answerController = TextEditingController();
  String _uploadedFileName = '';
  final List<Map<String, dynamic>> _selectedMembers = []; // List of selected members {uid, name}
  List<String> _completedUids = []; // List of student uids who already submitted
  bool _loadingProgress = true;

  @override
  void initState() {
    super.initState();
    if (widget.assignmentType == 'kelompok' && !widget.isTeacher) {
      _loadCompletedStudents();
    } else {
      _loadingProgress = false;
    }
  }

  Future<void> _loadCompletedStudents() async {
    try {
      final progressSnap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('studentProgress')
          .get();

      final List<String> completed = [];
      for (var doc in progressSnap.docs) {
        final completedTasks = doc.data()['completedTasks'] as List? ?? [];
        if (completedTasks.contains(widget.taskKey)) {
          completed.add(doc.id);
        }
      }
      setState(() {
        _completedUids = completed;
        _loadingProgress = false;
      });
    } catch (_) {
      setState(() {
        _loadingProgress = false;
      });
    }
  }

  void _showAddMemberDialog() {
    final List masterList = widget.studentsMasterList;
    final List joinedStudents = masterList.where((item) {
      if (item is! Map) return false;
      final String uid = item['uid'] ?? '';
      final bool joined = item['joined'] ?? false;
      return joined && uid.isNotEmpty && uid != widget.studentUid;
    }).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Tambah Anggota Kelompok',
            style: AppTypography.cardTitle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: joinedStudents.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Tidak ada siswa lain yang bergabung di kelas ini.',
                      style: AppTypography.timestamp(color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: joinedStudents.length,
                    itemBuilder: (context, idx) {
                      final student = joinedStudents[idx];
                      final String sUid = student['uid'] ?? '';
                      final String sName = student['name'] ?? '';
                      
                      final bool isAlreadySelected = _selectedMembers.any((m) => m['uid'] == sUid);
                      final bool isAlreadySubmitted = _completedUids.contains(sUid);
                      
                      final bool canSelect = !isAlreadySelected && !isAlreadySubmitted;
                      
                      return ListTile(
                        dense: true,
                        title: Text(
                          sName,
                          style: AppTypography.buttonLabel(color: canSelect ? Colors.black87 : Colors.black38, fontWeight: FontWeight.w600),
                        ),
                        trailing: isAlreadySubmitted
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Sudah mengerjakan',
                                  style: AppTypography.buttonLabel(color: Colors.red[700], fontWeight: FontWeight.bold),
                                ),
                              )
                            : isAlreadySelected
                                ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18)
                                : const Icon(Icons.add_circle_outline_rounded, color: Colors.black38, size: 18),
                        onTap: canSelect
                            ? () {
                                setState(() {
                                  _selectedMembers.add({'uid': sUid, 'name': sName});
                                });
                                Navigator.pop(dialogCtx);
                              }
                            : null,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Batal',
                style: AppTypography.buttonLabel(color: Colors.black54, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _simulateUpload() {
    setState(() {
      _uploadedFileName = 'tugas_${widget.title.toLowerCase().replaceAll(' ', '_')}_final.pdf';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.isTeacher ? 'Detail Tugas' : 'Kerjakan Tugas',
                    style: AppTypography.chatHeaderTitle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.isTeacher && widget.onEdit != null) ...[
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onEdit!();
                    },
                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: AppTypography.timestamp(color: Colors.black54),
            ),
            const SizedBox(height: 16),

            if (widget.isTeacher) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Mode Preview Guru',
                          style: AppTypography.buttonLabel(color: Colors.blue[900], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.assignmentType == 'kelompok'
                          ? 'Tugas ini merupakan tugas kelompok. Siswa dapat membentuk kelompok saat mengirimkan tugas.'
                          : 'Siswa dapat mengerjakan tugas ini dengan mengisi lembar jawaban langsung (teks) atau mengunggah berkas tugas format PDF.',
                      style: AppTypography.timestamp(color: Colors.blue[800], height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Tutup',
                  style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              if (widget.assignmentType == 'kelompok') ...[
                if (_loadingProgress)
                  const SizedBox.shrink()
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '👥 Anggota Kelompok',
                        style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: _showAddMemberDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent, width: 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text(
                                'Tambah Teman',
                                style: AppTypography.buttonLabel(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text('Saya', style: AppTypography.buttonLabel(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.blue[50],
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: Colors.blue[100]!),
                      ),
                      ..._selectedMembers.map((m) {
                        return Chip(
                          label: Text(m['name'] ?? '', style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onDeleted: () {
                            setState(() {
                              _selectedMembers.remove(m);
                            });
                          },
                          deleteIcon: const Icon(Icons.close_rounded, size: 12),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Option A: Jawab Langsung (Text field)
              Text(
                'Jawab Langsung (Text)',
                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _answerController,
                  maxLines: 4,
                  style: AppTypography.timestamp(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Tuliskan jawaban Anda di sini...',
                    hintStyle: AppTypography.timestamp(color: Colors.black38),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Option B: Upload File
              Text(
                'Unggah Berkas (Upload File)',
                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _uploadedFileName.isEmpty
                  ? GestureDetector(
                      onTap: _simulateUpload,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE), style: BorderStyle.solid),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Colors.blueAccent, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              'Pilih file untuk diunggah',
                              style: AppTypography.buttonLabel(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _uploadedFileName,
                              style: AppTypography.buttonLabel(color: Colors.green[800], fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _uploadedFileName = '';
                              });
                            },
                            icon: const Icon(Icons.cancel_rounded, color: Colors.black38, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final textAnswer = _answerController.text.trim();
                  if (textAnswer.isEmpty && _uploadedFileName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tolong isi jawaban text atau upload berkas terlebih dahulu.')),
                    );
                    return;
                  }

                  try {
                    final List<String> allGroupUids = [
                      widget.studentUid,
                      ..._selectedMembers.map((m) => m['uid'] as String)
                    ];

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
                        'textAnswer_${widget.taskKey}': textAnswer,
                        'fileAnswer_${widget.taskKey}': _uploadedFileName,
                        'submittedAt_${widget.taskKey}': FieldValue.serverTimestamp(),
                        if (widget.assignmentType == 'kelompok')
                          'groupMembers_${widget.taskKey}': allGroupUids,
                      }, SetOptions(merge: true));
                    }

                    await batch.commit();

                    widget.onCompleted();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tugas berhasil dikirim!'),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal mengirim tugas: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text(
                  'Kirim Tugas',
                  style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. QUIZ EXECUTION DIALOG (ANTI-CHEAT + TIMERS)
// ---------------------------------------------------------
void showQuizExecutionDialog({
  required BuildContext context,
  required String title,
  required String durationStr,
  required String startTime,
  required String projectId,
  required String studentUid,
  required String taskKey,
  required VoidCallback onCompleted,
  bool isTeacher = false,
  VoidCallback? onEdit,
  List<dynamic>? questions,
}) {
  showDialog(
    context: context,
    barrierDismissible: isTeacher, // Allow clicking outside to dismiss for teacher
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: QuizViewDialogContent(
              title: title,
              durationStr: durationStr,
              startTime: startTime,
              projectId: projectId,
              studentUid: studentUid,
              taskKey: taskKey,
              onComplete: onCompleted,
              isTeacher: isTeacher,
              onEdit: onEdit,
              questions: questions,
            ),
          ),
        ),
      );
    },
  );
}

class QuizViewDialogContent extends StatefulWidget {
  final String title;
  final String durationStr;
  final String startTime;
  final String projectId;
  final String studentUid;
  final String taskKey;
  final VoidCallback onComplete;
  final bool isTeacher;
  final VoidCallback? onEdit;
  final List<dynamic>? questions;

  const QuizViewDialogContent({
    super.key,
    required this.title,
    required this.durationStr,
    required this.startTime,
    required this.projectId,
    required this.studentUid,
    required this.taskKey,
    required this.onComplete,
    this.isTeacher = false,
    this.onEdit,
    this.questions,
  });

  @override
  State<QuizViewDialogContent> createState() => _QuizViewDialogContentState();
}

class _QuizViewDialogContentState extends State<QuizViewDialogContent> with WidgetsBindingObserver {
  bool _quizStarted = false;
  bool _isLocked = false;
  int _secondsLeft = 0;
  Timer? _countdownTimer;
  bool _isLoading = true;

  int _currentQuestionIdx = 0;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initQuestions();
    _checkLockStatus();
  }

  void _initQuestions() {
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      _questions = widget.questions!.map((qRaw) {
        final q = Map<String, dynamic>.from(qRaw as Map);
        final String questionText = (q['question'] ?? q['title'] ?? '').toString();

        List<String> options = [];
        if (q['options'] != null && q['options'] is List && (q['options'] as List).isNotEmpty) {
          options = List<String>.from((q['options'] as List).map((e) => e.toString()));
        } else {
          final a = (q['a'] ?? '').toString();
          final b = (q['b'] ?? '').toString();
          final c = (q['c'] ?? '').toString();
          final d = (q['d'] ?? '').toString();
          options = [a, b, c, d];
        }

        int correctIndex = 0;
        final rawCorrect = q['correct'];
        if (rawCorrect is int) {
          correctIndex = rawCorrect;
        } else if (rawCorrect != null) {
          final cStr = rawCorrect.toString().trim().toUpperCase();
          if (cStr == 'A') {
            correctIndex = 0;
          } else if (cStr == 'B') {
            correctIndex = 1;
          } else if (cStr == 'C') {
            correctIndex = 2;
          } else if (cStr == 'D') {
            correctIndex = 3;
          } else {
            correctIndex = int.tryParse(cStr) ?? 0;
          }
        }

        return {
          'question': questionText.isEmpty ? 'Pertanyaan Kuis' : questionText,
          'options': options,
          'correctIndex': correctIndex,
          'selected': -1,
        };
      }).toList();
    } else {
      // Default questions if no questions list is attached
      _questions = [
        {
          'question': 'Berikut ini yang merupakan perangkat keras input adalah...',
          'options': ['Keyboard', 'Monitor', 'Printer', 'Speaker'],
          'correctIndex': 0,
          'selected': -1,
        },
        {
          'question': 'Protokol transfer data standar di web browser adalah...',
          'options': ['FTP', 'HTTP', 'SMTP', 'POP3'],
          'correctIndex': 1,
          'selected': -1,
        },
        {
          'question': 'Bagian dari sistem komputer yang berfungsi memproses instruksi adalah...',
          'options': ['CPU', 'RAM', 'Harddisk', 'VGA'],
          'correctIndex': 0,
          'selected': -1,
        },
      ];
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('studentProgress')
          .doc(widget.studentUid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final locked = data['quizLocked_${widget.taskKey}'] == true;
        setState(() {
          _isLocked = locked;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _lockQuiz() async {
    setState(() {
      _isLocked = true;
      _quizStarted = false;
    });
    _countdownTimer?.cancel();
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('studentProgress')
          .doc(widget.studentUid)
          .set({
        'quizLocked_${widget.taskKey}': true,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_quizStarted && (state == AppLifecycleState.paused || state == AppLifecycleState.inactive)) {
      // Cheat detected! Lock quiz immediately!
      _lockQuiz();
    }
  }

  void _startQuiz() {
    final int minutes = int.tryParse(widget.durationStr) ?? 15;
    setState(() {
      _quizStarted = true;
      _secondsLeft = minutes * 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _submitQuiz();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  Future<void> _submitQuiz() async {
    _countdownTimer?.cancel();
    
    int correctCount = 0;
    for (var q in _questions) {
      final int sel = q['selected'] as int? ?? -1;
      final int correctIdx = q['correctIndex'] as int? ?? 0;
      if (sel != -1 && sel == correctIdx) {
        correctCount++;
      }
    }

    int score = _questions.isNotEmpty
        ? ((correctCount / _questions.length) * 100).round()
        : 100;

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('studentProgress')
          .doc(widget.studentUid)
          .set({
        'quizScore_${widget.taskKey}': score,
      }, SetOptions(merge: true));
      
      widget.onComplete();
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz selesai! Nilai Anda: $score ($correctCount/${_questions.length} Benar)'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  String _formatTime(int totalSeconds) {
    final int min = totalSeconds ~/ 60;
    final int sec = totalSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: SizedBox.shrink(),
      );
    }

    // 1. LOCKED VIEW
    if (_isLocked) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              'Quiz Terkunci!',
              style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Anda terdeteksi menutup atau keluar dari aplikasi saat kuis berlangsung.\n\nHarap hubungi Guru Anda untuk membuka akses kuis kembali.',
              style: AppTypography.timestamp(color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Tutup Layar',
                  style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. ACTIVE QUIZ RUNNING VIEW
    if (_quizStarted) {
      final q = _questions[_currentQuestionIdx];
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timer & Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_secondsLeft),
                        style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Soal ${_currentQuestionIdx + 1}/${_questions.length}',
                  style: AppTypography.buttonLabel(color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _questions.isNotEmpty ? (_currentQuestionIdx + 1) / _questions.length : 0.0,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 4,
            ),
            const SizedBox(height: 20),

            // Warning Text
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perhatian: Menutup aplikasi akan mengunci kuis Anda!',
                      style: AppTypography.buttonLabel(color: Colors.orange[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Question text
            Text(
              q['question'],
              style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Answer options
            ...List.generate(q['options'].length, (optIdx) {
              final isSel = q['selected'] == optIdx;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSel ? Colors.orange[50] : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSel ? Colors.orange : const Color(0xFFE2E8F0)),
                ),
                child: RadioListTile<int>(
                  value: optIdx,
                  groupValue: q['selected'],
                  dense: true,
                  activeColor: Colors.orange,
                  title: Text(
                    q['options'][optIdx],
                    style: AppTypography.timestamp(color: Colors.black87),
                  ),
                  onChanged: (val) {
                    setState(() {
                      q['selected'] = val;
                    });
                  },
                ),
              );
            }),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _currentQuestionIdx > 0
                    ? OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentQuestionIdx--;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black26),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Kembali', style: AppTypography.timestamp(color: Colors.black87)),
                      )
                    : const SizedBox(),
                
                _currentQuestionIdx < _questions.length - 1
                    ? ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentQuestionIdx++;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Lanjut', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
                      )
                    : ElevatedButton(
                        onPressed: _submitQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Kirim Kuis', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. PREVIEW & RULES SCREEN
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Preview Quiz',
                  style: AppTypography.chatHeaderTitle(fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.isTeacher && widget.onEdit != null) ...[
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEdit!();
                  },
                  icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: AppTypography.cardTitle(color: Colors.orange[800], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Start Time & Duration settings info
          _buildInfoRow(Icons.calendar_today_rounded, 'Mulai Pengerjaan', widget.startTime.isNotEmpty ? widget.startTime : 'Bebas / Kapan saja'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.timer_outlined, 'Durasi Pengerjaan', '${widget.durationStr} Menit'),
          const SizedBox(height: 20),

          // Anti-Cheat warning card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Anti-Curang Offline Mode',
                      style: AppTypography.buttonLabel(color: Colors.red[900], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ketika quiz dimulai, sistem akan memantau aktivitas Anda. Jika Anda menutup aplikasi, keluar dari layar kuis, atau membuka aplikasi lain, kuis akan otomatis terkunci.\n\nAnda tidak akan bisa membukanya kembali kecuali Guru membuka kunci akses.',
                  style: AppTypography.timestamp(color: Colors.red[800], height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          widget.isTeacher
              ? OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Tutup',
                    style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                )
              : ElevatedButton(
                  onPressed: _startQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    'Mulai Quiz',
                    style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54, size: 16),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: AppTypography.buttonLabel(color: Colors.black54),
        ),
        Text(
          value,
          style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
