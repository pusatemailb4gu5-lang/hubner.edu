import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final List<Color> _classroomAccentColors = const [
  Color(0xFF009688), // 0: Teal
  Color(0xFF448AFF), // 1: Blue
  Color(0xFFE040FB), // 2: Purple/Magenta
  Color(0xFFFF4081), // 3: Pink/Rose
  Color(0xFFFFAB40), // 4: Orange/Amber
  Color(0xFF536DFE), // 5: Indigo
  Color(0xFF607D8B), // 6: Blue Grey
];

class DesktopJadwalPembelajaranTab extends StatefulWidget {
  final String projectId;

  const DesktopJadwalPembelajaranTab({
    super.key,
    required this.projectId,
  });

  @override
  State<DesktopJadwalPembelajaranTab> createState() =>
      _DesktopJadwalPembelajaranTabState();
}

class _DesktopJadwalPembelajaranTabState
    extends State<DesktopJadwalPembelajaranTab> {
  String _selectedDayFilter = 'Semua Hari';

  final List<String> _daysList = const [
    'Semua Hari',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String ownerUid = data['ownerUid'] as String? ?? '';
        final bool isOwner =
            ownerUid == (FirebaseAuth.instance.currentUser?.uid ?? '');
        final int? rawColorIndex = data['colorIndex'] as int?;

        // 40/60 Color Concept Accent Sync
        final Color accentColor = rawColorIndex != null
            ? _classroomAccentColors[rawColorIndex % _classroomAccentColors.length]
            : const Color(0xFF7C3AED);

        final List rawSchedules = data['schedules'] as List? ?? [];
        final List<Map<String, dynamic>> schedules = rawSchedules
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();

        // Filter schedules by day if filter selected
        final List<Map<String, dynamic>> filteredSchedules =
            _selectedDayFilter == 'Semua Hari'
                ? schedules
                : schedules
                    .where((s) => (s['day'] ?? '') == _selectedDayFilter)
                    .toList();

        return SingleChildScrollView(
            key: const PageStorageKey('JadwalPembelajaranScroll'),
            padding: const EdgeInsets.only(left: 24, right: 24, top: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. TOP SCHEDULE HERO BANNER (Emerald Style) ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFF059669),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jadwal Pembelajaran Kelas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 23.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${schedules.length} Sesi Belajar Mengajar Terjadwal Otomatis',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showAddScheduleDialog(context, schedules),
                          icon: const Icon(Icons.alarm_add_rounded, size: 18),
                          label: Text(
                            'Atur & Tambah Jadwal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD600),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
 
                // ─── 2. DAY FILTER PILLS ───
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _daysList.map((day) {
                      final isSelected = _selectedDayFilter == day;
                      Color activeColor = const Color(0xFF7C3AED); // Default purple
                      if (isSelected) {
                        switch (day.toLowerCase()) {
                          case 'senin':
                            activeColor = const Color(0xFFEF4444);
                            break;
                          case 'selasa':
                            activeColor = const Color(0xFFF97316);
                            break;
                          case 'rabu':
                            activeColor = const Color(0xFF10B981);
                            break;
                          case 'kamis':
                            activeColor = const Color(0xFF3B82F6);
                            break;
                          case 'jumat':
                            activeColor = const Color(0xFF8B5CF6);
                            break;
                          case 'sabtu':
                            activeColor = const Color(0xFFEC4899);
                            break;
                          case 'minggu':
                            activeColor = const Color(0xFF14B8A6);
                            break;
                          default:
                            activeColor = const Color(0xFF7C3AED); // Semua hari: ungu
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedDayFilter = day;
                              });
                            }
                          },
                          selectedColor: activeColor,
                          backgroundColor: Colors.white,
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? activeColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── 3. MULTI-COLUMN MAIN LAYOUT (Left 60% Timetable Cards + Right 40% Agenda & Reminders) ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN (60% Width — flex: 6): Timetable Session List
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sesi Pembelajaran (${_selectedDayFilter})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18.7,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF000000),
                                ),
                              ),
                              Text(
                                '${filteredSchedules.length} Sesi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF000000),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (filteredSchedules.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 44,
                                      color: const Color(0xFF000000),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada jadwal pembelajaran untuk ${_selectedDayFilter}.',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15.2,
                                        color: const Color(0xFF000000),
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
                              itemCount: filteredSchedules.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final s = filteredSchedules[index];
                                return _buildScheduleSessionCard(
                                  context: context,
                                  scheduleData: s,
                                  index: index,
                                  accentColor: accentColor,
                                  isOwner: isOwner,
                                  allSchedules: schedules,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // RIGHT COLUMN (40% Width — flex: 4): Agenda & Reminder Side Cards
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          // Card 1: Today's Summary & Live Agenda
                          _buildTodaySummaryCard(
                            accentColor: accentColor,
                            schedules: schedules,
                          ),
                          const SizedBox(height: 16),
                          // Card 2: Classroom Calendar Info & Notes
                          _buildCalendarNotesCard(accentColor: accentColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        );
      },
    );
  }

  // Session Card Widget
  Widget _buildScheduleSessionCard({
    required BuildContext context,
    required Map<String, dynamic> scheduleData,
    required int index,
    required Color accentColor,
    required bool isOwner,
    required List<Map<String, dynamic>> allSchedules,
  }) {
    final String day = scheduleData['day'] ?? 'Senin';
    final String time = scheduleData['time'] ?? '08:00 - 09:30';
    final String room = scheduleData['room'] ?? 'Ruang Kelas XI DKV 2';
    final String topic = scheduleData['topic'] ?? 'Sesi Belajar Mengajar Utama';
    final String teacher = scheduleData['teacher'] ?? 'Guru Pengajar';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  day,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteSchedule(index, allSchedules),
                  tooltip: 'Hapus Jadwal',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            topic,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.6,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.room_rounded,
                size: 15,
                color: const Color(0xFF000000),
              ),
              const SizedBox(width: 4),
              Text(
                room,
                style: GoogleFonts.dmSans(
                  fontSize: 14.7,
                  color: const Color(0xFF000000),
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: const Color(0xFF000000),
              ),
              const SizedBox(width: 4),
              Text(
                teacher,
                style: GoogleFonts.dmSans(
                  fontSize: 14.7,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Today Summary Card
  Widget _buildTodaySummaryCard({
    required Color accentColor,
    required List<Map<String, dynamic>> schedules,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.today_rounded, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Ringkasan Jadwal Mingguan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17.6,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Total ${schedules.length} sesi pembelajaran terkonfigurasi di kelas ini.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF000000),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF059669),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seluruh jadwal tersinkronisasi otomatis dengan siswa.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF000000),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Calendar Notes Card
  Widget _buildCalendarNotesCard({required Color accentColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Catatan Pembelajaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17.6,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pastikan siswa telah menerima notifikasi sebelum sesi pembelajaran dimulai.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF000000),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog to Add Schedule
  void _showAddScheduleDialog(
      BuildContext context, List<Map<String, dynamic>> currentSchedules) {
    final List<String> availableDays = const [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    String selectedDay = 'Senin';
    final timeController = TextEditingController(text: '08:00 - 09:30');

    // Load existing schedules into editable local list
    final List<Map<String, dynamic>> tempSchedules = List.from(
      currentSchedules.map((e) => Map<String, dynamic>.from(e as Map)),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.alarm_add_rounded,
                    color: Color(0xFF7C3AED),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Atur Jadwal Belajar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. INPUT FORM AREA
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hari Belajar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedDay,
                                  isExpanded: true,
                                  isDense: true,
                                  itemHeight: null,
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                  items: availableDays.map((d) {
                                    return DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedDay = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Jam Pelajaran',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: timeController,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                color: const Color(0xFF1E293B),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Contoh: 08:00 - 09:30',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7C3AED),
                                    width: 1.8,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final timeText = timeController.text.trim();
                                  if (timeText.isEmpty) return;

                                  final defaultTeacher = FirebaseAuth
                                          .instance.currentUser?.displayName ??
                                      'Guru Pengajar';

                                  setDialogState(() {
                                    tempSchedules.add({
                                      'id': 'sched_${selectedDay}_${DateTime.now().millisecondsSinceEpoch}_${tempSchedules.length}',
                                      'day': selectedDay,
                                      'time': timeText,
                                      'room': '',
                                      'topic': 'Sesi Belajar',
                                      'teacher': defaultTeacher,
                                    });
                                  });
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Tambah Jadwal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. EXISTING & NEW SCHEDULES LIST
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daftar Jadwal (${tempSchedules.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          if (tempSchedules.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempSchedules.clear();
                                });
                              },
                              child: Text(
                                'Hapus Semua',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (tempSchedules.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Belum ada jadwal yang ditambahkan.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: tempSchedules.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final sched = tempSchedules[idx];
                              final String dayName = sched['day'] ?? 'Senin';
                              final String timeVal = sched['time'] ?? '08:00 - 09:30';

                              Color dayBadgeColor;
                              switch (dayName.toLowerCase()) {
                                case 'senin':
                                  dayBadgeColor = const Color(0xFFEF4444);
                                  break;
                                case 'selasa':
                                  dayBadgeColor = const Color(0xFFF97316);
                                  break;
                                case 'rabu':
                                  dayBadgeColor = const Color(0xFF10B981);
                                  break;
                                case 'kamis':
                                  dayBadgeColor = const Color(0xFF3B82F6);
                                  break;
                                case 'jumat':
                                  dayBadgeColor = const Color(0xFF8B5CF6);
                                  break;
                                case 'sabtu':
                                  dayBadgeColor = const Color(0xFFEC4899);
                                  break;
                                default:
                                  dayBadgeColor = const Color(0xFF14B8A6);
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: dayBadgeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        dayName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: dayBadgeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        timeVal,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                        size: 18,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        setDialogState(() {
                                          tempSchedules.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.only(
                right: 20,
                bottom: 16,
                left: 20,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .update({'schedules': tempSchedules});

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    'Simpan Jadwal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteSchedule(
      int index, List<Map<String, dynamic>> currentSchedules) async {
    if (index >= 0 && index < currentSchedules.length) {
      final updated = List<Map<String, dynamic>>.from(currentSchedules)
        ..removeAt(index);
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'schedules': updated});
    }
  }
}
