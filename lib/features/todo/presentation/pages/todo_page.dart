import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/features/projects/presentation/widgets/student_activity_dialogs.dart';
import 'package:hubner/features/projects/presentation/pages/mengerjakan_quiz_page.dart';
import 'package:hubner/features/projects/presentation/pages/mengerjakan_tugas_page.dart';
import 'package:hubner/features/projects/presentation/pages/baca_materi_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TodoPage extends StatefulWidget {
  final DateTime? initialDate;
  final bool showBackButton;
  const TodoPage({super.key, this.initialDate, this.showBackButton = true});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  late DateTime _selectedDay;
  late final ScrollController _calendarScrollController;
  late final ScrollController _stickyCalendarScrollController;
  late final ScrollController _mainScrollController;
  late final ValueNotifier<double> _scrollOffsetNotifier;

  late final Stream<DocumentSnapshot> _userStream;
  List<String> _lastProjectIds = [];
  Stream<QuerySnapshot?>? _projectsStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _calendarScrollController = ScrollController();
    _stickyCalendarScrollController = ScrollController();
    _mainScrollController = ScrollController();
    _scrollOffsetNotifier = ValueNotifier<double>(0.0);

    _mainScrollController.addListener(() {
      _scrollOffsetNotifier.value = _mainScrollController.offset;
    });

    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .snapshots();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDay();
    });
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _calendarScrollController.dispose();
    _stickyCalendarScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDay() {
    // 14 days generated starting 4 days before today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 4));
    final diff = _selectedDay.difference(startDate).inDays;
    if (diff > 0) {
      final offset = (diff * 52.0) - 100;
      if (_calendarScrollController.hasClients) {
        _calendarScrollController.animateTo(
          offset.clamp(0.0, _calendarScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      if (_stickyCalendarScrollController.hasClients) {
        _stickyCalendarScrollController.animateTo(
          offset.clamp(0.0, _stickyCalendarScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  String _getFullDateString(DateTime date) {
    const List<String> days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const List<String> months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  bool _isTaskOnDay(Map<String, dynamic> task, DateTime day) {
    final startStr = task['start'] as String? ?? '';
    final endStr = task['end'] as String? ?? '';
    if (startStr.isEmpty && endStr.isEmpty) return true;

    final startDate = _parseDateString(startStr);
    final endDate = _parseDateString(endStr);
    final targetDay = DateTime(day.year, day.month, day.day);

    if (startDate != null && endDate != null) {
      final normStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normEnd = DateTime(endDate.year, endDate.month, endDate.day);
      return (targetDay.isAfter(normStart) || targetDay.isAtSameMomentAs(normStart)) &&
          (targetDay.isBefore(normEnd) || targetDay.isAtSameMomentAs(normEnd));
    } else if (startDate != null) {
      final normStart = DateTime(startDate.year, startDate.month, startDate.day);
      return targetDay.isAtSameMomentAs(normStart) || targetDay.isAfter(normStart);
    } else if (endDate != null) {
      final normEnd = DateTime(endDate.year, endDate.month, endDate.day);
      return targetDay.isAtSameMomentAs(normEnd);
    }
    return false;
  }

  bool _isQuizStarted(Map<String, dynamic> quiz, DateTime currentDay) {
    final startStr = quiz['start'] as String? ?? quiz['quizStartDate'] as String? ?? '';
    if (startStr.isEmpty) return true;
    final startDate = _parseDateString(startStr);
    if (startDate == null) return true;
    final normStart = DateTime(startDate.year, startDate.month, startDate.day);
    final targetDay = DateTime(currentDay.year, currentDay.month, currentDay.day);
    return targetDay.isAfter(normStart) || targetDay.isAtSameMomentAs(normStart);
  }

  Future<void> _toggleTaskCompletion({
    required String projectId,
    required String taskKey,
    required bool isCurrentlyCompleted,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final userProgressRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('userProgress')
        .doc(currentUid);

    if (isCurrentlyCompleted) {
      await userProgressRef.set({
        'completedTasks': FieldValue.arrayRemove([taskKey]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await userProgressRef.set({
        'completedTasks': FieldValue.arrayUnion([taskKey]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);

    // 16 rolling calendar days around today
    final List<DateTime> calendarDays = List.generate(21, (index) {
      return todayDate.subtract(const Duration(days: 4)).add(Duration(days: index));
    });

    final fullDateText = _getFullDateString(_selectedDay);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: Stack(
            children: [
              // 1. Main Scrollable Content (Underlay with smooth blur transition)
              StreamBuilder<DocumentSnapshot>(
                stream: _userStream,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                      final projectIds = List<String>.from(userData?['projectIds'] ?? []);

                      final bool listsEqual = _lastProjectIds.length == projectIds.length &&
                          projectIds.every((id) => _lastProjectIds.contains(id));

                      if (!listsEqual || _projectsStream == null) {
                        _lastProjectIds = projectIds;
                        _projectsStream = projectIds.isEmpty
                            ? Stream<QuerySnapshot?>.value(null)
                            : FirebaseFirestore.instance
                                .collection('projects')
                                .where(FieldPath.documentId, whereIn: projectIds.take(30).toList())
                                .snapshots();
                      }

                      return StreamBuilder<QuerySnapshot?>(
                        stream: _projectsStream,
                        builder: (context, projectsSnapshot) {
                          if (projectsSnapshot.connectionState == ConnectionState.waiting &&
                              !projectsSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final projectDocs = projectsSnapshot.data?.docs ?? [];
                          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                          if (projectDocs.isEmpty) {
                            return _buildEmptyState(
                              isDark: isDark,
                              message: 'Belum terdaftar di kelas manapun.\nGabung kelas untuk melihat tugas, materi, dan kuis.',
                            );
                          }

                            return StreamBuilder<List<DocumentSnapshot>>(
                            stream: _combineUserProgressStreams(projectDocs, currentUid),
                            builder: (context, progressSnap) {
                              final Map<String, List<String>> progressMap = {};
                              final Map<String, Map<String, int>> quizScoreMap = {};
                              if (progressSnap.hasData && progressSnap.data != null) {
                                for (var pDoc in progressSnap.data!) {
                                  final pData = pDoc.data() as Map<String, dynamic>? ?? {};
                                  final cTasks = List<String>.from(pData['completedTasks'] ?? []);
                                  final rawScores = pData['quizScores'] as Map<String, dynamic>? ?? pData['scores'] as Map<String, dynamic>? ?? {};
                                  final pId = pDoc.reference.parent.parent?.id ?? '';
                                  if (pId.isNotEmpty) {
                                    progressMap[pId] = cTasks;
                                    quizScoreMap[pId] = rawScores.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
                                  }
                                }
                              }

                              // Extract: 1. Tugas Hari Ini, 2. Materi Belum Dibaca, 3. Quiz Belum Dikerjakan / Selesai
                              final List<Map<String, dynamic>> tasksToday = [];
                              final List<Map<String, dynamic>> unreadMateris = [];
                              final List<Map<String, dynamic>> pendingQuizzes = [];

                              for (var projDoc in projectDocs) {
                                final projData = projDoc.data() as Map<String, dynamic>;
                                final projName = projData['name'] ?? 'Kelas';
                                final projId = projDoc.id;
                                final stages = projData['stages'] as List? ?? [];
                                final completedList = progressMap[projId] ?? [];

                                for (int sIdx = 0; sIdx < stages.length; sIdx++) {
                                  final stage = stages[sIdx] as Map;
                                  final stageName = stage['name'] ?? 'Tahap ${sIdx + 1}';
                                  final List rawMateris = stage['materis'] as List? ?? [];

                                  List<Map<String, dynamic>> materis = [];
                                  if (rawMateris.isNotEmpty) {
                                    materis = List<Map<String, dynamic>>.from(rawMateris);
                                  } else {
                                    final List tasksList = stage['tasks'] as List? ?? [];
                                    if (tasksList.isNotEmpty) {
                                      materis = [
                                        {
                                          'title': stageName,
                                          'tasks': tasksList,
                                        }
                                      ];
                                    }
                                  }

                                  for (int mIdx = 0; mIdx < materis.length; mIdx++) {
                                    final m = materis[mIdx];
                                    final materiTitle = m['title'] ?? stageName;
                                    final List tasks = m['tasks'] as List? ?? [];

                                    for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
                                      final t = Map<String, dynamic>.from(tasks[tIdx] as Map);
                                      final String taskId = t['id'] as String? ?? '';
                                      final String taskKey = taskId.isNotEmpty ? taskId : '${sIdx}_${mIdx}_$tIdx';
                                      final String type = (t['type'] as String? ?? 'tugas').toLowerCase();
                                      final bool isCompleted = completedList.contains(taskKey) || completedList.contains(taskId);

                                      t['projectId'] = projId;
                                      t['projectName'] = projName;
                                      t['stageName'] = stageName;
                                      t['materiTitle'] = materiTitle;
                                      t['taskKey'] = taskKey;
                                      t['isCompleted'] = isCompleted;
                                      t['stageIdx'] = sIdx;
                                      t['materiIdx'] = mIdx;
                                      t['taskIdx'] = tIdx;

                                      if (type == 'tugas') {
                                        // Check if active on selected day
                                        if (_isTaskOnDay(t, _selectedDay)) {
                                          tasksToday.add(t);
                                        }
                                      } else if (type == 'pdf' || type == 'materi') {
                                        // Unread materials
                                        if (!isCompleted) {
                                          unreadMateris.add(t);
                                        }
                                      } else if (type == 'quiz') {
                                        // Quizzes started today or earlier
                                        if (_isQuizStarted(t, _selectedDay)) {
                                          final int? score = quizScoreMap[projId]?[taskKey] ?? quizScoreMap[projId]?[taskId];
                                          if (score != null) {
                                            t['score'] = score;
                                          }
                                          pendingQuizzes.add(t);
                                        }
                                      }
                                    }
                                  }
                                }
                              }

                              final bool isAllEmpty = tasksToday.isEmpty && unreadMateris.isEmpty && pendingQuizzes.isEmpty;

                              return ListView(
                                controller: _mainScrollController,
                                padding: EdgeInsets.fromLTRB(
                                  AppTypography.screenHorizontalMargin,
                                  MediaQuery.of(context).padding.top + 16.0,
                                  AppTypography.screenHorizontalMargin,
                                  120.0,
                                ),
                                children: [
                                  // 1. Top Row: "Tugas"
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.showBackButton && Navigator.canPop(context)) ...[
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            margin: const EdgeInsets.only(right: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_back_rounded,
                                              color: isDark ? Colors.white : Colors.black87,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                      Text(
                                        'Tugas',
                                        style: AppTypography.pageTitle(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // 2. Hari & Tanggal (DIBAWAH Tugas, DIATAS Slider Kalender, SEBELAH KIRI)
                                  Text(
                                    fullDateText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // 3. Dibawahnya: Deretan Tanggal Melingkar (Posisi asli sebelum di-scroll)
                                  _buildCircularCalendarSlider(
                                    isDark: isDark,
                                    calendarDays: calendarDays,
                                    controller: _calendarScrollController,
                                    storageKey: 'todo_main_calendar',
                                  ),
                                  const SizedBox(height: 20),

                                  if (isAllEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 36.0),
                                      child: _buildEmptyState(
                                        isDark: isDark,
                                        message: 'Bebas tugas untuk hari ini!\nSemua materi dan kuis telah terselesaikan.',
                                      ),
                                    ),
                                  ] else ...[
                                    // SECTION 1: TUGAS HARI INI
                                    if (tasksToday.isNotEmpty) ...[
                                      _buildSectionHeader(
                                        title: 'Tugas Hari Ini',
                                        count: tasksToday.length,
                                        iconWidget: const _TaskDeadlineDoodle(size: 24),
                                        accentColor: const Color(0xFFF59E0B),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF241D17) : const Color(0xFFFFEDD5),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: _TaskFacetPatternPainter(isDark: isDark),
                                              ),
                                            ),
                                            ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              itemCount: tasksToday.length,
                                              separatorBuilder: (context, index) => Divider(
                                                height: 1,
                                                thickness: 0.8,
                                                color: isDark ? Colors.white10 : const Color(0xFFFDE68A).withValues(alpha: 0.40),
                                              ),
                                              itemBuilder: (context, index) {
                                                final task = tasksToday[index];
                                                return _buildTaskRowItem(
                                                  task: task,
                                                  isDark: isDark,
                                                  onToggle: () => _toggleTaskCompletion(
                                                    projectId: task['projectId'],
                                                    taskKey: task['taskKey'],
                                                    isCurrentlyCompleted: task['isCompleted'] == true,
                                                  ),
                                                  onOpen: () => _openTaskDialog(context, task),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // SECTION 2: MATERI YANG BELUM DIBACA
                                    if (unreadMateris.isNotEmpty) ...[
                                      _buildSectionHeader(
                                        title: 'Materi Belum Dibaca',
                                        count: unreadMateris.length,
                                        iconWidget: const _ClassScheduleDoodle(size: 24),
                                        accentColor: const Color(0xFF0284C7),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF132230) : const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: _QuizFacetPatternPainter(isDark: isDark),
                                              ),
                                            ),
                                            ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              itemCount: unreadMateris.length,
                                              separatorBuilder: (context, index) => Divider(
                                                height: 1,
                                                thickness: 0.8,
                                                color: isDark ? Colors.white10 : const Color(0xFFBAE6FD).withValues(alpha: 0.40),
                                              ),
                                              itemBuilder: (context, index) {
                                                final materi = unreadMateris[index];
                                                return _buildMateriRowItem(
                                                  materi: materi,
                                                  isDark: isDark,
                                                  onOpen: () => _openMateriDialog(context, materi),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // SECTION 3: QUIZ YANG BELUM DIKERJAKAN / SELESAI
                                    if (pendingQuizzes.isNotEmpty) ...[
                                      _buildSectionHeader(
                                        title: pendingQuizzes.any((q) => q['isCompleted'] != true) ? 'Quiz Belum Dikerjakan' : 'Quiz & Evaluasi',
                                        count: pendingQuizzes.length,
                                        iconWidget: const _QuizPuzzleDoodle(size: 24),
                                        accentColor: const Color(0xFF9333EA),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E142B) : const Color(0xFFF3E8FF),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: _QuizFacetPatternPainter(isDark: isDark),
                                              ),
                                            ),
                                            ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              itemCount: pendingQuizzes.length,
                                              separatorBuilder: (context, index) => Divider(
                                                height: 1,
                                                thickness: 0.8,
                                                color: isDark ? Colors.white10 : const Color(0xFFE9D5FF).withValues(alpha: 0.40),
                                              ),
                                              itemBuilder: (context, index) {
                                                final quiz = pendingQuizzes[index];
                                                return _buildQuizRowItem(
                                                  quiz: quiz,
                                                  isDark: isDark,
                                                  onOpen: () => _openQuizPage(context, quiz),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

              // 2. Sticky Glassmorphic Header Bar (Transparan Glassmorphic Blur 20px - Muncul saat di-scroll)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffsetNotifier,
                  builder: (context, scrollOffset, _) {
                    if (scrollOffset <= 20.0) {
                      return const SizedBox.shrink();
                    }
                    final double scrollProgress = ((scrollOffset - 20.0) / 30.0).clamp(0.0, 1.0);
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
                              AppTypography.screenHorizontalMargin,
                              MediaQuery.of(context).padding.top + 8.0,
                              AppTypography.screenHorizontalMargin,
                              10.0,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF000000).withValues(alpha: 0.60 * scrollProgress)
                                  : Colors.white.withValues(alpha: 0.65 * scrollProgress),
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
                                // Tulisan "Tugas" HILANG digantikan tulisan tanggal
                                Row(
                                  children: [
                                    if (widget.showBackButton && Navigator.canPop(context)) ...[
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.arrow_back_rounded,
                                            color: isDark ? Colors.white : Colors.black87,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      fullDateText,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Slider Kalender juga Sticky
                                _buildCircularCalendarSlider(
                                  isDark: isDark,
                                  calendarDays: calendarDays,
                                  controller: _stickyCalendarScrollController,
                                  storageKey: 'todo_sticky_calendar',
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
          ),
        ),
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _combineUserProgressStreams(
      List<QueryDocumentSnapshot> projectDocs, String uid) {
    if (projectDocs.isEmpty || uid.isEmpty) {
      return Stream.value([]);
    }

    final streams = projectDocs.map((doc) {
      return FirebaseFirestore.instance
          .collection('projects')
          .doc(doc.id)
          .collection('userProgress')
          .doc(uid)
          .snapshots();
    }).toList();

    return StreamZip(streams);
  }

  Widget _buildCircularCalendarSlider({
    required bool isDark,
    required List<DateTime> calendarDays,
    required ScrollController controller,
    String? storageKey,
  }) {
    return SizedBox(
      key: storageKey != null ? PageStorageKey(storageKey) : null,
      height: 50,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        itemCount: calendarDays.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = calendarDays[index];
          final bool isSelected = _selectedDay.day == day.day &&
              _selectedDay.month == day.month &&
              _selectedDay.year == day.year;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = day;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF18181B))
                    : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F3F5)),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                day.day.toString(),
                style: AppTypography.pageTitle(
                  fontSize: 16.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  height: 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader({
    required String title,
    required int count,
    IconData? icon,
    Widget? iconWidget,
    required Color accentColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        if (iconWidget != null)
          iconWidget
        else
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 16, color: accentColor)
                : const SizedBox.shrink(),
          ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // --- 1. TUGAS ROW ITEM (Unified Card Row) ---
  Widget _buildTaskRowItem({
    required Map<String, dynamic> task,
    required bool isDark,
    required VoidCallback onToggle,
    required VoidCallback onOpen,
  }) {
    final title = task['title'] ?? task['name'] ?? 'Tugas';
    final projectName = task['projectName'] ?? 'Kelas';
    final startStr = task['start'] as String? ?? '';
    final endStr = task['end'] as String? ?? '';
    final isDone = task['isCompleted'] == true;

    final scheduleInfo = (startStr.isNotEmpty && endStr.isNotEmpty)
        ? '$startStr - $endStr'
        : (endStr.isNotEmpty ? 'Deadline: $endStr' : 'Hari ini');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox Circle for quick toggle
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF22C55E)
                        : (isDark ? const Color(0xFF27272A) : Colors.white),
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF22C55E)
                          : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                      width: 1.6,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle(
                        color: isDone
                            ? (isDark ? Colors.white38 : Colors.black38)
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w700,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
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
                            projectName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          scheduleInfo,
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

              const SizedBox(width: 8),

              // SVG Action Button for Task (Kerjakan Tugas - Tanpa Background)
              GestureDetector(
                onTap: onOpen,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: SvgPicture.string(
                      '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" stroke="${isDark ? '#FDE68A' : '#D97706'}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                      </svg>''',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. MATERI ROW ITEM (Unified Card Row + SVG Read Button) ---
  Widget _buildMateriRowItem({
    required Map<String, dynamic> materi,
    required bool isDark,
    required VoidCallback onOpen,
  }) {
    final title = materi['title'] ?? materi['name'] ?? 'Materi Pembelajaran';
    final projectName = materi['projectName'] ?? 'Kelas';
    final docName = materi['doc'] ?? materi['fileName'] ?? 'Modul PDF';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
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
                            projectName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFBAE6FD)
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            docName.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.timestamp(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // SVG Read Action Button (Baca Materi - Tanpa Background & Ikon Dokumen Pembaca)
              GestureDetector(
                onTap: onOpen,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: SvgPicture.string(
                      '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" stroke="${isDark ? '#38BDF8' : '#0284C7'}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                      </svg>''',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. QUIZ ROW ITEM (Unified Card Row + Start Button / Score) ---
  Widget _buildQuizRowItem({
    required Map<String, dynamic> quiz,
    required bool isDark,
    required VoidCallback onOpen,
  }) {
    final title = quiz['title'] ?? quiz['name'] ?? 'Kuis Harian';
    final projectName = quiz['projectName'] ?? 'Kelas';
    final questions = quiz['questions'] as List? ?? [];
    final questionCount = questions.length;
    final bool isDone = quiz['isCompleted'] == true;
    final int? score = quiz['score'] as int?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
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
                            projectName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFE9D5FF)
                                  : const Color(0xFF9333EA),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDone ? 'Selesai Dikerjakan' : '$questionCount Soal Evaluasi',
                          style: AppTypography.timestamp(
                            color: isDone
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                                : (isDark ? Colors.white38 : Colors.black45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Jika sudah mengerjakan tombol mulai jadi nilai font bold, jika belum tombol ikon puzzle
              if (isDone) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(
                    score != null ? '$score' : '100',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF9333EA),
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: onOpen,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: SvgPicture.string(
                        '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M14.25 4.5a2.25 2.25 0 00-2.25 2.25v.75H8.25A2.25 2.25 0 006 9.75v3.75h.75a2.25 2.25 0 010 4.5H6v2.25A2.25 2.25 0 008.25 22.5h3.75v-.75a2.25 2.25 0 014.5 0v.75h3.75a2.25 2.25 0 002.25-2.25v-3.75h-.75a2.25 2.25 0 010-4.5h.75V9.75a2.25 2.25 0 00-2.25-2.25h-3.75v-.75A2.25 2.25 0 0014.25 4.5z" stroke="${isDark ? '#D8B4FE' : '#9333EA'}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>''',
                        width: 18,
                        height: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState({required bool isDark, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _TaskDeadlineDoodle(size: 80),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS (Full Pages Navigation) ---
  void _openTaskDialog(BuildContext context, Map<String, dynamic> task) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MengerjakanTugasPage(
          title: task['title'] ?? task['name'] ?? 'Tugas',
          projectId: task['projectId'] ?? '',
          studentUid: currentUid,
          taskKey: task['taskKey'] ?? '',
          assignmentType: task['assignmentType'] ?? 'mandiri',
          studentsMasterList: const [],
          taskText: task['desc'] ?? task['taskText'] ?? task['description'],
          docName: task['doc'] ?? task['docName'] ?? task['fileUrl'],
          onCompleted: () => _toggleTaskCompletion(
            projectId: task['projectId'],
            taskKey: task['taskKey'],
            isCurrentlyCompleted: false,
          ),
        ),
      ),
    );
  }

  void _openMateriDialog(BuildContext context, Map<String, dynamic> materi) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BacaMateriPage(
          title: materi['title'] ?? materi['name'] ?? 'Materi Pembelajaran',
          docName: materi['doc']?.toString() ?? materi['fileName']?.toString() ?? '',
          onCompleted: () => _toggleTaskCompletion(
            projectId: materi['projectId'],
            taskKey: materi['taskKey'],
            isCurrentlyCompleted: false,
          ),
        ),
      ),
    );
  }

  void _openQuizPage(BuildContext context, Map<String, dynamic> quiz) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MengerjakanQuizPage(
          title: quiz['title'] ?? quiz['name'] ?? 'Quiz',
          durationStr: quiz['quizDuration']?.toString() ?? '15',
          startTime: quiz['quizStartTime']?.toString() ?? '',
          projectId: quiz['projectId'],
          studentUid: currentUid,
          taskKey: quiz['taskKey'],
          onCompleted: () => _toggleTaskCompletion(
            projectId: quiz['projectId'],
            taskKey: quiz['taskKey'],
            isCurrentlyCompleted: false,
          ),
          questions: quiz['questions'] as List?,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// STREAM ZIP HELPER FOR REACTIVE MULTI-PROJECT PROGRESS
// -------------------------------------------------------------
class StreamZip<T> extends Stream<List<T>> {
  final Iterable<Stream<T>> _streams;
  StreamZip(this._streams);

  @override
  StreamSubscription<List<T>> listen(
    void Function(List<T> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final List<Stream<T>> streamList = _streams.toList();
    if (streamList.isEmpty) {
      return Stream<List<T>>.value([]).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }

    final controller = StreamController<List<T>>(sync: true);
    final List<T?> latestValues = List<T?>.filled(streamList.length, null);
    final List<bool> hasEmitted = List<bool>.filled(streamList.length, false);
    final List<StreamSubscription<T>> subscriptions = [];

    void checkEmit() {
      if (hasEmitted.every((h) => h)) {
        controller.add(latestValues.cast<T>());
      }
    }

    for (int i = 0; i < streamList.length; i++) {
      final sub = streamList[i].listen(
        (data) {
          latestValues[i] = data;
          hasEmitted[i] = true;
          checkEmit();
        },
        onError: (err) {
          controller.addError(err);
        },
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

// -------------------------------------------------------------
// SVG / CANVAS DOODLES (MATCHING HOME SISWA EXACTLY)
// -------------------------------------------------------------

/// 1. Doodle Illustration for Task (Clipboard with Checkmark)
class _TaskDeadlineDoodle extends StatelessWidget {
  final double size;
  const _TaskDeadlineDoodle({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TaskDeadlinePainter(),
      ),
    );
  }
}

class _TaskDeadlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeW = (w / 28.0).clamp(1.1, 1.35);

    final Paint outline = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint boardBg = Paint()..color = const Color(0xFFFED7AA)..style = PaintingStyle.fill;
    final Paint paperBg = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final Paint clipBg = Paint()..color = const Color(0xFF94A3B8)..style = PaintingStyle.fill;
    final Paint checkBg = Paint()..color = const Color(0xFF4ADE80)..style = PaintingStyle.fill;

    final RRect board = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.16, w * 0.70, h * 0.76),
      const Radius.circular(8),
    );
    canvas.drawRRect(board, boardBg);
    canvas.drawRRect(board, outline);

    final RRect paper = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.23, h * 0.24, w * 0.54, h * 0.62),
      const Radius.circular(4),
    );
    canvas.drawRRect(paper, paperBg);
    canvas.drawRRect(paper, outline);

    final RRect clamp = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.36, h * 0.10, w * 0.28, h * 0.12),
      const Radius.circular(3),
    );
    canvas.drawRRect(clamp, clipBg);
    canvas.drawRRect(clamp, outline);

    canvas.drawLine(Offset(w * 0.32, h * 0.40), Offset(w * 0.68, h * 0.40), outline);
    canvas.drawLine(Offset(w * 0.32, h * 0.54), Offset(w * 0.68, h * 0.54), outline);
    canvas.drawLine(Offset(w * 0.32, h * 0.68), Offset(w * 0.56, h * 0.68), outline);

    final double checkRadius = (w * 0.13).clamp(3.5, 7.0);
    canvas.drawCircle(Offset(w * 0.75, h * 0.74), checkRadius, checkBg);
    canvas.drawCircle(Offset(w * 0.75, h * 0.74), checkRadius, outline);
    final Path checkPath = Path()
      ..moveTo(w * 0.71, h * 0.74)
      ..lineTo(w * 0.74, h * 0.77)
      ..lineTo(w * 0.79, h * 0.70);
    canvas.drawPath(checkPath, outline);
  }

  @override
  bool shouldRepaint(covariant _TaskDeadlinePainter oldDelegate) => false;
}

/// 2. Doodle Illustration for Materi / PDF (Open Book + Ribbon)
class _ClassScheduleDoodle extends StatelessWidget {
  final double size;
  const _ClassScheduleDoodle({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ClassSchedulePainter(),
      ),
    );
  }
}

class _ClassSchedulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeW = (w / 28.0).clamp(1.1, 1.35);

    final Paint outline = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint bookBg = Paint()..color = const Color(0xFFBAE6FD)..style = PaintingStyle.fill;
    final Paint bookmark = Paint()..color = const Color(0xFFF472B6)..style = PaintingStyle.fill;
    final Paint pencil = Paint()..color = const Color(0xFFFDE047)..style = PaintingStyle.fill;

    final Path leftPage = Path()
      ..moveTo(w * 0.50, h * 0.78)
      ..cubicTo(w * 0.35, h * 0.72, w * 0.20, h * 0.76, w * 0.12, h * 0.70)
      ..lineTo(w * 0.12, h * 0.28)
      ..cubicTo(w * 0.22, h * 0.34, w * 0.36, h * 0.30, w * 0.50, h * 0.36)
      ..close();
    canvas.drawPath(leftPage, bookBg);
    canvas.drawPath(leftPage, outline);

    final Path rightPage = Path()
      ..moveTo(w * 0.50, h * 0.78)
      ..cubicTo(w * 0.65, h * 0.72, w * 0.80, h * 0.76, w * 0.88, h * 0.70)
      ..lineTo(w * 0.88, h * 0.28)
      ..cubicTo(w * 0.78, h * 0.34, w * 0.64, h * 0.30, w * 0.50, h * 0.36)
      ..close();
    canvas.drawPath(rightPage, bookBg);
    canvas.drawPath(rightPage, outline);

    canvas.drawLine(Offset(w * 0.50, h * 0.36), Offset(w * 0.50, h * 0.78), outline);

    final Path ribbon = Path()
      ..moveTo(w * 0.46, h * 0.36)
      ..lineTo(w * 0.46, h * 0.55)
      ..lineTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.54, h * 0.55)
      ..lineTo(w * 0.54, h * 0.36)
      ..close();
    canvas.drawPath(ribbon, bookmark);
    canvas.drawPath(ribbon, outline);

    final Path pencilPath = Path()
      ..moveTo(w * 0.70, h * 0.18)
      ..lineTo(w * 0.82, h * 0.08)
      ..lineTo(w * 0.88, h * 0.14)
      ..lineTo(w * 0.76, h * 0.24)
      ..close();
    canvas.drawPath(pencilPath, pencil);
    canvas.drawPath(pencilPath, outline);
  }

  @override
  bool shouldRepaint(covariant _ClassSchedulePainter oldDelegate) => false;
}

/// 3. Doodle Illustration for Quiz (Interlocking Colorful Puzzle Pieces)
class _QuizPuzzleDoodle extends StatelessWidget {
  final double size;
  const _QuizPuzzleDoodle({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _QuizPuzzlePainter(),
      ),
    );
  }
}

class _QuizPuzzlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeW = (w / 28.0).clamp(1.1, 1.35);

    final Paint outlinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint puzzle1Paint = Paint()
      ..color = const Color(0xFFC084FC) // Lavender Purple Piece
      ..style = PaintingStyle.fill;

    final Paint puzzle2Paint = Paint()
      ..color = const Color(0xFFFDE047) // Amber Gold Piece
      ..style = PaintingStyle.fill;

    // Piece 1: Left / Top-Left Interlocking Puzzle Piece
    final Path piece1 = Path()
      ..moveTo(w * 0.12, h * 0.22)
      ..lineTo(w * 0.38, h * 0.22)
      // Top Tab
      ..cubicTo(w * 0.36, h * 0.08, w * 0.54, h * 0.08, w * 0.52, h * 0.22)
      ..lineTo(w * 0.56, h * 0.22)
      // Right Connector to Piece 2
      ..lineTo(w * 0.56, h * 0.40)
      ..cubicTo(w * 0.70, h * 0.38, w * 0.70, h * 0.56, w * 0.56, h * 0.54)
      ..lineTo(w * 0.56, h * 0.78)
      ..lineTo(w * 0.12, h * 0.78)
      // Left Indent
      ..lineTo(w * 0.12, h * 0.54)
      ..cubicTo(w * 0.24, h * 0.56, w * 0.24, h * 0.38, w * 0.12, h * 0.40)
      ..close();

    // Piece 2: Right / Bottom-Right Puzzle Piece
    final Path piece2 = Path()
      ..moveTo(w * 0.56, h * 0.26)
      ..lineTo(w * 0.88, h * 0.26)
      ..lineTo(w * 0.88, h * 0.48)
      // Right Tab
      ..cubicTo(w * 1.02, h * 0.46, w * 1.02, h * 0.64, w * 0.88, h * 0.62)
      ..lineTo(w * 0.88, h * 0.88)
      ..lineTo(w * 0.56, h * 0.88)
      // Bottom Indent
      ..lineTo(w * 0.46, h * 0.88)
      ..cubicTo(w * 0.48, h * 0.76, w * 0.34, h * 0.76, w * 0.36, h * 0.88)
      ..lineTo(w * 0.56, h * 0.88)
      ..lineTo(w * 0.56, h * 0.78)
      ..lineTo(w * 0.56, h * 0.54)
      ..cubicTo(w * 0.70, h * 0.56, w * 0.70, h * 0.38, w * 0.56, h * 0.40)
      ..close();

    // Draw Piece 1 with outline
    canvas.drawPath(piece1, puzzle1Paint);
    canvas.drawPath(piece1, outlinePaint);

    // Draw Piece 2 with outline
    canvas.drawPath(piece2, puzzle2Paint);
    canvas.drawPath(piece2, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _QuizPuzzlePainter oldDelegate) => false;
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
