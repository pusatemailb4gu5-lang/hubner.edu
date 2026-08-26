import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:hubner/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:hubner/features/projects/presentation/pages/add_class_page.dart';
import 'package:hubner/features/projects/presentation/pages/class_page.dart';
import 'package:hubner/features/projects/presentation/pages/desktop_classroom_page.dart';
import 'package:hubner/features/projects/presentation/pages/monitoring_page.dart';
import 'package:hubner/features/home/presentation/widgets/home_card_painters.dart';
import 'package:hubner/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherHomePage extends StatefulWidget {
  final Function(int index, {String? projectId})? onNavigateTab;
  const TeacherHomePage({super.key, this.onNavigateTab});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final ScrollController _homeScrollController = ScrollController();
  final Set<String> _deletedProjectIds = {};
  List<DocumentSnapshot> _lastProjectDocs = [];

  void _toggleTheme(BuildContext context, bool isDark) async {
    final newTheme = isDark ? 'Terang' : 'Gelap';
    HubnerApp.themeNotifier.value = newTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', newTheme);
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
        final String rawName = userData['name'] ?? user.displayName ?? 'Pengajar';
        final String gender = userData['gender'] ?? '';
        final String schoolLevel = userData['schoolLevel'] ?? 'SMA/SMK';
        final List<dynamic> projectIds = userData['projectIds'] ?? [];

        final isFemale = gender.toLowerCase().contains('perempuan') || gender.toLowerCase().startsWith('p');
        final String titlePrefix = isFemale ? 'Bu' : 'Pak';
        final String displayName = '$titlePrefix $rawName';
        final String teacherRoleTitle = 'Pengajar · ${schoolLevel.toUpperCase()}';

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

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddClassPage(),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF7C3AED), // Ungu Hubner
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Buat Kelas Baru',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  controller: _homeScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teacher Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacherRoleTitle,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName,
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
                      const SizedBox(height: 20),

                      // Teacher Action Cards Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildTeacherActionCard(
                              icon: Icons.add_circle_outline_rounded,
                              iconBg: const Color(0xFF7C3AED),
                              title: 'Buat Kelas',
                              subtitle: 'Tambah classroom',
                              isDark: isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AddClassPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTeacherActionCard(
                              icon: Icons.analytics_outlined,
                              iconBg: const Color(0xFF0284C7),
                              title: 'Monitoring',
                              subtitle: 'Perkembangan siswa',
                              isDark: isDark,
                              onTap: () {
                                if (projectDocs.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MonitoringPage(
                                        projectId: projectDocs.first.id,
                                        projectTitle: (projectDocs.first.data() as Map)['name'] ?? 'Classroom',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Teacher Classroom Title Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Classroom Yang Diampu',
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

                      // Teacher Classroom Cards
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
                                Icons.school_outlined,
                                size: 40,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada classroom yang diampu.',
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
                            final String category = data['category'] ?? 'Mata Pelajaran';

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

  Widget _buildTeacherActionCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
