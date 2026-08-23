import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../edit_class_page.dart';
import 'package:hubner/features/projects/domain/activity_logger.dart';
import 'package:hubner/core/theme/app_colors.dart';

final List<Color> _classroomAccentColors = const [
  Color(0xFF009688), // 0: Teal
  Color(0xFF448AFF), // 1: Blue
  Color(0xFFE040FB), // 2: Purple/Magenta
  Color(0xFFFF4081), // 3: Pink/Rose
  Color(0xFFFFAB40), // 4: Orange/Amber
  Color(0xFF536DFE), // 5: Indigo
  Color(0xFF607D8B), // 6: Blue Grey
];

class DesktopDetailKelasTab extends StatelessWidget {
  final String projectId;
  final String projectTitle;

  const DesktopDetailKelasTab({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String description =
            data['description'] ?? 'Belum ada deskripsi kelas.';
        final String gradeLevel = data['gradeLevel'] ?? '-';
        final String major = data['major'] ?? '-';
        final String ownerUid = data['ownerUid'] ?? '';
        final int? rawColorIndex = data['colorIndex'] as int?;

        // 1. Color Sync: If colorIndex exists use palette, else default to PURPLE (Color(0xFF7C3AED))
        final Color accentColor = rawColorIndex != null
            ? _classroomAccentColors[rawColorIndex % _classroomAccentColors.length]
            : const Color(0xFF7C3AED);

        final bool isYellow = accentColor.value == 0xFFFFAB40 ||
            accentColor.value == 0xFFFFD600 ||
            accentColor.computeLuminance() > 0.42;
        final Color heroTextColor = isYellow ? Colors.black : Colors.white;
        final Color heroSubtextColor = isYellow ? Colors.black87 : Colors.white70;

        final int colorIndexForPattern = rawColorIndex ?? 2; // Purple index

        final List stages = data['stages'] as List? ?? [];
        final List membersArray = data['members'] as List? ?? [];
        final List studentsArray = data['students'] as List? ?? [];
        final List schedules = data['schedules'] as List? ?? [];

        final String iconFileName = data['icon'] as String? ?? 'project_1.png';
        final String iconPath = 'assets/icon_pack/project/$iconFileName';

        // Format schedule string
        String scheduleText = 'Jadwal belum diatur';
        if (schedules.isNotEmpty) {
          final s = schedules[0] as Map;
          scheduleText = '${s['day'] ?? ''}, ${s['time'] ?? ''}';
        }

        // 2. Accurate Database Sync for Materi, PDF Files, Tasks, & Quizzes
        int totalSubMateriCount = 0;
        int totalPdfFileCount = 0;
        int totalTasksCount = 0;
        int totalQuizCount = 0;
        int totalTaskSubmissions = 0;
        int totalQuizSubmissions = 0;

        for (var s in stages) {
          final rawMateris = (s as Map)['materis'] as List? ?? [];
          totalSubMateriCount += rawMateris.length;

          for (var m in rawMateris) {
            final mMap = m as Map;
            final pdfs = mMap['pdfs'] as List? ?? [];
            final pdfUrl = mMap['pdfUrl'] as String?;

            if (pdfs.isNotEmpty) {
              totalPdfFileCount += pdfs.length;
            } else if (pdfUrl != null && pdfUrl.isNotEmpty) {
              totalPdfFileCount++;
            }

            final tasks = mMap['tasks'] as List? ?? [];
            for (var t in tasks) {
              final tMap = t as Map;
              final type = tMap['type'] ?? 'tugas';
              final submissions = tMap['submissions'] as List? ?? [];
              if (type == 'quiz') {
                totalQuizCount++;
                totalQuizSubmissions += submissions.length;
              } else {
                totalTasksCount++;
                totalTaskSubmissions += submissions.length;
              }
            }
          }
        }

        // Fetch Member count from subcollection or fallback to array
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('members')
              .snapshots(),
          builder: (context, membersSnap) {
            final List studentsMasterList = data['studentsMasterList'] as List? ?? [];
            final int joinedStudentsCount = studentsMasterList.where((s) {
              if (s is Map) {
                final bool isJoined = s['joined'] == true;
                final String sUid = (s['uid'] ?? '').toString();
                return isJoined && sUid.isNotEmpty;
              }
              return false;
            }).length;

            int activeStudentsCount = 0;
            if (joinedStudentsCount > 0) {
              activeStudentsCount = joinedStudentsCount;
            } else if (membersSnap.hasData && membersSnap.data!.docs.isNotEmpty) {
              activeStudentsCount = membersSnap.data!.docs.length;
            } else if (studentsArray.isNotEmpty) {
              activeStudentsCount = studentsArray.length;
            } else if (membersArray.isNotEmpty) {
              activeStudentsCount = membersArray.length;
            } else {
              activeStudentsCount = 0;
            }

            final int maxExpectedTaskSubmissions = totalTasksCount * (activeStudentsCount > 0 ? activeStudentsCount : 1);
            final int maxExpectedQuizSubmissions = totalQuizCount * (activeStudentsCount > 0 ? activeStudentsCount : 1);

            final double readPct = totalPdfFileCount > 0 ? 1.0 : 0.0;
            final double taskPct = maxExpectedTaskSubmissions > 0
                ? (totalTaskSubmissions / maxExpectedTaskSubmissions).clamp(0.0, 1.0)
                : 0.0;
            final double quizPct = maxExpectedQuizSubmissions > 0
                ? (totalQuizSubmissions / maxExpectedQuizSubmissions).clamp(0.0, 1.0)
                : 0.0;

            return StreamBuilder<DocumentSnapshot>(
              stream: ownerUid.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(ownerUid)
                      .snapshots()
                  : null,
              builder: (context, userSnap) {
                String teacherName = data['instructorName'] ?? data['ownerName'] ?? 'Instruktur Kelas';
                if (userSnap.hasData &&
                    userSnap.data != null &&
                    userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  if (userData != null && (userData['name'] as String? ?? '').isNotEmpty) {
                    teacherName = userData['name'];
                  }
                }

                return SingleChildScrollView(
                  key: const PageStorageKey('DetailKelasScroll'),
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 8,
                    bottom: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── 1. HERO CLASSROOM BANNER (Database Color Synced / Default Purple) ───
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: ClassroomCardPatternPainter(
                                    patternIndex: colorIndexForPattern,
                                    accentColor:
                                        Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row (White Tag Left & Yellow Atur Ulang Button Right)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.08),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'Tingkat $gradeLevel • $major',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF000000),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                opaque: false,
                                                barrierColor: Colors.transparent,
                                                pageBuilder: (context, _, __) => EditClassPage(
                                                  projectId: projectId,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFD600),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.12),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.tune_rounded,
                                                  size: 15,
                                                  color: Colors.black,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Atur Ulang',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // Hero Main Content
                                    Row(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              iconPath,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  CircleAvatar(
                                                backgroundColor: Colors.white
                                                    .withValues(alpha: 0.25),
                                                child: const Icon(
                                                  Icons.school_rounded,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                projectTitle,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: () {
                                                    final len = projectTitle.length;
                                                    if (len > 70) return 18.0;
                                                    if (len > 50) return 21.0;
                                                    if (len > 32) return 24.0;
                                                    return 28.1;
                                                  }(),
                                                  fontWeight: FontWeight.bold,
                                                  color: heroTextColor,
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 15,
                                                    color: heroSubtextColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    teacherName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 15.2,
                                                      fontWeight: FontWeight.w600,
                                                      color: heroTextColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Container(
                                                    width: 4,
                                                    height: 4,
                                                    decoration:
                                                        BoxDecoration(
                                                      color: heroSubtextColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 15,
                                                    color: heroSubtextColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    scheduleText,
                                                    style: GoogleFonts.dmSans(
                                                      fontSize: 15.2,
                                                      color: heroSubtextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14.7,
                                                  color: heroSubtextColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: QrImageView(
                                            data: projectId,
                                            version: QrVersions.auto,
                                            size: 110,
                                            eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: Colors.black,
                                            ),
                                            dataModuleStyle:
                                                const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.square,
                                              color: Colors.black,
                                            ),
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
                      ),
                      const SizedBox(height: 18),

                      // ─── 2. OVERVIEW METRIC CARDS (Synced Numbers) ───
                      Row(
                        children: [
                          _buildSoftAiCard(
                            tagLabel: 'Elemen Kurikulum',
                            title: '${stages.length} Elemen',
                            subtitle:
                                'Struktur elemen & capaian pembelajaran terdaftar.',
                            accentColor: const Color(0xFF0284C7),
                            bgColor: const Color(0xFFE0F2FE),
                            icon: Icons.account_tree_rounded,
                          ),
                          const SizedBox(width: 16),
                          _buildSoftAiCard(
                            tagLabel: 'Materi Terlampir',
                            title: '$totalSubMateriCount Materi',
                            subtitle:
                                'Total materi pembelajaran di bawah elemen.',
                            accentColor: const Color(0xFF059669),
                            bgColor: const Color(0xFFDCFCE7),
                            icon: Icons.menu_book_rounded,
                          ),
                          const SizedBox(width: 16),
                          _buildSoftAiCard(
                            tagLabel: 'Komunitas Siswa',
                            title: '$activeStudentsCount Siswa',
                            subtitle: 'Siswa aktif yang bergabung di kelas.',
                            accentColor: const Color(0xFF7C3AED),
                            bgColor: const Color(0xFFF3E8FF),
                            icon: Icons.groups_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ─── 3. 40-60 SPLIT SECTION (NO BOLD TITLES, NO "TERUPLOAD", NO "STATISTIK PEMBELAJARAN" HEADER) ───
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (~40%): Single Statistics Card
                          Expanded(
                            flex: 4,
                            child: _buildSingleStatisticsCard(
                              totalPdfCount: totalPdfFileCount,
                              totalTasksCount: totalTasksCount,
                              totalQuizCount: totalQuizCount,
                              readPct: readPct,
                              taskPct: taskPct,
                              quizPct: quizPct,
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Right Column (~60%): Classroom Activity Table (Matching Laporan Screenshot 1)
                          Expanded(
                            flex: 6,
                            child: _buildClassroomActivityCard(
                              projectId: projectId,
                              projectTitle: projectTitle,
                              stages: stages,
                              teacherName: teacherName,
                              studentsMasterList: data['studentsMasterList'] as List? ?? [],
                              membersArray: membersArray,
                            ),
                          ),
                        ],
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
  }

  Widget _buildSoftAiCard({
    required String tagLabel,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: accentColor),
                  const SizedBox(width: 5),
                  Text(
                    tagLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 21.1,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 14.0,
                color: const Color(0xFF000000),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Single White Card for Statistics (Column 1 - 40%)
  // NO BOLD TITLES, NO "TERUPLOAD" WORD, NO "STATISTIK PEMBELAJARAN" HEADER
  Widget _buildSingleStatisticsCard({
    required int totalPdfCount,
    required int totalTasksCount,
    required int totalQuizCount,
    required double readPct,
    required double taskPct,
    required double quizPct,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Materi PDF (NO BOLD TITLE, NO "TERUPLOAD")
          _buildStatProgressRow(
            icon: Icons.picture_as_pdf_rounded,
            accentColor: const Color(0xFF0284C7),
            combinedTitle: '$totalPdfCount Materi PDF',
            statusSuffix: 'dibaca siswa',
            percentageValue: readPct,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // 2. Tugas Evaluasi (NO BOLD TITLE, NO "TERUPLOAD")
          _buildStatProgressRow(
            icon: Icons.assignment_rounded,
            accentColor: const Color(0xFFE11D48),
            combinedTitle: '$totalTasksCount Tugas Evaluasi',
            statusSuffix: 'mengirim tugas',
            percentageValue: taskPct,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // 3. Quiz Interaktif (NO BOLD TITLE, NO "TERUPLOAD")
          _buildStatProgressRow(
            icon: Icons.quiz_rounded,
            accentColor: const Color(0xFFD97706),
            combinedTitle: '$totalQuizCount Quiz Interaktif',
            statusSuffix: 'mengerjakan quiz',
            percentageValue: quizPct,
          ),
        ],
      ),
    );
  }

  Widget _buildStatProgressRow({
    required IconData icon,
    required Color accentColor,
    required String combinedTitle,
    required String statusSuffix,
    required double percentageValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Combined Title Row with Icon & Title (NOT BOLD: FontWeight.w600)
        Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                combinedTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600, // NOT BOLD AS REQUESTED
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Animated Progress Bar (12px minHeight) & Floating Badge ("85% dibaca siswa")
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: percentageValue),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, animVal, child) {
            final int pctInt = (animVal * 100).round();
            final String badgeText = '$pctInt% $statusSuffix';

            return LayoutBuilder(
              builder: (context, constraints) {
                final double barWidth = constraints.maxWidth;
                final double stopPos =
                    (barWidth * animVal).clamp(0.0, barWidth);
                final double badgeWidth = badgeText.length * 8.2 + 20;
                final double badgeOffset =
                    (stopPos - (badgeWidth / 2)).clamp(0.0, barWidth - badgeWidth);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: barWidth,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: badgeOffset,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: animVal,
                        minHeight: 12,
                        backgroundColor: accentColor.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Classroom Activity Feed Card (Column 2 - 60%): REAL-TIME SYNC WITH FIRESTORE ACTIVITIES
  Widget _buildClassroomActivityCard({
    required String projectId,
    required String projectTitle,
    required List stages,
    required String teacherName,
    List studentsMasterList = const [],
    List membersArray = const [],
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> rawActivities = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            rawActivities.add(data);
          }
        }

        // Deduplicate: keep only the first occurrence of each action+target+type combo
        final Set<String> seenKeys = {};
        final List<Map<String, dynamic>> realActivities = [];
        for (var item in rawActivities) {
          final key = '${item['action']}||${item['target']}||${item['type']}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            realActivities.add(item);
          }
        }

        // Trigger one-time cleanup of duplicate entries in Firestore
        if (rawActivities.length != realActivities.length) {
          cleanupDuplicateActivities(projectId: projectId);
        }

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF7C3AED),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Aktivitas Kelas Terbaru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.7,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF000000),
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 18),

              // Activity List Items
              if (realActivities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 40,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada aktivitas kelas.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aktivitas akan muncul saat ada perubahan di kelas ini.',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.0,
                            color: const Color(0xFF94A3B8),
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
                  itemCount: realActivities.length > 20 ? 20 : realActivities.length,
                  separatorBuilder: (_, __) => const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = realActivities[index];
                    return _buildActivityItem(item);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> avatarColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];
    return avatarColors[hash % avatarColors.length];
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }



  Widget _buildActivityItem(Map<String, dynamic> data) {
    final String type = (data['type'] ?? 'general').toString().toLowerCase();
    final String actor = data['actor'] ?? 'Pengguna';
    final String target = data['target'] ?? '';
    final String action = data['action'] ?? 'melakukan aktivitas';
    final String timeStr = data['time'] as String? ??
        (data['timestamp'] != null
            ? _formatTimestamp(data['timestamp'] as Timestamp)
            : 'Baru saja');

    Color typeColor;
    IconData iconData;

    switch (type) {
      case 'tugas':
        typeColor = const Color(0xFF059669);
        iconData = Icons.assignment_rounded;
        break;
      case 'elemen':
        typeColor = const Color(0xFF0284C7);
        iconData = Icons.account_tree_rounded;
        break;
      case 'quiz':
        typeColor = const Color(0xFFEC4899);
        iconData = Icons.quiz_rounded;
        break;
      case 'materi':
        typeColor = const Color(0xFF0D9488);
        iconData = Icons.menu_book_rounded;
        break;
      case 'siswa':
      case 'member':
      case 'join':
        typeColor = const Color(0xFF7C3AED);
        iconData = Icons.person_add_rounded;
        break;
      default:
        typeColor = const Color(0xFF64748B);
        iconData = Icons.notifications_active_rounded;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(iconData, color: typeColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.7,
                    color: const Color(0xFF000000),
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(
                      text: '$actor ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '$action '),
                    if (target.isNotEmpty)
                      TextSpan(
                        text: '[$target]',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeStr,
                style: GoogleFonts.dmSans(
                  fontSize: 14.0,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit yang lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam yang lalu';
    } else {
      return '${diff.inDays} hari yang lalu';
    }
  }
}

// ─── Custom Classroom Card Pattern Painter ───
class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool isDark = AppColors.isDarkMode;
    final Color primaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.08);
    final Color secondaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.30);
    final Color strokePatternColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);
    final Color ringPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.16)
        : accentColor.withValues(alpha: 0.07);
    final Color dotPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : accentColor.withValues(alpha: 0.10);

    switch (patternIndex % 5) {
      case 0:
        final paint = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final path = Path();
        path.moveTo(size.width * 0.45, 0);
        path.cubicTo(
          size.width * 0.65,
          size.height * 0.35,
          size.width * 0.35,
          size.height * 0.75,
          size.width * 0.85,
          size.height,
        );
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
        path.close();
        canvas.drawPath(path, paint);

        final paintSecondary = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathSecondary = Path();
        pathSecondary.moveTo(size.width * 0.6, 0);
        pathSecondary.cubicTo(
          size.width * 0.8,
          size.height * 0.4,
          size.width * 0.5,
          size.height * 0.8,
          size.width,
          size.height * 0.7,
        );
        pathSecondary.lineTo(size.width, 0);
        pathSecondary.close();
        canvas.drawPath(pathSecondary, paintSecondary);
        break;

      case 1:
        final paintRing = Paint()
          ..color = ringPatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        final center = Offset(size.width * 0.85, size.height * 0.3);
        canvas.drawCircle(center, 30, paintRing);
        canvas.drawCircle(center, 55, paintRing);

        final paintWave = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRing = Path();
        pathRing.moveTo(size.width * 0.55, 0);
        pathRing.quadraticBezierTo(
          size.width * 0.8,
          size.height * 0.5,
          size.width,
          size.height,
        );
        pathRing.lineTo(size.width, 0);
        pathRing.close();
        canvas.drawPath(pathRing, paintWave);
        break;

      case 2:
        final paintBubble1 = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.8, size.height * 0.2),
          45,
          paintBubble1,
        );

        final paintBubble2 = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.9, size.height * 0.75),
          35,
          paintBubble2,
        );
        break;

      case 3:
        final paintDot = Paint()
          ..color = dotPatternColor
          ..style = PaintingStyle.fill;
        for (double x = size.width * 0.5; x < size.width; x += 18) {
          for (double y = 10; y < size.height; y += 18) {
            canvas.drawCircle(Offset(x, y), 3, paintDot);
          }
        }
        break;

      case 4:
      default:
        final paintRay = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRay = Path();
        pathRay.moveTo(size.width * 0.5, 0);
        pathRay.quadraticBezierTo(
          size.width * 0.7,
          size.height * 0.5,
          size.width * 0.8,
          size.height,
        );
        pathRay.lineTo(size.width, size.height);
        pathRay.lineTo(size.width, 0);
        pathRay.close();
        canvas.drawPath(pathRay, paintRay);

        final paintStroke = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
        final pathStroke = Path();
        pathStroke.moveTo(size.width * 0.65, 0);
        pathStroke.quadraticBezierTo(
          size.width * 0.8,
          size.height * 0.4,
          size.width * 0.85,
          size.height,
        );
        canvas.drawPath(pathStroke, paintStroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ClassroomCardPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex ||
        oldDelegate.accentColor != accentColor;
  }
}
