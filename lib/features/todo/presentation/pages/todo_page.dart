import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoPage extends StatefulWidget {
  final DateTime? initialDate;
  const TodoPage({super.key, this.initialDate});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  late DateTime _selectedDay;
  
  // Cache the streams to avoid flicker on rebuild
  late final Stream<DocumentSnapshot> _userStream;
  List<String> _lastProjectIds = [];
  Stream<QuerySnapshot?>? _projectsStream;

  final List<Color> _bgColors = const [
    Color(0xFFE2ECE9), // Teal
    Color(0xFFE2DCF7), // Purple/Lavender
    Color(0xFFFEF3C7), // Yellow
    Color(0xFFEFF6FF), // Blue
    Color(0xFFFCE7F3), // Pink
  ];

  final List<Color> _textColors = const [
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate ?? DateTime.now();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .snapshots();
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
    } catch (e) {
      // ignore
    }
    return null;
  }

  bool _isTaskOnDay(Map<String, dynamic> task, DateTime day) {
    final startStr = task['start'] as String? ?? '';
    final endStr = task['end'] as String? ?? '';
    if (startStr.isEmpty || endStr.isEmpty || startStr == 'DD/MM/YYYY') return false;

    final startDate = _parseDateString(startStr);
    final endDate = _parseDateString(endStr);
    if (startDate == null || endDate == null) return false;

    final targetDay = DateTime(day.year, day.month, day.day);
    final normStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return (targetDay.isAfter(normStart) || targetDay.isAtSameMomentAs(normStart)) &&
           (targetDay.isBefore(normEnd) || targetDay.isAtSameMomentAs(normEnd));
  }

  Color _getDayCardBg(int weekday) {
    switch (weekday) {
      case 1: // Senin
        return const Color(0xFFDBEAFE); // Rich Soft Blue Tint
      case 2: // Selasa
        return const Color(0xFFD1FAE5); // Rich Soft Green Tint
      case 3: // Rabu
        return const Color(0xFFFDE68A); // Rich Soft Amber Tint
      case 4: // Kamis
        return const Color(0xFFE9D5FF); // Rich Soft Purple Tint
      case 5: // Jumat
        return const Color(0xFFCCFBF1); // Rich Soft Teal Tint
      case 6: // Sabtu
      case 7: // Minggu
      default:
        return const Color(0xFFFECDD3); // Rich Soft Red Tint for Sat & Sun
    }
  }

  Color _getDayTextColor(int weekday) {
    switch (weekday) {
      case 1: // Senin
        return const Color(0xFF1D4ED8); // Deep Blue
      case 2: // Selasa
        return const Color(0xFF047857); // Deep Green
      case 3: // Rabu
        return const Color(0xFFB45309); // Deep Amber
      case 4: // Kamis
        return const Color(0xFF6D28D9); // Deep Purple
      case 5: // Jumat
        return const Color(0xFF0F766E); // Deep Teal
      case 6: // Sabtu
      case 7: // Minggu
      default:
        return const Color(0xFFBE123C); // Deep Red for Sat & Sun
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);
    // Generate 14 rolling calendar days
    final List<DateTime> calendarDays = List.generate(14, (index) {
      return todayDate.subtract(const Duration(days: 4)).add(Duration(days: index));
    });

    final currentMonthYearStr = '${_getMonthName(_selectedDay.month)} ${_selectedDay.year}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom AppBar (Clean top)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                      Text(
                        'Jadwal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21.1,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // Calendar Day Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentMonthYearStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17.6,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_month_outlined, size: 18, color: Colors.black45),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    key: const PageStorageKey('todo_calendar_slider'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: calendarDays.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = calendarDays[index];
                      final bool isSelected = _selectedDay.day == day.day &&
                          _selectedDay.month == day.month &&
                          _selectedDay.year == day.year;

                      final Color activeBgColor = _getDayCardBg(day.weekday);
                      final Color dayTextColor = _getDayTextColor(day.weekday);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDay = day;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? activeBgColor : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? dayTextColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? dayTextColor : dayTextColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getDayName(day.weekday),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : dayTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                day.day.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18.7,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.black : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Vertical Timeline Schedule
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _userStream,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
                        return const Center(child: ThreeDotsLoader());
                      }
                      final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                      final projectIds = List<String>.from(userData?['projectIds'] ?? []);

                      // Only create a new stream if the list of projectIds has changed
                      final bool listsEqual = _lastProjectIds.length == projectIds.length &&
                          projectIds.every((id) => _lastProjectIds.contains(id));
                      
                      if (!listsEqual || _projectsStream == null) {
                        _lastProjectIds = projectIds;
                        _projectsStream = projectIds.isEmpty
                            ? Stream<QuerySnapshot?>.value(null)
                            : FirebaseFirestore.instance
                                .collection('projects')
                                .where(FieldPath.documentId, whereIn: projectIds)
                                .snapshots();
                      }

                      return StreamBuilder<QuerySnapshot?>(
                        stream: _projectsStream,
                        builder: (context, projectsSnapshot) {
                          if (projectsSnapshot.connectionState == ConnectionState.waiting && !projectsSnapshot.hasData) {
                            return const Center(child: ThreeDotsLoader());
                          }

                          final projectDocs = projectsSnapshot.data?.docs ?? [];
                          final List<Map<String, dynamic>> allTasks = [];

                          for (var projDoc in projectDocs) {
                            final projData = projDoc.data() as Map<String, dynamic>;
                            final projName = projData['name'] ?? 'Proyek';
                            final projectId = projDoc.id;
                            final stages = projData['stages'] as List? ?? [];
                            for (int stageIdx = 0; stageIdx < stages.length; stageIdx++) {
                              final stageMap = stages[stageIdx] as Map<String, dynamic>;
                              final stageName = stageMap['name'] ?? '';
                              final tasks = stageMap['stagesList'] ?? stageMap['tasks'] as List? ?? [];
                              for (int taskIdx = 0; taskIdx < tasks.length; taskIdx++) {
                                final taskMap = Map<String, dynamic>.from(tasks[taskIdx] as Map);
                                taskMap['projectName'] = projName;
                                taskMap['projectId'] = projectId;
                                taskMap['stageName'] = stageName;
                                taskMap['stageIdx'] = stageIdx;
                                taskMap['taskIdx'] = taskIdx;
                                taskMap['stagesList'] = stages;
                                allTasks.add(taskMap);
                              }
                            }
                          }

                          // Filter tasks for the selected day
                          final dayTasks = allTasks.where((t) => _isTaskOnDay(t, _selectedDay)).toList();

                          if (dayTasks.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 64,
                                    color: Colors.black12,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Bebas tugas untuk hari ini!',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 16.4,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            itemCount: dayTasks.length,
                            itemBuilder: (context, index) {
                              final task = dayTasks[index];
                              final bool isDone = task['isDone'] ?? false;
                              final int progress = task['progress'] ?? (isDone ? 100 : 0);

                              String progressStr = '';
                              if (isDone || progress == 100) {
                                progressStr = 'Selesai';
                              } else if (progress > 0) {
                                progressStr = 'Sedang berjalan ($progress%)';
                              } else {
                                progressStr = 'Harus dilakukan';
                              }

                              final cardBgColor = _bgColors[index % _bgColors.length];
                              final cardTextColor = _textColors[index % _textColors.length];

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Left: Date info
                                    Container(
                                      width: 75,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Text(
                                        task['start'] ?? '',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),

                                    // Middle: Timeline Line
                                    Column(
                                      children: [
                                        const SizedBox(height: 22),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: index < dayTasks.length - 1
                                              ? Container(
                                                  width: 2,
                                                  color: const Color(0xFFF1F5F9),
                                                )
                                              : const SizedBox(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),

                                    // Right: Task Details Card
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            final bool isPending = task['isPendingApproval'] ?? false;
                                            if (isPending) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Tugas ini sedang menunggu persetujuan pemilik.')),
                                              );
                                              return;
                                            }
                                            _showTaskProgressDialog(
                                              context: context,
                                              projectId: task['projectId'] ?? '',
                                              stageIdx: task['stageIdx'] ?? 0,
                                              taskIdx: task['taskIdx'] ?? 0,
                                              currentProgress: progress,
                                              currentStages: task['stagesList'] ?? [],
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: cardBgColor,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  task['title'] ?? '',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 15.2,
                                                    fontWeight: FontWeight.bold,
                                                    color: cardTextColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Classroom: ${task['projectName']} | Materi: ${task['stageName']}',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 14.0,
                                                    color: cardTextColor.withOpacity(0.8),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  task['isPendingApproval'] == true
                                                      ? 'Status: Menunggu Acc Guru'
                                                      : 'Status: $progressStr',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: cardTextColor.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[weekday - 1];
  }

  Future<void> _showTaskProgressDialog({
    required BuildContext context,
    required String projectId,
    required int stageIdx,
    required int taskIdx,
    required int currentProgress,
    required List<dynamic> currentStages,
  }) async {
    int selectedProgress = currentProgress;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double progressVal = selectedProgress.toDouble();
            final Color dynamicColor = Color.lerp(
              const Color(0xFFEF4444), // Red
              const Color(0xFF22C55E), // Green
              progressVal / 100.0,
            ) ?? Colors.black;

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: dynamicColor,
                              inactiveTrackColor: const Color(0xFFF1F5F9),
                              thumbColor: dynamicColor,
                              overlayColor: dynamicColor.withOpacity(0.1),
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              showValueIndicator: ShowValueIndicator.onDrag,
                              valueIndicatorColor: dynamicColor,
                              valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            child: Slider(
                              value: progressVal,
                              min: 0,
                              max: 100,
                              divisions: 4,
                              label: '$selectedProgress%',
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedProgress = val.toInt();
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [0, 25, 50, 75, 100].map((v) {
                                final isSelected = selectedProgress == v;
                                return Text(
                                  '$v%',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.0,
                                    color: isSelected ? dynamicColor : Colors.black26,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.black87,
                          size: 18,
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

    // Auto-save to Firestore on dialog dismissal
    try {
      final List<dynamic> updatedStages = List<dynamic>.from(
        currentStages.map((s) {
          final stageMap = Map<String, dynamic>.from(s as Map);
          final tasksList = List<dynamic>.from(stageMap['tasks'] as List);
          stageMap['tasks'] = tasksList.map((t) => Map<String, dynamic>.from(t as Map)).toList();
          return stageMap;
        }),
      );

      final task = updatedStages[stageIdx]['tasks'][taskIdx] as Map<String, dynamic>;
      task['progress'] = selectedProgress;
      task['isDone'] = selectedProgress == 100;

      await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
        'stages': updatedStages,
      });
    } catch (e) {
      // ignore
    }
  }
}
