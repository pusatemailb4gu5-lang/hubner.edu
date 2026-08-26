import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:hubner/features/projects/presentation/pages/class_page.dart';
import 'package:hubner/features/todo/presentation/pages/todo_page.dart';
import 'package:hubner/features/home/presentation/widgets/home_card_painters.dart';
import 'package:hubner/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentHomePage extends StatefulWidget {
  final Function(int index, {String? projectId})? onNavigateTab;
  const StudentHomePage({super.key, this.onNavigateTab});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  DateTime _selectedCalendarDay = DateTime.now();
  final ScrollController _homeScrollController = ScrollController();
  final Set<String> _deletedProjectIds = {};
  List<DocumentSnapshot> _lastProjectDocs = [];

  final List<Color> _classroomCardColors = const [
    Color(0xFFD6A5F8), // 01. Lilac Purple (Core)
    Color(0xFF9CC8FC), // 02. Sky Blue
    Color(0xFF7DE3D0), // 03. Emerald Mint / Tosca
    Color(0xFFF7BD84), // 04. Amber Peach / Orange
    Color(0xFFF794BE), // 05. Rose Magenta / Pink
    Color(0xFFA5B4FC), // 06. Indigo Violet
    Color(0xFFBEF264), // 07. Fresh Lime
    Color(0xFF67E8F9), // 08. Ocean Cyan
    Color(0xFFFDE047), // 09. Amber Gold / Kuning
    Color(0xFFCBD5E1), // 10. Steel Slate / Grey
  ];

  final List<Color> _classroomAccentColors = const [
    Color(0xFF7C3AED), // 01. Ungu Hubner Core / Primary
    Color(0xFF2864A8), // 02. Deep Sky Blue
    Color(0xFF147D75), // 03. Deep Teal / Tosca
    Color(0xFFC76D10), // 04. Deep Amber / Orange
    Color(0xFFA82658), // 05. Deep Rose / Magenta
    Color(0xFF4338CA), // 06. Deep Indigo
    Color(0xFF4D7C0F), // 07. Deep Olive Lime
    Color(0xFF0E7490), // 08. Deep Ocean Cyan
    Color(0xFFA16207), // 09. Deep Amber Gold
    Color(0xFF334155), // 10. Deep Slate Steel
  ];

  void _toggleTheme(BuildContext context, bool isDark) async {
    final newTheme = isDark ? 'Terang' : 'Gelap';
    HubnerApp.themeNotifier.value = newTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', newTheme);
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      final parts = dateStr.trim().split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isDark = AppColors.isDarkMode;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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

                      // Calendar Schedule Slider
                      _buildCalendarSlider(allUserTasks),
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
                          Text(
                            '${projectDocs.length} Kelas',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Classroom Rich Cards List
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
                            final String ownerUid = (data['ownerUid'] ?? data['teacherUid'] ?? '').toString();

                            return _buildStudentClassroomCard(
                              context: context,
                              projectId: doc.id,
                              title: title,
                              category: category,
                              ownerUid: ownerUid,
                              index: index,
                              isDark: isDark,
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

  Widget _buildStudentClassroomCard({
    required BuildContext context,
    required String projectId,
    required String title,
    required String category,
    required String ownerUid,
    required int index,
    required bool isDark,
  }) {
    final Color cardColor = _classroomCardColors[index % _classroomCardColors.length];
    final Color accentColor = _classroomAccentColors[index % _classroomAccentColors.length];

    return FutureBuilder<DocumentSnapshot>(
      future: ownerUid.isNotEmpty
          ? FirebaseFirestore.instance.collection('users').doc(ownerUid).get()
          : null,
      builder: (context, userSnap) {
        String teacherName = 'Pengajar';
        String gender = '';
        if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>;
          teacherName = userData['name'] ?? userData['displayName'] ?? 'Pengajar';
          gender = userData['gender'] ?? '';
        }

        final isFemale = gender.toLowerCase().contains('perempuan') || gender.toLowerCase().startsWith('p');
        final titlePrefix = isFemale ? 'Bu' : 'Pak';
        final displayTeacherName = '$titlePrefix $teacherName';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClassPage(
                  projectId: projectId,
                  projectTitle: title,
                ),
              ),
            );
          },
          child: Container(
            height: 155,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: ClassroomCardPatternPainter(
                      patternIndex: index,
                      accentColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : accentColor.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Category badge & Arrow Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFA78BFA) : accentColor,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF27272A) : Colors.white.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      // Classroom Title
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Bottom Row: Teacher Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  displayTeacherName,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarSlider(List<Map<String, dynamic>> allTasks) {
    final bool isDark = AppColors.isDarkMode;
    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);
    final List<DateTime> calendarDays = List.generate(14, (index) {
      return todayDate.subtract(const Duration(days: 4)).add(Duration(days: index));
    });

    final currentMonthYearStr =
        '${_getMonthName(_selectedCalendarDay.month)} ${_selectedCalendarDay.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentMonthYearStr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            key: const PageStorageKey('student_home_calendar_slider'),
            scrollDirection: Axis.horizontal,
            itemCount: calendarDays.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = calendarDays[index];
              final bool isSelected =
                  _selectedCalendarDay.day == day.day &&
                  _selectedCalendarDay.month == day.month &&
                  _selectedCalendarDay.year == day.year;

              final bool hasTasks = _hasTaskOnDay(day, allTasks);
              final Color activeBgColor = _getDayCardBg(day.weekday);
              final Color dayTextColor = _getDayTextColor(day.weekday);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCalendarDay = day;
                  });
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TodoPage(initialDate: day),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeBgColor
                        : (isDark ? const Color(0xFF18181B) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? dayTextColor
                              : dayTextColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDayName(day.weekday),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : dayTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        day.day.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (hasTasks) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? dayTextColor
                                : dayTextColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else
                        const SizedBox(height: 9),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _hasTaskOnDay(DateTime day, List<Map<String, dynamic>> allTasks) {
    for (var task in allTasks) {
      final startStr = task['start'] as String? ?? '';
      final endStr = task['end'] as String? ?? '';
      if (startStr.isEmpty || endStr.isEmpty || startStr == 'DD/MM/YYYY') continue;

      final startDate = _parseDateString(startStr);
      final endDate = _parseDateString(endStr);
      if (startDate == null || endDate == null) continue;

      final targetDay = DateTime(day.year, day.month, day.day);
      final normStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normEnd = DateTime(endDate.year, endDate.month, endDate.day);

      if ((targetDay.isAfter(normStart) || targetDay.isAtSameMomentAs(normStart)) &&
          (targetDay.isBefore(normEnd) || targetDay.isAtSameMomentAs(normEnd))) {
        return true;
      }
    }
    return false;
  }

  Color _getDayCardBg(int weekday) {
    switch (weekday) {
      case 1:
        return const Color(0xFFDBEAFE);
      case 2:
        return const Color(0xFFD1FAE5);
      case 3:
        return const Color(0xFFFDE68A);
      case 4:
        return const Color(0xFFE9D5FF);
      case 5:
        return const Color(0xFFCCFBF1);
      case 6:
      case 7:
      default:
        return const Color(0xFFFECDD3);
    }
  }

  Color _getDayTextColor(int weekday) {
    switch (weekday) {
      case 1:
        return const Color(0xFF1D4ED8);
      case 2:
        return const Color(0xFF047857);
      case 3:
        return const Color(0xFFB45309);
      case 4:
        return const Color(0xFF6D28D9);
      case 5:
        return const Color(0xFF0F766E);
      case 6:
      case 7:
      default:
        return const Color(0xFFBE123C);
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[weekday - 1];
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
