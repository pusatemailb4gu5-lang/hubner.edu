import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:hubner/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:hubner/features/projects/presentation/pages/class_page.dart';
import 'package:hubner/features/projects/presentation/pages/desktop_classroom_page.dart';
import 'package:hubner/features/home/presentation/widgets/home_card_painters.dart';
import 'package:hubner/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_editor_page.dart';

class StudentHomePage extends StatefulWidget {
  final Function(int index, {String? projectId})? onNavigateTab;
  const StudentHomePage({super.key, this.onNavigateTab});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  DateTime _selectedCalendarDay = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  int _quizCardPage = 0;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final ScrollController _homeScrollController = ScrollController();
  final Set<String> _deletedProjectIds = {};
  List<DocumentSnapshot> _lastProjectDocs = [];

  void _toggleTheme(BuildContext context, bool isDark) async {
    final newTheme = isDark ? 'Terang' : 'Gelap';
    HubnerApp.themeNotifier.value = newTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', newTheme);
  }

  DateTime _parseDateString(String dateStr) {
    try {
      final parts = dateStr.trim().split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.now();
  }

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: ThreeDotsLoader()),
      );
    }

    final bool isDark = AppColors.isDarkMode;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: ThreeDotsLoader()),
          );
        }

        final Map<String, dynamic> userData =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final String userName = userData['name'] ?? user.displayName ?? 'Siswa';
        final String schoolLevel = userData['schoolLevel'] ?? 'SMK';
        final List<dynamic> projectIds = userData['projectIds'] ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where(FieldPath.documentId, whereIn: projectIds.isNotEmpty ? projectIds.take(10).toList() : ['dummy'])
              .snapshots(),
          builder: (context, projectsSnapshot) {
            final rawDocs = projectsSnapshot.data?.docs ?? _lastProjectDocs;
            if (projectsSnapshot.hasData && projectsSnapshot.data!.docs.isNotEmpty) {
              _lastProjectDocs = projectsSnapshot.data!.docs;
            }

            final projectDocs = rawDocs.where((doc) {
              final pData = doc.data() as Map<String, dynamic>? ?? {};
              final pId = (pData['projectId'] ?? doc.id).toString();
              return !_deletedProjectIds.contains(doc.id) && !_deletedProjectIds.contains(pId);
            }).toList();

            final List<Map<String, dynamic>> allUserTasks = [];
            for (var projDoc in projectDocs) {
              final projData = projDoc.data() as Map<String, dynamic>;
              final projName = projData['name'] ?? 'Classroom';
              final stages = projData['stages'] as List? ?? [];
              for (var stage in stages) {
                final stageMap = stage as Map<String, dynamic>;
                final stageName = stageMap['name'] ?? '';
                final tasks = stageMap['tasks'] as List? ?? [];
                for (var task in tasks) {
                  final taskMap = Map<String, dynamic>.from(task as Map);
                  taskMap['projectName'] = projName;
                  taskMap['stageName'] = stageName;
                  allUserTasks.add(taskMap);
                }
              }
            }

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
              body: SafeArea(
                child: SingleChildScrollView(
                  controller: _homeScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Siswa · ${schoolLevel.toUpperCase()}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleTheme(context, isDark),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Icon(
                                    isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                    color: isDark ? const Color(0xFFFBBF24) : Colors.black87,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              NotificationBellIcon(isDark: isDark, size: 40),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Student Dashboard Cards: 2 Columns (Left: Hari Ini | Right: Tugas & Quiz)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Hari Ini Card
                          Expanded(
                            child: Container(
                              height: 300,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1C1C1E) : null,
                                gradient: isDark
                                    ? null
                                    : const LinearGradient(
                                        colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: BlueCardPatternPainter(isDark: isDark),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Hari Ini',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF27272A) : Colors.white.withValues(alpha: 0.8),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Rabu',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0369A1),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildLeftSection(
                                                  icon: Icons.calendar_today_rounded,
                                                  iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0369A1),
                                                  title: 'Jadwal Kelas Hari Ini',
                                                  subtitle: 'Bebas kelas hari ini',
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 12),
                                                _buildLeftSection(
                                                  icon: Icons.assignment_outlined,
                                                  iconColor: isDark ? const Color(0xFFD6A5F8) : const Color(0xFF7E22CE),
                                                  title: 'Deadline Tugas Hari Ini',
                                                  subtitle: 'Bebas tugas hari ini',
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 12),
                                                _buildLeftSection(
                                                  icon: Icons.quiz_outlined,
                                                  iconColor: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                                                  title: 'Jadwal Quiz Hari Ini',
                                                  subtitle: 'Bebas quiz hari ini',
                                                  isDark: isDark,
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
                          ),
                          const SizedBox(width: 12),

                          // Right Column: Tugas & Quiz Cards
                          Expanded(
                            child: Column(
                              children: [
                                // Progress Tugas Card
                                Container(
                                  height: 142,
                                  width: double.infinity,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : null,
                                    gradient: isDark
                                        ? null
                                        : const LinearGradient(
                                            colors: [Color(0xFFF3E8FF), Color(0xFFFAF5FF)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: LavenderCardPatternPainter(isDark: isDark),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF7C3AED), // Ungu Hubner Core
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.assignment_turned_in_rounded,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Tugas',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  '0',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 24.0,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? const Color(0xFFD6A5F8) : const Color(0xFF6B21A8),
                                                    height: 1.0,
                                                  ),
                                                ),
                                                Text(
                                                  '/2',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF7E22CE),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '0% tercapai',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFFD6A5F8) : const Color(0xFF6B21A8),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: 0.0,
                                                    backgroundColor: isDark ? const Color(0xFF27272A) : Colors.white,
                                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                                                    minHeight: 5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Quiz Card
                                Container(
                                  height: 142,
                                  width: double.infinity,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : null,
                                    gradient: isDark
                                        ? null
                                        : const LinearGradient(
                                            colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: AmberCardPatternPainter(isDark: isDark),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFD97706),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.quiz_rounded,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Quiz',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 14.0,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: List.generate(3, (idx) {
                                                    return Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                                      width: 5,
                                                      height: 5,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: idx == 0
                                                            ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                                                            : (isDark ? const Color(0xFF78350F) : const Color(0xFFFCD34D)),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  '1',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 24.0,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                                    height: 1.0,
                                                  ),
                                                ),
                                                Text(
                                                  '/4',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFFFDE047) : const Color(0xFFD97706),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '25% kuis tercapai',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: 0.25,
                                                    backgroundColor: isDark ? const Color(0xFF27272A) : Colors.white,
                                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                                                    minHeight: 5,
                                                  ),
                                                ),
                                              ],
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Classroom Title Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Classroom Saya',
                            style: AppTypography.pageTitle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Classroom Grid / Cards
                      if (projectDocs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.class_outlined,
                                size: 40,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum bergabung dengan classroom manapun.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14.0,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: projectDocs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = projectDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final String title = data['name'] ?? 'Classroom';
                            final String category = data['category'] ?? 'Umum';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassPage(
                                      projectId: doc.id,
                                      projectTitle: title,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Color(0xFF7C3AED),
                                        size: 24,
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
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            category,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 13.0,
                                              color: isDark ? Colors.white54 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildLeftSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              color: isDark ? Colors.white54 : Colors.black45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
