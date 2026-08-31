import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/services/app_sound_service.dart';
import 'mengerjakan_quiz_page.dart';

class DetailCpPage extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final int stageIdx;
  final bool isOwner;
  final Color accentColor;
  final Color cardColor;

  const DetailCpPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.stageIdx,
    required this.isOwner,
    required this.accentColor,
    required this.cardColor,
  });

  static void openCreateTaskPage(
    BuildContext context, {
    required String projectId,
    required String projectTitle,
    required int stageIdx,
    required bool isOwner,
    required Color accentColor,
    required Color cardColor,
    required List stages,
    int initialMateriIdx = 0,
    bool openFromClassPage = true,
  }) {
    openTaskPage(
      context,
      stages,
      initialMateriIdx: initialMateriIdx,
      openFromClassPage: openFromClassPage,
      customProjectId: projectId,
      customProjectTitle: projectTitle,
      customStageIdx: stageIdx,
      customIsOwner: isOwner,
      customAccentColor: accentColor,
      customCardColor: cardColor,
    );
  }

  static void openTaskPage(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
    bool openFromClassPage = false,
    String? customProjectId,
    String? customProjectTitle,
    int? customStageIdx,
    bool? customIsOwner,
    Color? customAccentColor,
    Color? customCardColor,
  }) {
    _DetailCpPageState.openTaskPage(
      context,
      stages,
      initialMateriIdx: initialMateriIdx,
      taskToEdit: taskToEdit,
      taskIdxToEdit: taskIdxToEdit,
      openFromClassPage: openFromClassPage,
      customProjectId: customProjectId,
      customProjectTitle: customProjectTitle,
      customStageIdx: customStageIdx,
      customIsOwner: customIsOwner,
      customAccentColor: customAccentColor,
      customCardColor: customCardColor,
    );
  }

  static void openCreateQuizPage(
    BuildContext context, {
    required String projectId,
    required String projectTitle,
    required int stageIdx,
    required bool isOwner,
    required Color accentColor,
    required Color cardColor,
    required List stages,
    int initialMateriIdx = 0,
    bool openFromClassPage = true,
  }) {
    openQuizPage(
      context,
      stages,
      initialMateriIdx: initialMateriIdx,
      openFromClassPage: openFromClassPage,
      customProjectId: projectId,
      customProjectTitle: projectTitle,
      customStageIdx: stageIdx,
      customIsOwner: isOwner,
      customAccentColor: accentColor,
      customCardColor: cardColor,
    );
  }

  static void openQuizPage(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
    bool openFromClassPage = false,
    String? customProjectId,
    String? customProjectTitle,
    int? customStageIdx,
    bool? customIsOwner,
    Color? customAccentColor,
    Color? customCardColor,
  }) {
    _DetailCpPageState.openQuizPage(
      context,
      stages,
      initialMateriIdx: initialMateriIdx,
      taskToEdit: taskToEdit,
      taskIdxToEdit: taskIdxToEdit,
      openFromClassPage: openFromClassPage,
      customProjectId: customProjectId,
      customProjectTitle: customProjectTitle,
      customStageIdx: customStageIdx,
      customIsOwner: customIsOwner,
      customAccentColor: customAccentColor,
      customCardColor: customCardColor,
    );
  }

  static void openCreateMateriPage(
    BuildContext context, {
    required String projectId,
    required String projectTitle,
    required int stageIdx,
    required bool isOwner,
    required Color accentColor,
    required Color cardColor,
    required List stages,
    int initialMateriIdx = 0,
    bool openFromClassPage = true,
  }) {
    openMateriItemPage(
      context,
      stages,
      initialMateriIdx: initialMateriIdx,
      openFromClassPage: openFromClassPage,
      customProjectId: projectId,
      customProjectTitle: projectTitle,
      customStageIdx: stageIdx,
      customIsOwner: isOwner,
      customAccentColor: accentColor,
      customCardColor: cardColor,
    );
  }

  static void openMateriItemPage(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
    bool openFromClassPage = false,
    String? customProjectId,
    String? customProjectTitle,
    int? customStageIdx,
    bool? customIsOwner,
    Color? customAccentColor,
    Color? customCardColor,
  }) {
    _DetailCpPageState.openMateriItemPage(
      context,
      stages,
      initialMateriIdx: initialMateriIdx,
      taskToEdit: taskToEdit,
      taskIdxToEdit: taskIdxToEdit,
      openFromClassPage: openFromClassPage,
      customProjectId: customProjectId,
      customProjectTitle: customProjectTitle,
      customStageIdx: customStageIdx,
      customIsOwner: customIsOwner,
      customAccentColor: customAccentColor,
      customCardColor: customCardColor,
    );
  }

  @override
  State<DetailCpPage> createState() => _DetailCpPageState();
}

class _DetailCpPageState extends State<DetailCpPage> {
  bool _isEditMode = false;
  List _cachedStages = [];
  TextEditingController? _stageNameController;
  TextEditingController? _stageDescController;
  final Map<int, TextEditingController> _materiControllers = {};
  Timer? _debounceTimer;

  late final ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  final Set<int> _expandedMateriIndices = {};

  final List<Color> _classroomCardColors = const [
    Color(0xFFF3E8FF), // 01. Soft Purple (Lilac)
    Color(0xFFE0F2FE), // 02. Soft Blue
    Color(0xFFD1FAE5), // 03. Soft Mint / Green
    Color(0xFFFFEDD5), // 04. Soft Orange / Peach
    Color(0xFFFCE7F3), // 05. Soft Pink
    Color(0xFFA5B4FC), // 06. Indigo Violet
    Color(0xFFBEF264), // 07. Fresh Lime
    Color(0xFF67E8F9), // 08. Ocean Cyan
    Color(0xFFFDE047), // 09. Amber Gold
    Color(0xFFCBD5E1), // 10. Steel Slate
  ];

  final List<Color> _classroomCardDarkColors = const [
    Color(0xFF1E162B), // 01. Dark Soft Purple
    Color(0xFF102030), // 02. Dark Soft Blue
    Color(0xFF0C241C), // 03. Dark Soft Mint
    Color(0xFF2B1D11), // 04. Dark Soft Orange
    Color(0xFF2B1220), // 05. Dark Soft Pink
    Color(0xFF4338CA), // 06. Deep Indigo
    Color(0xFF4D7C0F), // 07. Deep Olive Lime
    Color(0xFF0E7490), // 08. Deep Ocean Cyan
    Color(0xFFA16207), // 09. Deep Amber Gold
    Color(0xFF334155), // 10. Deep Slate Steel
  ];

