import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:ui';
import 'package:hubner/core/theme/app_colors.dart';
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

  @override
  State<DetailCpPage> createState() => _DetailCpPageState();
}

class _DetailCpPageState extends State<DetailCpPage> {
  final Set<String> _collapsedMateriKeys = {};
  bool _isEditMode = false;
  List _cachedStages = [];
  TextEditingController? _stageNameController;
  TextEditingController? _stageDescController;
  final Map<int, TextEditingController> _materiControllers = {};
  Timer? _debounceTimer;

  final List<Color> _sliderColors = const [
    Color(0xFFD6A5F8), // 1. Ungu Slider
    Color(0xFF9CC8FC), // 2. Biru Slider
    Color(0xFF7DE3D0), // 3. Tosca Slider
    Color(0xFFF7BD84), // 4. Orange Slider
    Color(0xFFF794BE), // 5. Pink Slider
  ];

  final List<Color> _softPastelColors = const [
    Color(0xFFEDE9FE), // Soft Lavender
    Color(0xFFE0F2FE), // Soft Blue
    Color(0xFFD1FAE5), // Soft Mint
    Color(0xFFFEF3C7), // Soft Kuning/Peach
    Color(0xFFFFE4E6), // Soft Pink
  ];

  @override
  void dispose() {
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
    final int badgeColorIdx = widget.stageIdx % _sliderColors.length;
    final Color cpCardBg = isDark
        ? _softPastelColors[badgeColorIdx]
        : _sliderColors[badgeColorIdx];
    final Color badgeTextCol = (badgeColorIdx == 0
        ? const Color(0xFF7C3AED)
        : badgeColorIdx == 1
            ? const Color(0xFF2563EB)
            : badgeColorIdx == 2
                ? const Color(0xFF059669)
                : badgeColorIdx == 3
                    ? const Color(0xFFC2410C)
                    : const Color(0xFFE11D48));

    final Color materiTopColor = Color.lerp(cpCardBg, Colors.white, 0.40)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Text(
          'Detail Capaian Pembelajaran',
          maxLines: 2,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.15,
          ),
        ),
        actions: [
          if (widget.isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _isEditMode
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
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7BD84),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF7BD84).withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Mode Edit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: ThreeDotsLoader());
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

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CP Header Hero Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cpCardBg,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Stack(
                          children: [
                            // Angka tanpa frame berupa Pattern besar menyatu dengan kartu
                            Positioned(
                              left: 14,
                              top: 2,
                              child: Text(
                                (widget.stageIdx + 1).toString().padLeft(2, '0'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 78,
                                  fontWeight: FontWeight.w900,
                                  color: badgeTextCol.withValues(alpha: 0.25),
                                  letterSpacing: -3.5,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            // Decorative Background Pattern Circles
                            Positioned(
                              right: -25,
                              top: -25,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 65,
                              bottom: -40,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.14),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -30,
                              bottom: -30,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row 1: Status Dropdown di pojok kanan atas
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      _buildStatusBadge(stageStatus, isDark, stages),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Row 2: Detail CP (Perbesar Judul CP)
                                        if (_isEditMode)
                                          TextField(
                                            controller: _stageNameController,
                                            minLines: 1,
                                            maxLines: null,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              height: 1.25,
                                              letterSpacing: -0.4,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                              hintText: 'Nama Capaian Pembelajaran',
                                              hintStyle: GoogleFonts.dmSans(color: Colors.black38, fontSize: 14),
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
                                        else
                                          Text(
                                            stageName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              height: 1.25,
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        // Row 3: Text kecil mapel di bawahnya (Lengkap, tanpa ...)
                                        Text(
                                          widget.projectTitle,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF334155).withValues(alpha: 0.8),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (stageDesc.isNotEmpty || _isEditMode) ...[
                                    const SizedBox(height: 14),
                                    // Deskripsi CP Lebih Putih & Bersih
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: _isEditMode ? 14 : 18,
                                        vertical: _isEditMode ? 12 : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.90),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: _isEditMode
                                              ? const Color(0xFF7C3AED)
                                              : Colors.white.withValues(alpha: 0.95),
                                          width: _isEditMode ? 1.5 : 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: _isEditMode
                                          ? TextField(
                                              controller: _stageDescController,
                                              maxLines: null,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF0F172A),
                                                height: 1.5,
                                              ),
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                                hintText: 'Tulis ringkasan capaian pembelajaran di sini...',
                                                hintStyle: GoogleFonts.dmSans(color: Colors.black38, fontSize: 14.0),
                                              ),
                                              onChanged: (v) => _debouncedAutoSave(stages),
                                            )
                                          : Text(
                                              stageDesc,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: const Color(0xFF0F172A),
                                                height: 1.5,
                                              ),
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Title & Add Materi Button (Bulat solid hitam)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Materi Pembelajaran',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (widget.isOwner)
                          GestureDetector(
                            onTap: () => _showAddMateriDialog(context, stages),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: isDark ? Colors.black : Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (materis.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum ada materi pada capaian pembelajaran ini.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: materis.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, mIdx) {
                          final materi = materis[mIdx];
                          final String mTitle = (materi['title'] ?? 'Materi ${mIdx + 1}').toString();
                          final List tasks = materi['tasks'] as List? ?? [];
                          final String materiKey = '${widget.stageIdx}_$mIdx';
                          final bool isExpanded = !_collapsedMateriKeys.contains(materiKey);

                          int tugasCount = 0;
                          int quizCount = 0;
                          int pdfCount = 0;

                          for (var t in tasks) {
                            final type = (t as Map)['type'] ?? 'tugas';
                            if (type == 'quiz') {
                              quizCount++;
                            } else if (type == 'pdf') {
                              pdfCount++;
                            } else {
                              tugasCount++;
                            }
                          }

                          return Dismissible(
                            key: ValueKey('materi_${widget.stageIdx}_${mIdx}_$mTitle'),
                            direction: widget.isOwner ? DismissDirection.endToStart : DismissDirection.none,
                            confirmDismiss: (direction) async {
                              return await _confirmDeleteMateri(context, stages, mIdx, mTitle);
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
                                      fontSize: 14.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF141416) : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Materi Header (Solid Soft Pastel)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: materiTopColor,
                                      borderRadius: isExpanded
                                          ? const BorderRadius.vertical(top: Radius.circular(28))
                                          : BorderRadius.circular(28),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (_collapsedMateriKeys.contains(materiKey)) {
                                            _collapsedMateriKeys.remove(materiKey);
                                          } else {
                                            _collapsedMateriKeys.add(materiKey);
                                          }
                                        });
                                      },
                                      borderRadius: isExpanded
                                          ? const BorderRadius.vertical(top: Radius.circular(28))
                                          : BorderRadius.circular(28),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _isEditMode
                                                  ? TextField(
                                                      controller: _getMateriController(mIdx, mTitle),
                                                      minLines: 1,
                                                      maxLines: null,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                        height: 1.3,
                                                      ),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        filled: true,
                                                        fillColor: Colors.white.withValues(alpha: 0.8),
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        hintText: 'Judul Materi...',
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
                                                  : Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                         Text(
                                                           mTitle,
                                                           style: GoogleFonts.plusJakartaSans(
                                                             fontSize: 15,
                                                             fontWeight: FontWeight.bold,
                                                             color: Colors.black87,
                                                           ),
                                                         ),
                                                         const SizedBox(height: 2),
                                                         Text(
                                                           quizCount > 0
                                                               ? '$tugasCount tugas · $quizCount quiz · $pdfCount materi'
                                                               : '$tugasCount tugas · $pdfCount materi',
                                                           style: GoogleFonts.dmSans(
                                                             fontSize: 14.0,
                                                             color: Colors.black54,
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                            ),
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Tasks / Items inside Materi as Chips with (+) at the end
                                  if (isExpanded) ...[
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF141416) : Colors.white,
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Align(
                                        alignment: tasks.isNotEmpty ? Alignment.centerLeft : Alignment.center,
                                        child: Wrap(
                                          alignment: tasks.isNotEmpty ? WrapAlignment.start : WrapAlignment.center,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            ...List.generate(tasks.length, (tIdx) {
                                              final task = Map<String, dynamic>.from(tasks[tIdx] as Map);
                                              final String originalTitle = task['title'] ?? 'Tugas';
                                              final String displayTitle = originalTitle.length > 10
                                                  ? '${originalTitle.substring(0, 10)}...'
                                                  : originalTitle;
                                              final String type = task['type'] ?? 'tugas';
                                              final String taskKey = '${widget.stageIdx}_${mIdx}_$tIdx';
                                              final bool isTaskDone = widget.isOwner
                                                  ? (task['isDone'] == true)
                                                  : completedTasks.contains(taskKey);

                                              IconData typeIcon;
                                              Color iconCol;
                                              Color iconBg;
                                              if (type == 'quiz') {
                                                typeIcon = Icons.quiz_outlined;
                                                iconCol = const Color(0xFFD97706);
                                                iconBg = const Color(0xFFFEF3C7);
                                              } else if (type == 'pdf') {
                                                typeIcon = Icons.menu_book_rounded;
                                                iconCol = const Color(0xFF059669);
                                                iconBg = const Color(0xFFD1FAE5);
                                              } else {
                                                typeIcon = Icons.assignment_outlined;
                                                iconCol = const Color(0xFF2563EB);
                                                iconBg = const Color(0xFFDBEAFE);
                                              }

                                              return GestureDetector(
                                                onTap: () {
                                                  if (widget.isOwner) {
                                                    if (type == 'pdf') {
                                                      _showEditMateriItemDialog(context, mIdx, tIdx, stages, task);
                                                    } else if (type == 'quiz') {
                                                      _showEditQuizDialog(context, mIdx, tIdx, stages, task);
                                                    } else {
                                                      _showEditTaskDialog(context, mIdx, tIdx, stages, task);
                                                    }
                                                  } else {
                                                    if (type == 'quiz') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => MengerjakanQuizPage(
                                                            title: originalTitle,
                                                            durationStr: task['duration']?.toString() ?? '15',
                                                            startTime: task['startDate']?.toString() ?? task['startTime']?.toString() ?? '',
                                                            projectId: widget.projectId,
                                                            studentUid: currentUid,
                                                            taskKey: '${widget.stageIdx}_${mIdx}_$tIdx',
                                                            onCompleted: () => _toggleTaskDone(stages, mIdx, tIdx),
                                                            isTeacher: false,
                                                            questions: (task['questions'] as List?)
                                                                ?.map((e) => Map<String, dynamic>.from(e as Map))
                                                                .toList(),
                                                            cpColor: cpCardBg,
                                                          ),
                                                        ),
                                                      );
                                                    } else {
                                                      _toggleTaskDone(stages, mIdx, tIdx);
                                                    }
                                                  }
                                                },
                                                onDoubleTap: () {
                                                  if (widget.isOwner) {
                                                    if (type == 'pdf') {
                                                      _showEditMateriItemDialog(context, mIdx, tIdx, stages, task);
                                                    } else if (type == 'quiz') {
                                                      _showEditQuizDialog(context, mIdx, tIdx, stages, task);
                                                    } else {
                                                      _showEditTaskDialog(context, mIdx, tIdx, stages, task);
                                                    }
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                                                    borderRadius: BorderRadius.circular(30),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 26,
                                                        height: 26,
                                                        decoration: BoxDecoration(
                                                          color: iconBg,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Center(
                                                          child: Icon(typeIcon, color: iconCol, size: 14),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        displayTitle,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 14.0,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                          decoration: isTaskDone ? TextDecoration.lineThrough : null,
                                                        ),
                                                      ),
                                                      if (_isEditMode && widget.isOwner) ...[
                                                        const SizedBox(width: 8),
                                                        GestureDetector(
                                                          onTap: () => _showEditTaskDialog(context, mIdx, tIdx, stages, task),
                                                          child: const Icon(
                                                            Icons.edit_outlined,
                                                            color: Colors.grey,
                                                            size: 15,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        GestureDetector(
                                                          onTap: () => _confirmDeleteTask(context, stages, mIdx, tIdx, originalTitle),
                                                          child: const Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.redAccent,
                                                            size: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                            // Tombol (+) simetris lingkaran warna hitam text putih
                                            if (widget.isOwner)
                                              GestureDetector(
                                                onTap: () => _showAddTaskChoice(context, mIdx, stages),
                                                child: Container(
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.white : Colors.black,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.add_rounded,
                                                      color: isDark ? Colors.black : Colors.white,
                                                      size: 14,
                                                    ),
                                                  ),
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
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
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
    // Status Mobile Match: Proses = Kuning/Orange, Selesai = Hijau, Akan Datang = Abu
    Color statusBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    Color statusFg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    if (status == 'selesai' || status == 'Selesai') {
      displayLabel = 'Selesai';
      statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      statusFg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    } else if (status == 'akan_datang' || status == 'Akan Datang') {
      displayLabel = 'Akan Datang';
      statusBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
      statusFg = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF475569);
    } else {
      displayLabel = 'Proses';
      statusBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      statusFg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    }

    if (!widget.isOwner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
        child: Text(
          displayLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            color: statusFg,
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Pilih Status Elemen',
      offset: const Offset(0, 36),
      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
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
          height: 38,
          padding: EdgeInsets.zero,
          child: Container(
            height: 38,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'Proses',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'selesai',
          height: 38,
          padding: EdgeInsets.zero,
          child: Container(
            height: 38,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'Selesai',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'akan_datang',
          height: 38,
          padding: EdgeInsets.zero,
          child: Container(
            height: 38,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Akan Datang',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.8),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: statusFg,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: statusFg,
              size: 18,
            ),
          ],
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
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: AppColors.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          autofocus: true,
          style: GoogleFonts.dmSans(
            color: AppColors.isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Contoh: Materi 1: Pengenalan Konsep',
            hintStyle: GoogleFonts.dmSans(color: Colors.black38),
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

  void _showAddTaskChoice(BuildContext context, int materiIdx, List currentStages) {
    final bool isDark = AppColors.isDarkMode;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.75 : 0.55),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogCtx, animation, secondaryAnimation, child) {
        final bounceCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeInCubic,
        );

        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * animation.value,
            sigmaY: 8 * animation.value,
          ),
          child: Center(
            child: ScaleTransition(
              scale: bounceCurve,
              child: Material(
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Tugas (Solid Biru Slider / Dark Soft Pastel Blue)
                    _buildFramelessCircleItem(
                      label: 'Tugas',
                      icon: Icons.assignment_outlined,
                      circleBg: isDark ? const Color(0xFFE0F2FE) : const Color(0xFF9CC8FC),
                      contentFg: isDark ? const Color(0xFF0284C7) : const Color(0xFF1E3A8A),
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        _showCreateTugasDialog(context, materiIdx, currentStages);
                      },
                    ),
                    const SizedBox(width: 18),
                    // 2. Quiz (Solid Kuning-Orange Slider / Dark Soft Pastel Kuning)
                    _buildFramelessCircleItem(
                      label: 'Quiz',
                      icon: Icons.quiz_outlined,
                      circleBg: isDark ? const Color(0xFFFEF3C7) : const Color(0xFFF7BD84),
                      contentFg: isDark ? const Color(0xFFD97706) : const Color(0xFF7C2D12),
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        _showCreateQuizDialog(context, materiIdx, currentStages);
                      },
                    ),
                    const SizedBox(width: 18),
                    // 3. Materi (Solid Tosca Slider / Dark Soft Pastel Mint)
                    _buildFramelessCircleItem(
                      label: 'Materi',
                      icon: Icons.menu_book_rounded,
                      circleBg: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF7DE3D0),
                      contentFg: isDark ? const Color(0xFF059669) : const Color(0xFF064E3B),
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        _showCreateMateriDialog(context, materiIdx, currentStages);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFramelessCircleItem({
    required String label,
    required IconData icon,
    required Color circleBg,
    required Color contentFg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: circleBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: circleBg.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: contentFg,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w800,
                color: contentFg,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
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
    _openTaskDialog(context, currentStages, initialMateriIdx: initialMateriIdx);
  }

  void _showEditTugasDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    _openTaskDialog(context, currentStages, initialMateriIdx: materiIdx, taskToEdit: task, taskIdxToEdit: taskIdx);
  }

  void _openTaskDialog(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
  }) {
    if (stages.isEmpty) return;

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = widget.stageIdx < stages.length ? widget.stageIdx : 0;
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

    showDialog(
      context: context,
      barrierDismissible: false,
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
                    .doc(widget.projectId)
                    .update({'stages': updatedStages});
              }

              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                width: screenWidth > 680 ? 640 : screenWidth * 0.94,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    // Header Atas Persis Jadwal Pembelajaran (Overlay Blue Theme)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC8FC), // Soft Blue matching Tugas
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
                                Icons.assignment_rounded,
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
                                  isEditMode ? 'Edit Tugas' : 'Unggah / Buat Tugas',
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
                                  'Atur tugas, tenggat waktu & instruksi',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
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
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: 'Pilih Elemen',
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
                                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: 'Pilih Materi',
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
                                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Masukkan judul tugas...',
                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: startDateController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(startDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: endDateController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(endDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                              style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
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
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: assignmentType == 'individu' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569))),
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
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: assignmentType == 'kelompok' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569))),
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
                              style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
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
                                            Text('Jawaban Teks', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: tugasMode == 'text' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569)))),
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
                                            Text('File PDF', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: tugasMode == 'pdf' ? const Color(0xFF1D4ED8) : (isDark ? Colors.white70 : const Color(0xFF475569)))),
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
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: taskTextController,
                                maxLines: 5,
                                style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Tulis pertanyaan / instruksi tugas di sini...',
                                  hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: taskPdfController,
                                style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: modul_tugas_01.pdf',
                                  hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  isEditMode ? 'Perbarui' : 'Simpan',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Action Persis Round
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: submitTask,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F92F7),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F92F7).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: const ThreeDotsLoader(),
                              )
                            : Text(
                                isEditMode ? 'Perbarui Tugas' : 'Simpan Tugas',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
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

  // -------------------------------------------------------------
  // 2. POPUP FORM BUAT / EDIT QUIZ (EXACT DESKTOP CLASSROOM MATCH)
  // -------------------------------------------------------------
  void _showCreateQuizDialog(BuildContext context, int initialMateriIdx, List currentStages) {
    _openQuizDialog(context, currentStages, initialMateriIdx: initialMateriIdx);
  }

  void _showEditQuizDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    _openQuizDialog(context, currentStages, initialMateriIdx: materiIdx, taskToEdit: task, taskIdxToEdit: taskIdx);
  }

  void _openQuizDialog(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
int? taskIdxToEdit,
  }) {
    if (stages.isEmpty) return;

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = widget.stageIdx < stages.length ? widget.stageIdx : 0;
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

    showDialog(
      context: context,
      barrierDismissible: false,
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
                    .doc(widget.projectId)
                    .update({'stages': updatedStages});
              }

              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                width: screenWidth > 680 ? 640 : screenWidth * 0.94,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    // Header Atas Persis Jadwal Pembelajaran (Overlay Quiz Peach/Orange Theme)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7BD84), // Soft Peach/Orange matching Quiz
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
                                Icons.quiz_rounded,
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
                                  isEditMode ? 'Edit Quiz' : 'Unggah / Buat Quiz',
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
                                  'Atur soal pilihan ganda, durasi & waktu',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
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
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: 'Pilih Elemen',
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
                                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: 'Pilih Materi',
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
                                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Masukkan judul quiz...',
                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: startDateController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(startDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: endDateController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                                        onChanged: (_) => formatDateInput(endDateController),
                                        decoration: InputDecoration(
                                          hintText: 'HH/BB/TTTT',
                                          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                              style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
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
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: quizTimeMode == 'no_limit' ? const Color(0xFFB45309) : (isDark ? Colors.white70 : const Color(0xFF475569))),
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
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: quizTimeMode == 'set_time' ? const Color(0xFFB45309) : (isDark ? Colors.white70 : const Color(0xFF475569))),
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
                                      style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
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
                                          DropdownMenuItem(value: 'per_quiz', child: Text('Menit / Quiz', style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87))),
                                          DropdownMenuItem(value: 'per_question', child: Text('Detik / Soal', style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87))),
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
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
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
                                          Text('Soal ${qIdx + 1}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0, color: const Color(0xFFD97706))),
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
                                        style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
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
                                                title: Text('Masukkan URL Gambar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                                                content: TextField(
                                                  controller: imgCtrl,
                                                  style: GoogleFonts.dmSans(color: isDark ? Colors.white : Colors.black),
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
                                                Text('Tambah Gambar Soal', style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF2563EB))),
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
                                              style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan A',
                                                prefixText: 'A. ',
                                                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: (q['correct'] ?? 'A') == 'A' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontSize: 14.0),
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
                                              style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan B',
                                                prefixText: 'B. ',
                                                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: (q['correct'] ?? 'A') == 'B' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontSize: 14.0),
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
                                              style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan C',
                                                prefixText: 'C. ',
                                                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: (q['correct'] ?? 'A') == 'C' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontSize: 14.0),
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
                                              style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                hintText: 'Pilihan D',
                                                prefixText: 'D. ',
                                                prefixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: (q['correct'] ?? 'A') == 'D' ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF0F172A)), fontSize: 14.0),
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
                                              Text('Kunci Jawaban: ', style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
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
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 14.0,
                                                          fontWeight: FontWeight.bold,
                                                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                                                        ),
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
                                label: Text('Tambah Soal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF7C2D12))),
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
                                final cpCardBg = widget.cardColor;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MengerjakanQuizPage(
                                      title: title,
                                      durationStr: durationStr,
                                      startTime: startDateController.text.trim(),
                                      projectId: widget.projectId,
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, color: Color(0xFFD97706), size: 16),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Preview',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFD97706),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.0,
                                      ),
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
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                                    const SizedBox(width: 4),
                                    Text(
                                      isEditMode ? 'Perbarui' : 'Simpan',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.0,
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
                ),

                // Bottom Action Persis Round
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: submitQuiz,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: const ThreeDotsLoader(),
                              )
                            : Text(
                                isEditMode ? 'Perbarui Quiz' : 'Simpan Quiz',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
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

  // -------------------------------------------------------------
  // 3. POPUP FORM BUAT / EDIT MATERI (EXACT DESKTOP CLASSROOM MATCH)
  // -------------------------------------------------------------
  void _showCreateMateriDialog(BuildContext context, int initialMateriIdx, List currentStages) {
    _openMateriItemDialog(context, currentStages, initialMateriIdx: initialMateriIdx);
  }

  void _showEditMateriItemDialog(BuildContext context, int materiIdx, int taskIdx, List currentStages, Map<String, dynamic> task) {
    _openMateriItemDialog(context, currentStages, initialMateriIdx: materiIdx, taskToEdit: task, taskIdxToEdit: taskIdx);
  }

  void _openMateriItemDialog(
    BuildContext context,
    List stages, {
    int initialMateriIdx = 0,
    Map<String, dynamic>? taskToEdit,
    int? taskIdxToEdit,
  }) {
    if (stages.isEmpty) return;

    final bool isEditMode = taskToEdit != null;
    int selectedStageIdx = widget.stageIdx < stages.length ? widget.stageIdx : 0;
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

    showDialog(
      context: context,
      barrierDismissible: false,
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
                    .doc(widget.projectId)
                    .update({'stages': updatedStages});
              }

              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                width: screenWidth > 680 ? 640 : screenWidth * 0.94,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    // Header Atas Persis Jadwal Pembelajaran (Overlay Materi Mint/Tosca Theme)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7DE3D0), // Soft Mint/Tosca matching Materi
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
                                Icons.menu_book_rounded,
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
                                  isEditMode ? 'Edit Materi' : 'Unggah / Buat Materi',
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
                                  'Bagikan materi bacaan & modul pembelajaran',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
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
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: 'Pilih Elemen',
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
                                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<int>(
                              tooltip: 'Pilih Materi',
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
                                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Masukkan judul materi...',
                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 5,
                              style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Tulis penjelasan materi di sini...',
                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: docController,
                              style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Contoh: modul_pembelajaran_01.pdf',
                                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  isEditMode ? 'Perbarui' : 'Simpan',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Action Persis Round
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: submitMateri,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: const ThreeDotsLoader(),
                              )
                            : Text(
                                isEditMode ? 'Perbarui Materi' : 'Simpan Materi',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
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
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus materi "$mTitle"? Semua tugas dan item di dalamnya akan ikut terhapus.',
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.dmSans(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Hapus', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus item "$taskTitle"?',
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.dmSans(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Hapus', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
