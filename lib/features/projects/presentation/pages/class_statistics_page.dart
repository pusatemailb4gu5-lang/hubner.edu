import 'dart:math' as math;
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'class_page.dart';

class ClassStatisticsPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final int themeIndex;
  final Color accentColor;
  final Color cardColor;

  const ClassStatisticsPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.themeIndex = 0,
    this.accentColor = const Color(0xFF6366F1),
    this.cardColor = const Color(0xFFD6A5F8),
  });

  @override
  State<ClassStatisticsPage> createState() => _ClassStatisticsPageState();
}

class _ClassStatisticsPageState extends State<ClassStatisticsPage>
    with SingleTickerProviderStateMixin {
  int _selectedFilterIdx = 0; // 0: Mingguan, 1: Bulanan, 2: Semester
  late AnimationController _animController;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
      builder: (context, projectSnap) {
        if (projectSnap.connectionState == ConnectionState.waiting && !projectSnap.hasData) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            body: const SizedBox.shrink(),
          );
        }

        final projectData = (projectSnap.data?.data() as Map<String, dynamic>?) ?? {};
        final liveStages = projectData['stages'] as List? ?? [];
        final String gradeLevel = (projectData['gradeLevel'] ?? '').toString();
        final String major = (projectData['major'] ?? '').toString();
        final String classLabel = gradeLevel.isNotEmpty
            ? (major.isNotEmpty ? '$gradeLevel $major' : gradeLevel)
            : (major.isNotEmpty ? major : 'Kelas');

        int totalMateris = 0;
        int totalTasks = 0;
        int totalQuiz = 0;
        int completedStagesCount = 0;

        for (var s in liveStages) {
          if (s is Map) {
            final String status = (s['status'] ?? '').toString().toLowerCase();
            if (status == 'selesai') completedStagesCount++;

            final materis = s['materis'] as List? ?? [];
            totalMateris += materis.length;
            for (var m in materis) {
              if (m is Map) {
                final tasks = m['tasks'] as List? ?? [];
                for (var t in tasks) {
                  if (t is Map) {
                    final type = (t['type'] ?? 'tugas').toString().toLowerCase();
                    if (type == 'quiz') {
                      totalQuiz++;
                    } else {
                      totalTasks++;
                    }
                  }
                }
              }
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('projectIds', arrayContains: widget.projectId)
              .snapshots(),
          builder: (context, membersSnap) {
            final allUserDocs = membersSnap.data?.docs ?? [];
            final ownerUid = projectData['ownerUid'] ?? '';
            final studentDocs = allUserDocs.where((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final role = (data['role'] ?? '').toString().toLowerCase();
              if (d.id == ownerUid) return false;
              if (role == 'guru' || role == 'teacher' || role == 'pengajar' || role == 'admin') {
                return false;
              }
              return true;
            }).toList();

            final int totalSiswa = studentDocs.length;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('studentProgress')
                  .snapshots(),
              builder: (context, progressSnap) {
                final progressDocs = progressSnap.data?.docs ?? [];
                int totalSubmittedTasks = 0;
                for (var doc in progressDocs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final List completed = data['completedTasks'] as List? ?? [];
                  totalSubmittedTasks += completed.length;
                }

                final int totalPossibleSubmissions = totalSiswa * (totalTasks + totalQuiz);
                final double overallCompletionPercent = totalPossibleSubmissions > 0
                    ? (totalSubmittedTasks / totalPossibleSubmissions).clamp(0.0, 1.0)
                    : (liveStages.isNotEmpty ? (completedStagesCount / liveStages.length).clamp(0.0, 1.0) : 0.0);

                // Per-filter calculations
                final int displayedScore = (overallCompletionPercent * 100).toInt();

                return Scaffold(
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Navigation & Actions Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _BouncyButton(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    size: 22,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, size: 16, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$classLabel · $totalSiswa Siswa',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Header Title (Learning Pathway Status)
                          Text(
                            'Learning\nPathway Status',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.projectName,
                            style: GoogleFonts.dmSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Top 2 Bouncy Pattern Cards (Achieved & Final Score / Tasks)
                          Row(
                            children: [
                              // Card 1: Achieved Stages (Mint / Tosca Slider Tone)
                              Expanded(
                                child: _BouncyCard(
                                  cardBg: isDark ? const Color(0xFF11453B) : const Color(0xFFD1FAE5),
                                  patternIndex: 2,
                                  accentColor: const Color(0xFF0D9488),
                                  icon: Icons.verified_outlined,
                                  title: 'Achieved',
                                  value: '$completedStagesCount',
                                  onArrowTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$completedStagesCount dari ${liveStages.length} tahapan capaian telah diselesaikan.'),
                                        backgroundColor: const Color(0xFF0D9488),
                                      ),
                                    );
                                  },
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Card 2: Tasks & Score (Yellow / Orange Slider Tone)
                              Expanded(
                                child: _BouncyCard(
                                  cardBg: isDark ? const Color(0xFF332014) : const Color(0xFFFEF3C7),
                                  patternIndex: 3,
                                  accentColor: const Color(0xFFEA580C),
                                  icon: Icons.emoji_events_outlined,
                                  title: 'Final Score',
                                  value: '${totalTasks + totalQuiz}',
                                  onArrowTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Total $totalTasks Tugas dan $totalQuiz Kuis aktif di kelas.'),
                                        backgroundColor: const Color(0xFFEA580C),
                                      ),
                                    );
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Time Filter Floating Pills (Weekly, Month, Year)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Row(
                              children: [
                                _buildFilterPill('Weekly', 0, isDark),
                                _buildFilterPill('Month', 1, isDark),
                                _buildFilterPill('Year', 2, isDark),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Big Animated Progress Gauge Card (Round Centerpiece in Purple Tone)
                          _BouncyContainer(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF261938) : const Color(0xFFD6A5F8),
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Subtle Background Decorative Pattern
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: ClassroomCardPatternPainter(
                                        patternIndex: 0,
                                        accentColor: const Color(0xFF7E22CE),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Card Header
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.speed_rounded,
                                                  color: Color(0xFF6B21A8),
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Progress',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.more_vert_rounded,
                                              color: Color(0xFF0F172A),
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 24),

                                      // Semi-circle Speedometer Gauge Meter
                                      Center(
                                        child: AnimatedBuilder(
                                          animation: _gaugeAnimation,
                                          builder: (context, child) {
                                            final currentProgress = overallCompletionPercent * _gaugeAnimation.value;
                                            return CustomPaint(
                                              size: const Size(260, 160),
                                              painter: _SpeedometerGaugePainter(
                                                progress: currentProgress,
                                                isDark: isDark,
                                              ),
                                              child: SizedBox(
                                                width: 260,
                                                height: 160,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '$displayedScore',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 42,
                                                        fontWeight: FontWeight.w900,
                                                        color: const Color(0xFF0F172A),
                                                        letterSpacing: -1.0,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Score',
                                                      style: GoogleFonts.dmSans(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF4C1D95),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Additional Metrics Breakdown (Blue & Pink Cards)
                          Row(
                            children: [
                              // Total Materi Card (Blue Slider Tone)
                              Expanded(
                                child: _BouncyCard(
                                  cardBg: isDark ? const Color(0xFF172E54) : const Color(0xFF9CC8FC),
                                  patternIndex: 1,
                                  accentColor: const Color(0xFF1D4ED8),
                                  icon: Icons.menu_book_rounded,
                                  title: 'Materi Belajar',
                                  value: '$totalMateris',
                                  onArrowTap: () {},
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Laporan / Siswa Aktif Card (Pink Slider Tone)
                              Expanded(
                                child: _BouncyCard(
                                  cardBg: isDark ? const Color(0xFF4C1D38) : const Color(0xFFF794BE),
                                  patternIndex: 4,
                                  accentColor: const Color(0xFFBE123C),
                                  icon: Icons.people_alt_rounded,
                                  title: 'Siswa Aktif',
                                  value: '$totalSiswa',
                                  onArrowTap: () {},
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),

                          // Section Title: Detail Tahapan Pembelajaran
                          Text(
                            'Distribusi Tahapan Pembelajaran',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // List of Stages with Bouncy Design
                          if (liveStages.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(28),
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
                            ...liveStages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final stage = entry.value as Map<String, dynamic>;
                              final String name = stage['name'] ?? 'Elemen ${index + 1}';
                              final String status = (stage['status'] ?? 'proses').toString();
                              final rawMateris = stage['materis'] as List? ?? [];

                              int stageTasks = 0;
                              for (var m in rawMateris) {
                                final tasks = (m as Map)['tasks'] as List? ?? [];
                                stageTasks += tasks.length;
                              }

                              const List<Color> stageColors = [
                                Color(0xFFD6A5F8), // Ungu
                                Color(0xFF9CC8FC), // Biru
                                Color(0xFF7DE3D0), // Tosca
                                Color(0xFFF7BD84), // Orange
                                Color(0xFFF794BE), // Pink
                              ];
                              final Color itemColor = stageColors[index % stageColors.length];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _BouncyContainer(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: itemColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              (index + 1).toString().padLeft(2, '0'),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${rawMateris.length} Materi · $stageTasks Tugas/Kuis',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14.0,
                                                  color: isDark ? Colors.white54 : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: status == 'selesai'
                                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                : const Color(0xFF6366F1).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            status == 'selesai' ? 'Selesai' : 'Aktif',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'selesai'
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPill(String label, int index, bool isDark) {
    final bool isSelected = _selectedFilterIdx == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilterIdx = index;
          });
          _animController.reset();
          _animController.forward();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BouncyCard extends StatefulWidget {
  final Color cardBg;
  final int patternIndex;
  final Color accentColor;
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onArrowTap;
  final bool isDark;

  const _BouncyCard({
    required this.cardBg,
    required this.patternIndex,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.value,
    required this.onArrowTap,
    required this.isDark,
  });

  @override
  State<_BouncyCard> createState() => _BouncyCardState();
}

class _BouncyCardState extends State<_BouncyCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onArrowTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          height: 155,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ClassroomCardPatternPainter(
                    patternIndex: widget.patternIndex,
                    accentColor: widget.accentColor,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Icon Circle + Title
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: const Color(0xFF0F172A), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Bottom Row: Big Value + Arrow Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -1.0,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.north_east_rounded,
                            color: Color(0xFF0F172A),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
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

class _BouncyContainer extends StatefulWidget {
  final Widget child;

  const _BouncyContainer({required this.child});

  @override
  State<_BouncyContainer> createState() => _BouncyContainerState();
}

class _BouncyContainerState extends State<_BouncyContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {},
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncyButton({required this.child, required this.onTap});

  @override
  State<_BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<_BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _SpeedometerGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final bool isDark;

  _SpeedometerGaugePainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width * 0.44;

    const startAngle = math.pi * 0.85; // ~153 deg
    const sweepAngle = math.pi * 1.30; // ~234 deg

    // 1. Thick Outer White Background Arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Inner Dashed Guideline Arc
    final dashPaint = Paint()
      ..color = const Color(0xFF4C1D95).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const int totalDashes = 18;
    for (int i = 0; i <= totalDashes; i++) {
      final double dashAngle = startAngle + (sweepAngle * (i / totalDashes));
      final double innerR = radius - 20;
      final double outerR = radius - 14;
      final p1 = Offset(center.dx + innerR * math.cos(dashAngle), center.dy + innerR * math.sin(dashAngle));
      final p2 = Offset(center.dx + outerR * math.cos(dashAngle), center.dy + outerR * math.sin(dashAngle));
      canvas.drawLine(p1, p2, dashPaint);
    }

    // 3. Progress Active Arc (Golden Yellow / Vibrant Accent)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = const Color(0xFFFDE047) // Vibrant Yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round;

      final activeSweep = sweepAngle * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