  final List<Color> _classroomAccentColors = const [
    Color(0xFF7C3AED), // 01. Purple (Core)
    Color(0xFF2563EB), // 02. Blue
    Color(0xFF059669), // 03. Teal
    Color(0xFFD97706), // 04. Amber / Orange
    Color(0xFFDB2777), // 05. Pink / Rose
    Color(0xFF4F46E5), // 06. Indigo
    Color(0xFF65A30D), // 07. Lime
    Color(0xFF0891B2), // 08. Cyan
    Color(0xFFCA8A04), // 09. Gold
    Color(0xFF475569), // 10. Slate
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollOffsetNotifier.value = _scrollController.offset;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _stageNameController?.dispose();
    _stageDescController?.dispose();
    for (var c in _materiControllers.values) {
      c.dispose();
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  TextEditingController _getMateriController(int idx, String initialText) {
    if (!_materiControllers.containsKey(idx)) {
      _materiControllers[idx] = TextEditingController(text: initialText);
    }
    return _materiControllers[idx]!;
  }

  void _debouncedAutoSave(List currentStages) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveAllEdits(currentStages);
    });
  }

  Future<void> _saveAllEdits(List currentStages) async {
    final updatedStages = List.from(currentStages);
    if (widget.stageIdx >= updatedStages.length) return;

    final stage = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
    if (_stageNameController != null && _stageNameController!.text.trim().isNotEmpty) {
      stage['name'] = _stageNameController!.text.trim();
    }
    if (_stageDescController != null) {
      stage['summary'] = _stageDescController!.text.trim();
    }
    final List rawMateris = stage['materis'] as List? ?? [];
    final List<Map<String, dynamic>> materis = List<Map<String, dynamic>>.from(
      rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
    );
    for (int i = 0; i < materis.length; i++) {
      if (_materiControllers.containsKey(i) && _materiControllers[i]!.text.trim().isNotEmpty) {
        materis[i]['title'] = _materiControllers[i]!.text.trim();
      }
    }
    stage['materis'] = materis;
    updatedStages[widget.stageIdx] = stage;

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'stages': updatedStages});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final int badgeColorIdx = widget.stageIdx % _classroomCardColors.length;
    final Color cpCardBg = isDark
        ? _classroomCardDarkColors[badgeColorIdx]
        : _classroomCardColors[badgeColorIdx];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final projectData = snapshot.data!.data() as Map<String, dynamic>;
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final List stages = projectData['stages'] as List? ?? [];
          _cachedStages = stages;

          if (widget.stageIdx >= stages.length) {
            return const Center(child: Text('Tahapan tidak ditemukan.'));
          }

          final stage = stages[widget.stageIdx] as Map<String, dynamic>;
          final String stageName = stage['name'] ?? 'Elemen ${widget.stageIdx + 1}';
          final String stageDesc = (stage['summary'] ?? '').toString();
          final String stageStatus = stage['status'] as String? ?? 'proses';

          // Extract materis
          final List rawMateris = stage['materis'] as List? ?? [];
          List<Map<String, dynamic>> materis = [];
          if (rawMateris.isNotEmpty) {
            materis = rawMateris
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else {
            final List tasksList = stage['tasks'] as List? ?? [];
            if (tasksList.isNotEmpty) {
              materis = [
                {'title': 'Materi Pembelajaran', 'tasks': tasksList},
              ];
            }
          }

          if (_stageNameController == null) {
            _stageNameController = TextEditingController(text: stageName);
          } else if (!_isEditMode) {
            if (_stageNameController!.text != stageName) {
              _stageNameController!.text = stageName;
            }
          }
          if (_stageDescController == null) {
            _stageDescController = TextEditingController(text: stageDesc);
          } else if (!_isEditMode) {
            if (_stageDescController!.text != stageDesc) {
              _stageDescController!.text = stageDesc;
            }
          }

          // Fetch student completed tasks list
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('studentProgress')
                .doc(currentUid)
                .snapshots(),
            builder: (context, progSnap) {
              final progData = progSnap.hasData && progSnap.data!.exists
                  ? (progSnap.data!.data() as Map<String, dynamic>?) ?? {}
                  : {};
              final List<String> completedTasks = List<String>.from(
                progData['completedTasks'] ?? [],
              );

              return Stack(
                children: [
                  // 1. SingleChildScrollView: Halaman Normal yang Bergulir Penuh secara Alami
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 8,
                      16,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Back Button (Kiri) + Status Proses & Mode Edit (Kanan)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.centerLeft,
                                color: Colors.transparent,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  size: 24,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tombol Proses di kirinya Mode Edit
                                _buildStatusBadge(stageStatus, isDark, stages),
                                if (widget.isOwner) ...[
                                  const SizedBox(width: 8),
                                  _isEditMode
                                      ? GestureDetector(
                                          onTap: () {
                                            _saveAllEdits(_cachedStages);
                                            setState(() {
                                              _isEditMode = false;
                                            });
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: const Center(
                                            child: Icon(
                                              Icons.check_rounded,
                                              color: Color(0xFF10B981),
                                              size: 28,
                                            ),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isEditMode = true;
                                            });
                                          },
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
                                              'Mode Edit',
                                              style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 2: CP Header Hero (01 + Nama CP Penuh)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Angka 01
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  (widget.stageIdx + 1).toString().padLeft(2, '0'),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Judul CP (Besar & Tebal)
                            Expanded(
                              child: _isEditMode
                                  ? TextField(
                                      controller: _stageNameController,
                                      minLines: 1,
                                      maxLines: null,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        height: 1.22,
                                        letterSpacing: -0.5,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                        hintText: 'Nama Capaian Pembelajaran',
                                        hintStyle: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black38),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                                        ),
                                      ),
                                      onChanged: (v) => _debouncedAutoSave(stages),
                                    )
                                  : Text(
                                      stageName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        height: 1.22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                            ),
                          ],
                        ),

                        // Row 3: Deskripsi CP (Sesuai Warna Card Tahapan di Classroom & Teks Hitam) Tepat di Bawah Nama CP
                        if (stageDesc.isNotEmpty || _isEditMode) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: cpCardBg,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _TaskFacetPatternPainter(isDark: isDark),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _isEditMode
                                        ? TextField(
                                            controller: _stageDescController,
                                            maxLines: null,
                                            style: AppTypography.timestamp(
                                              color: isDark ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.w600,
                                              height: 1.5,
                                            ),
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                              hintText: 'Tulis ringkasan capaian pembelajaran di sini...',
                                              hintStyle: AppTypography.timestamp(
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                            onChanged: (v) => _debouncedAutoSave(stages),
                                          )
                                        : Text(
                                            stageDesc,
                                            style: AppTypography.timestamp(
                                              color: isDark ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.w600,
                                              height: 1.5,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),

                        // Row 4: Header Section Materi Pembelajaran & Tombol Tambah Materi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Materi Pembelajaran',
                              style: AppTypography.chatHeaderTitle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (widget.isOwner)
                              GestureDetector(
                                onTap: () => _showAddMateriDialog(context, stages),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Tambah Materi',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // List Setiap Materi: Judul di Luar Card, di Bawahnya Card Berisi Tugas/Materi/Quiz
                          if (materis.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.auto_stories_outlined,
                                      size: 40,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Belum ada materi pada capaian pembelajaran ini.',
                                      style: AppTypography.timestamp(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: materis.length,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, mIdx) {
                                final materi = materis[mIdx];
                              final String mTitle = (materi['title'] ?? 'Materi ${mIdx + 1}').toString();
                              final List tasks = materi['tasks'] as List? ?? [];
                              final bool isExpanded = _expandedMateriIndices.contains(mIdx);

                              // Filter items by category
                              final List<Map<String, dynamic>> tugasItems = [];
                              final List<Map<String, dynamic>> pdfItems = [];
                              final List<Map<String, dynamic>> quizItems = [];

                              for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
                                final t = Map<String, dynamic>.from(tasks[tIdx] as Map);
                                t['_origIdx'] = tIdx;
                                final type = (t['type'] as String? ?? 'tugas').toLowerCase();
                                if (type == 'quiz') {
                                  quizItems.add(t);
                                } else if (type == 'pdf' || type == 'materi') {
                                  pdfItems.add(t);
                                } else {
                                  tugasItems.add(t);
                                }
                              }

                              final int tugasCount = tugasItems.length;
                              final int pdfCount = pdfItems.length;
                              final int quizCount = quizItems.length;

                              return Dismissible(
                                key: ValueKey('materi_${mIdx}_${mTitle}_${stages.hashCode}'),
                                direction: widget.isOwner ? DismissDirection.endToStart : DismissDirection.none,
                                confirmDismiss: (direction) async {
                                  AppSoundService.playDeleteWhoosh();
                                  return await _confirmDeleteMateri(context, stages, mIdx, mTitle);
                                },
                                onUpdate: (details) {
                                  if (details.reached && !details.previousReached) {
                                    AppSoundService.playDeleteWhoosh();
                                  }
                                },
                                background: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 16),
                                    child: SizedBox(
                                      height: 28,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Hapus',
                                            style: AppTypography.buttonLabel(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 22),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 1. Judul Materi DI LUAR CARD (Judul Lengkap Tanpa Ellipsis '...', Lingkaran Warna: Orange=Tugas, Biru=Materi, Ungu=Quiz)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: _isEditMode
                                                  ? TextField(
                                                      controller: _getMateriController(mIdx, mTitle),
                                                      minLines: 1,
                                                      maxLines: null,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 16.0,
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        filled: true,
                                                        fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        hintText: 'Judul Materi...',
                                                        hintStyle: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black38),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                                                        ),
                                                      ),
                                                      onChanged: (v) => _debouncedAutoSave(stages),
                                                    )
                                                  : GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          if (_expandedMateriIndices.contains(mIdx)) {
                                                            _expandedMateriIndices.remove(mIdx);
                                                          } else {
                                                            _expandedMateriIndices.add(mIdx);
                                                          }
                                                        });
                                                      },
                                                      behavior: HitTestBehavior.opaque,
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                                        child: Text(
                                                          mTitle,
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 16.0,
                                                            fontWeight: FontWeight.w800,
                                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                            letterSpacing: -0.3,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Lingkaran Orange: Total Tugas (Warna Soft)
                                            if (tugasCount > 0) ...[
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF2B1D11) : const Color(0xFFFFEDD5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$tugasCount',
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w900,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],

                                            // Lingkaran Biru: Total Materi (Warna Soft)
                                            if (pdfCount > 0) ...[
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF102030) : const Color(0xFFE0F2FE),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$pdfCount',
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w900,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],

                                            // Lingkaran Ungu: Total Quiz (Warna Soft)
                                            if (quizCount > 0) ...[
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1E162B) : const Color(0xFFF3E8FF),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$quizCount',
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE),
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w900,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],

                                            // Jika belum ada item
                                            if (tasks.isEmpty) ...[
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '0',
                                                    style: TextStyle(
                                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w900,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],

                                            // Indikator Chevron ^ / v (Buka / Tutup)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (_expandedMateriIndices.contains(mIdx)) {
                                                    _expandedMateriIndices.remove(mIdx);
                                                  } else {
                                                    _expandedMateriIndices.add(mIdx);
                                                  }
                                                });
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                child: Icon(
                                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                                  size: 20,
                                                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                    // 2. Card Soft Warna-Warni Berisi Tugas (Orange), Materi (Biru), dan Quiz (Ungu) saat dibuka (Pola Facet Pattern Painter Sesuai Todo Siswa)
                                    if (isExpanded) ...[
                                      if (tasks.isEmpty && !widget.isOwner)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(22),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Belum ada tugas, materi, atau quiz',
                                              style: AppTypography.timestamp(
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                          ),
                                        )
                                      else ...[
                                        // A. CARD TUGAS (Soft Orange/Peach dengan Baris Tambah Tugas di Akhir)
                                        if (tugasItems.isNotEmpty || widget.isOwner) ...[
                                          Container(
                                            clipBehavior: Clip.antiAlias,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E1B16) : const Color(0xFFFFEDD5),
                                              borderRadius: BorderRadius.circular(22),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _TaskFacetPatternPainter(isDark: isDark),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (tugasItems.isNotEmpty)
                                                      ListView.separated(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: tugasItems.length,
                                                        padding: EdgeInsets.zero,
                                                        separatorBuilder: (context, index) => Divider(
                                                          height: 1,
                                                          thickness: 0.8,
                                                          color: isDark ? Colors.white10 : const Color(0xFFFDE68A).withValues(alpha: 0.40),
                                                        ),
                                                        itemBuilder: (context, idx) {
                                                          final task = tugasItems[idx];
                                                          final int tIdx = task['_origIdx'] as int;
                                                          final String originalTitle = task['title'] ?? 'Tugas';
                                                          final bool isLocked = task['isLocked'] == true;
                                                          final bool isClosed = task['isClosed'] == true;

                                                          final startStr = (task['startDate'] ?? task['start'] ?? '').toString().trim();
                                                          final endStr = (task['endDate'] ?? task['deadline'] ?? task['end'] ?? '').toString().trim();
                                                          String periodeText = '';
                                                          if (startStr.isNotEmpty && endStr.isNotEmpty) {
                                                            periodeText = '$startStr - $endStr';
                                                          } else if (endStr.isNotEmpty) {
                                                            periodeText = 'Sampai $endStr';
                                                          } else if (startStr.isNotEmpty) {
                                                            periodeText = 'Mulai $startStr';
                                                          } else {
                                                            periodeText = 'Hari ini';
                                                          }

                                                          return InkWell(
                                                            splashColor: Colors.transparent,
                                                            highlightColor: Colors.transparent,
                                                            hoverColor: Colors.transparent,
                                                            onTap: () {
                                                              if (widget.isOwner) {
                                                                _showEditTaskDialog(context, mIdx, tIdx, stages, task);
                                                              }
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                                              child: Row(
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  // Ikon Tugas SVG di SEBELAH KIRI (Matching Nav & Todo)
                                                                  SizedBox(
                                                                    width: 28,
                                                                    height: 28,
                                                                    child: Center(
                                                                      child: SvgPicture.string(
                                                                        '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                                          <path d="M7 3H5a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2v-3" stroke="${isDark ? '#FDE68A' : '#B45309'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                                                                          <path d="M7 8h5M7 12h4M7 16h6" stroke="${isDark ? '#FDE68A' : '#B45309'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                                                                          <path d="M19.1 2.9a2.12 2.12 0 013 3L13.5 14.5l-4.5 1 1-4.5L19.1 2.9z" fill="${isDark ? '#F59E0B' : '#D97706'}" stroke="${isDark ? '#FDE68A' : '#B45309'}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
                                                                        </svg>''',
                                                                        width: 22,
                                                                        height: 22,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 10),

                                                                  // Info Tugas (Tengah)
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          originalTitle,
                                                                          style: AppTypography.cardTitle(
                                                                            color: isDark ? Colors.white : Colors.black87,
                                                                            fontWeight: FontWeight.w700,
                                                                          ),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        const SizedBox(height: 3),
                                                                        Wrap(
                                                                          crossAxisAlignment: WrapCrossAlignment.center,
                                                                          spacing: 6,
                                                                          runSpacing: 3,
                                                                          children: [
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                                                              decoration: BoxDecoration(
                                                                                color: isDark
                                                                                    ? Colors.white.withValues(alpha: 0.12)
                                                                                    : Colors.white.withValues(alpha: 0.65),
                                                                                borderRadius: BorderRadius.circular(6),
                                                                              ),
                                                                              child: Text(
                                                                                'Tugas',
                                                                                style: GoogleFonts.plusJakartaSans(
                                                                                  fontSize: 11,
                                                                                  fontWeight: FontWeight.w700,
                                                                                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.access_time_rounded,
                                                                                  size: 13,
                                                                                  color: isDark ? Colors.white38 : Colors.black45,
                                                                                ),
                                                                                const SizedBox(width: 3),
                                                                                Text(
                                                                                  periodeText,
                                                                                  style: AppTypography.timestamp(
                                                                                    color: isDark ? Colors.white38 : Colors.black45,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // Sisi Kanan: Aksi Guru (Baris 1: Tutup & Lock, Baris 2: Hapus Rata Kanan)
                                                                  if (widget.isOwner) ...[
                                                                    const SizedBox(width: 6),
                                                                    Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            GestureDetector(
                                                                              onTap: () => _toggleTaskClosed(stages, mIdx, tIdx),
                                                                              behavior: HitTestBehavior.opaque,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(3),
                                                                                child: Icon(
                                                                                  isClosed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                                                  size: 16,
                                                                                  color: isClosed
                                                                                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                                                                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                            GestureDetector(
                                                                              onTap: () => _toggleTaskLock(stages, mIdx, tIdx),
                                                                              behavior: HitTestBehavior.opaque,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(3),
                                                                                child: Icon(
                                                                                  isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                                                                                  size: 16,
                                                                                  color: isLocked
                                                                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                                                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(height: 2),
                                                                        GestureDetector(
                                                                          onTap: () => _confirmDeleteTask(context, stages, mIdx, tIdx, originalTitle),
                                                                          behavior: HitTestBehavior.opaque,
                                                                          child: const Padding(
                                                                            padding: EdgeInsets.all(3),
                                                                            child: Icon(
                                                                              Icons.delete_outline_rounded,
                                                                              size: 16,
                                                                              color: Color(0xFFEF4444),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),

                                                    // Baris Akhir: Tambah Tugas (Card Hitam Teks Putih Rata Kiri)
                                                    if (widget.isOwner) ...[
                                                      if (tugasItems.isNotEmpty)
                                                        Divider(
                                                          height: 1,
                                                          thickness: 0.8,
                                                          color: isDark ? Colors.white10 : const Color(0xFFFDE68A).withValues(alpha: 0.40),
                                                        ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                                        child: Align(
                                                          alignment: Alignment.centerLeft,
                                                          child: GestureDetector(
                                                            onTap: () => _showCreateTugasDialog(context, mIdx, stages),
                                                            behavior: HitTestBehavior.opaque,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                                                borderRadius: BorderRadius.circular(16),
                                                              ),
                                                              child: Text(
                                                                'Tambah Tugas',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        // B. CARD MATERI PDF / MODUL (Soft Sky Blue dengan Baris Upload Materi di Akhir)
                                        if (pdfItems.isNotEmpty || widget.isOwner) ...[
                                          Container(
                                            clipBehavior: Clip.antiAlias,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F1C2E) : const Color(0xFFE0F2FE),
                                              borderRadius: BorderRadius.circular(22),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _QuizFacetPatternPainter(isDark: isDark),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (pdfItems.isNotEmpty)
                                                      ListView.separated(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: pdfItems.length,
                                                        padding: EdgeInsets.zero,
                                                        separatorBuilder: (context, index) => Divider(
                                                          height: 1,
                                                          thickness: 0.8,
                                                          color: isDark ? Colors.white10 : const Color(0xFFBAE6FD).withValues(alpha: 0.40),
                                                        ),
                                                        itemBuilder: (context, idx) {
                                                          final task = pdfItems[idx];
                                                          final int tIdx = task['_origIdx'] as int;
                                                          final String originalTitle = task['title'] ?? 'Materi Pembelajaran';
                                                          final String docName = task['fileName'] ?? task['doc'] ?? 'Modul PDF';
                                                          final bool isLocked = task['isLocked'] == true;
                                                          final bool isClosed = task['isClosed'] == true;

                                                          String uploadDateText = '';
                                                          if (task['uploadDate'] != null && task['uploadDate'].toString().isNotEmpty) {
                                                            uploadDateText = task['uploadDate'].toString();
                                                          } else if (task['createdAt'] != null && task['createdAt'].toString().isNotEmpty) {
                                                            final raw = task['createdAt'].toString();
                                                            try {
                                                              final dt = DateTime.parse(raw);
                                                              uploadDateText = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                                                            } catch (_) {
                                                              uploadDateText = raw.split('T').first;
                                                            }
                                                          } else if (task['startDate'] != null && task['startDate'].toString().isNotEmpty) {
                                                            uploadDateText = task['startDate'].toString();
                                                          } else {
                                                            final now = DateTime.now();
                                                            uploadDateText = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
                                                          }

                                                          return InkWell(
                                                            splashColor: Colors.transparent,
                                                            highlightColor: Colors.transparent,
                                                            hoverColor: Colors.transparent,
                                                            onTap: () {
                                                              if (widget.isOwner) {
                                                                _showEditMateriItemDialog(context, mIdx, tIdx, stages, task);
                                                              }
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                                              child: Row(
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  // Ikon Dokumen Materi SVG di SEBELAH KIRI (Matching Nav & Todo)
                                                                  SizedBox(
                                                                    width: 28,
                                                                    height: 28,
                                                                    child: Center(
                                                                      child: SvgPicture.string(
                                                                        '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                                          <path d="M4 19.5A2.5 2.5 0 016.5 17H20" stroke="${isDark ? '#BAE6FD' : '#0369A1'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                                                                          <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" stroke="${isDark ? '#BAE6FD' : '#0369A1'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                                                                          <path d="M9 7h7M9 11h5" stroke="${isDark ? '#38BDF8' : '#0284C7'}" stroke-width="2" stroke-linecap="round"/>
                                                                          <circle cx="16" cy="11" r="1.5" fill="${isDark ? '#38BDF8' : '#0284C7'}"/>
                                                                        </svg>''',
                                                                        width: 22,
                                                                        height: 22,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 10),

                                                                  // Info Materi (Tengah)
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          originalTitle,
                                                                          style: AppTypography.cardTitle(
                                                                            color: isDark ? Colors.white : Colors.black87,
                                                                            fontWeight: FontWeight.w700,
                                                                          ),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        const SizedBox(height: 3),
                                                                        Wrap(
                                                                          crossAxisAlignment: WrapCrossAlignment.center,
                                                                          spacing: 6,
                                                                          runSpacing: 3,
                                                                          children: [
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                                                              decoration: BoxDecoration(
                                                                                color: isDark
                                                                                    ? Colors.white.withValues(alpha: 0.12)
                                                                                    : Colors.white.withValues(alpha: 0.65),
                                                                                borderRadius: BorderRadius.circular(6),
                                                                              ),
                                                                              child: Text(
                                                                                'Materi',
                                                                                style: GoogleFonts.plusJakartaSans(
                                                                                  fontSize: 11,
                                                                                  fontWeight: FontWeight.w700,
                                                                                  color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.access_time_rounded,
                                                                                  size: 13,
                                                                                  color: isDark ? Colors.white38 : Colors.black45,
                                                                                ),
                                                                                const SizedBox(width: 3),
                                                                                Text(
                                                                                  'Diunggah $uploadDateText',
                                                                                  style: AppTypography.timestamp(
                                                                                    color: isDark ? Colors.white38 : Colors.black45,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            if (docName.isNotEmpty)
                                                                              Text(
                                                                                '• $docName',
                                                                                style: AppTypography.timestamp(
                                                                                  color: isDark ? Colors.white38 : Colors.black45,
                                                                                  fontWeight: FontWeight.w600,
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // Sisi Kanan: Aksi Guru (Baris 1: Tutup & Lock, Baris 2: Hapus Rata Kanan)
                                                                  if (widget.isOwner) ...[
                                                                    const SizedBox(width: 6),
                                                                    Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            GestureDetector(
                                                                              onTap: () => _toggleTaskClosed(stages, mIdx, tIdx),
                                                                              behavior: HitTestBehavior.opaque,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(3),
                                                                                child: Icon(
                                                                                  isClosed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                                                  size: 16,
                                                                                  color: isClosed
                                                                                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                                                                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                            GestureDetector(
                                                                              onTap: () => _toggleTaskLock(stages, mIdx, tIdx),
                                                                              behavior: HitTestBehavior.opaque,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(3),
                                                                                child: Icon(
                                                                                  isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                                                                                  size: 16,
                                                                                  color: isLocked
                                                                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                                                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(height: 2),
                                                                        GestureDetector(
                                                                          onTap: () => _confirmDeleteTask(context, stages, mIdx, tIdx, originalTitle),
                                                                          behavior: HitTestBehavior.opaque,
                                                                          child: const Padding(
                                                                            padding: EdgeInsets.all(3),
                                                                            child: Icon(
                                                                              Icons.delete_outline_rounded,
                                                                              size: 16,
                                                                              color: Color(0xFFEF4444),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),

                                                    // Baris Akhir: Upload Materi (Card Hitam Teks Putih Rata Kiri)
                                                    if (widget.isOwner) ...[
                                                      if (pdfItems.isNotEmpty)
                                                        Divider(
                                                          height: 1,
                                                          thickness: 0.8,
                                                          color: isDark ? Colors.white10 : const Color(0xFFBAE6FD).withValues(alpha: 0.40),
                                                        ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                                        child: Align(
                                                          alignment: Alignment.centerLeft,
                                                          child: GestureDetector(
                                                            onTap: () => _showCreateMateriDialog(context, mIdx, stages),
                                                            behavior: HitTestBehavior.opaque,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                                                borderRadius: BorderRadius.circular(16),
                                                              ),
                                                              child: Text(
                                                                'Upload Materi',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        // C. CARD QUIZ (Soft Lilac/Purple dengan Baris Buat Quiz di Akhir)
                                        if (quizItems.isNotEmpty || widget.isOwner) ...[
                                          Container(
                                            clipBehavior: Clip.antiAlias,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1A1226) : const Color(0xFFF3E8FF),
                                              borderRadius: BorderRadius.circular(22),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _QuizFacetPatternPainter(isDark: isDark),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (quizItems.isNotEmpty)
                                                      ListView.separated(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: quizItems.length,
                                                        padding: EdgeInsets.zero,
                                                        separatorBuilder: (context, index) => Divider(
                                                          height: 1,
                                                          thickness: 0.8,
                                                          color: isDark ? Colors.white10 : const Color(0xFFE9D5FF).withValues(alpha: 0.40),
                                                        ),
                                                        itemBuilder: (context, idx) {
                                                          final task = quizItems[idx];
                                                          final int tIdx = task['_origIdx'] as int;
                                                          final String originalTitle = task['title'] ?? 'Kuis Harian';
                                                          final questions = task['questions'] as List? ?? [];
                                                          final questionCount = questions.length;
                                                          final bool isLocked = task['isLocked'] == true;
                                                          final bool isClosed = task['isClosed'] == true;

                                                          final startStr = (task['startDate'] ?? task['startTime'] ?? task['start'] ?? '').toString().trim();
                                                          final endStr = (task['endDate'] ?? task['endTime'] ?? task['deadline'] ?? task['end'] ?? '').toString().trim();
                                                          String quizPeriodText = '';
                                                          if (startStr.isNotEmpty && endStr.isNotEmpty) {
                                                            quizPeriodText = '$startStr - $endStr';
                                                          } else if (endStr.isNotEmpty) {
                                                            quizPeriodText = 'Sampai $endStr';
                                                          } else if (startStr.isNotEmpty) {
                                                            quizPeriodText = 'Mulai $startStr';
                                                          } else {
                                                            quizPeriodText = 'Hari ini';
                                                          }

                                                          return InkWell(
                                                            onTap: () {
                                                              if (widget.isOwner) {
                                                                _showEditQuizDialog(context, mIdx, tIdx, stages, task);
                                                              }
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                                              child: Row(
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  // Ikon Quiz SVG di SEBELAH KIRI (Matching Nav & Todo 1 2 3 Podium)
                                                                  SizedBox(
                                                                    width: 28,
                                                                    height: 28,
                                                                    child: Center(
                                                                      child: SvgPicture.string(
                                                                        '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                                          <!-- Step 1 (Tingkat 1 - Rendah) -->
                                                                          <rect x="2.5" y="13.5" width="5.5" height="8" rx="2" fill="${isDark ? '#D8B4FE' : '#7E22CE'}"/>
                                                                          <path d="M4.5 16.5l1-0.8v4.3" stroke="${isDark ? '#1E162B' : '#FFFFFF'}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>

                                                                          <!-- Step 2 (Tingkat 2 - Sedang) -->
                                                                          <rect x="9.25" y="8.5" width="5.5" height="13" rx="2" fill="${isDark ? '#C084FC' : '#9333EA'}"/>
                                                                          <path d="M10.8 11.2c.2-.5.7-.8 1.2-.8.7 0 1.2.4 1.2 1 0 .7-.5 1.1-1.1 1.6l-1.3 1.2h2.4" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>

                                                                          <!-- Step 3 (Tingkat 3 - Tinggi) -->
                                                                          <rect x="16" y="3.5" width="5.5" height="18" rx="2" fill="${isDark ? '#D8B4FE' : '#7E22CE'}"/>
                                                                          <path d="M17.6 6.2h2.2l-1.1 1.6c.7 0 1.2.4 1.2 1 0 .7-.6 1.2-1.3 1.2-.6 0-1-.3-1.2-.7" stroke="${isDark ? '#1E162B' : '#FFFFFF'}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
                                                                        </svg>''',
                                                                        width: 22,
                                                                        height: 22,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 10),

                                                                  // Info Quiz (Tengah)
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          originalTitle,
                                                                          style: AppTypography.cardTitle(
                                                                            color: isDark ? Colors.white : Colors.black87,
                                                                            fontWeight: FontWeight.w700,
                                                                          ),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        const SizedBox(height: 3),
                                                                        Wrap(
                                                                          crossAxisAlignment: WrapCrossAlignment.center,
                                                                          spacing: 6,
                                                                          runSpacing: 3,
                                                                          children: [
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                                                              decoration: BoxDecoration(
                                                                                color: isDark
                                                                                    ? Colors.white.withValues(alpha: 0.12)
                                                                                    : Colors.white.withValues(alpha: 0.65),
                                                                                borderRadius: BorderRadius.circular(6),
                                                                              ),
                                                                              child: Text(
                                                                                'Quiz',
                                                                                style: GoogleFonts.plusJakartaSans(
                                                                                  fontSize: 11,
                                                                                  fontWeight: FontWeight.w700,
                                                                                  color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.access_time_rounded,
                                                                                  size: 13,
                                                                                  color: isDark ? Colors.white38 : Colors.black45,
                                                                                ),
                                                                                const SizedBox(width: 3),
                                                                                Text(
                                                                                  quizPeriodText,
                                                                                  style: AppTypography.timestamp(
                                                                                    color: isDark ? Colors.white38 : Colors.black45,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            Text(
                                                                              '• $questionCount Soal',
                                                                              style: AppTypography.timestamp(
                                                                                color: isDark ? Colors.white38 : Colors.black45,
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // Sisi Kanan: Aksi Guru (Baris 1: Tutup & Lock, Baris 2: Hapus Rata Kanan)
                                                                  if (widget.isOwner) ...[
                                                                    const SizedBox(width: 6),
                                                                    Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            GestureDetector(
                                                                              onTap: () => _toggleTaskClosed(stages, mIdx, tIdx),
                                                                              behavior: HitTestBehavior.opaque,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(3),
                                                                                child: Icon(
                                                                                  isClosed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                                                  size: 16,
                                                                                  color: isClosed
                                                                                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                                                                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 2),
                                                                            GestureDetector(
                                                                              onTap: () => _toggleTaskLock(stages, mIdx, tIdx),
                                                                              behavior: HitTestBehavior.opaque,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(3),
                                                                                child: Icon(
                                                                                  isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                                                                                  size: 16,
                                                                                  color: isLocked
                                                                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                                                                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(height: 2),
                                                                        GestureDetector(
                                                                          onTap: () => _confirmDeleteTask(context, stages, mIdx, tIdx, originalTitle),
                                                                          behavior: HitTestBehavior.opaque,
                                                                          child: const Padding(
                                                                            padding: EdgeInsets.all(3),
                                                                            child: Icon(
                                                                              Icons.delete_outline_rounded,
                                                                              size: 16,
                                                                              color: Color(0xFFEF4444),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),

                                                    // Baris Akhir: Buat Quiz (Card Hitam Teks Putih Rata Kiri)
                                                    if (widget.isOwner) ...[
                                                      if (quizItems.isNotEmpty)
                                                        Divider(
                                                          height: 1,
                                                          thickness: 0.8,
                                                          color: isDark ? Colors.white10 : const Color(0xFFE9D5FF).withValues(alpha: 0.40),
                                                        ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                                        child: Align(
                                                          alignment: Alignment.centerLeft,
                                                          child: GestureDetector(
                                                            onTap: () => _showCreateQuizDialog(context, mIdx, stages),
                                                            behavior: HitTestBehavior.opaque,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                              decoration: BoxDecoration(
                                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                                                borderRadius: BorderRadius.circular(16),
                                                              ),
                                                              child: Text(
                                                                'Buat Quiz',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // 2. Sticky Glassmorphic Header Bar (Transparan Glassmorphic Blur - Muncul saat di-scroll > 60px)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollOffsetNotifier,
                      builder: (context, scrollOffset, _) {
                        if (scrollOffset <= 60.0) {
                          return const SizedBox.shrink();
                        }
                        final double scrollProgress = ((scrollOffset - 60.0) / 40.0).clamp(0.0, 1.0);
                        final double blurSigma = 20.0 * scrollProgress;

                        return Opacity(
                          opacity: scrollProgress,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: blurSigma > 0.1 ? blurSigma : 0.001,
                                sigmaY: blurSigma > 0.1 ? blurSigma : 0.001,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  MediaQuery.of(context).padding.top + 8.0,
                                  16,
                                  10.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF000000).withValues(alpha: 0.85 * scrollProgress)
                                      : Colors.white.withValues(alpha: 0.90 * scrollProgress),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: (isDark
                                              ? const Color(0xFF27272A)
                                              : const Color(0xFFF1F5F9))
                                          .withValues(alpha: 0.9 * scrollProgress),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Single Row: ← + Judul CP (2 baris) + Ikon Proses (lingkaran) + Ikon Edit (lingkaran)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Tombol Kembali
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.centerLeft,
                                            decoration: const BoxDecoration(
                                              color: Colors.transparent,
                                            ),
                                            child: Icon(
                                              Icons.arrow_back_rounded,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Judul CP (2 baris max)
                                        Expanded(
                                          child: Text(
                                            stageName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              height: 1.25,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Ikon Status Proses (Lingkaran)
                                        _buildStickyStatusIcon(stageStatus, isDark, stages),

                                        // Ikon Mode Edit (Lingkaran)
                                        if (widget.isOwner) ...[
                                          const SizedBox(width: 8),
                                          _isEditMode
                                              ? GestureDetector(
                                                  onTap: () {
                                                    _saveAllEdits(_cachedStages);
                                                    setState(() {
                                                      _isEditMode = false;
                                                    });
                                                  },
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.check_rounded,
                                                        color: Color(0xFF10B981),
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _isEditMode = true;
                                                    });
                                                  },
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFF1E293B),
                                                      shape: BoxShape.circle,
                                                      border: isDark
                                                          ? Border.all(color: const Color(0xFF3F3F46), width: 1.0)
                                                          : null,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.edit_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Row 2: Materi Pembelajaran & Tambah Materi
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Materi Pembelajaran',
                                          style: AppTypography.chatHeaderTitle(
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (widget.isOwner)
                                          GestureDetector(
                                            onTap: () => _showAddMateriDialog(context, stages),
                                            behavior: HitTestBehavior.opaque,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Tambah Materi',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
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
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
  Future<void> _toggleTaskLock(List currentStages, int mIdx, int tIdx) async {
    final updatedStages = List.from(currentStages);
    if (widget.stageIdx >= updatedStages.length) return;
    final stage = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
    final List rawMateris = stage['materis'] as List? ?? [];
    final List<Map<String, dynamic>> materis = List<Map<String, dynamic>>.from(
      rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
    );
    if (mIdx < materis.length) {
      final List rawTasks = materis[mIdx]['tasks'] as List? ?? [];
      final List<Map<String, dynamic>> tasks = List<Map<String, dynamic>>.from(
        rawTasks.map((t) => Map<String, dynamic>.from(t as Map)),
      );
      if (tIdx < tasks.length) {
        final isLocked = tasks[tIdx]['isLocked'] == true;
        tasks[tIdx]['isLocked'] = !isLocked;
        materis[mIdx]['tasks'] = tasks;
        stage['materis'] = materis;
        updatedStages[widget.stageIdx] = stage;

        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({'stages': updatedStages});
      }
    }
  }

  Future<void> _toggleTaskClosed(List currentStages, int mIdx, int tIdx) async {
    final updatedStages = List.from(currentStages);
    if (widget.stageIdx >= updatedStages.length) return;
    final stage = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
    final List rawMateris = stage['materis'] as List? ?? [];
    final List<Map<String, dynamic>> materis = List<Map<String, dynamic>>.from(
      rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
    );
    if (mIdx < materis.length) {
      final List rawTasks = materis[mIdx]['tasks'] as List? ?? [];
      final List<Map<String, dynamic>> tasks = List<Map<String, dynamic>>.from(
        rawTasks.map((t) => Map<String, dynamic>.from(t as Map)),
      );
      if (tIdx < tasks.length) {
        final isClosed = tasks[tIdx]['isClosed'] == true;
        tasks[tIdx]['isClosed'] = !isClosed;
        materis[mIdx]['tasks'] = tasks;
        stage['materis'] = materis;
        updatedStages[widget.stageIdx] = stage;

        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({'stages': updatedStages});
      }
    }
  }

  Future<void> _toggleTaskDone(List stages, int mIdx, int tIdx) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String taskKey = '${widget.stageIdx}_${mIdx}_$tIdx';

    final docRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('studentProgress')
        .doc(currentUid);

    final snap = await docRef.get();
    List<String> completed = [];
    if (snap.exists && snap.data() != null) {
      completed = List<String>.from(snap.data()!['completedTasks'] ?? []);
    }

    if (completed.contains(taskKey)) {
      completed.remove(taskKey);
    } else {
      completed.add(taskKey);
    }

    await docRef.set({'completedTasks': completed}, SetOptions(merge: true));
  }

  Widget _buildStatusBadge(String status, bool isDark, List stages) {
    String displayLabel = 'Proses';
    Color statusBg = isDark ? const Color(0xFFC76D10) : const Color(0xFFF7BD84);
    const Color statusFg = Color(0xFF0F172A);

    if (status == 'selesai' || status == 'Selesai') {
      displayLabel = 'Selesai';
      statusBg = isDark ? const Color(0xFF147D75) : const Color(0xFF7DE3D0);
    } else if (status == 'akan_datang' || status == 'Akan Datang') {
      displayLabel = 'Akan Datang';
      statusBg = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);
    }

    if (!widget.isOwner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          displayLabel,
          style: AppTypography.buttonLabel(color: statusFg, fontWeight: FontWeight.bold),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 36),
      color: isDark ? const Color(0xFF101012) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      onSelected: (String newValue) async {
        final updatedStages = List.from(stages);
        if (widget.stageIdx < updatedStages.length) {
          final s = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
          s['status'] = newValue;
          updatedStages[widget.stageIdx] = s;
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .update({'stages': updatedStages});
          setState(() {});
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'proses',
          height: 32,
          padding: EdgeInsets.zero,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'selesai',
          height: 32,
          padding: EdgeInsets.zero,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'akan_datang',
          height: 32,
          padding: EdgeInsets.zero,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Akan Datang',
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: AppTypography.buttonLabel(
                color: statusFg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: statusFg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyStatusIcon(String status, bool isDark, List stages) {
    Color statusBg = isDark ? const Color(0xFFC76D10) : const Color(0xFFF7BD84);
    IconData statusIcon = Icons.timelapse_rounded;

    if (status == 'selesai' || status == 'Selesai') {
      statusBg = isDark ? const Color(0xFF147D75) : const Color(0xFF7DE3D0);
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'akan_datang' || status == 'Akan Datang') {
      statusBg = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);
      statusIcon = Icons.schedule_rounded;
    }

    if (!widget.isOwner) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: statusBg,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            statusIcon,
            color: const Color(0xFF0F172A),
            size: 18,
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      color: isDark ? const Color(0xFF101012) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      onSelected: (String newValue) async {
        final updatedStages = List.from(stages);
        if (widget.stageIdx < updatedStages.length) {
          final s = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
          s['status'] = newValue;
          updatedStages[widget.stageIdx] = s;
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .update({'stages': updatedStages});
          setState(() {});
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'proses',
          height: 32,
          padding: EdgeInsets.zero,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'selesai',
          height: 32,
          padding: EdgeInsets.zero,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'akan_datang',
          height: 32,
          padding: EdgeInsets.zero,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Akan Datang',
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: statusBg,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            statusIcon,
            color: const Color(0xFF0F172A),
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showAddMateriDialog(BuildContext context, List currentStages) {
    String title = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.isDarkMode ? const Color(0xFF141416) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tambah Materi Baru',
          style: AppTypography.buttonLabel(color: AppColors.isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          autofocus: true,
          style: AppTypography.timestamp(color: AppColors.isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Contoh: Materi 1: Pengenalan Konsep',
            hintStyle: AppTypography.timestamp(color: Colors.black38),
          ),
          onChanged: (v) => title = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (title.trim().isEmpty) return;
              Navigator.pop(ctx);
              final updatedStages = List.from(currentStages);
              final stage = Map<String, dynamic>.from(updatedStages[widget.stageIdx]);
              final List rawMateris = stage['materis'] as List? ?? [];
              final List<Map<String, dynamic>> materis = List<Map<String, dynamic>>.from(
                rawMateris.map((m) => Map<String, dynamic>.from(m as Map)),
              );
              materis.add({'title': title.trim(), 'tasks': []});
              stage['materis'] = materis;
              updatedStages[widget.stageIdx] = stage;

              await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .update({'stages': updatedStages});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Tambah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    final String type = task['type'] ?? 'tugas';
    if (type == 'quiz') {
      _showEditQuizDialog(context, materiIdx, taskIdx, currentStages, task);
    } else if (type == 'pdf') {
      _showEditMateriItemDialog(context, materiIdx, taskIdx, currentStages, task);
    } else {
      _showEditTugasDialog(context, materiIdx, taskIdx, currentStages, task);
    }
  }

  // -------------------------------------------------------------
  // 1. POPUP FORM BUAT / EDIT TUGAS (EXACT DESKTOP CLASSROOM MATCH)
  // -------------------------------------------------------------
  void _showCreateTugasDialog(BuildContext context, int initialMateriIdx, List currentStages) {
    openTaskPage(
      context,
      currentStages,
      initialMateriIdx: initialMateriIdx,
      customProjectId: widget.projectId,
      customProjectTitle: widget.projectTitle,
      customStageIdx: widget.stageIdx,
      customIsOwner: widget.isOwner,
      customAccentColor: widget.accentColor,
      customCardColor: widget.cardColor,
      openFromClassPage: false,
    );
  }

  void _showEditTugasDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    openTaskPage(
      context,
      currentStages,
      initialMateriIdx: materiIdx,
      taskToEdit: task,
      taskIdxToEdit: taskIdx,
      customProjectId: widget.projectId,
      customProjectTitle: widget.projectTitle,
      customStageIdx: widget.stageIdx,
      customIsOwner: widget.isOwner,
      customAccentColor: widget.accentColor,
      customCardColor: widget.cardColor,
      openFromClassPage: false,
    );
  }

  static void openTaskPage(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
    bool openFromClassPage = false,
    String? customProjectId,
    String? customProjectTitle,
    int? customStageIdx,
    bool? customIsOwner,
    Color? customAccentColor,
    Color? customCardColor,
  }) {
    if (stages.isEmpty) return;

    final String activeProjectId = customProjectId ?? '';
    final String activeProjectTitle = customProjectTitle ?? '';
    final bool activeIsOwner = customIsOwner ?? false;
    final Color activeAccentColor = customAccentColor ?? const Color(0xFFEA580C);
    final Color activeCardColor = customCardColor ?? const Color(0xFF1E293B);
    final int baseStageIdx = customStageIdx ?? 0;

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = baseStageIdx < stages.length ? baseStageIdx : 0;
    int selectedMateriIdx = initialMateriIdx;

    int countTugas = 0;
    if (selectedStageIdx < stages.length) {
      final st = stages[selectedStageIdx] as Map;
      final mats = st['materis'] as List? ?? [];
      if (selectedMateriIdx < mats.length) {
        final mat = mats[selectedMateriIdx] as Map;
        final ts = mat['tasks'] as List? ?? [];
        for (var t in ts) {
          if ((t as Map)['type'] == 'tugas' || t['type'] == null) countTugas++;
        }
      }
    }
    final defaultTaskTitle = 'Tugas_${countTugas + 1}';
    final titleController = TextEditingController(text: isEditMode ? (taskToEdit['title'] ?? '') : defaultTaskTitle);

    String initDateStr(String? raw) => raw ?? '';
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final startDateController = TextEditingController(
      text: isEditMode ? initDateStr(taskToEdit['startDate'] as String?) : todayStr,
    );
    final endDateController = TextEditingController(
      text: isEditMode ? initDateStr(taskToEdit['endDate'] as String?) : '',
    );

    void formatDateInput(TextEditingController ctrl) {
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
    String assignmentType = isEditMode ? (extraDataEdit['assignmentType'] ?? taskToEdit['assignmentType'] ?? 'individu') : 'individu';
    String tugasMode = isEditMode ? (extraDataEdit['tugasMode'] ?? 'text') : 'text';
    final taskTextController = TextEditingController(
      text: isEditMode ? (extraDataEdit['tugasText'] ?? taskToEdit['tugasText'] ?? taskToEdit['docName'] ?? '') : '',
    );
    final taskPdfController = TextEditingController(
      text: isEditMode && tugasMode == 'pdf' ? (taskToEdit['docName'] ?? taskToEdit['doc'] ?? '') : '',
    );

    bool isSubmitting = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (dialogCtx) {
          final screenHeight = MediaQuery.of(dialogCtx).size.height;
          final screenWidth = MediaQuery.of(dialogCtx).size.width;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = AppColors.isDarkMode;
              final stageMap = stages[selectedStageIdx] as Map;
              final List materis = stageMap['materis'] as List? ?? [];
              if (selectedMateriIdx >= materis.length) {
                selectedMateriIdx = materis.isNotEmpty ? 0 : 0;
              }

              Future<void> submitTask() async {
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
                    'tugasText': taskTextController.text.trim(),
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
                  'id': isEditMode ? (taskToEdit['id'] ?? 'task_${DateTime.now().millisecondsSinceEpoch}') : 'task_${DateTime.now().millisecondsSinceEpoch}',
                  'type': 'tugas',
                  'title': title,
                  'startDate': startStr,
                  'endDate': endStr,
                  'doc': docName,
                  'docName': docName,
                  'assignmentType': assignmentType,
                  'tugasText': taskTextController.text.trim(),
                  'extraData': extraData,
                  'submissions': isEditMode ? (taskToEdit['submissions'] ?? []) : [],
                  'isDone': isEditMode ? (taskToEdit['isDone'] ?? false) : false,
                  'progress': isEditMode ? (taskToEdit['progress'] ?? 0) : 0,
                };

                setDialogState(() => isSubmitting = true);

                final List updatedStages = List.from(stages);
                final Map targetStage = Map.from(updatedStages[selectedStageIdx] as Map);
                final List targetMateris = List.from(targetStage['materis'] as List? ?? []);

                if (selectedMateriIdx < targetMateris.length) {
                  final Map targetMateri = Map.from(targetMateris[selectedMateriIdx] as Map);
                  final List currentMateriTasks = List.from(targetMateri['tasks'] as List? ?? []);

                  if (isEditMode) {
                    if (taskIdxToEdit != null && taskIdxToEdit < currentMateriTasks.length) {
                      currentMateriTasks[taskIdxToEdit] = newTask;
                    } else {
                      final int tIdx = currentMateriTasks.indexWhere((t) => t['id'] == taskToEdit['id']);
                      if (tIdx != -1) {
                        currentMateriTasks[tIdx] = newTask;
                      } else {
                        currentMateriTasks.add(newTask);
                      }
                    }
                  } else {
                    currentMateriTasks.add(newTask);
                  }

                  targetMateri['tasks'] = currentMateriTasks;
                  targetMateris[selectedMateriIdx] = targetMateri;
                  targetStage['materis'] = targetMateris;
                  updatedStages[selectedStageIdx] = targetStage;

                  await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(activeProjectId)
                      .update({'stages': updatedStages});
                }

                if (dialogCtx.mounted) {
                  if (openFromClassPage) {
                    Navigator.pushReplacement(
                      dialogCtx,
                      MaterialPageRoute(
                        builder: (_) => DetailCpPage(
                          projectId: activeProjectId,
                          projectTitle: activeProjectTitle,
                          stageIdx: selectedStageIdx,
                          isOwner: activeIsOwner,
                          accentColor: activeAccentColor,
                          cardColor: activeCardColor,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(dialogCtx);
                  }
                }
              }

              return Scaffold(
                backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                body: SafeArea(
                  child: Column(
                    children: [
                      // Header Atas Full Page (Transparan Blur Glassmorphic)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF1E1B16) : const Color(0xFFFFEDD5)).withValues(alpha: isDark ? 0.90 : 0.85),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                            ),
                          child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2B1D11) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.assignment_rounded,
                                color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFEA580C),
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
                                  isEditMode ? 'Edit Tugas' : 'Unggah / Buat Tugas',
                                  style: AppTypography.cardTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Atur tugas, tenggat waktu & instruksi',
                                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                    // Form Body Lengkap with Floating Overlay Action Button
                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20.0, 52.0, 20.0, 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            // 1. Pilih Elemen
                            Text(
                              'Pilih Elemen Pembelajaran',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: '',
                              offset: const Offset(0, 48),
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              enabled: !isEditMode,
                              onSelected: (val) {
                                setDialogState(() {
                                  selectedStageIdx = val;
                                  selectedMateriIdx = 0;
                                });
                              },
                              itemBuilder: (context) => List.generate(stages.length, (idx) {
                                final st = stages[idx] as Map;
                                final bool isLast = idx == stages.length - 1;
                                return PopupMenuItem<int>(
                                  value: idx,
                                  height: 40,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9)),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      st['name'] ?? st['title'] ?? 'Elemen ${idx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: selectedStageIdx == idx
                                            ? const Color(0xFF2563EB)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stages[selectedStageIdx]['name'] ?? stages[selectedStageIdx]['title'] ?? 'Elemen ${selectedStageIdx + 1}',
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Pilih Materi
                            Text(
                              'Pilih Materi',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: '',
                              offset: const Offset(0, 48),
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              enabled: !isEditMode && materis.isNotEmpty,
                              onSelected: (val) {
                                setDialogState(() {
                                  selectedMateriIdx = val;
                                });
                              },
                              itemBuilder: (context) => List.generate(materis.length, (mIdx) {
                                final m = materis[mIdx] as Map;
                                final bool isLast = mIdx == materis.length - 1;
                                return PopupMenuItem<int>(
                                  value: mIdx,
                                  height: 40,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9)),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      m['title'] ?? 'Materi ${mIdx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: selectedMateriIdx == mIdx
                                            ? const Color(0xFF2563EB)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        materis.isNotEmpty ? (materis[selectedMateriIdx]['title'] ?? 'Materi ${selectedMateriIdx + 1}') : 'Belum ada materi',
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. Judul Tugas
                            Text(
                              'Judul Tugas',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Masukkan judul tugas...',
                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 4. Tanggal Mulai & Selesai
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tanggal Mulai',
                                        style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: startDateController,
                                        keyboardType: TextInputType.number,
                                        style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(startDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
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
                                        'Tanggal Selesai / Tenggat',
                                        style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: endDateController,
                                        keyboardType: TextInputType.number,
                                        style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(endDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 5. Pengaturan Jenis Tugas
                            Text(
                              'Jenis Penugasan',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => assignmentType = 'individu'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: assignmentType == 'individu' ? const Color(0xFFDBEAFE) : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: assignmentType == 'individu' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Tugas Individu',
                                          style: AppTypography.buttonLabel(color: assignmentType == 'individu' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => assignmentType = 'kelompok'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: assignmentType == 'kelompok' ? const Color(0xFFDBEAFE) : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: assignmentType == 'kelompok' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Tugas Kelompok',
                                          style: AppTypography.buttonLabel(color: assignmentType == 'kelompok' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Mode Pengumpulan Tugas
                            Text(
                              'Mode Pengumpulan Tugas',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => tugasMode = 'text'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: tugasMode == 'text' ? const Color(0xFFDBEAFE) : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: tugasMode == 'text' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.notes_rounded, size: 16, color: tugasMode == 'text' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569))),
                                            const SizedBox(width: 6),
                                            Text('Jawaban Teks', style: AppTypography.buttonLabel(color: tugasMode == 'text' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => tugasMode = 'pdf'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: tugasMode == 'pdf' ? const Color(0xFFDBEAFE) : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: tugasMode == 'pdf' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.picture_as_pdf_rounded, size: 16, color: tugasMode == 'pdf' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569))),
                                            const SizedBox(width: 6),
                                            Text('File PDF', style: AppTypography.buttonLabel(color: tugasMode == 'pdf' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (tugasMode == 'text') ...[
                              Text(
                                'Teks Soal / Pertanyaan Tugas',
                                style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: taskTextController,
                                maxLines: 5,
                                style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Tulis pertanyaan / instruksi tugas di sini...',
                                  hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                  contentPadding: const EdgeInsets.all(14),
                                  fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'File / Nama Dokumen Modul Soal PDF',
                                style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: taskPdfController,
                                style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: modul_tugas_01.pdf',
                                  hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Floating Overlay: Pojok Kanan Atas Body
                      Positioned(
                        top: 12,
                        right: 18,
                        child: GestureDetector(
                          onTap: submitTask,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  isEditMode ? 'Perbarui' : 'Simpan',
                                  style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
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
        );
      },
    );
  },
),
);
}

  // -------------------------------------------------------------
  // 2. POPUP FORM BUAT / EDIT QUIZ (EXACT DESKTOP CLASSROOM MATCH)
  // -------------------------------------------------------------
  void _showCreateQuizDialog(BuildContext context, int initialMateriIdx, List currentStages) {
    openQuizPage(
      context,
      currentStages,
      initialMateriIdx: initialMateriIdx,
      customProjectId: widget.projectId,
      customProjectTitle: widget.projectTitle,
      customStageIdx: widget.stageIdx,
      customIsOwner: widget.isOwner,
      customAccentColor: widget.accentColor,
      customCardColor: widget.cardColor,
      openFromClassPage: false,
    );
  }

  void _showEditQuizDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    openQuizPage(
      context,
      currentStages,
      initialMateriIdx: materiIdx,
      taskToEdit: task,
      taskIdxToEdit: taskIdx,
      customProjectId: widget.projectId,
      customProjectTitle: widget.projectTitle,
      customStageIdx: widget.stageIdx,
      customIsOwner: widget.isOwner,
      customAccentColor: widget.accentColor,
      customCardColor: widget.cardColor,
      openFromClassPage: false,
    );
  }

  static void openQuizPage(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
    bool openFromClassPage = false,
    String? customProjectId,
    String? customProjectTitle,
    int? customStageIdx,
    bool? customIsOwner,
    Color? customAccentColor,
    Color? customCardColor,
  }) {
    if (stages.isEmpty) return;

    final String activeProjectId = customProjectId ?? '';
    final String activeProjectTitle = customProjectTitle ?? '';
    final bool activeIsOwner = customIsOwner ?? false;
    final Color activeAccentColor = customAccentColor ?? const Color(0xFF9333EA);
    final Color activeCardColor = customCardColor ?? const Color(0xFF1E293B);
    final int baseStageIdx = customStageIdx ?? 0;

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = baseStageIdx < stages.length ? baseStageIdx : 0;
    int selectedMateriIdx = initialMateriIdx;

    int countQuiz = 0;
    if (selectedStageIdx < stages.length) {
      final st = stages[selectedStageIdx] as Map;
      final mats = st['materis'] as List? ?? [];
      if (selectedMateriIdx < mats.length) {
        final mat = mats[selectedMateriIdx] as Map;
        final ts = mat['tasks'] as List? ?? [];
        for (var t in ts) {
          if ((t as Map)['type'] == 'quiz') countQuiz++;
        }
      }
    }
    final defaultQuizTitle = 'Quiz_${countQuiz + 1}';
    final titleController = TextEditingController(text: isEditMode ? (taskToEdit['title'] ?? '') : defaultQuizTitle);

    String initDateStr(String? raw) => raw ?? '';
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final startDateController = TextEditingController(
      text: isEditMode ? initDateStr(taskToEdit['startDate'] as String?) : todayStr,
    );
    final endDateController = TextEditingController(
      text: isEditMode ? initDateStr(taskToEdit['endDate'] as String?) : '',
    );

    void formatDateInput(TextEditingController ctrl) {
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
    List rawQuestions = isEditMode
        ? (taskToEdit['questions'] as List? ?? extraDataEdit['questions'] as List? ?? [])
        : [];
    List<Map<String, dynamic>> questionsList = rawQuestions.isNotEmpty
        ? rawQuestions.map((q) {
            final qMap = Map<String, dynamic>.from(q as Map);
            // normalize correct to A, B, C, D
            if (qMap['correct'] is int) {
              const opts = ['A', 'B', 'C', 'D'];
              int cIdx = qMap['correct'] as int;
              qMap['correct'] = (cIdx >= 0 && cIdx < opts.length) ? opts[cIdx] : 'A';
            }
            return qMap;
          }).toList()
        : [
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

    String quizTimeMode = isEditMode ? (extraDataEdit['quizTimeMode'] ?? 'set_time') : 'set_time';
    String quizTimeType = isEditMode ? (extraDataEdit['quizTimeType'] ?? 'per_quiz') : 'per_quiz';
    final quizTimeController = TextEditingController(
      text: isEditMode ? (extraDataEdit['quizTimeDuration'] ?? taskToEdit['duration']?.toString() ?? '15') : '15',
    );

    bool isSubmitting = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (dialogCtx) {
          final screenHeight = MediaQuery.of(dialogCtx).size.height;
          final screenWidth = MediaQuery.of(dialogCtx).size.width;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = AppColors.isDarkMode;
              final stageMap = stages[selectedStageIdx] as Map;
              final List materis = stageMap['materis'] as List? ?? [];
              if (selectedMateriIdx >= materis.length) {
                selectedMateriIdx = materis.isNotEmpty ? 0 : 0;
              }

              Future<void> submitQuiz() async {
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
                  'quizTimeMode': quizTimeMode,
                  'quizTimeType': quizTimeType,
                  'quizTimeDuration': quizTimeController.text.trim(),
                  'questions': questionsList,
                };

                final newQuiz = {
                  'id': isEditMode ? (taskToEdit['id'] ?? 'quiz_${DateTime.now().millisecondsSinceEpoch}') : 'quiz_${DateTime.now().millisecondsSinceEpoch}',
                  'type': 'quiz',
                  'title': title,
                  'startDate': startStr,
                  'endDate': endStr,
                  'duration': int.tryParse(quizTimeController.text.trim()) ?? 15,
                  'questions': questionsList,
                  'extraData': extraData,
                  'submissions': isEditMode ? (taskToEdit['submissions'] ?? []) : [],
                  'isDone': isEditMode ? (taskToEdit['isDone'] ?? false) : false,
                  'progress': isEditMode ? (taskToEdit['progress'] ?? 0) : 0,
                };

                setDialogState(() => isSubmitting = true);

                final List updatedStages = List.from(stages);
                final Map targetStage = Map.from(updatedStages[selectedStageIdx] as Map);
                final List targetMateris = List.from(targetStage['materis'] as List? ?? []);

                if (selectedMateriIdx < targetMateris.length) {
                  final Map targetMateri = Map.from(targetMateris[selectedMateriIdx] as Map);
                  final List currentMateriTasks = List.from(targetMateri['tasks'] as List? ?? []);

                  if (isEditMode) {
                    if (taskIdxToEdit != null && taskIdxToEdit < currentMateriTasks.length) {
                      currentMateriTasks[taskIdxToEdit] = newQuiz;
                    } else {
                      final int tIdx = currentMateriTasks.indexWhere((t) => t['id'] == taskToEdit['id']);
                      if (tIdx != -1) {
                        currentMateriTasks[tIdx] = newQuiz;
                      } else {
                        currentMateriTasks.add(newQuiz);
                      }
                    }
                  } else {
                    currentMateriTasks.add(newQuiz);
                  }

                  targetMateri['tasks'] = currentMateriTasks;
                  targetMateris[selectedMateriIdx] = targetMateri;
                  targetStage['materis'] = targetMateris;
                  updatedStages[selectedStageIdx] = targetStage;

                  await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(activeProjectId)
                      .update({'stages': updatedStages});
                }

                if (dialogCtx.mounted) {
                  if (openFromClassPage) {
                    Navigator.pushReplacement(
                      dialogCtx,
                      MaterialPageRoute(
                        builder: (_) => DetailCpPage(
                          projectId: activeProjectId,
                          projectTitle: activeProjectTitle,
                          stageIdx: selectedStageIdx,
                          isOwner: activeIsOwner,
                          accentColor: activeAccentColor,
                          cardColor: activeCardColor,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(dialogCtx);
                  }
                }
              }

              return Scaffold(
                backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                body: SafeArea(
                  child: Column(
                    children: [
                      // Header Atas Full Page (Transparan Blur Glassmorphic)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF1A1226) : const Color(0xFFF3E8FF)).withValues(alpha: isDark ? 0.90 : 0.85),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                            ),
                          child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E1A47) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.quiz_rounded,
                                color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF9333EA),
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
                                  isEditMode ? 'Edit Quiz' : 'Unggah / Buat Quiz',
                                  style: AppTypography.cardTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Atur soal quiz, batas waktu & jadwal pengerjaan',
                                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                    // Form Body Lengkap with Floating Overlay (Preview & Perbarui)
                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20.0, 52.0, 20.0, 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            // 1. Pilih Elemen
                            Text(
                              'Pilih Elemen Pembelajaran',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: '',
                              offset: const Offset(0, 48),
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              enabled: !isEditMode,
                              onSelected: (val) {
                                setDialogState(() {
                                  selectedStageIdx = val;
                                  selectedMateriIdx = 0;
                                });
                              },
                              itemBuilder: (context) => List.generate(stages.length, (idx) {
                                final st = stages[idx] as Map;
                                final bool isLast = idx == stages.length - 1;
                                return PopupMenuItem<int>(
                                  value: idx,
                                  height: 40,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9)),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      st['name'] ?? st['title'] ?? 'Elemen ${idx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: selectedStageIdx == idx
                                            ? const Color(0xFFD97706)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stages[selectedStageIdx]['name'] ?? stages[selectedStageIdx]['title'] ?? 'Elemen ${selectedStageIdx + 1}',
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Pilih Materi
                            Text(
                              'Pilih Materi',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: '',
                              offset: const Offset(0, 48),
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              enabled: !isEditMode && materis.isNotEmpty,
                              onSelected: (val) {
                                setDialogState(() {
                                  selectedMateriIdx = val;
                                });
                              },
                              itemBuilder: (context) => List.generate(materis.length, (mIdx) {
                                final m = materis[mIdx] as Map;
                                final bool isLast = mIdx == materis.length - 1;
                                return PopupMenuItem<int>(
                                  value: mIdx,
                                  height: 40,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9)),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      m['title'] ?? 'Materi ${mIdx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: selectedMateriIdx == mIdx
                                            ? const Color(0xFFD97706)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        materis.isNotEmpty ? (materis[selectedMateriIdx]['title'] ?? 'Materi ${selectedMateriIdx + 1}') : 'Belum ada materi',
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. Judul Quiz
                            Text(
                              'Judul Quiz',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Masukkan judul quiz...',
                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 4. Tanggal Mulai & Selesai
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tanggal Mulai',
                                        style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: startDateController,
                                        keyboardType: TextInputType.number,
                                        style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(startDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFD97706)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
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
                                        'Tanggal Selesai / Tenggat',
                                        style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: endDateController,
                                        keyboardType: TextInputType.number,
                                        style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(endDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFD97706)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // 5. Batasan Waktu Pengerjaan
                            Text(
                              'Batasan Waktu Pengerjaan',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => quizTimeMode = 'no_limit'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: quizTimeMode == 'no_limit' ? const Color(0xFFFEF3C7) : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: quizTimeMode == 'no_limit' ? const Color(0xFFD97706) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Tanpa Batas',
                                          style: AppTypography.buttonLabel(color: quizTimeMode == 'no_limit' ? const Color(0xFFB45309) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => quizTimeMode = 'set_time'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: quizTimeMode == 'set_time' ? const Color(0xFFFEF3C7) : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: quizTimeMode == 'set_time' ? const Color(0xFFD97706) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Set Batas Waktu',
                                          style: AppTypography.buttonLabel(color: quizTimeMode == 'set_time' ? const Color(0xFFB45309) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (quizTimeMode == 'set_time') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: quizTimeController,
                                      keyboardType: TextInputType.number,
                                      style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                      decoration: InputDecoration(
                                        hintText: 'Durasi...',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                        filled: true,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: quizTimeType,
                                        dropdownColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        items: [
                                          DropdownMenuItem(value: 'per_quiz', child: Text('Menit / Quiz', style: AppTypography.dropdownItem(color: isDark ? Colors.white : Colors.black87))),
                                          DropdownMenuItem(value: 'per_question', child: Text('Detik / Soal', style: AppTypography.dropdownItem(color: isDark ? Colors.white : Colors.black87))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => quizTimeType = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),

                            // 6. Daftar Pertanyaan Quiz
                            Text(
                              'Daftar Pertanyaan Quiz',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: questionsList.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, qIdx) {
                                final q = questionsList[qIdx];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Soal ${qIdx + 1}', style: AppTypography.buttonLabel(color: const Color(0xFFD97706), fontWeight: FontWeight.bold)),
                                          if (questionsList.length > 1)
                                            GestureDetector(
                                              onTap: () {
                                                setDialogState(() => questionsList.removeAt(qIdx));
                                              },
                                              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      TextFormField(
                                        initialValue: q['question'],
                                        onChanged: (v) => q['question'] = v,
                                        maxLines: null,
                                        minLines: 2,
                                        keyboardType: TextInputType.multiline,
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                        decoration: InputDecoration(
                                          hintText: 'Tulis pertanyaan soal quiz...',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          fillColor: isDark ? const Color(0xFF141416) : Colors.white,
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8)),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Tombol Tambah Gambar Soal
                                      if (q['image'] != null && (q['image'] as String).isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Stack(
                                            children: [
                                              Image.network(
                                                q['image'],
                                                height: 130,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, stack) => Container(
                                                  height: 70,
                                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                  child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                                                ),
                                              ),
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: GestureDetector(
                                                  onTap: () => setDialogState(() => q['image'] = ''),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ] else ...[
                                        InkWell(
                                          onTap: () {
                                            final imgCtrl = TextEditingController();
                                            showDialog(
                                              context: context,
                                              builder: (imgCtx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                                                title: Text('Masukkan URL Gambar', style: AppTypography.cardTitle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                                content: TextField(
                                                  controller: imgCtrl,
                                                  style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black),
                                                  decoration: InputDecoration(
                                                    hintText: 'https://...',
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(imgCtx), child: const Text('Batal')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                                                    onPressed: () {
                                                      if (imgCtrl.text.trim().isNotEmpty) {
                                                        setDialogState(() => q['image'] = imgCtrl.text.trim());
                                                      }
                                                      Navigator.pop(imgCtx);
                                                    },
                                                    child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFBFDBFE)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_photo_alternate_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF2563EB)),
                                                const SizedBox(width: 6),
                                                Text('Tambah Gambar Soal', style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],

                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: q['a'],
                                              onChanged: (v) => q['a'] = v,
                                              maxLines: null,
                                              minLines: 1,
                                              keyboardType: TextInputType.multiline,
                                              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan A',
                                                prefixText: 'A. ',
                                                prefixStyle: AppTypography.buttonLabel(color: (q['correct'] ?? 'A') == 'A' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontWeight: FontWeight.bold),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                fillColor: (q['correct'] ?? 'A') == 'A' ? (isDark ? const Color(0xFF143825) : const Color(0xFFDCFCE7)) : (isDark ? const Color(0xFF141416) : Colors.white),
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'A' ? const Color(0xFF86EFAC) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
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
                                              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan B',
                                                prefixText: 'B. ',
                                                prefixStyle: AppTypography.buttonLabel(color: (q['correct'] ?? 'A') == 'B' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontWeight: FontWeight.bold),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                fillColor: (q['correct'] ?? 'A') == 'B' ? (isDark ? const Color(0xFF143825) : const Color(0xFFDCFCE7)) : (isDark ? const Color(0xFF141416) : Colors.white),
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'B' ? const Color(0xFF86EFAC) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
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
                                              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan C',
                                                prefixText: 'C. ',
                                                prefixStyle: AppTypography.buttonLabel(color: (q['correct'] ?? 'A') == 'C' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontWeight: FontWeight.bold),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                fillColor: (q['correct'] ?? 'A') == 'C' ? (isDark ? const Color(0xFF143825) : const Color(0xFFDCFCE7)) : (isDark ? const Color(0xFF141416) : Colors.white),
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'C' ? const Color(0xFF86EFAC) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
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
                                              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan D',
                                                prefixText: 'D. ',
                                                prefixStyle: AppTypography.buttonLabel(color: (q['correct'] ?? 'A') == 'D' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontWeight: FontWeight.bold),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                fillColor: (q['correct'] ?? 'A') == 'D' ? (isDark ? const Color(0xFF143825) : const Color(0xFFDCFCE7)) : (isDark ? const Color(0xFF141416) : Colors.white),
                                                filled: true,
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: (q['correct'] ?? 'A') == 'D' ? const Color(0xFF86EFAC) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)), width: 1.5)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Kunci Jawaban
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text('Kunci Jawaban: ', style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Row(
                                                children: ['A', 'B', 'C', 'D'].map((opt) {
                                                  final bool isSelected = (q['correct'] ?? 'A') == opt;
                                                  return GestureDetector(
                                                    onTap: () => setDialogState(() => q['correct'] = opt),
                                                    child: Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? const Color(0xFFD97706) : (isDark ? const Color(0xFF141416) : Colors.white),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: isSelected ? const Color(0xFFD97706) : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0))),
                                                      ),
                                                      child: Text(
                                                        opt,
                                                        style: AppTypography.buttonLabel(color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF0F172A)), fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

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
                                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF7C2D12)),
                                label: Text('Tambah Soal', style: AppTypography.buttonLabel(color: const Color(0xFF7C2D12), fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDE68A),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Floating Overlay: Pojok Kanan Atas Body (Preview & Perbarui)
                      Positioned(
                        top: 12,
                        right: 18,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final title = titleController.text.trim().isNotEmpty
                                    ? titleController.text.trim()
                                    : 'Preview Kuis';
                                final durationStr = quizTimeController.text.trim().isNotEmpty
                                    ? quizTimeController.text.trim()
                                    : '15';
                                final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                final cpCardBg = activeCardColor;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MengerjakanQuizPage(
                                      title: title,
                                      durationStr: durationStr,
                                      startTime: startDateController.text.trim(),
                                      projectId: activeProjectId,
                                      studentUid: currentUid,
                                      taskKey: 'preview_${DateTime.now().millisecondsSinceEpoch}',
                                      onCompleted: () {},
                                      isTeacher: true,
                                      questions: questionsList,
                                      cpColor: cpCardBg,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, color: Color(0xFF9333EA), size: 16),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Preview',
                                      style: AppTypography.buttonLabel(color: const Color(0xFF9333EA), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: submitQuiz,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9333EA),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                                    const SizedBox(width: 4),
                                    Text(
                                      isEditMode ? 'Perbarui' : 'Simpan',
                                      style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

  // -------------------------------------------------------------
  // 3. POPUP FORM BUAT / EDIT MATERI (EXACT DESKTOP CLASSROOM MATCH)
  // -------------------------------------------------------------
  void _showCreateMateriDialog(BuildContext context, int initialMateriIdx, List currentStages) {
    openMateriItemPage(
      context,
      currentStages,
      initialMateriIdx: initialMateriIdx,
      customProjectId: widget.projectId,
      customProjectTitle: widget.projectTitle,
      customStageIdx: widget.stageIdx,
      customIsOwner: widget.isOwner,
      customAccentColor: widget.accentColor,
      customCardColor: widget.cardColor,
      openFromClassPage: false,
    );
  }

  void _showEditMateriItemDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    openMateriItemPage(
      context,
      currentStages,
      initialMateriIdx: materiIdx,
      taskToEdit: task,
      taskIdxToEdit: taskIdx,
      customProjectId: widget.projectId,
      customProjectTitle: widget.projectTitle,
      customStageIdx: widget.stageIdx,
      customIsOwner: widget.isOwner,
      customAccentColor: widget.accentColor,
      customCardColor: widget.cardColor,
      openFromClassPage: false,
    );
  }

  static void openMateriItemPage(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
    bool openFromClassPage = false,
    String? customProjectId,
    String? customProjectTitle,
    int? customStageIdx,
    bool? customIsOwner,
    Color? customAccentColor,
    Color? customCardColor,
  }) {
    if (stages.isEmpty) return;

    final String activeProjectId = customProjectId ?? '';
    final String activeProjectTitle = customProjectTitle ?? '';
    final bool activeIsOwner = customIsOwner ?? false;
    final Color activeAccentColor = customAccentColor ?? const Color(0xFF0284C7);
    final Color activeCardColor = customCardColor ?? const Color(0xFF1E293B);
    final int baseStageIdx = customStageIdx ?? 0;

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = baseStageIdx < stages.length ? baseStageIdx : 0;
    int selectedMateriIdx = initialMateriIdx;

    int countMateri = 0;
    if (selectedStageIdx < stages.length) {
      final st = stages[selectedStageIdx] as Map;
      final mats = st['materis'] as List? ?? [];
      if (selectedMateriIdx < mats.length) {
        final mat = mats[selectedMateriIdx] as Map;
        final ts = mat['tasks'] as List? ?? [];
        for (var t in ts) {
          if ((t as Map)['type'] == 'pdf') countMateri++;
        }
      }
    }
    final defaultMateriTitle = 'Materi_${countMateri + 1}';
    final titleController = TextEditingController(text: isEditMode ? (taskToEdit['title'] ?? '') : defaultMateriTitle);
    final descController = TextEditingController(text: isEditMode ? (taskToEdit['content'] ?? '') : '');
    final docController = TextEditingController(text: isEditMode ? (taskToEdit['docName'] ?? taskToEdit['doc'] ?? '') : '');

    bool isSubmitting = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (dialogCtx) {
          final screenHeight = MediaQuery.of(dialogCtx).size.height;
          final screenWidth = MediaQuery.of(dialogCtx).size.width;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = AppColors.isDarkMode;
              final stageMap = stages[selectedStageIdx] as Map;
              final List materis = stageMap['materis'] as List? ?? [];
              if (selectedMateriIdx >= materis.length) {
                selectedMateriIdx = materis.isNotEmpty ? 0 : 0;
              }

              Future<void> submitMateri() async {
                if (isSubmitting) return;
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Judul materi tidak boleh kosong!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final String docName = docController.text.trim();

                final newTask = {
                  'id': isEditMode ? (taskToEdit['id'] ?? 'task_${DateTime.now().millisecondsSinceEpoch}') : 'task_${DateTime.now().millisecondsSinceEpoch}',
                  'type': 'pdf',
                  'title': title,
                  'doc': docName,
                  'docName': docName,
                  'content': descController.text.trim(),
                  'isDone': isEditMode ? (taskToEdit['isDone'] ?? false) : false,
                  'progress': isEditMode ? (taskToEdit['progress'] ?? 0) : 0,
                };

                setDialogState(() => isSubmitting = true);

                final List updatedStages = List.from(stages);
                final Map targetStage = Map.from(updatedStages[selectedStageIdx] as Map);
                final List targetMateris = List.from(targetStage['materis'] as List? ?? []);

                if (selectedMateriIdx < targetMateris.length) {
                  final Map targetMateri = Map.from(targetMateris[selectedMateriIdx] as Map);
                  final List currentMateriTasks = List.from(targetMateri['tasks'] as List? ?? []);

                  if (isEditMode) {
                    if (taskIdxToEdit != null && taskIdxToEdit < currentMateriTasks.length) {
                      currentMateriTasks[taskIdxToEdit] = newTask;
                    } else {
                      final int tIdx = currentMateriTasks.indexWhere((t) => t['id'] == taskToEdit['id']);
                      if (tIdx != -1) {
                        currentMateriTasks[tIdx] = newTask;
                      } else {
                        currentMateriTasks.add(newTask);
                      }
                    }
                  } else {
                    currentMateriTasks.add(newTask);
                  }

                  targetMateri['tasks'] = currentMateriTasks;
                  targetMateris[selectedMateriIdx] = targetMateri;
                  targetStage['materis'] = targetMateris;
                  updatedStages[selectedStageIdx] = targetStage;

                  await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(activeProjectId)
                      .update({'stages': updatedStages});
                }

                if (dialogCtx.mounted) {
                  if (openFromClassPage) {
                    Navigator.pushReplacement(
                      dialogCtx,
                      MaterialPageRoute(
                        builder: (_) => DetailCpPage(
                          projectId: activeProjectId,
                          projectTitle: activeProjectTitle,
                          stageIdx: selectedStageIdx,
                          isOwner: activeIsOwner,
                          accentColor: activeAccentColor,
                          cardColor: activeCardColor,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(dialogCtx);
                  }
                }
              }

              return Scaffold(
                backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                body: SafeArea(
                  child: Column(
                    children: [
                      // Header Atas Full Page (Transparan Blur Glassmorphic)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF0F1C2E) : const Color(0xFFE0F2FE)).withValues(alpha: isDark ? 0.90 : 0.85),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                            ),
                          child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF102030) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
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
                                  isEditMode ? 'Edit Materi' : 'Unggah / Buat Materi',
                                  style: AppTypography.cardTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bagikan materi bacaan & modul pembelajaran',
                                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                    // Form Body Lengkap with Floating Overlay (Perbarui/Simpan)
                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20.0, 52.0, 20.0, 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            // 1. Pilih Elemen
                            Text(
                              'Pilih Elemen Pembelajaran',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: '',
                              offset: const Offset(0, 48),
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              enabled: !isEditMode,
                              onSelected: (val) {
                                setDialogState(() {
                                  selectedStageIdx = val;
                                  selectedMateriIdx = 0;
                                });
                              },
                              itemBuilder: (context) => List.generate(stages.length, (idx) {
                                final st = stages[idx] as Map;
                                final bool isLast = idx == stages.length - 1;
                                return PopupMenuItem<int>(
                                  value: idx,
                                  height: 40,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9)),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      st['name'] ?? st['title'] ?? 'Elemen ${idx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: selectedStageIdx == idx
                                            ? const Color(0xFF059669)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stages[selectedStageIdx]['name'] ?? stages[selectedStageIdx]['title'] ?? 'Elemen ${selectedStageIdx + 1}',
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Pilih Materi
                            Text(
                              'Pilih Materi',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: '',
                              offset: const Offset(0, 48),
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              enabled: !isEditMode && materis.isNotEmpty,
                              onSelected: (val) {
                                setDialogState(() {
                                  selectedMateriIdx = val;
                                });
                              },
                              itemBuilder: (context) => List.generate(materis.length, (mIdx) {
                                final m = materis[mIdx] as Map;
                                final bool isLast = mIdx == materis.length - 1;
                                return PopupMenuItem<int>(
                                  value: mIdx,
                                  height: 40,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9)),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      m['title'] ?? 'Materi ${mIdx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: selectedMateriIdx == mIdx
                                            ? const Color(0xFF059669)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        materis.isNotEmpty ? (materis[selectedMateriIdx]['title'] ?? 'Materi ${selectedMateriIdx + 1}') : 'Belum ada materi',
                                        style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. Judul Materi
                            Text(
                              'Judul Materi',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Masukkan judul materi...',
                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 4. Ringkasan / Konten Materi
                            Text(
                              'Ringkasan / Konten Materi',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 5,
                              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Tulis penjelasan materi di sini...',
                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.all(14),
                                fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 5. Nama Dokumen / PDF (Opsional)
                            Text(
                              'File Dokumen / Modul PDF (Opsional)',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: docController,
                              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Contoh: modul_pembelajaran_01.pdf',
                                hintStyle: AppTypography.timestamp(color: const Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                fillColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Floating Overlay: Pojok Kanan Atas Body (Perbarui/Simpan)
                      Positioned(
                        top: 12,
                        right: 18,
                        child: GestureDetector(
                          onTap: submitMateri,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  isEditMode ? 'Perbarui' : 'Simpan',
                                  style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
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
        );
      },
    );
  },
),
);
}

  Future<bool> _confirmDeleteMateri(
    BuildContext context,
    List stages,
    int mIdx,
    String mTitle,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Materi',
          style: AppTypography.cardTitle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus materi "$mTitle"? Semua tugas dan item di dalamnya akan ikut terhapus.',
          style: AppTypography.timestamp(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: AppTypography.timestamp(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Hapus', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final List updatedStages = List.from(stages);
      final Map<String, dynamic> targetStage = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
      final List rawMateris = List.from(targetStage['materis'] as List? ?? []);
      if (mIdx < rawMateris.length) {
        rawMateris.removeAt(mIdx);
        targetStage['materis'] = rawMateris;
        updatedStages[widget.stageIdx] = targetStage;
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({'stages': updatedStages});
      }
      return true;
    }
    return false;
  }

  Future<bool> _confirmDeleteTask(
    BuildContext context,
    List stages,
    int mIdx,
    int tIdx,
    String taskTitle,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Item',
          style: AppTypography.cardTitle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus item "$taskTitle"?',
          style: AppTypography.timestamp(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: AppTypography.timestamp(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Hapus', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final List updatedStages = List.from(stages);
      final Map<String, dynamic> targetStage = Map<String, dynamic>.from(updatedStages[widget.stageIdx] as Map);
      final List rawMateris = List.from(targetStage['materis'] as List? ?? []);
      if (mIdx < rawMateris.length) {
        final Map<String, dynamic> targetMateri = Map<String, dynamic>.from(rawMateris[mIdx] as Map);
        final List rawTasks = List.from(targetMateri['tasks'] as List? ?? []);
        if (tIdx < rawTasks.length) {
          rawTasks.removeAt(tIdx);
          targetMateri['tasks'] = rawTasks;
          rawMateris[mIdx] = targetMateri;
          targetStage['materis'] = rawMateris;
          updatedStages[widget.stageIdx] = targetStage;
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .update({'stages': updatedStages});
        }
      }
      return true;
    }
    return false;
  }
}

class _QuizFacetPatternPainter extends CustomPainter {
  final bool isDark;

  const _QuizFacetPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Color basePatternColor = isDark ? Colors.black : Colors.white;

    // Facet 1: Top-Right large corner polygon
    final Path facet1 = Path()
      ..moveTo(w * 0.58, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.88)
      ..lineTo(w * 0.76, h)
      ..lineTo(w * 0.65, h * 0.42)
      ..close();
    final Paint p1 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.09 : 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(facet1, p1);

    // Facet 2: Angular top wedge / notch
    final Path facet2 = Path()
      ..moveTo(w * 0.58, 0)
      ..lineTo(w * 0.78, 0)
      ..lineTo(w * 0.68, h * 0.38)
      ..lineTo(w * 0.48, h * 0.10)
      ..close();
    final Paint p2 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.15 : 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(facet2, p2);

    // Facet 3: Far right angled flank
    final Path facet3 = Path()
      ..moveTo(w * 0.78, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.60)
      ..lineTo(w * 0.80, h * 0.30)
      ..close();
    final Paint p3 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.20 : 0.36)
      ..style = PaintingStyle.fill;
    canvas.drawPath(facet3, p3);

    // Facet 4: Bottom right connecting shard
    final Path facet4 = Path()
      ..moveTo(w * 0.76, h)
      ..lineTo(w, h * 0.88)
      ..lineTo(w, h)
      ..close();
    final Paint p4 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.13 : 0.24)
      ..style = PaintingStyle.fill;
    canvas.drawPath(facet4, p4);
  }

  @override
  bool shouldRepaint(covariant _QuizFacetPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _TaskFacetPatternPainter extends CustomPainter {
  final bool isDark;

  const _TaskFacetPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Color basePatternColor = isDark ? Colors.black : Colors.white;

    // Shard 1: Diagonal sweep polygon
    final Path shard1 = Path()
      ..moveTo(w * 0.52, 0)
      ..lineTo(w * 0.82, 0)
      ..lineTo(w * 0.62, h)
      ..lineTo(w * 0.42, h)
      ..close();
    final Paint p1 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.08 : 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shard1, p1);

    // Shard 2: Top Right angular facet
    final Path shard2 = Path()
      ..moveTo(w * 0.76, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.72)
      ..lineTo(w * 0.70, h * 0.34)
      ..close();
    final Paint p2 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.15 : 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shard2, p2);

    // Shard 3: Bottom right origami triangle
    final Path shard3 = Path()
      ..moveTo(w * 0.62, h)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..close();
    final Paint p3 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.12 : 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shard3, p3);

    // Shard 4: Left subtle accent notch
    final Path shard4 = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w * 0.14, h * 0.42)
      ..lineTo(0, h * 0.62)
      ..close();
    final Paint p4 = Paint()
      ..color = basePatternColor.withValues(alpha: isDark ? 0.06 : 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shard4, p4);
  }

  @override
  bool shouldRepaint(covariant _TaskFacetPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

