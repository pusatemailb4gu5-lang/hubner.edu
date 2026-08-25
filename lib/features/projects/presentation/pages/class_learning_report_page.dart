import 'dart:ui';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/main.dart';
import 'class_page.dart';

class ClassLearningReportPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final int themeIndex;
  final Color accentColor;

  const ClassLearningReportPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.themeIndex = 0,
    this.accentColor = const Color(0xFFE11D48),
  });

  @override
  State<ClassLearningReportPage> createState() => _ClassLearningReportPageState();
}

class _ClassLearningReportPageState extends State<ClassLearningReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';

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
        final String ownerUid = projectData['ownerUid'] ?? '';
        final String gradeLevel = (projectData['gradeLevel'] ?? '').toString();
        final String major = (projectData['major'] ?? '').toString();
        final String classLabel = gradeLevel.isNotEmpty
            ? (major.isNotEmpty ? '$gradeLevel $major' : gradeLevel)
            : (major.isNotEmpty ? major : 'Kelas');

        int totalAllTasks = 0;
        for (var s in liveStages) {
          if (s is Map) {
            final materis = s['materis'] as List? ?? [];
            for (var m in materis) {
              if (m is Map) {
                final tasks = m['tasks'] as List? ?? [];
                totalAllTasks += tasks.length;
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
            final allDocs = membersSnap.data?.docs ?? [];
            final studentDocs = allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final role = (data['role'] ?? '').toString().toLowerCase();
              if (d.id == ownerUid) return false;
              if (role == 'guru' || role == 'teacher' || role == 'pengajar' || role == 'admin') {
                return false;
              }
              return true;
            }).toList();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('studentProgress')
                  .snapshots(),
              builder: (context, progressSnap) {
                final progressDocs = progressSnap.data?.docs ?? [];
                final Map<String, List<String>> studentCompletedTasksMap = {};
                for (var p in progressDocs) {
                  final pData = p.data() as Map<String, dynamic>? ?? {};
                  final List completed = pData['completedTasks'] as List? ?? [];
                  studentCompletedTasksMap[p.id] = List<String>.from(completed);
                }

                return Scaffold(
                  backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                  body: Stack(
                    children: [
                      NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverToBoxAdapter(
                              child: _buildHeroHeader(
                                context: context,
                                isDark: isDark,
                                classLabel: classLabel,
                                studentCount: studentDocs.length,
                                totalStages: liveStages.length,
                                totalTasks: totalAllTasks,
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _SliverTabHeaderDelegate(
                                isDark: isDark,
                                tabController: _tabController,
                              ),
                            ),
                          ];
                        },
                        body: TabBarView(
                          controller: _tabController,
                          children: [
                            // TAB 1: Rincian Capaian Elemen / Tahapan CP
                            _buildStagesReportTab(
                              liveStages: liveStages,
                              isDark: isDark,
                              totalStudents: studentDocs.length,
                              studentCompletedMap: studentCompletedTasksMap,
                            ),

                            // TAB 2: Rekapitulasi Progres Siswa
                            _buildStudentsReportTab(
                              studentDocs: studentDocs,
                              isDark: isDark,
                              totalTasks: totalAllTasks,
                              studentCompletedMap: studentCompletedTasksMap,
                            ),
                          ],
                        ),
                      ),

                      // Top Pinned Back Button
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: ClipOval(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.black.withValues(alpha: 0.35)
                                              : Colors.white.withValues(alpha: 0.75),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.15)
                                                : Colors.white.withValues(alpha: 0.6),
                                            width: 1.0,
                                          ),
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
        },
      );
    },
  );
}

  Widget _buildHeroHeader({
    required BuildContext context,
    required bool isDark,
    required String classLabel,
    required int studentCount,
    required int totalStages,
    required int totalTasks,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E1325) : const Color(0xFFF794BE),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ClassroomCardPatternPainter(
                patternIndex: widget.themeIndex,
                accentColor: widget.accentColor,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: Color(0xFFBE123C),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Laporan Hasil Belajar',
                              style: AppTypography.pageTitle(color: const Color(0xFF0F172A), fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                            Text(
                              widget.projectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.timestamp(color: const Color(0xFF4C0519), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFFBE123C)),
                            const SizedBox(width: 5),
                            Text(
                              '$studentCount Siswa',
                              style: AppTypography.buttonLabel(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_rounded, size: 15, color: Color(0xFFBE123C)),
                            const SizedBox(width: 5),
                            Text(
                              '$totalStages Tahapan · $totalTasks Tugas',
                              style: AppTypography.buttonLabel(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagesReportTab({
    required List liveStages,
    required bool isDark,
    required int totalStudents,
    required Map<String, List<String>> studentCompletedMap,
  }) {
    if (liveStages.isEmpty) {
      return Center(
        child: Text(
          'Belum ada tahapan capaian pembelajaran.',
          style: AppTypography.timestamp(color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: liveStages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stage = liveStages[index] as Map<String, dynamic>;
        final String name = stage['name'] ?? 'Elemen ${index + 1}';
        final String summary = (stage['summary'] ?? '').toString();
        final String status = (stage['status'] ?? 'proses').toString();
        final rawMateris = stage['materis'] as List? ?? [];

        int stageTasksCount = 0;
        final List<String> taskTitles = [];
        for (var m in rawMateris) {
          final tasks = (m as Map)['tasks'] as List? ?? [];
          stageTasksCount += tasks.length;
          for (var t in tasks) {
            if (t is Map) {
              taskTitles.add((t['title'] ?? 'Tugas').toString());
            }
          }
        }

        String statusLabel = 'Proses';
        Color statusBg = const Color(0xFFDBEAFE);
        Color statusFg = const Color(0xFF1D4ED8);
        if (status == 'selesai') {
          statusLabel = 'Selesai';
          statusBg = const Color(0xFFD1FAE5);
          statusFg = const Color(0xFF047857);
        } else if (status == 'akan_datang') {
          statusLabel = 'Akan Datang';
          statusBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
          statusFg = isDark ? Colors.white70 : Colors.black54;
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE7F3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (index + 1).toString().padLeft(2, '0'),
                        style: AppTypography.buttonLabel(color: const Color(0xFFBE123C), fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.timestamp(color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? statusFg.withValues(alpha: 0.2) : statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : statusFg, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222226) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSubStatItem(
                      label: 'Total Materi',
                      value: '${rawMateris.length}',
                      icon: Icons.menu_book_rounded,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                    Container(height: 24, width: 1, color: isDark ? Colors.white12 : Colors.black12),
                    _buildSubStatItem(
                      label: 'Tugas / Kuis',
                      value: '$stageTasksCount',
                      icon: Icons.assignment_turned_in_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
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

  Widget _buildStudentsReportTab({
    required List<DocumentSnapshot> studentDocs,
    required bool isDark,
    required int totalTasks,
    required Map<String, List<String>> studentCompletedMap,
  }) {
    if (studentDocs.isEmpty) {
      return Center(
        child: Text(
          'Belum ada siswa terdaftar di kelas ini.',
          style: AppTypography.timestamp(color: isDark ? Colors.white54 : Colors.black45),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: studentDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = studentDocs[index].data() as Map<String, dynamic>? ?? {};
        final String uid = studentDocs[index].id;
        final String name = (data['name'] ?? 'Siswa').toString();
        final String userId = (data['userId'] ?? 'ID').toString();
        final String gender = (data['gender'] ?? '').toString().toLowerCase();
        final bool isFemale = gender == 'perempuan' || gender == 'wanita' || gender == 'female';

        final Color avatarBorder = isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB);
        final List<String> completedList = studentCompletedMap[uid] ?? [];
        final int completedCount = completedList.length;
        final double progress = totalTasks > 0 ? (completedCount / totalTasks).clamp(0.0, 1.0) : 0.0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: avatarBorder,
                        width: 2.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                        style: AppTypography.cardTitle(color: const Color(0xFF0F172A), fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: $userId',
                          style: AppTypography.timestamp(color: isDark ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: progress >= 1.0
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$completedCount/$totalTasks Selesai',
                      style: AppTypography.buttonLabel(color: progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: AppTypography.timestamp(color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final TabController tabController;

  _SliverTabHeaderDelegate({
    required this.isDark,
    required this.tabController,
  });

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(28),
        ),
        child: TabBar(
          controller: tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: isDark ? const Color(0xFF27272A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          labelStyle: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppTypography.buttonLabel(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Capaian Elemen CP'),
            Tab(text: 'Rekap Progres Siswa'),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.tabController != tabController;
  }
}
