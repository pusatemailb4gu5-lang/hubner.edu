import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/features/projects/presentation/widgets/student_activity_dialogs.dart';
import 'package:hubner/features/projects/presentation/pages/class_page.dart';
import 'mengerjakan_tugas_page.dart';
import 'mengerjakan_quiz_page.dart';
import 'baca_materi_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/core/theme/app_colors.dart';

class MonitoringPage extends StatefulWidget {
  final String? initialProjectId;
  const MonitoringPage({super.key, this.initialProjectId});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  String? _selectedProjectId;
  Map<String, dynamic>? _selectedProjectData;
  List<Map<String, dynamic>> _userProjects = [];
  bool _isLoadingProjects = true;
  bool _isGuru = false;
  String _searchQuery = '';

  String _teacherName = '';
  String _teacherPhoto = '';
  String _teacherGender = '';

  final Set<int> _expandedStageIndices = {};
  final Set<String> _expandedMateriKeys = {};

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

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    _checkUserRole();
    _loadUserProjects();
  }

  Future<void> _checkUserRole() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (userDoc.exists && mounted) {
        final role = (userDoc.data()?['role'] ?? 'Siswa').toString();
        setState(() {
          _isGuru = role.toLowerCase() == 'guru';
        });
      }
    } catch (e) {
      // ignore
    }
  }

  String _formatTeacherTitle(String rawName, String? gender) {
    if (rawName.isEmpty) return 'Bp. Pengajar';

    String cleanName = rawName
        .replaceAll(
          RegExp(r'^(Pak|Bapak|Bp\.?|Bu\.?|Ibu)\s+', caseSensitive: false),
          '',
        )
        .trim();

    if (cleanName.isEmpty) return 'Bp. Pengajar';

    final lowerGender = (gender ?? '').toLowerCase();
    final lowerFirst = cleanName.toLowerCase();
    bool isFemale =
        lowerGender == 'perempuan' ||
        lowerGender == 'female' ||
        lowerFirst.startsWith('siti') ||
        lowerFirst.startsWith('nurut') ||
        lowerFirst.startsWith('ani') ||
        lowerFirst.startsWith('dwi') ||
        lowerFirst.startsWith('riri') ||
        lowerFirst.startsWith('fitri') ||
        lowerFirst.startsWith('putri') ||
        lowerFirst.startsWith('dian') ||
        lowerFirst.startsWith('dewi');

    final prefix = isFemale ? 'Bu' : 'Bp.';
    return '$prefix $cleanName';
  }

  Future<void> _fetchTeacherInfo(String? ownerUid) async {
    if (ownerUid == null || ownerUid.isEmpty) {
      if (mounted) {
        setState(() {
          _teacherName =
              _selectedProjectData?['teacherName'] ??
              _selectedProjectData?['ownerName'] ??
              '';
          _teacherPhoto =
              _selectedProjectData?['teacherPhoto'] ??
              _selectedProjectData?['ownerPhoto'] ??
              '';
          _teacherGender = _selectedProjectData?['teacherGender'] ?? '';
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .get();
      if (userDoc.exists && mounted) {
        final uData = userDoc.data()!;
        final tName =
            (uData['name'] ?? uData['displayName'] ?? uData['full_name'] ?? '')
                .toString();
        final tPhoto =
            (uData['photoUrl'] ??
                    uData['profileImage'] ??
                    uData['photo'] ??
                    uData['avatar'] ??
                    '')
                .toString();
        final tGender = (uData['gender'] ?? uData['jenisKelamin'] ?? '')
            .toString();

        setState(() {
          _teacherName = tName;
          _teacherPhoto = tPhoto;
          _teacherGender = tGender;
        });
      } else if (mounted) {
        setState(() {
          _teacherName =
              _selectedProjectData?['teacherName'] ??
              _selectedProjectData?['ownerName'] ??
              '';
          _teacherPhoto =
              _selectedProjectData?['teacherPhoto'] ??
              _selectedProjectData?['ownerPhoto'] ??
              '';
          _teacherGender = _selectedProjectData?['teacherGender'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teacherName =
              _selectedProjectData?['teacherName'] ??
              _selectedProjectData?['ownerName'] ??
              '';
          _teacherPhoto =
              _selectedProjectData?['teacherPhoto'] ??
              _selectedProjectData?['ownerPhoto'] ??
              '';
          _teacherGender = _selectedProjectData?['teacherGender'] ?? '';
        });
      }
    }
  }

  void _showCpDialog(
    BuildContext context,
    Map<String, dynamic>? projectData,
    Color accentColor,
  ) {
    final List stages = projectData?['stages'] as List? ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_outlined,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capaian Pembelajaran',
                                style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Target & Tujuan Pembelajaran (CP)',
                                style: AppTypography.timestamp(color: Colors.black45),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black45,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Elemen Pembelajaran',
                          style: AppTypography.buttonLabel(color: accentColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (stages.isEmpty)
                          Text(
                            'Belum ada elemen pembelajaran yang dikonfigurasi.',
                            style: AppTypography.timestamp(color: Colors.black45),
                          )
                        else
                          ...List.generate(stages.length, (idx) {
                            final stage = stages[idx] as Map;
                            final String title =
                                stage['name'] ?? 'Elemen ${idx + 1}';
                            final String desc =
                                stage['desc'] ??
                                'Elemen pembelajaran ke-${idx + 1}';
                            final Color itemBgColor =
                                _classroomCardColors[idx %
                                    _classroomCardColors.length];
                            final Color itemAccentColor =
                                _classroomAccentColors[idx %
                                    _classroomAccentColors.length];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: itemBgColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: itemAccentColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${idx + 1}',
                                        style: AppTypography.buttonLabel(color: itemAccentColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          desc,
                                          style: AppTypography.timestamp(color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJadwalDialog(
    BuildContext context,
    Map<String, dynamic>? projectData,
    Color accentColor,
  ) {
    final List schedules = projectData?['schedules'] as List? ?? [];

    final Map<String, Map<String, Color>> dayColorsMap = {
      'senin': {'bg': const Color(0xFFFEF2F2), 'fg': const Color(0xFFEF4444)},
      'selasa': {'bg': const Color(0xFFFFF7ED), 'fg': const Color(0xFFF97316)},
      'rabu': {'bg': const Color(0xFFF0FDF4), 'fg': const Color(0xFF10B981)},
      'kamis': {'bg': const Color(0xFFEFF6FF), 'fg': const Color(0xFF3B82F6)},
      'jumat': {'bg': const Color(0xFFF3E8FF), 'fg': const Color(0xFF8B5CF6)},
      'sabtu': {'bg': const Color(0xFFFDF2F8), 'fg': const Color(0xFFEC4899)},
      'minggu': {'bg': const Color(0xFFF0FDFA), 'fg': const Color(0xFF14B8A6)},
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jadwal Pelajaran',
                                style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Hari & Jam Pertemuan Kelas',
                                style: AppTypography.timestamp(color: Colors.black45),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black45,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (schedules.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 36,
                                  color: Colors.black26,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Belum Ada Jadwal',
                                  style: AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Jadwal pelajaran belum diatur oleh guru pengajar.',
                                  style: AppTypography.timestamp(color: Colors.black45),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ...List.generate(schedules.length, (idx) {
                            final item = schedules[idx] as Map;
                            final String dayStr = (item['day'] ?? 'Senin')
                                .toString();
                            final String startTime =
                                (item['startTime'] ?? item['start'] ?? '07:30')
                                    .toString();
                            final String endTime =
                                (item['endTime'] ?? item['end'] ?? '09:00')
                                    .toString();
                            final String room =
                                (item['room'] ??
                                        item['ruangan'] ??
                                        'Ruang Kelas')
                                    .toString();

                            final key = dayStr.toLowerCase();
                            final colorScheme =
                                dayColorsMap[key] ??
                                {
                                  'bg': const Color(0xFFEFF6FF),
                                  'fg': const Color(0xFF2563EB),
                                };
                            final Color dBg = colorScheme['bg']!;
                            final Color dFg = colorScheme['fg']!;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: dBg,
                                borderRadius: BorderRadius.circular(20),
                                border: null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dFg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      dayStr.toUpperCase(),
                                      style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 14,
                                              color: dFg,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$startTime - $endTime WIB',
                                              style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 13,
                                              color: Colors.black45,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              room,
                                              style: AppTypography.timestamp(color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addFriendByUid(
    BuildContext context,
    String targetUid,
    String targetName,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || targetUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
            'friendUids': FieldValue.arrayUnion([targetUid]),
          });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .update({
            'friendUids': FieldValue.arrayUnion([currentUid]),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil berteman dengan $targetName!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan teman: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showClassMembersSheet(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List masterList =
        _selectedProjectData?['studentsMasterList'] as List? ?? [];
    final String ownerUid =
        (_selectedProjectData?['ownerUid'] ??
                _selectedProjectData?['teacherUid'] ??
                '')
            .toString();
    final String teacherDisplayName = _formatTeacherTitle(
      _teacherName.isNotEmpty
          ? _teacherName
          : (_selectedProjectData?['teacherName'] ??
                _selectedProjectData?['ownerName'] ??
                'Pengajar'),
      _teacherGender,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, userSnap) {
            final userData = (userSnap.hasData && userSnap.data!.exists)
                ? userSnap.data!.data() as Map<String, dynamic>?
                : null;
            final List<String> friendUids =
                userData != null && userData.containsKey('friendUids')
                ? List<String>.from(userData['friendUids'] ?? [])
                : [];

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anggota Kelas',
                          style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Guru pengajar & teman sekelas terdaftar',
                          style: AppTypography.timestamp(color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      children: [
                        // 1. GURU SECTION (TEACHER AT THE VERY TOP)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                ),
                                child: _teacherPhoto.isNotEmpty
                                    ? Image.network(
                                        _teacherPhoto,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) =>
                                            const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                      )
                                    : const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            teacherDisplayName,
                                            style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Guru',
                                            style: AppTypography.buttonLabel(color: const Color(0xFFD97706), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Pengajar Kelas',
                                      style: AppTypography.timestamp(color: Colors.black45),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (ownerUid.isNotEmpty &&
                                  ownerUid != currentUid) ...[
                                if (friendUids.contains(ownerUid))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Teman',
                                      style: AppTypography.buttonLabel(color: const Color(0xFF15803D), fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () => _addFriendByUid(
                                      context,
                                      ownerUid,
                                      teacherDisplayName,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.person_add_alt_1_rounded,
                                            size: 11,
                                            color: Color(0xFF1D4ED8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tambah',
                                            style: AppTypography.buttonLabel(color: const Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFFE2E8F0), height: 1),
                        const SizedBox(height: 12),

                        // 2. STUDENTS LIST SECTION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daftar Siswa',
                              style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${masterList.length} Siswa',
                              style: AppTypography.timestamp(color: Colors.black45),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (masterList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Belum ada siswa terdaftar di kelas ini.',
                                style: AppTypography.timestamp(color: Colors.black45),
                              ),
                            ),
                          )
                        else
                          ...List.generate(masterList.length, (idx) {
                            final student = masterList[idx] as Map;
                            final String sName =
                                (student['name'] ??
                                        student['studentName'] ??
                                        'Siswa')
                                    .toString();
                            final String sNis =
                                (student['nis'] ?? student['nisn'] ?? '')
                                    .toString();
                            final String sUid = (student['uid'] ?? '')
                                .toString();
                            final bool isSelf =
                                sUid == currentUid ||
                                (sName.toLowerCase() ==
                                    (FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.displayName ??
                                            '')
                                        .toLowerCase());
                            final bool isFriend = friendUids.contains(sUid);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelf
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFE2E8F0),
                                    child: Text(
                                      sName.isNotEmpty
                                          ? sName[0].toUpperCase()
                                          : 'S',
                                      style: AppTypography.buttonLabel(color: isSelf ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                sName,
                                                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelf) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDBEAFE,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Saya',
                                                  style: AppTypography.buttonLabel(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (sNis.isNotEmpty)
                                          Text(
                                            'NIS: $sNis',
                                            style: AppTypography.timestamp(color: Colors.black45),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  if (isSelf)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _confirmLeaveClass(context);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.logout_rounded,
                                              size: 11,
                                              color: Color(0xFFEF4444),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Keluar',
                                              style: AppTypography.buttonLabel(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (isFriend)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Teman',
                                        style: AppTypography.buttonLabel(color: const Color(0xFF15803D), fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () =>
                                          _addFriendByUid(context, sUid, sName),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.person_add_alt_1_rounded,
                                              size: 11,
                                              color: Color(0xFF1D4ED8),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tambah',
                                              style: AppTypography.buttonLabel(color: const Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLeaveClass(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar Kelas?',
          style: AppTypography.chatHeaderTitle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari kelas ${_selectedProjectData?['name'] ?? ''}?',
          style: AppTypography.timestamp(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: AppTypography.timestamp(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Keluar',
              style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || _selectedProjectId == null) return;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .update({
              'projectIds': FieldValue.arrayRemove([_selectedProjectId]),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda telah keluar dari kelas.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
          _loadUserProjects();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal keluar kelas: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadUserProjects() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (mounted) setState(() => _isLoadingProjects = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoadingProjects = false);
        return;
      }

      final List projectIds = userDoc.data()?['projectIds'] as List? ?? [];
      if (projectIds.isEmpty) {
        if (mounted) {
          setState(() {
            _userProjects = [];
            _isLoadingProjects = false;
          });
        }
        return;
      }

      final List<Map<String, dynamic>> projects = [];
      for (var id in projectIds) {
        final doc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(id.toString())
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          projects.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _userProjects = projects;
          if (projects.isNotEmpty) {
            if (_selectedProjectId == null ||
                !projects.any((p) => p['id'] == _selectedProjectId)) {
              _selectedProjectId = projects.first['id'];
              _selectedProjectData = projects.first;
            } else {
              _selectedProjectData = projects.firstWhere(
                (p) => p['id'] == _selectedProjectId,
              );
            }
          }
          _isLoadingProjects = false;
        });

        if (_selectedProjectData != null) {
          final ownerUid =
              _selectedProjectData!['ownerUid'] ??
              _selectedProjectData!['teacherUid'];
          _fetchTeacherInfo(ownerUid?.toString());
          final List stages = _selectedProjectData!['stages'] as List? ?? [];
          final int activeIdx = _getActiveStageIndex(stages);
          if (activeIdx >= 0) {
            _expandedStageIndices.add(activeIdx);
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _toggleCompletion(
    String key,
    List<String> currentCompleted,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _selectedProjectId == null) return;

    final List<String> updatedCompleted = List<String>.from(currentCompleted);
    if (updatedCompleted.contains(key)) {
      updatedCompleted.remove(key);
    } else {
      updatedCompleted.add(key);
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(_selectedProjectId)
          .collection('studentProgress')
          .doc(currentUid)
          .set({
            'uid': currentUid,
            'name': FirebaseAuth.instance.currentUser?.displayName ?? 'Siswa',
            'completedTasks': updatedCompleted,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui progress: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _updateStageStatus(int stageIdx, String newStatus) async {
    if (_selectedProjectId == null || _selectedProjectData == null) return;

    final List stagesRaw = _selectedProjectData!['stages'] as List? ?? [];
    final List<Map<String, dynamic>> updatedStages = [];

    for (var s in stagesRaw) {
      updatedStages.add(Map<String, dynamic>.from(s as Map));
    }

    if (stageIdx >= 0 && stageIdx < updatedStages.length) {
      updatedStages[stageIdx]['status'] = newStatus;

      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(_selectedProjectId)
            .update({'stages': updatedStages});

        setState(() {
          _selectedProjectData!['stages'] = updatedStages;
        });

        if (mounted) {
          final label = newStatus == 'selesai'
              ? 'Selesai'
              : newStatus == 'proses'
              ? 'Proses Pembelajaran'
              : 'Akan Datang';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status elemen diperbarui: $label'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui status elemen: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  int _getActiveStageIndex(List stages) {
    if (stages.isEmpty) return -1;

    for (int i = 0; i < stages.length; i++) {
      final sMap = stages[i] as Map;
      final status = sMap['status'] as String? ?? 'akan_datang';
      if (status == 'proses') return i;
    }

    for (int i = 0; i < stages.length; i++) {
      final sMap = stages[i] as Map;
      final status = sMap['status'] as String? ?? 'akan_datang';
      if (status == 'akan_datang') return i;
    }

    return 0;
  }

  Widget _buildMonitoringItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String type, // 'materi', 'tugas', 'quiz', 'pdf'
    required bool isCompleted,
    required VoidCallback onTapAction,
  }) {
    String buttonText;
    IconData buttonIcon;
    Color buttonColor;

    if (type == 'quiz') {
      buttonText = 'Kerjakan Quiz';
      buttonIcon = Icons.play_arrow_rounded;
      buttonColor = const Color(0xFF7C3AED);
    } else if (type == 'tugas') {
      buttonText = 'Kerjakan Tugas';
      buttonIcon = Icons.edit_note_rounded;
      buttonColor = const Color(0xFF2563EB);
    } else {
      buttonText = 'Buka PDF';
      buttonIcon = Icons.visibility_rounded;
      buttonColor = const Color(0xFF0D9488);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Text Title & Subtitle (NO LEFT DOT!)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.buttonLabel(color: isCompleted ? Colors.black38 : Colors.black87, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      type == 'quiz'
                          ? Icons.quiz_outlined
                          : type == 'pdf'
                          ? Icons.description_outlined
                          : Icons.assignment_outlined,
                      size: 11,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: AppTypography.timestamp(color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Button
          if (isCompleted)
            GestureDetector(
              onTap: onTapAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFA7F3D0),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF059669),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Selesai',
                      style: AppTypography.buttonLabel(color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                onPressed: onTapAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: buttonColor, width: 1.5),
                  ),
                ),
                icon: Icon(buttonIcon, size: 11),
                label: Text(
                  buttonText,
                  style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProjects) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    if (_userProjects.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    size: 48,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum Ada Kelas',
                  style: AppTypography.chatHeaderTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Silakan bergabung ke kelas untuk melihat monitoring.',
                  style: AppTypography.timestamp(color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Determine card theme index (matching Home Page classroom card loop)
    final int selectedIndex = _userProjects.indexWhere(
      (p) => p['id'] == _selectedProjectId,
    );
    final int themeIdx = (_selectedProjectData?['colorIndex'] as int?) ??
        (selectedIndex >= 0 ? selectedIndex % _classroomCardColors.length : 0);
    final Color cardColor = _classroomCardColors[themeIdx];
    final Color accentColor = _classroomAccentColors[themeIdx];

    final String projectTitle = _selectedProjectData?['name'] ?? 'Classroom';
    final String displayTeacherName = _teacherName.isNotEmpty
        ? _teacherName
        : (_selectedProjectData?['teacherName'] ??
              _selectedProjectData?['ownerName'] ??
              '');
    final String displayTeacherPhoto = _teacherPhoto.isNotEmpty
        ? _teacherPhoto
        : (_selectedProjectData?['teacherPhoto'] ??
              _selectedProjectData?['ownerPhoto'] ??
              '');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedRainbowBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width > 500
                      ? double.infinity
                      : 500,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PAGE TITLE & SUBTITLE
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monitoring Classroom',
                                    style: AppTypography.pageTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Cek checklist materi, kuis, dan tugas Anda di sini.',
                                    style: AppTypography.timestamp(color: Colors.black45),
                                  ),
                                ],
                              ),
                            ),
                            // Hide dropdown entirely if only 1 project
                            if (_userProjects.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: null,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedProjectId,
                                    isDense: true,
                                    menuWidth: 320,
                                    itemHeight: 56,
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.black87,
                                      size: 18,
                                    ),
                                    selectedItemBuilder:
                                        (BuildContext context) {
                                          return _userProjects.map((p) {
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Ganti',
                                                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          }).toList();
                                        },
                                    hint: Text(
                                      'Pilih Classroom',
                                      style: AppTypography.timestamp(color: Colors.black54),
                                    ),
                                    onChanged: (newVal) {
                                      if (newVal != null &&
                                          newVal != _selectedProjectId) {
                                        final proj = _userProjects.firstWhere(
                                          (p) => p['id'] == newVal,
                                          orElse: () => {},
                                        );
                                        setState(() {
                                          _selectedProjectId = newVal;
                                          _selectedProjectData = proj;
                                        });
                                        _fetchTeacherInfo(
                                          proj['ownerUid'] ??
                                              proj['teacherUid'],
                                        );
                                      }
                                    },
                                    items: _userProjects.map((p) {
                                      final String pId =
                                          p['id']?.toString() ?? '';
                                      final String pName =
                                          p['name']?.toString() ?? 'Classroom';
                                      return DropdownMenuItem<String>(
                                        value: pId,
                                        child: Text(
                                          pName,
                                          style: AppTypography.timestamp(color: Colors.black87, fontWeight: FontWeight.w500),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // 2. STREAM LISTENER FOR REAL-TIME PROJECT STAGES & STUDENT PROGRESS DATA
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .doc(_selectedProjectId)
                          .snapshots(),
                      builder: (context, projectSnap) {
                        if (projectSnap.hasData && projectSnap.data!.exists) {
                          final liveProjectData =
                              projectSnap.data!.data() as Map<String, dynamic>?;
                          if (liveProjectData != null) {
                            _selectedProjectData = liveProjectData;
                          }
                        }
                        final List stages =
                            _selectedProjectData?['stages'] as List? ?? [];
                        final int activeStageIdx = _getActiveStageIndex(stages);

                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(_selectedProjectId)
                              .collection('studentProgress')
                              .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                              .snapshots(),
                          builder: (context, progressSnap) {
                            final progressData =
                                (progressSnap.hasData &&
                                    progressSnap.data!.exists)
                                ? progressSnap.data!.data()
                                      as Map<String, dynamic>?
                                : null;

                            final List<String> completedTasks =
                                progressData != null &&
                                    progressData.containsKey('completedTasks')
                                ? List<String>.from(
                                    progressData['completedTasks'] ?? [],
                                  )
                                : [];

                            // Calculate metrics for Progress Saya, Tugas, & Quiz
                            int totalItems = 0;
                            int completedItems = 0;
                            int totalTugas = 0;
                            int completedTugas = 0;
                            int totalQuiz = 0;
                            int completedQuiz = 0;

                            for (int sIdx = 0; sIdx < stages.length; sIdx++) {
                              final stage = stages[sIdx] as Map;
                              final List rawMateris =
                                  stage['materis'] as List? ?? [];
                              List<Map<String, dynamic>> materis = [];
                              if (rawMateris.isNotEmpty) {
                                materis = rawMateris
                                    .map(
                                      (e) =>
                                          Map<String, dynamic>.from(e as Map),
                                    )
                                    .toList();
                              } else {
                                final List tasksList =
                                    stage['tasks'] as List? ?? [];
                                if (tasksList.isNotEmpty) {
                                  materis = [
                                    {
                                      'title': 'Materi Pembelajaran',
                                      'tasks': tasksList,
                                    },
                                  ];
                                }
                              }

                              for (
                                int mIdx = 0;
                                mIdx < materis.length;
                                mIdx++
                              ) {
                                totalItems++; // Material item
                                if (completedTasks.contains('m_${sIdx}_$mIdx'))
                                  completedItems++;

                                final List tasks =
                                    materis[mIdx]['tasks'] as List? ?? [];
                                for (
                                  int tIdx = 0;
                                  tIdx < tasks.length;
                                  tIdx++
                                ) {
                                  totalItems++;
                                  final task = tasks[tIdx] as Map;
                                  final String type = task['type'] ?? 'tugas';
                                  final String key = '${sIdx}_${mIdx}_$tIdx';

                                  if (completedTasks.contains(key))
                                    completedItems++;

                                  if (type == 'tugas') {
                                    totalTugas++;
                                    if (completedTasks.contains(key))
                                      completedTugas++;
                                  } else if (type == 'quiz') {
                                    totalQuiz++;
                                    if (completedTasks.contains(key))
                                      completedQuiz++;
                                  }
                                }
                              }
                            }

                            final double percent = totalItems > 0
                                ? (completedItems / totalItems)
                                : 0.0;

                            // Quiz score accumulation
                            double accumulatedScore = 0.0;
                            final quizScoresData =
                                progressData != null &&
                                    progressData.containsKey('quizScores')
                                ? progressData['quizScores']
                                      as Map<String, dynamic>?
                                : null;
                            if (quizScoresData != null &&
                                quizScoresData.isNotEmpty) {
                              double sum = 0.0;
                              int count = 0;
                              quizScoresData.forEach((_, val) {
                                if (val is num) {
                                  sum += val.toDouble();
                                  count++;
                                }
                              });
                              if (count > 0) accumulatedScore = sum / count;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // UNIFIED HERO CARD (CLASSROOM TITLE + TEACHER + PROGRESS BAR + SEARCH BOX)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: ClassroomCardPatternPainter(
                                            patternIndex: themeIdx,
                                            accentColor: accentColor,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              20,
                                              20,
                                              20,
                                              16,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    final cardWidth =
                                                        constraints.maxWidth;
                                                    final double
                                                    buttonRowWidth = _isGuru
                                                        ? 220
                                                        : 100;
                                                    final double
                                                    firstLineMaxWidth =
                                                        cardWidth -
                                                        buttonRowWidth -
                                                        16;

                                                    final textStyle =
                                                        AppTypography.pageTitle(color: Colors.black87, fontWeight: FontWeight.bold, height: 1.2);

                                                    String splitTitle(
                                                      String title,
                                                      double maxWidth,
                                                      TextStyle style,
                                                    ) {
                                                      final painter =
                                                          TextPainter(
                                                            textDirection:
                                                                TextDirection
                                                                    .ltr,
                                                            maxLines: 1,
                                                          );
                                                      int low = 0;
                                                      int high = title.length;
                                                      int best = 0;
                                                      while (low <= high) {
                                                        int mid =
                                                            (low + high) ~/ 2;
                                                        painter.text = TextSpan(
                                                          text: title.substring(
                                                            0,
                                                            mid,
                                                          ),
                                                          style: style,
                                                        );
                                                        painter.layout();
                                                        if (painter.width <=
                                                            maxWidth) {
                                                          best = mid;
                                                          low = mid + 1;
                                                        } else {
                                                          high = mid - 1;
                                                        }
                                                      }
                                                      int splitIndex = best;
                                                      if (best < title.length) {
                                                        final lastSpace = title
                                                            .substring(0, best)
                                                            .lastIndexOf(' ');
                                                        if (lastSpace != -1) {
                                                          splitIndex =
                                                              lastSpace;
                                                        }
                                                      }
                                                      return title
                                                          .substring(
                                                            0,
                                                            splitIndex,
                                                          )
                                                          .trim();
                                                    }

                                                    final firstLine =
                                                        splitTitle(
                                                          projectTitle,
                                                          firstLineMaxWidth,
                                                          textStyle,
                                                        );
                                                    final secondLine =
                                                        projectTitle
                                                            .substring(
                                                              firstLine.length,
                                                            )
                                                            .trim();

                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                firstLine
                                                                        .isEmpty
                                                                    ? projectTitle
                                                                    : firstLine,
                                                                style:
                                                                    textStyle,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Row(
                                                              children: [
                                                                if (_isGuru) ...[
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      Navigator.of(
                                                                        context,
                                                                      ).push(
                                                                        MaterialPageRoute(
                                                                          builder: (_) => ClassPage(
                                                                            projectId:
                                                                                _selectedProjectId!,
                                                                            projectTitle:
                                                                                projectTitle,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            11,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .white
                                                                            .withValues(
                                                                              alpha: 0.9,
                                                                            ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              16,
                                                                            ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                            Icons.edit_note_rounded,
                                                                            size:
                                                                                14,
                                                                            color:
                                                                                accentColor,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                5,
                                                                          ),
                                                                          Text(
                                                                            'Kelola Kelas',
                                                                            style: AppTypography.buttonLabel(color: accentColor, fontWeight: FontWeight.bold),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                ],
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    _showClassMembersSheet(
                                                                      context,
                                                                    );
                                                                  },
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          11,
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .white
                                                                          .withValues(
                                                                            alpha:
                                                                                0.9,
                                                                          ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            16,
                                                                          ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .groups_rounded,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              accentColor,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              5,
                                                                        ),
                                                                        Text(
                                                                          'Lihat Kelas',
                                                                          style: AppTypography.buttonLabel(color: accentColor, fontWeight: FontWeight.bold),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        Icon(
                                                                          Icons
                                                                              .chevron_right_rounded,
                                                                          size:
                                                                              13,
                                                                          color:
                                                                              accentColor,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        if (firstLine
                                                                .isNotEmpty &&
                                                            secondLine
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            secondLine,
                                                            style: textStyle,
                                                          ),
                                                        ],
                                                      ],
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 14),

                                                // Teacher Info Row (Large Avatar with ClipAntiAlias to fix white square corners, Format Title Bp./Bu Full Name)
                                                Builder(
                                                  builder: (context) {
                                                    final formattedName =
                                                        _formatTeacherTitle(
                                                          displayTeacherName,
                                                          _teacherGender,
                                                        );
                                                    return Row(
                                                      children: [
                                                        Container(
                                                          width: 42,
                                                          height: 42,
                                                          clipBehavior:
                                                              Clip.antiAlias,
                                                          decoration:
                                                              BoxDecoration(
                                                                color: accentColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.18,
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child:
                                                              displayTeacherPhoto
                                                                  .isNotEmpty
                                                              ? Image.network(
                                                                  displayTeacherPhoto,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder:
                                                                      (
                                                                        ctx,
                                                                        err,
                                                                        st,
                                                                      ) => Icon(
                                                                        Icons
                                                                            .person_rounded,
                                                                        size:
                                                                            22,
                                                                        color:
                                                                            accentColor,
                                                                      ),
                                                                )
                                                              : Icon(
                                                                  Icons
                                                                      .person_rounded,
                                                                  size: 22,
                                                                  color:
                                                                      accentColor,
                                                                ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              formattedName,
                                                              style: AppTypography.replySubtitle(color: Colors.black87, fontWeight: FontWeight.normal),
                                                            ),
                                                            Text(
                                                              'Pengajar Kelas',
                                                              style:
                                                                  AppTypography.timestamp(color: Colors.black54),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 18),

                                                // Progress Saya Direct Line
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Progress Saya',
                                                      style:
                                                          AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                                                    ),
                                                    Text(
                                                      '$completedItems/$totalItems Selesai',
                                                      style:
                                                          AppTypography.buttonLabel(color: accentColor, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: LinearProgressIndicator(
                                                    value: percent,
                                                    backgroundColor: accentColor
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(accentColor),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                                const SizedBox(height: 14),

                                                // CTA Buttons Row (Lihat CP & Lihat Jadwal)
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () => _showCpDialog(
                                                          context,
                                                          _selectedProjectData,
                                                          accentColor,
                                                        ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 8,
                                                                horizontal: 10,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.85,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                            border: null,
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .verified_outlined,
                                                                size: 14,
                                                                color:
                                                                    accentColor,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                'Lihat Elemen',
                                                                style: AppTypography.timestamp(color: Colors.black54, fontWeight: FontWeight.w500),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _showJadwalDialog(
                                                              context,
                                                              _selectedProjectData,
                                                              accentColor,
                                                            ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 8,
                                                                horizontal: 10,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.85,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                            border: null,
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .schedule_rounded,
                                                                size: 14,
                                                                color:
                                                                    accentColor,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                'Lihat Jadwal',
                                                                style: AppTypography.timestamp(color: Colors.black54, fontWeight: FontWeight.w500),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Search Box with Border matching card accent and rounded top & bottom
                                          Container(
                                            margin: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.95,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: null,
                                            ),
                                            child: TextField(
                                              onChanged: (val) {
                                                setState(() {
                                                  _searchQuery = val
                                                      .toLowerCase();
                                                });
                                              },
                                              style: AppTypography.subtitle(),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Cari materi atau tugas...',
                                                hintStyle: AppTypography.timestamp(color: Colors.black45),
                                                prefixIcon: Icon(
                                                  Icons.search_rounded,
                                                  size: 18,
                                                  color: accentColor,
                                                ),
                                                filled: true,
                                                fillColor: Colors.transparent,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16,
                                                    ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // CONTENT PADDING
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ROW OF 3 METRIC CARDS WITH PATTERN & LARGE NUMBERS
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildMetricCard(
                                              cardIndex: 0,
                                              icon: Icons.menu_book_rounded,
                                              bgColor: const Color(0xFFEFF6FF),
                                              value: totalTugas > 0
                                                  ? '$completedTugas/$totalTugas'
                                                  : '0/0',
                                              label: 'Tugas',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildMetricCard(
                                              cardIndex: 1,
                                              icon: Icons.quiz_outlined,
                                              bgColor: const Color(0xFFF3E8FF),
                                              value: totalQuiz > 0
                                                  ? '$completedQuiz/$totalQuiz'
                                                  : '0/0',
                                              label: 'Quizzes',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildMetricCard(
                                              cardIndex: 2,
                                              icon: Icons.star_outline_rounded,
                                              bgColor: const Color(0xFFFEF3C7),
                                              value: accumulatedScore > 0
                                                  ? accumulatedScore
                                                        .toStringAsFixed(1)
                                                  : '-',
                                              label: 'Nilai Quiz',
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      // ELEMENT CARDS LIST (Matching Image 2 style & element index colors!)
                                      ...List.generate(stages.length, (sIdx) {
                                        final stage = stages[sIdx] as Map;
                                        final String stageTitle =
                                            (stage['name'] ?? 'Elemen')
                                                .toString();

                                        if (_searchQuery.isNotEmpty &&
                                            !stageTitle.toLowerCase().contains(
                                              _searchQuery,
                                            )) {
                                          return const SizedBox.shrink();
                                        }

                                        return _buildStageDetailCard(
                                          stage: stage,
                                          stageIdx: sIdx,
                                          completedTasks: completedTasks,
                                          isPrimaryActive:
                                              sIdx == activeStageIdx,
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required int cardIndex,
    required IconData icon,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Container(
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: MetricCardPatternPainter(cardIndex: cardIndex),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 22, color: Colors.black87),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: AppTypography.pageTitle(color: Colors.black87, fontWeight: FontWeight.bold, height: 1.0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: AppTypography.timestamp(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageDetailCard({
    required Map stage,
    required int stageIdx,
    required List<String> completedTasks,
    required bool isPrimaryActive,
  }) {
    final String stageTitle = stage['name'] ?? 'Elemen';
    final String stageDesc =
        (stage['desc'] ?? stage['scope'] ?? stage['ruangLingkup'] ?? '')
            .toString();
    final String status = stage['status'] as String? ?? 'akan_datang';
    final bool isLockedForStudent = !_isGuru && status == 'akan_datang';

    // Color theme matching element index number
    final int colorIdx = stageIdx % _classroomCardColors.length;
    final Color elementBgColor = _classroomCardColors[colorIdx];
    final Color elementAccentColor = _classroomAccentColors[colorIdx];

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

    int totalMateris = materis.length;
    int totalTasksCount = 0;
    int totalQuizCount = 0;

    for (int mIdx = 0; mIdx < materis.length; mIdx++) {
      final List tasks = materis[mIdx]['tasks'] as List? ?? [];
      for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
        final task = tasks[tIdx] as Map;
        final String type = task['type'] ?? 'tugas';
        if (type == 'quiz') {
          totalQuizCount++;
        } else {
          totalTasksCount++;
        }
      }
    }

    final bool isExpanded =
        !isLockedForStudent &&
        (_expandedStageIndices.contains(stageIdx) ||
            (isPrimaryActive && !_isGuru));

    String statusLabel = 'Akan Datang';
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusFg = Colors.black54;

    if (status == 'selesai') {
      statusLabel = 'Selesai';
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF059669);
    } else if (status == 'proses') {
      statusLabel = 'Proses Pembelajaran';
      statusBg = const Color(0xFFDBEAFE);
      statusFg = const Color(0xFF1D4ED8);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: elementBgColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: null,
      ),
      child: Column(
        children: [
          // Header Card (Locks expansion if status is 'akan_datang' for students)
          InkWell(
            onTap: isLockedForStudent
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Elemen "$stageTitle" belum dibuka oleh guru.',
                        ),
                        backgroundColor: Colors.black87,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                : () {
                    setState(() {
                      if (_expandedStageIndices.contains(stageIdx)) {
                        _expandedStageIndices.remove(stageIdx);
                      } else {
                        _expandedStageIndices.add(stageIdx);
                      }
                    });
                  },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stageTitle,
                              style: AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.bold, height: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalMateris Materi · ${totalTasksCount + totalQuizCount} Tugas & Quiz',
                              style: AppTypography.timestamp(color: Colors.black54),
                            ),
                            if (stageDesc.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                stageDesc,
                                style: AppTypography.timestamp(color: Colors.black87.withValues(alpha: 0.75), height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isLockedForStudent)
                        const Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: Colors.black38,
                        )
                      else
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: Colors.black38,
                        ),
                    ],
                  ),

                  // Bottom status badge/dropdown placed below title line
                  const SizedBox(height: 8),
                  if (_isGuru)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          itemHeight: null,
                          value: status,
                          isDense: true,
                          icon: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: statusFg,
                            size: 16,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              _updateStageStatus(stageIdx, val);
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: 'selesai',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Selesai',
                                  style: AppTypography.buttonLabel(color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'proses',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Proses Pembelajaran',
                                  style: AppTypography.buttonLabel(color: const Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'akan_datang',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Akan Datang',
                                  style: AppTypography.buttonLabel(color: Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: AppTypography.buttonLabel(color: statusFg, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Expanded Materials List (Only if NOT locked for student)
          if (isExpanded && !isLockedForStudent) ...[
            Divider(
              height: 1,
              color: elementAccentColor.withValues(alpha: 0.2),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: List.generate(materis.length, (mIdx) {
                  final materi = materis[mIdx];
                  final String mTitle =
                      (materi['title'] ?? 'Materi ${mIdx + 1}').toString();
                  final List tasks = materi['tasks'] as List? ?? [];
                  final String materiKey = '${stageIdx}_$mIdx';
                  final String materiCheckKey = 'm_${stageIdx}_$mIdx';

                  // Calculate REAL completion status for Materi based on its sub-tasks!
                  int tugasCount = 0;
                  int quizCount = 0;
                  int pdfCount = 0;
                  bool isMateriCompleted = true;

                  if (tasks.isEmpty) {
                    isMateriCompleted = completedTasks.contains(materiCheckKey);
                  } else {
                    for (int tIdx = 0; tIdx < tasks.length; tIdx++) {
                      final task = tasks[tIdx] as Map;
                      final String type = task['type'] ?? 'tugas';
                      final String taskKey = '${stageIdx}_${mIdx}_$tIdx';

                      if (type == 'quiz') {
                        quizCount++;
                      } else if (type == 'pdf') {
                        pdfCount++;
                      } else {
                        tugasCount++;
                      }

                      if (!completedTasks.contains(taskKey)) {
                        isMateriCompleted = false;
                      }
                    }
                  }

                  final bool isMateriExpanded = _expandedMateriKeys.contains(
                    materiKey,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: null,
                    ),
                    child: Column(
                      children: [
                        // MATERI ITEM ROW (Clickable to Expand / Unhide Tasks)
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_expandedMateriKeys.contains(materiKey)) {
                                _expandedMateriKeys.remove(materiKey);
                              } else {
                                _expandedMateriKeys.add(materiKey);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Text Title & Subtitle Counts (NO LEFT DOT!)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mTitle,
                                        style: AppTypography.buttonLabel(color: isMateriCompleted ? const Color(0xFF10B981) : Colors.black54, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tasks.isNotEmpty
                                            ? '$tugasCount Tugas · $quizCount Quiz · $pdfCount PDF'
                                            : 'Materi Pembelajaran',
                                        style: AppTypography.timestamp(color: Colors.black45),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // RIGHT SIDE ROSETTE / STAR VERIFIED CHECK BADGE (Image format!)
                                Icon(
                                  isMateriCompleted
                                      ? Icons.verified_rounded
                                      : Icons.verified_outlined,
                                  color: isMateriCompleted
                                      ? const Color(0xFF10B981)
                                      : Colors.black26,
                                  size: 24,
                                ),

                                if (tasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    isMateriExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: Colors.black38,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // SUB-TASKS UNDER THIS MATERI (EXPAND / HIDE-UNHIDE ABOVE NEXT MATERI)
                        if (tasks.isNotEmpty && isMateriExpanded) ...[
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                            child: Column(
                              children: List.generate(tasks.length, (tIdx) {
                                final task = tasks[tIdx] as Map;
                                final String taskTitle =
                                    task['title'] ?? 'Tugas';
                                final String type = task['type'] ?? 'tugas';
                                final String taskKey =
                                    '${stageIdx}_${mIdx}_$tIdx';
                                final bool isTaskChecked = completedTasks
                                    .contains(taskKey);

                                String typeLabel;
                                if (type == 'quiz') {
                                  typeLabel = 'Kuis Evaluasi';
                                } else if (type == 'pdf') {
                                  typeLabel = 'Materi PDF';
                                } else {
                                  typeLabel = 'Tugas Mandiri/Kelompok';
                                }

                                final currentUid =
                                    FirebaseAuth.instance.currentUser?.uid ??
                                    '';

                                return _buildMonitoringItem(
                                  context: context,
                                  title: taskTitle,
                                  subtitle: typeLabel,
                                  type: type,
                                  isCompleted: isTaskChecked,
                                  onTapAction: () {
                                    if (isTaskChecked) {
                                      _toggleCompletion(
                                        taskKey,
                                        completedTasks,
                                      );
                                    } else {
                                      if (type == 'pdf') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BacaMateriPage(
                                                  title: taskTitle,
                                                  docName:
                                                      task['doc']?.toString() ??
                                                      '',
                                                  onCompleted: () =>
                                                      _toggleCompletion(
                                                        taskKey,
                                                        completedTasks,
                                                      ),
                                                ),
                                          ),
                                        );
                                      } else if (type == 'tugas') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MengerjakanTugasPage(
                                                  title: taskTitle,
                                                  projectId:
                                                      _selectedProjectId!,
                                                  studentUid: currentUid,
                                                  taskKey: taskKey,
                                                  onCompleted: () =>
                                                      _toggleCompletion(
                                                        taskKey,
                                                        completedTasks,
                                                      ),
                                                  assignmentType:
                                                      task['assignmentType']
                                                          ?.toString() ??
                                                      'individu',
                                                  studentsMasterList:
                                                      _selectedProjectData?['studentsMasterList']
                                                          as List? ??
                                                      [],
                                                  taskText:
                                                      task['tugasText']
                                                          ?.toString() ??
                                                      '',
                                                  docName:
                                                      task['doc']?.toString() ??
                                                      '',
                                                ),
                                          ),
                                        );
                                      } else if (type == 'quiz') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MengerjakanQuizPage(
                                                  title: taskTitle,
                                                  durationStr:
                                                      task['quizDuration']
                                                          ?.toString() ??
                                                      '15',
                                                  startTime:
                                                      task['quizStartTime']
                                                          ?.toString() ??
                                                      '',
                                                  projectId:
                                                      _selectedProjectId!,
                                                  studentUid: currentUid,
                                                  taskKey: taskKey,
                                                  onCompleted: () =>
                                                      _toggleCompletion(
                                                        taskKey,
                                                        completedTasks,
                                                      ),
                                                  questions:
                                                      task['questions']
                                                          as List?,
                                                ),
                                          ),
                                        );
                                      } else {
                                        _toggleCompletion(
                                          taskKey,
                                          completedTasks,
                                        );
                                      }
                                    }
                                  },
                                );
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MetricCardPatternPainter extends CustomPainter {
  final int cardIndex;

  const MetricCardPatternPainter({required this.cardIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (cardIndex == 0) {
      // Blue Card Pattern: Soft ribbon wave curve
      final paint = Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(size.width * 0.4, 0);
      path.cubicTo(
        size.width * 0.8,
        size.height * 0.35,
        size.width * 0.5,
        size.height * 0.8,
        size.width,
        size.height * 0.7,
      );
      path.lineTo(size.width, 0);
      path.close();
      canvas.drawPath(path, paint);
    } else if (cardIndex == 1) {
      // Purple Card Pattern: Swirl spiral ring arcs
      final paintRing = Paint()
        ..color = const Color(0xFF7C3AED).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      final center = Offset(size.width * 0.82, size.height * 0.45);
      canvas.drawCircle(center, 18, paintRing);
      canvas.drawCircle(center, 34, paintRing);
    } else {
      // Amber Card Pattern: Leaf ray curves
      final paintRay = Paint()
        ..color = const Color(0xFFD97706).withValues(alpha: 0.09)
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(size.width * 0.45, 0);
      path.quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.35,
        size.width * 0.85,
        size.height,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.close();
      canvas.drawPath(path, paintRay);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
        : accentColor.withValues(alpha: 0.20);
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
    return oldDelegate.patternIndex != patternIndex || oldDelegate.accentColor != accentColor;
  }
}
