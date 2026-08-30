import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/features/projects/presentation/pages/class_page.dart';
import 'package:hubner/features/projects/presentation/pages/desktop_classroom_page.dart';
import 'package:hubner/features/projects/presentation/pages/detail_cp_page.dart';
import 'package:hubner/features/projects/presentation/pages/monitoring_page.dart';
import 'package:hubner/features/projects/presentation/pages/baca_materi_page.dart';
import 'package:hubner/features/projects/presentation/pages/mengerjakan_tugas_page.dart';
import 'package:hubner/features/projects/presentation/pages/mengerjakan_quiz_page.dart';
import 'package:hubner/features/todo/presentation/pages/todo_page.dart';
import 'note_editor_page.dart';
import 'package:hubner/features/projects/presentation/pages/add_class_page.dart';
import 'package:hubner/features/projects/presentation/pages/edit_class_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hubner/features/notifications/presentation/pages/notifications_page.dart';
import 'package:hubner/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:hubner/core/services/classroom_export_service.dart';
import 'package:hubner/core/services/login_history_service.dart';
import 'package:hubner/core/services/app_sound_service.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';

class StudentHomePage extends StatefulWidget {
  final Function(int index, {String? projectId})? onNavigateTab;
  const StudentHomePage({super.key, this.onNavigateTab});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final PageController _taskQuizPageController = PageController();
  int _taskQuizPageIndex = 0;
  DateTime _selectedCalendarDay = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  int _quizCardMode = 0;
  int _tugasCardMode = 0;
  Timer? _cardsAutoSlideTimer;
  String? _selectedClassroomId;
  String? _selectedClassroomTitle;
  bool _isClassPageFullScreen = false;
  final Set<String> _flippedClassroomIds = {};
  final Set<String> _deletedProjectIds = {};
  Stream<List<DocumentSnapshot>>? _cachedProjectsStream;
  String? _cachedUid;
  List<String>? _cachedProjectIds;
  List<DocumentSnapshot> _lastProjectDocs = [];
  final ValueNotifier<bool> _isManagingClassesNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isClassroomGridNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final GlobalKey _notesButtonKey = GlobalKey();
  final ScrollController _homeScrollController = ScrollController();
  final ValueNotifier<double> _headerScrollOffsetNotifier = ValueNotifier<double>(0.0);

  void _startCardsAutoSlideTimer() {
    _cardsAutoSlideTimer?.cancel();
    _cardsAutoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _quizCardMode = (_quizCardMode + 1) % 3;
          _tugasCardMode = (_tugasCardMode + 1) % 3;
        });
      }
    });
  }

  bool _isYellowCardColor(Color color) {
    return color.value == 0xFFFFAB40 ||
        color.value == 0xFFFFD600 ||
        color.value == 0xFFFFC107 ||
        color.value == 0xFFFEF3C7 ||
        color.computeLuminance() > 0.42;
  }

  Future<bool> _confirmDeleteProject(BuildContext context, String projectId, String title) async {
    DocumentSnapshot? projectDoc;
    try {
      projectDoc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
    } catch (_) {}

    final Map<String, dynamic> projectData =
        projectDoc != null && projectDoc.exists
            ? Map<String, dynamic>.from(projectDoc.data() as Map)
            : {'projectId': projectId, 'name': title};

    final bool isDriveConnected = await GoogleDriveService.isConnected();

    if (!context.mounted) return false;

    if (isDriveConnected) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) {
          final bool isDark = AppColors.isDarkMode;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Hapus Classroom',
                            style: AppTypography.chatHeaderTitle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogCtx, false),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Data classroom "$title" akan dicadangkan secara otomatis ke Google Drive Anda sebelum dihapus dari sistem.',
                    style: AppTypography.bodySubtitle(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Google Drive terhubung. Salinan data akan tersimpan aman.',
                            style: AppTypography.timestamp(
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text('Batal', style: AppTypography.buttonLabel(color: isDark ? Colors.white60 : Colors.black54)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: Text('Cadangkan & Hapus', style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (confirm == true && context.mounted) {
        // Instant removal from local UI
        if (mounted) {
          setState(() {
            _deletedProjectIds.add(projectId);
            _lastProjectDocs.removeWhere((d) {
              final pData = d.data() as Map<String, dynamic>? ?? {};
              final pId = (pData['projectId'] ?? d.id).toString();
              return d.id == projectId || pId == projectId;
            });
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom "$title" dihapus & dicadangkan di latar belakang.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Run deletion and cloud backup silently in the background
        Future.microtask(() async {
          try {
            await GoogleDriveService.backupClassroomToDrive(projectData);
            await FirebaseFirestore.instance.collection('projects').doc(projectId).delete();
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'projectIds': FieldValue.arrayRemove([projectId]),
              }).catchError((_) {});
            }
          } catch (_) {}
        });

        return true;
      }
    } else {
      final int? choice = await showDialog<int>(
        context: context,
        builder: (dialogCtx) {
          final bool isDark = AppColors.isDarkMode;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Icon + Title & Circular Close X Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Color(0xFFEA580C), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Peringatan Cadangan',
                            style: AppTypography.chatHeaderTitle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogCtx, 0),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Warning Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D1214) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Google Drive belum terhubung! Data classroom "$title" TIDAK DAPAT DIPULIHKAN jika dihapus sekarang.',
                            style: AppTypography.chatBody(
                              fontSize: 13.5,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hubungkan akun Google Drive untuk mencadangkan data secara otomatis sebelum menghapus, atau tetap hapus secara permanen.',
                    style: AppTypography.timestamp(
                      fontSize: 13.0,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons (1 Horizontal Row)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(dialogCtx, 1),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              'Hubungkan Drive',
                              style: AppTypography.buttonLabel(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 13.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(dialogCtx, 2),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              'Tetap Hapus',
                              style: AppTypography.buttonLabel(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (choice == 1 && context.mounted) {
        final bool connected = await GoogleDriveService.connectGoogleDrive();
        if (connected && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive berhasil terhubung! Silakan ulangi hapus untuk mencadangkan.'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menghubungkan Google Drive.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (choice == 2 && context.mounted) {
        // Instant removal from local UI
        if (mounted) {
          setState(() {
            _deletedProjectIds.add(projectId);
            _lastProjectDocs.removeWhere((d) {
              final pData = d.data() as Map<String, dynamic>? ?? {};
              final pId = (pData['projectId'] ?? d.id).toString();
              return d.id == projectId || pId == projectId;
            });
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom "$title" berhasil dihapus.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Run Firestore deletion in background
        Future.microtask(() async {
          try {
            await FirebaseFirestore.instance.collection('projects').doc(projectId).delete();
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'projectIds': FieldValue.arrayRemove([projectId]),
              }).catchError((_) {});
            }
          } catch (_) {}
        });

        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _startCardsAutoSlideTimer();
    _homeScrollController.addListener(() {
      _headerScrollOffsetNotifier.value = _homeScrollController.offset;
    });
  }

  @override
  void dispose() {
    _cardsAutoSlideTimer?.cancel();
    _homeScrollController.dispose();
    _headerScrollOffsetNotifier.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  void _toggleThemeWithBounce(BuildContext context, bool currentlyDark) async {
    final String newTheme = currentlyDark ? 'Terang' : 'Gelap';

    // 1. Activate full-screen blur with bouncing dots for theme transition
    HubnerApp.isThemeTransitioning.value = true;

    // 2. Persist locally and in Firestore in background
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newTheme);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({'themeMode': newTheme})
          .catchError((_) {});
    }

    // 3. Let the dots animate smoothly, then switch theme underneath
    await Future.delayed(const Duration(milliseconds: 600));
    HubnerApp.themeNotifier.value = newTheme;

    // 4. Complete transition and dismiss overlay
    await Future.delayed(const Duration(milliseconds: 250));
    HubnerApp.isThemeTransitioning.value = false;
  }

  void _showClassBarcodeDialog(BuildContext context, String projectId, String title, Color accentColor) {
    final bool isDark = AppColors.isDarkMode;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: isDark ? const BorderSide(color: Color(0xFF27272A), width: 1.2) : BorderSide.none,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Title & Close Button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Barcode Kelas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black87,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Classroom Title Info
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gunakan barcode ini atau salin kode kelas untuk bergabung.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.0,
                    color: isDark ? Colors.white60 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code Image (styled premium, black, frameless round)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1.5,
                      ),
                    ),
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: QrImageView(
                        data: projectId,
                        version: QrVersions.auto,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Code display container with copy action (Round & Frameless with Soft Purple/Dark Purple Bg)
                Container(
                  padding: const EdgeInsets.only(left: 18, right: 5, top: 5, bottom: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF221A33) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(32),
                    border: isDark ? Border.all(color: const Color(0xFF382952), width: 1.0) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KODE KELAS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            SelectableText(
                              projectId,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: projectId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kode kelas berhasil disalin!'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141416) : Colors.black,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Salin',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                        ),
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

  Stream<Map<String, Map<String, dynamic>>> _combineStudentProgressStreams(
    List<String> projectIds,
    String currentUid,
  ) {
    if (projectIds.isEmpty) {
      return Stream.value({});
    }

    final controller = StreamController<Map<String, Map<String, dynamic>>>();
    final Map<String, Map<String, dynamic>> latestData = {};
    final List<StreamSubscription> subscriptions = [];

    void emitLatest() {
      if (!controller.isClosed) {
        controller.add(Map.from(latestData));
      }
    }

    for (final projId in projectIds) {
      final sub = FirebaseFirestore.instance
          .collection('projects')
          .doc(projId)
          .collection('studentProgress')
          .doc(currentUid)
          .snapshots()
          .listen(
            (docSnap) {
              if (docSnap.exists) {
                latestData[projId] = docSnap.data() as Map<String, dynamic>;
              } else {
                latestData[projId] = {};
              }
              emitLatest();
            },
            onError: (err) {
              // ignore
            },
          );
      subscriptions.add(sub);
    }

    // Emit initial empty state so it doesn't block waiting
    emitLatest();

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    return controller.stream;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Stream<List<DocumentSnapshot>> _combineProjectsStreams(
    String currentUid,
    List<String> projectIds,
  ) {
    if (_cachedProjectsStream != null &&
        _cachedUid == currentUid &&
        _cachedProjectIds != null &&
        _listEquals(_cachedProjectIds!, projectIds)) {
      return _cachedProjectsStream!;
    }

    _cachedUid = currentUid;
    _cachedProjectIds = List<String>.from(projectIds);

    final controller = StreamController<List<DocumentSnapshot>>.broadcast();
    final Map<String, DocumentSnapshot> latestDocs = {};
    final List<StreamSubscription> subscriptions = [];

    void emitLatest() {
      if (!controller.isClosed) {
        final list = latestDocs.values.toList();
        _lastProjectDocs = list;
        controller.add(list);
      }
    }

    if (_lastProjectDocs.isNotEmpty) {
      for (var d in _lastProjectDocs) {
        latestDocs[d.id] = d;
      }
    }

    if (currentUid.isNotEmpty) {
      final subOwner = FirebaseFirestore.instance
          .collection('projects')
          .where('ownerUid', isEqualTo: currentUid)
          .snapshots()
          .listen(
            (snap) {
              for (var doc in snap.docs) {
                latestDocs[doc.id] = doc;
              }
              emitLatest();
            },
            onError: (_) {},
          );
      subscriptions.add(subOwner);
    }

    if (projectIds.isNotEmpty) {
      final safeIds = projectIds.take(30).toList();
      final subJoined = FirebaseFirestore.instance
          .collection('projects')
          .where(FieldPath.documentId, whereIn: safeIds)
          .snapshots()
          .listen(
            (snap) {
              for (var doc in snap.docs) {
                latestDocs[doc.id] = doc;
              }
              emitLatest();
            },
            onError: (_) {},
          );
      subscriptions.add(subJoined);
    }

    if (latestDocs.isNotEmpty) {
      emitLatest();
    } else if (currentUid.isEmpty && projectIds.isEmpty) {
      return Stream.value([]);
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    _cachedProjectsStream = controller.stream;
    return _cachedProjectsStream!;
  }

  static String _formatTeacherTitle(String rawName, String? gender) {
    if (rawName.trim().isEmpty) return '';
    final trimmed = rawName.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('pak ') ||
        lower.startsWith('bu ') ||
        lower.startsWith('bapak ') ||
        lower.startsWith('ibu ') ||
        lower.startsWith('mr. ') ||
        lower.startsWith('mrs. ') ||
        lower.startsWith('ms. ')) {
      return trimmed;
    }
    final lowerGender = (gender ?? '').toLowerCase();
    final isFemale = lowerGender.contains('perempuan') ||
        lowerGender.contains('wanita') ||
        lowerGender.contains('female') ||
        lowerGender.startsWith('p');
    return isFemale ? 'Bu $trimmed' : 'Pak $trimmed';
  }

  final List<Color> _softCardColors = const [
    Color(0xFFF9EED2), // Soft Peach/Cream
    Color(0xFFE5ECEB), // Soft Mint/Teal
    Color(0xFFE2DCF7), // Soft Lavender/Purple
    Color(0xFFEFF6FF), // Soft Blue
    Color(0xFFFCE7F3), // Soft Pink
    Color(0xFFE2ECE9), // Soft Sage/Slate
    Color(0xFFFFF1F2), // Soft Rose
    Color(0xFFF0FDF4), // Soft Green
  ];

  final List<Color> _classroomCardColors = const [
    Color(0xFFD6A5F8), // 01. Lilac Purple (Core)
    Color(0xFF9CC8FC), // 02. Sky Blue
    Color(0xFF7DE3D0), // 03. Emerald Mint / Tosca
    Color(0xFFF7BD84), // 04. Amber Peach / Orange
    Color(0xFFF794BE), // 05. Rose Magenta / Pink
    Color(0xFFA5B4FC), // 06. Indigo Violet
    Color(0xFFBEF264), // 07. Fresh Lime
    Color(0xFF67E8F9), // 08. Ocean Cyan
    Color(0xFFFDE047), // 09. Amber Gold
    Color(0xFFCBD5E1), // 10. Steel Slate
  ];

  final List<Color> _classroomCardDarkColors = const [
    Color(0xFF6B3BA3), // 01. Deep Lilac (Core)
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

  final List<Color> _classroomAccentColors = const [
    Color(0xFF7C3AED), // 01. Purple (Core)
    Color(0xFF2563EB), // 02. Blue
    Color(0xFF059669), // 03. Teal
    Color(0xFFD97706), // 04. Amber / Orange
    Color(0xFFDB2777), // 05. Pink / Rose
    Color(0xFF4F46E5), // 06. Indigo
    Color(0xFF65A30D), // 07. Lime
    Color(0xFF0891B2), // 08. Cyan
    Color(0xFFCA8A04), // 09. Gold
    Color(0xFF475569), // 10. Slate
  ];

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

  String _getIndonesianDayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return 'Senin';
    }
  }

  String _getLatestMaterialTitle(List stages) {
    for (int sIdx = stages.length - 1; sIdx >= 0; sIdx--) {
      final stage = stages[sIdx] as Map;
      final bool isStageArchived = stage['isArchived'] == true;
      if (isStageArchived) continue;

      final List rawMateris = stage['materis'] as List? ?? [];
      for (int mIdx = rawMateris.length - 1; mIdx >= 0; mIdx--) {
        final m = rawMateris[mIdx] as Map;
        final bool isMateriArchived = m['isArchived'] == true;
        if (isMateriArchived) continue;

        final String title = m['title'] ?? '';
        if (title.isNotEmpty) {
          return '${stage['name'] ?? 'Elemen'} - $title';
        }
      }
    }
    return 'Belum ada materi aktif';
  }

  String _getScheduleSummary(List schedulesList) {
    if (schedulesList.isEmpty) {
      return 'Jadwal belum diatur';
    }
    final List<String> parts = [];
    for (var s in schedulesList) {
      if (s is Map) {
        final day = s['day'] ?? '';
        final time = s['time'] ?? '';
        if (day.isNotEmpty && time.isNotEmpty) {
          parts.add('$day ($time)');
        }
      }
    }
    return parts.join(', ');
  }

  Future<void> _processJoinProject(
    String inputProjectId,
    String selectedMasterName,
  ) async {
    final cleanId = inputProjectId.trim();
    if (cleanId.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F52FC)),
        ),
      ),
    );

    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(cleanId)
          .get();
      if (!projectDoc.exists) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID Classroom tidak ditemukan.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final projectName = projectDoc.get('name') ?? 'Project';
      final ownerUid = projectDoc.get('ownerUid') ?? '';

      final requesterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (!requesterDoc.exists) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final requesterName = requesterDoc.get('name') ?? 'User';
      final requesterUserId = requesterDoc.get('userId') ?? '';
      final currentProjectIds = List<String>.from(
        requesterDoc.data()?['projectIds'] ?? [],
      );

      if (currentProjectIds.contains(cleanId)) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah bergabung dalam classroom ini.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final pendingQuery = await FirebaseFirestore.instance
          .collection('projectJoinRequests')
          .where('projectId', isEqualTo: cleanId)
          .where('requesterUid', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingQuery.docs.isNotEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permintaan bergabung Anda masih tertunda.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('projectJoinRequests').add({
        'projectId': cleanId,
        'projectName': projectName,
        'requesterUid': currentUid,
        'requesterName': requesterName,
        'requesterUserId': requesterUserId,
        'ownerUid': ownerUid,
        'selectedMasterName': selectedMasterName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan bergabung berhasil dikirim!'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal bergabung: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openScannerForJoin(BuildContext context) async {
    final String? scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ClassroomQrScannerPage(),
      ),
    );
    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      _processJoinProject(scannedCode.trim(), '');
    }
  }

  void _showJoinProjectBottomSheet(BuildContext context) {
    final TextEditingController idController = TextEditingController();
    bool isScanning = false;

    // Two-step join variables
    bool isClassroomLoaded = false;
    bool isLoadingClassroom = false;
    String? classroomName;
    List<String> availableNames = [];
    String? selectedName;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    24 +
                    MediaQuery.of(context).padding.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Gabung Classroom Baru',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 23.4,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan kode ID classroom untuk bergabung.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!isClassroomLoaded) ...[
                      Text(
                        'ID Classroom',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: idController,
                        style: GoogleFonts.dmSans(fontSize: 16.4),
                        decoration: InputDecoration(
                          hintText: 'Masukkan ID Classroom...',
                          hintStyle: GoogleFonts.dmSans(
                            color: Colors.black26,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFF1F5F9),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: GoogleFonts.dmSans(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoadingClassroom
                              ? null
                              : () async {
                                  final projectId = idController.text.trim();
                                  if (projectId.isEmpty) {
                                    setModalState(() {
                                      errorMessage =
                                          'Masukkan ID Classroom terlebih dahulu.';
                                    });
                                    return;
                                  }
                                  setModalState(() {
                                    isLoadingClassroom = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    final doc = await FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(projectId)
                                        .get();
                                    if (!doc.exists) {
                                      setModalState(() {
                                        errorMessage =
                                            'ID Classroom tidak ditemukan.';
                                        isLoadingClassroom = false;
                                      });
                                      return;
                                    }
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final List masterList =
                                        data['studentsMasterList'] as List? ??
                                        [];
                                    final List<String> names = [];
                                    for (var e in masterList) {
                                      if (e is Map) {
                                        final String name = e['name'] ?? '';
                                        final String uid = e['uid'] ?? '';
                                        final bool joined =
                                            e['joined'] ?? false;
                                        if (name.isNotEmpty &&
                                            (uid.isEmpty || !joined)) {
                                          names.add(name);
                                        }
                                      }
                                    }
                                    setModalState(() {
                                      classroomName =
                                          data['name'] ?? 'Classroom';
                                      availableNames = names;
                                      isClassroomLoaded = true;
                                      isLoadingClassroom = false;
                                      if (names.isEmpty) {
                                        errorMessage = masterList.isEmpty
                                            ? 'Daftar siswa induk belum diatur oleh guru kelas. Hubungi guru Anda.'
                                            : 'Semua siswa di daftar induk kelas ini sudah bergabung.';
                                      }
                                    });
                                  } catch (e) {
                                    setModalState(() {
                                      errorMessage = 'Gagal memuat kelas: $e';
                                      isLoadingClassroom = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: isLoadingClassroom
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Periksa Kelas',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.4,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      // Classroom is loaded
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nama Kelas',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14.0,
                                      color: Colors.black45,
                                    ),
                                  ),
                                  Text(
                                    classroomName ?? '',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16.4,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.dmSans(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                isClassroomLoaded = false;
                                errorMessage = null;
                              });
                            },
                            child: Text(
                              'Kembali',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Pilih Nama Anda dari Daftar Induk',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFF1F5F9),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          items: availableNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          value: selectedName,
                          hint: Text(
                            'Pilih Nama Anda...',
                            style: GoogleFonts.dmSans(
                              fontSize: 15.2,
                              color: Colors.black26,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              selectedName = val;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setModalState(() {
                                    isClassroomLoaded = false;
                                    selectedName = null;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: Text(
                                  'Kembali',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: selectedName == null
                                    ? null
                                    : () {
                                        _processJoinProject(
                                          idController.text,
                                          selectedName!,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Gabung',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.4,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.shortestSide >= 700;

    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';
        AppColors.themeMode = themeMode;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          body: Stack(
            children: [
              if (isDark) ...[
                // Top-Left 30% soft ambient plum glow (Kilauan latar ungu 30% intensitas)
                Positioned(
                  top: -30,
                  left: -40,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF2E1038).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
                // Mid-Right 30% soft ambient plum sheen (Kilauan latar ungu 30% intensitas)
                Positioned(
                  top: 220,
                  right: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF280E32).withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.topCenter,
                child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop
                    ? double.infinity
                    : 700,
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
                    return Scaffold(
                      backgroundColor: isDark ? Colors.black : Colors.white,
                      body: const SizedBox.shrink(),
                    );
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return Scaffold(
                      backgroundColor: isDark ? Colors.black : Colors.white,
                      body: const Center(child: Text('Data pengguna tidak ditemukan.')),
                    );
                  }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              final fullName = userData['name'] ?? 'User';
              final userName = fullName
                  .trim()
                  .split(' ')
                  .first; // Only first name
              final projectIds = List<String>.from(
                userData['projectIds'] ?? [],
              );
              final projectCount = projectIds.length;

              final hour = DateTime.now().hour;
              String timeGreeting = 'Selamat pagi,';
              if (hour >= 11 && hour < 15) {
                timeGreeting = 'Selamat siang,';
              } else if (hour >= 15 && hour < 19) {
                timeGreeting = 'Selamat sore,';
              } else if (hour >= 19 || hour < 4) {
                timeGreeting = 'Selamat malam,';
              }

              final String role = userData['role'] ?? 'Siswa';
              final String gender = userData['gender'] ?? '';
              final String schoolLevel = userData['schoolLevel'] ?? 'SMA';

              String displayNameWithTitle = userName;
              String subtitleText = 'Siswa';

              if (role.toLowerCase() == 'guru') {
                final isFemale =
                    gender.toLowerCase().contains('perempuan') ||
                    gender.toLowerCase().startsWith('p');
                final title = isFemale ? 'Bu' : 'Pak';
                displayNameWithTitle = '$title $userName';
                subtitleText = 'Pendidik tingkat ${schoolLevel.toUpperCase()}';
              } else {
                subtitleText = 'Siswa tingkat ${schoolLevel.toUpperCase()}';
              }

              final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
              return StreamBuilder<List<DocumentSnapshot>>(
                initialData: _lastProjectDocs.isNotEmpty ? _lastProjectDocs : null,
                stream: _combineProjectsStreams(
                  currentUserId,
                  projectIds,
                ),
                builder: (context, projectsSnapshot) {
                  if (projectsSnapshot.hasData && projectsSnapshot.data != null && projectsSnapshot.data!.isNotEmpty) {
                    _lastProjectDocs = projectsSnapshot.data!;
                  }
                  final rawDocs = (projectsSnapshot.data != null && projectsSnapshot.data!.isNotEmpty)
                      ? projectsSnapshot.data!
                      : _lastProjectDocs;
                  final projectDocs = rawDocs.where((doc) {
                    final pData = doc.data() as Map<String, dynamic>? ?? {};
                    final pId = (pData['projectId'] ?? doc.id).toString();
                    return !_deletedProjectIds.contains(doc.id) && !_deletedProjectIds.contains(pId);
                  }).toList();
                  final List<Map<String, dynamic>> allUserTasks = [];

                  for (var projDoc in projectDocs) {
                    final projData = projDoc.data() as Map<String, dynamic>;
                    final projName = projData['name'] ?? 'Project';
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

                  // Filter tasks scheduled for selected calendar day
                  final targetDay = DateTime(
                    _selectedCalendarDay.year,
                    _selectedCalendarDay.month,
                    _selectedCalendarDay.day,
                  );
                  final List<Map<String, String>> selectedDayTasksList = [];
                  final dayFilteredTasks = allUserTasks.where((t) {
                    final startStr = t['start'] as String? ?? '';
                    final endStr = t['end'] as String? ?? '';
                    if (startStr.isEmpty ||
                        endStr.isEmpty ||
                        startStr == 'DD/MM/YYYY')
                      return false;

                    final startDate = _parseDateString(startStr);
                    final endDate = _parseDateString(endStr);
                    if (startDate == null || endDate == null) return false;

                    final normStart = DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                    );
                    final normEnd = DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                    );

                    return (targetDay.isAfter(normStart) ||
                            targetDay.isAtSameMomentAs(normStart)) &&
                        (targetDay.isBefore(normEnd) ||
                            targetDay.isAtSameMomentAs(normEnd));
                  }).toList();

                  for (var t in dayFilteredTasks.take(3)) {
                    selectedDayTasksList.add({
                      'time': t['start'] ?? '',
                      'title': t['title'] ?? 'Tugas Tanpa Judul',
                    });
                  }

                  // Teacher schedules gathering
                  final List<Map<String, dynamic>> teacherSchedules = [];
                  for (var projDoc in projectDocs) {
                    final projData = projDoc.data() as Map<String, dynamic>;
                    final projName = projData['name'] ?? 'Classroom';
                    final schedulesList = projData['schedules'] as List? ?? [];
                    for (var s in schedulesList) {
                      final sMap = Map<String, dynamic>.from(s as Map);
                      sMap['projectName'] = projName;
                      teacherSchedules.add(sMap);
                    }
                  }

                  final String selectedDayName = _getIndonesianDayName(
                    _selectedCalendarDay,
                  );
                  final List<Map<String, dynamic>> activeSchedules =
                      teacherSchedules.where((s) {
                        return (s['day'] as String? ?? '').toLowerCase() ==
                            selectedDayName.toLowerCase();
                      }).toList();

                  // Sort schedules by time
                  activeSchedules.sort((a, b) {
                    final aTime = a['time'] as String? ?? '';
                    final bTime = b['time'] as String? ?? '';
                    return aTime.compareTo(bTime);
                  });

                  final String userPhoto = (userData['profileImageUrl'] ??
                          userData['photoUrl'] ??
                          userData['avatarUrl'] ??
                          userData['avatar'] ??
                          '')
                      .toString()
                      .trim();
                  final bool isFemale = gender.toLowerCase().contains('perempuan') || gender.toLowerCase().startsWith('p');
                  final Color genderRoleColor = isFemale ? const Color(0xFFF43F5E) : const Color(0xFF0EA5E9);

                  final String capitalizedName = fullName.trim().isEmpty
                      ? 'User'
                      : fullName.trim().split(RegExp(r'\s+')).map((w) => w.isNotEmpty ? (w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '')) : '').join(' ');

                  final String roleSubtitle = role.toLowerCase() == 'guru'
                      ? 'Pengajar · ${schoolLevel.isNotEmpty ? schoolLevel.toUpperCase() : 'SMA/SMK'}'
                      : 'Siswa · ${schoolLevel.isNotEmpty ? schoolLevel.toUpperCase() : 'SMA/SMK'}';
                  final bool isDark = AppColors.isDarkMode;

                  return Stack(
                    children: [
                      // 1. Scrollable Page Content
                      SingleChildScrollView(
                        controller: _homeScrollController,
                        padding: EdgeInsets.fromLTRB(
                          AppTypography.screenHorizontalMargin,
                          MediaQuery.of(context).padding.top + (isDesktop ? 12.0 : 16.0),
                          AppTypography.screenHorizontalMargin,
                          125.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [                            // 1. Baris Tombol Kontrol di Pojok Kanan (Dark Mode di samping Lonceng)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Dark / Light Mode Toggle (Tanpa background & frame)
                                ValueListenableBuilder<String>(
                                  valueListenable: HubnerApp.themeNotifier,
                                  builder: (context, currentTheme, _) {
                                    final bool isDarkTheme = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                    return BouncyButton(
                                      onTap: () => _toggleThemeWithBounce(context, isDarkTheme),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                        child: Icon(
                                          isDarkTheme ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                          color: isDarkTheme ? const Color(0xFFFBBF24) : Colors.black87,
                                          size: 26,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),

                                // Notification Bell (Tanpa background & frame)
                                ValueListenableBuilder<String>(
                                  valueListenable: HubnerApp.themeNotifier,
                                  builder: (context, currentTheme, _) {
                                    final bool isDarkTheme = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                    return NotificationBellIcon(
                                      isDark: isDarkTheme,
                                      size: 40,
                                      showFrame: false,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 2. Baris DIBAWAHNYA: Avatar, Hai [Name], & Role Subtitle (Ukuran Lebih Besar)
                            Row(
                              children: [
                                // Profile Avatar (Ukuran lebih besar sebelum di-scroll: 56x56)
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  ),
                                  child: ClipOval(
                                    child: Transform.scale(
                                      scale: 1.45,
                                      child: userPhoto.isNotEmpty
                                          ? (userPhoto.startsWith('http')
                                              ? Image.network(
                                                  userPhoto,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(
                                                    child: Text(
                                                      userName.isNotEmpty
                                                          ? userName.substring(0, (userName.length >= 2 ? 2 : 1)).toUpperCase()
                                                          : 'P',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.white : Colors.black,
                                                        fontSize: 22,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Image.asset(
                                                  userPhoto,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(
                                                    child: Text(
                                                      userName.isNotEmpty
                                                          ? userName.substring(0, (userName.length >= 2 ? 2 : 1)).toUpperCase()
                                                          : 'P',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.white : Colors.black,
                                                        fontSize: 22,
                                                      ),
                                                    ),
                                                  ),
                                                ))
                                          : Center(
                                              child: Text(
                                                userName.isNotEmpty
                                                    ? userName.substring(0, (userName.length >= 2 ? 2 : 1)).toUpperCase()
                                                    : 'P',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontSize: 22,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nama & Role (Hai [Nama] diatas, Role Subtitle dibawah)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Hai, $capitalizedName',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                          height: 1.15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        roleSubtitle,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: genderRoleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Student Top Section Redesign
                            StreamBuilder<Map<String, Map<String, dynamic>>>(
                                stream: _combineStudentProgressStreams(
                                  projectDocs.map((d) => d.id).toList(),
                                  currentUserId,
                                ),
                                builder: (context, progressMapSnapshot) {
                                  final progressMap =
                                      progressMapSnapshot.data ?? {};

                                  int totalTugas = 0;
                                  int completedTugas = 0;
                                  int totalQuiz = 0;
                                  int completedQuiz = 0;
                                  final List<int> quizScores = [];

                                  for (var projDoc in projectDocs) {
                                    final projId = projDoc.id;
                                    final projData =
                                        projDoc.data() as Map<String, dynamic>;
                                    final stages =
                                        projData['stages'] as List? ?? [];

                                    final progData = progressMap[projId] ?? {};
                                    final List completedTasksList =
                                        progData['completedTasks'] as List? ?? [];

                                    for (
                                      int sIdx = 0;
                                      sIdx < stages.length;
                                      sIdx++
                                    ) {
                                      final stage = stages[sIdx] as Map;
                                      final List rawMateris =
                                          stage['materis'] as List? ?? [];
                                      List<Map<String, dynamic>> materis = [];
                                      if (rawMateris.isNotEmpty) {
                                        materis = List<Map<String, dynamic>>.from(
                                          rawMateris,
                                        );
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
                                        final m = materis[mIdx];
                                        final List tasks =
                                            m['tasks'] as List? ?? [];
                                        for (
                                          int tIdx = 0;
                                          tIdx < tasks.length;
                                          tIdx++
                                        ) {
                                          final task = tasks[tIdx] as Map;
                                          final String type =
                                              task['type'] ?? 'tugas';
                                          final String key =
                                              '${sIdx}_${mIdx}_$tIdx';
                                          final bool isCompleted =
                                              completedTasksList.contains(key);

                                          if (type == 'tugas') {
                                            totalTugas++;
                                            if (isCompleted) {
                                              completedTugas++;
                                            }
                                          } else if (type == 'quiz') {
                                            totalQuiz++;
                                            if (isCompleted) {
                                              completedQuiz++;
                                              final scoreVal =
                                                  progData['quizScore_$key'];
                                              if (scoreVal != null) {
                                                final int score =
                                                    (scoreVal as num).toInt();
                                                quizScores.add(score);
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }

                                  final double tugasRatio = totalTugas > 0
                                      ? completedTugas / totalTugas
                                      : 0.0;
                                  final double quizRatio = totalQuiz > 0
                                      ? completedQuiz / totalQuiz
                                      : 0.0;
                                  final String scoreText = quizScores.isEmpty
                                      ? '-'
                                      : '${quizScores.last}';
                                  final double averageScore =
                                      quizScores.isNotEmpty
                                      ? quizScores.reduce((a, b) => a + b) /
                                            quizScores.length
                                      : 0.0;
                                  final String avgScoreText = quizScores.isEmpty
                                      ? '-'
                                      : averageScore.toStringAsFixed(1);

                                  // Deadlines for selected calendar date
                                  final selectedDate = DateTime(
                                    _selectedCalendarDay.year,
                                    _selectedCalendarDay.month,
                                    _selectedCalendarDay.day,
                                  );

                                  final List<Map<String, dynamic>>
                                  todayTugasDeadlines = [];
                                  final List<Map<String, dynamic>>
                                  todayQuizDeadlines = [];

                                  for (var projDoc in projectDocs) {
                                    final projData =
                                        projDoc.data() as Map<String, dynamic>;
                                    final projName =
                                        projData['name'] ?? 'Classroom';
                                    final stages =
                                        projData['stages'] as List? ?? [];
                                    for (var stage in stages) {
                                      final stageMap =
                                          stage as Map<String, dynamic>;
                                      final List rawMateris =
                                          stageMap['materis'] as List? ?? [];
                                      List<Map<String, dynamic>> materis = [];
                                      if (rawMateris.isNotEmpty) {
                                        materis = List<Map<String, dynamic>>.from(
                                          rawMateris,
                                        );
                                      } else {
                                        final List tasksList =
                                            stageMap['tasks'] as List? ?? [];
                                        if (tasksList.isNotEmpty) {
                                          materis = [
                                            {
                                              'title': 'Materi Pembelajaran',
                                              'tasks': tasksList,
                                            },
                                          ];
                                        }
                                      }
                                      for (var m in materis) {
                                        final List tasks =
                                            m['tasks'] as List? ?? [];
                                        for (var task in tasks) {
                                          final taskMap =
                                              Map<String, dynamic>.from(
                                                task as Map,
                                              );
                                          taskMap['projectName'] = projName;
                                          final endStr =
                                              taskMap['end'] as String? ?? '';
                                          final type = taskMap['type'] ?? 'tugas';

                                          if (endStr.isNotEmpty &&
                                              endStr != 'DD/MM/YYYY') {
                                            final endDate = _parseDateString(
                                              endStr,
                                            );
                                            if (endDate != null) {
                                              final normEnd = DateTime(
                                                endDate.year,
                                                endDate.month,
                                                endDate.day,
                                              );
                                              if (normEnd.isAtSameMomentAs(
                                                selectedDate,
                                              )) {
                                                if (type == 'tugas') {
                                                  todayTugasDeadlines.add(
                                                    taskMap,
                                                  );
                                                } else if (type == 'quiz') {
                                                  todayQuizDeadlines.add(taskMap);
                                                }
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }

                                  final bool isDark = AppColors.isDarkMode;

                                  // Quiz Card (1:1 Ratio)
                                   Widget buildModeDots(int currentMode, int totalModes) {
                                     return Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: List.generate(totalModes, (index) {
                                         final bool isActive = index == currentMode;
                                         return AnimatedContainer(
                                           duration: const Duration(milliseconds: 260),
                                           curve: Curves.easeOutCubic,
                                           margin: const EdgeInsets.only(right: 3.5),
                                           width: isActive ? 11 : 4,
                                           height: 4,
                                           decoration: BoxDecoration(
                                             color: isActive
                                                 ? (isDark ? Colors.white : Colors.black87)
                                                 : (isDark ? Colors.white24 : Colors.black26),
                                             borderRadius: BorderRadius.circular(2),
                                           ),
                                         );
                                       }),
                                     );
                                   }

                                    // Quiz Card (Auto Slider 3 Mode: 0 = Progress X/Y + Donut %, 1 = Sparkline 3 Nilai Terakhir, 2 = Nilai Quiz Terakhir)
                                    Widget buildTugasPillCard() {
                                       final Color bgLight = const Color(0xFFFED7AA);
                                       final Color bgDark = const Color(0xFFC76D10);
                                       final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
                                       final Color subtitleColor = isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF334155);
                                       final Color dotActive = isDark ? Colors.white : const Color(0xFF18181B);
                                       final Color dotInactive = isDark ? Colors.white38 : const Color(0xFF18181B).withValues(alpha: 0.35);

                                       final taskChartValues = (totalTugas > 0 && completedTugas > 0)
                                           ? List.generate(7, (i) => ((completedTugas / totalTugas) * 80 + (i * 3)).clamp(20, 100).toInt())
                                           : <int>[];

                                       return Row(
                                         children: [
                                           Expanded(
                                             child: GestureDetector(
                                               onVerticalDragEnd: (details) {
                                                 final vel = details.primaryVelocity ?? 0;
                                                 if (vel < -100) {
                                                   if (_tugasCardMode != 1) {
                                                     HapticFeedback.selectionClick();
                                                     setState(() => _tugasCardMode = 1);
                                                   }
                                                 } else if (vel > 100) {
                                                   if (_tugasCardMode != 0) {
                                                     HapticFeedback.selectionClick();
                                                     setState(() => _tugasCardMode = 0);
                                                   }
                                                 }
                                               },
                                               onTap: () {
                                                 HapticFeedback.selectionClick();
                                                 setState(() {
                                                   _tugasCardMode = (_tugasCardMode + 1) % 2;
                                                 });
                                               },
                                               child: Container(
                                                 clipBehavior: Clip.antiAlias,
                                                 decoration: BoxDecoration(
                                                   color: isDark ? bgDark : bgLight,
                                                   borderRadius: BorderRadius.circular(32),
                                                   border: isDark
                                                       ? Border.all(
                                                           color: Colors.white.withValues(alpha: 0.15),
                                                           width: 1.0,
                                                         )
                                                       : null,
                                                 ),
                                                 child: Stack(
                                                   children: [
                                                     Positioned.fill(
                                                       child: CustomPaint(
                                                         painter: _TaskFacetPatternPainter(isDark: isDark),
                                                       ),
                                                     ),
                                                     Padding(
                                                       padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                                                       child: AnimatedSwitcher(
                                                         duration: const Duration(milliseconds: 220),
                                                         switchInCurve: Curves.easeOut,
                                                         switchOutCurve: Curves.easeIn,
                                                         child: KeyedSubtree(
                                                           key: ValueKey<int>(_tugasCardMode),
                                                           child: _tugasCardMode == 0
                                                               ? Row(
                                                                   key: const ValueKey('tugas_mode_0'),
                                                                   crossAxisAlignment: CrossAxisAlignment.center,
                                                                   children: [
                                                                     Expanded(
                                                                       child: Column(
                                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                                         mainAxisAlignment: MainAxisAlignment.center,
                                                                         children: [
                                                                           Row(
                                                                             children: [
                                                                               Icon(
                                                                                 Icons.assignment_turned_in_rounded,
                                                                                 size: 15,
                                                                                 color: isDark ? Colors.white70 : const Color(0xFFC2410C),
                                                                               ),
                                                                               const SizedBox(width: 5),
                                                                               Text(
                                                                                 'TARGET TUGAS',
                                                                                 style: GoogleFonts.plusJakartaSans(
                                                                                   fontSize: 12.5,
                                                                                   fontWeight: FontWeight.w800,
                                                                                   letterSpacing: 0.6,
                                                                                   color: isDark ? Colors.white70 : const Color(0xFFC2410C),
                                                                                 ),
                                                                               ),
                                                                             ],
                                                                           ),
                                                                           const SizedBox(height: 12),
                                                                           Text.rich(
                                                                             TextSpan(
                                                                               children: [
                                                                                 TextSpan(
                                                                                   text: totalTugas > 0 ? '$completedTugas' : '0',
                                                                                   style: GoogleFonts.plusJakartaSans(
                                                                                     fontSize: 38.0,
                                                                                     fontWeight: FontWeight.w900,
                                                                                     color: titleColor,
                                                                                     height: 1.0,
                                                                                   ),
                                                                                 ),
                                                                                 TextSpan(
                                                                                   text: totalTugas > 0 ? '/$totalTugas Selesai' : ' Tugas Selesai',
                                                                                   style: GoogleFonts.plusJakartaSans(
                                                                                     fontSize: 22.0,
                                                                                     fontWeight: FontWeight.w800,
                                                                                     color: titleColor,
                                                                                     height: 1.0,
                                                                                   ),
                                                                                 ),
                                                                               ],
                                                                             ),
                                                                             maxLines: 1,
                                                                             overflow: TextOverflow.ellipsis,
                                                                           ),
                                                                           const SizedBox(height: 11),
                                                                           Text(
                                                                             totalTugas > completedTugas
                                                                                 ? '${totalTugas - completedTugas} tugas belum diselesaikan.'
                                                                                 : 'Semua target tugas telah tercapai!',
                                                                             style: GoogleFonts.dmSans(
                                                                               fontSize: 13.5,
                                                                               fontWeight: FontWeight.w600,
                                                                               color: subtitleColor,
                                                                               height: 1.15,
                                                                             ),
                                                                             maxLines: 1,
                                                                             overflow: TextOverflow.ellipsis,
                                                                           ),
                                                                         ],
                                                                       ),
                                                                     ),
                                                                     const SizedBox(width: 10),
                                                                     Container(
                                                                       width: 66,
                                                                       height: 66,
                                                                       decoration: BoxDecoration(
                                                                         shape: BoxShape.circle,
                                                                         color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.92),
                                                                       ),
                                                                       child: Stack(
                                                                         alignment: Alignment.center,
                                                                         children: [
                                                                           SizedBox(
                                                                             width: 54,
                                                                             height: 54,
                                                                             child: CircularProgressIndicator(
                                                                               value: tugasRatio,
                                                                               strokeWidth: 5.0,
                                                                               backgroundColor: isDark ? Colors.white24 : const Color(0xFFFFEDD5),
                                                                               valueColor: AlwaysStoppedAnimation<Color>(
                                                                                 isDark ? Colors.white : const Color(0xFFEA580C),
                                                                               ),
                                                                             ),
                                                                           ),
                                                                           Text(
                                                                             '${(tugasRatio * 100).toInt()}%',
                                                                             style: GoogleFonts.plusJakartaSans(
                                                                               fontSize: 14.0,
                                                                               fontWeight: FontWeight.w900,
                                                                               color: titleColor,
                                                                             ),
                                                                           ),
                                                                         ],
                                                                       ),
                                                                     ),
                                                                   ],
                                                                 )
                                                               : Row(
                                                                   key: const ValueKey('tugas_mode_1'),
                                                                   crossAxisAlignment: CrossAxisAlignment.center,
                                                                   children: [
                                                                     Expanded(
                                                                       flex: 5,
                                                                       child: Column(
                                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                                         mainAxisAlignment: MainAxisAlignment.center,
                                                                         children: [
                                                                           Row(
                                                                             children: [
                                                                               Icon(
                                                                                 Icons.bar_chart_rounded,
                                                                                 size: 15,
                                                                                 color: isDark ? Colors.white70 : const Color(0xFFC2410C),
                                                                               ),
                                                                               const SizedBox(width: 5),
                                                                               Text(
                                                                                 'STATISTIK TUGAS',
                                                                                 style: GoogleFonts.plusJakartaSans(
                                                                                   fontSize: 12.5,
                                                                                   fontWeight: FontWeight.w800,
                                                                                   letterSpacing: 0.6,
                                                                                   color: isDark ? Colors.white70 : const Color(0xFFC2410C),
                                                                                 ),
                                                                               ),
                                                                             ],
                                                                           ),
                                                                           const SizedBox(height: 12),
                                                                           Text.rich(
                                                                             TextSpan(
                                                                               children: [
                                                                                 TextSpan(
                                                                                   text: '${(tugasRatio * 100).toInt()}',
                                                                                   style: GoogleFonts.plusJakartaSans(
                                                                                     fontSize: 38.0,
                                                                                     fontWeight: FontWeight.w900,
                                                                                     color: titleColor,
                                                                                     height: 1.0,
                                                                                   ),
                                                                                 ),
                                                                                 TextSpan(
                                                                                   text: '% Tuntas',
                                                                                   style: GoogleFonts.plusJakartaSans(
                                                                                     fontSize: 22.0,
                                                                                     fontWeight: FontWeight.w800,
                                                                                     color: titleColor,
                                                                                     height: 1.0,
                                                                                   ),
                                                                                 ),
                                                                               ],
                                                                             ),
                                                                             maxLines: 1,
                                                                             overflow: TextOverflow.ellipsis,
                                                                           ),
                                                                           const SizedBox(height: 11),
                                                                           Text(
                                                                             '$completedTugas dari $totalTugas tugas selesai',
                                                                             style: GoogleFonts.dmSans(
                                                                               fontSize: 13.5,
                                                                               fontWeight: FontWeight.w600,
                                                                               color: subtitleColor,
                                                                               height: 1.15,
                                                                             ),
                                                                             maxLines: 1,
                                                                             overflow: TextOverflow.ellipsis,
                                                                           ),
                                                                         ],
                                                                       ),
                                                                     ),
                                                                     if (taskChartValues.isNotEmpty) ...[
                                                                       const SizedBox(width: 8),
                                                                       Expanded(
                                                                         flex: 5,
                                                                         child: SizedBox(
                                                                           height: 78,
                                                                           child: CustomPaint(
                                                                             size: Size.infinite,
                                                                             painter: _StressStyleBarChartPainter(
                                                                               values: taskChartValues,
                                                                               isDark: isDark,
                                                                               barColor: isDark ? Colors.white : const Color(0xFF9A3412),
                                                                               lineColor: isDark ? Colors.white : const Color(0xFF431407),
                                                                             ),
                                                                           ),
                                                                         ),
                                                                       ),
                                                                     ],
                                                                   ],
                                                                 ),
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(width: 10),
                                           Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: List.generate(2, (index) {
                                               final bool isActive = index == _tugasCardMode;
                                               return AnimatedContainer(
                                                 duration: const Duration(milliseconds: 220),
                                                 margin: const EdgeInsets.symmetric(vertical: 4),
                                                 width: 8,
                                                 height: 8,
                                                 decoration: BoxDecoration(
                                                   shape: BoxShape.circle,
                                                   color: isActive ? dotActive : Colors.transparent,
                                                   border: isActive
                                                       ? null
                                                       : Border.all(color: dotInactive, width: 1.8),
                                                 ),
                                               );
                                             }),
                                           ),
                                           const SizedBox(width: 14),
                                         ],
                                       );
                                     }

                                     Widget buildQuizPillCard() {
                                       final Color bgLight = const Color(0xFFBAE6FD);
                                       final Color bgDark = const Color(0xFF6B3BA3);
                                       final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
                                       final Color subtitleColor = isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF334155);
                                       final Color dotActive = isDark ? Colors.white : const Color(0xFF18181B);
                                       final Color dotInactive = isDark ? Colors.white38 : const Color(0xFF18181B).withValues(alpha: 0.35);

                                       final last5Scores = quizScores.isNotEmpty
                                           ? (quizScores.length >= 5
                                               ? quizScores.sublist(quizScores.length - 5)
                                               : quizScores)
                                           : <int>[];

                                       return Row(
                                         children: [
                                           Expanded(
                                             child: GestureDetector(
                                               onVerticalDragEnd: (details) {
                                                 final vel = details.primaryVelocity ?? 0;
                                                 if (vel < -100) {
                                                   HapticFeedback.selectionClick();
                                                   setState(() => _quizCardMode = (_quizCardMode + 1) % 3);
                                                 } else if (vel > 100) {
                                                   HapticFeedback.selectionClick();
                                                   setState(() => _quizCardMode = (_quizCardMode - 1 + 3) % 3);
                                                 }
                                               },
                                               onTap: () {
                                                 HapticFeedback.selectionClick();
                                                 setState(() {
                                                   _quizCardMode = (_quizCardMode + 1) % 3;
                                                 });
                                               },
                                               child: Container(
                                                 clipBehavior: Clip.antiAlias,
                                                 decoration: BoxDecoration(
                                                   color: isDark ? bgDark : bgLight,
                                                   borderRadius: BorderRadius.circular(32),
                                                   border: isDark
                                                       ? Border.all(
                                                           color: Colors.white.withValues(alpha: 0.15),
                                                           width: 1.0,
                                                         )
                                                       : null,
                                                 ),
                                                 child: Stack(
                                                   children: [
                                                     Positioned.fill(
                                                       child: CustomPaint(
                                                         painter: _QuizFacetPatternPainter(isDark: isDark),
                                                       ),
                                                     ),
                                                     Padding(
                                                       padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                                                       child: AnimatedSwitcher(
                                                         duration: const Duration(milliseconds: 220),
                                                         switchInCurve: Curves.easeOut,
                                                         switchOutCurve: Curves.easeIn,
                                                         child: KeyedSubtree(
                                                           key: ValueKey<int>(_quizCardMode),
                                                           child: _quizCardMode == 0
                                                               ? Row(
                                                                   key: const ValueKey('quiz_mode_0'),
                                                                   crossAxisAlignment: CrossAxisAlignment.center,
                                                                   children: [
                                                                     Expanded(
                                                                       child: Column(
                                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                                         mainAxisAlignment: MainAxisAlignment.center,
                                                                         children: [
                                                                           Row(
                                                                             children: [
                                                                               Icon(
                                                                                 Icons.quiz_rounded,
                                                                                 size: 15,
                                                                                 color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                                                                               ),
                                                                               const SizedBox(width: 5),
                                                                               Text(
                                                                                 'RINGKASAN KUIS',
                                                                                 style: GoogleFonts.plusJakartaSans(
                                                                                   fontSize: 12.5,
                                                                                   fontWeight: FontWeight.w800,
                                                                                   letterSpacing: 0.6,
                                                                                   color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                                                                                 ),
                                                                               ),
                                                                             ],
                                                                           ),
                                                                           const SizedBox(height: 12),
                                                                           Text.rich(
                                                                             TextSpan(
                                                                               children: [
                                                                                 TextSpan(
                                                                                   text: totalQuiz > 0 ? '$completedQuiz' : '0',
                                                                                   style: GoogleFonts.plusJakartaSans(
                                                                                     fontSize: 38.0,
                                                                                     fontWeight: FontWeight.w900,
                                                                                     color: titleColor,
                                                                                     height: 1.0,
                                                                                   ),
                                                                                 ),
                                                                                 TextSpan(
                                                                                   text: totalQuiz > 0 ? '/$totalQuiz Selesai' : ' Kuis Selesai',
                                                                                   style: GoogleFonts.plusJakartaSans(
                                                                                     fontSize: 22.0,
                                                                                     fontWeight: FontWeight.w800,
                                                                                     color: titleColor,
                                                                                     height: 1.0,
                                                                                   ),
                                                                                 ),
                                                                               ],
                                                                             ),
                                                                             maxLines: 1,
                                                                             overflow: TextOverflow.ellipsis,
                                                                           ),
                                                                           const SizedBox(height: 11),
                                                                           Text(
                                                                             totalQuiz > 0
                                                                                 ? (completedQuiz == totalQuiz
                                                                                     ? 'Semua evaluasi telah tuntas!'
                                                                                     : '$completedQuiz dari $totalQuiz kuis diselesaikan.')
                                                                                 : 'Belum ada kuis aktif saat ini.',
                                                                             style: GoogleFonts.dmSans(
                                                                               fontSize: 13.5,
                                                                               fontWeight: FontWeight.w600,
                                                                               color: subtitleColor,
                                                                               height: 1.15,
                                                                             ),
                                                                             maxLines: 1,
                                                                             overflow: TextOverflow.ellipsis,
                                                                           ),
                                                                         ],
                                                                       ),
                                                                     ),
                                                                     const SizedBox(width: 10),
                                                                     Container(
                                                                       width: 66,
                                                                       height: 66,
                                                                       decoration: BoxDecoration(
                                                                         shape: BoxShape.circle,
                                                                         color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.92),
                                                                       ),
                                                                       child: Stack(
                                                                         alignment: Alignment.center,
                                                                         children: [
                                                                           SizedBox(
                                                                             width: 54,
                                                                             height: 54,
                                                                             child: CircularProgressIndicator(
                                                                               value: totalQuiz > 0 ? completedQuiz / totalQuiz : 0.0,
                                                                               strokeWidth: 5.0,
                                                                               backgroundColor: isDark ? Colors.white24 : const Color(0xFFE0F2FE),
                                                                               valueColor: AlwaysStoppedAnimation<Color>(
                                                                                 isDark ? Colors.white : const Color(0xFF0284C7),
                                                                               ),
                                                                             ),
                                                                           ),
                                                                           const _TrophySvgIcon(size: 28),
                                                                         ],
                                                                       ),
                                                                     ),
                                                                   ],
                                                                 )
                                                               : (_quizCardMode == 1
                                                                   ? Row(
                                                                       key: const ValueKey('quiz_mode_1'),
                                                                       crossAxisAlignment: CrossAxisAlignment.center,
                                                                       children: [
                                                                         Expanded(
                                                                           flex: 5,
                                                                           child: Column(
                                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                                             mainAxisAlignment: MainAxisAlignment.center,
                                                                             children: [
                                                                               Row(
                                                                                 children: [
                                                                                   Icon(
                                                                                     Icons.trending_up_rounded,
                                                                                     size: 15,
                                                                                     color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                                                                                   ),
                                                                                   const SizedBox(width: 5),
                                                                                   Text(
                                                                                     'TREN PERFORMA',
                                                                                     style: GoogleFonts.plusJakartaSans(
                                                                                       fontSize: 12.5,
                                                                                       fontWeight: FontWeight.w800,
                                                                                       letterSpacing: 0.6,
                                                                                       color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                                                                                     ),
                                                                                   ),
                                                                                 ],
                                                                               ),
                                                                               const SizedBox(height: 12),
                                                                               Text.rich(
                                                                                 TextSpan(
                                                                                   children: [
                                                                                     TextSpan(
                                                                                       text: avgScoreText == '-' ? '0' : avgScoreText,
                                                                                       style: GoogleFonts.plusJakartaSans(
                                                                                         fontSize: 38.0,
                                                                                         fontWeight: FontWeight.w900,
                                                                                         color: titleColor,
                                                                                         height: 1.0,
                                                                                       ),
                                                                                     ),
                                                                                     TextSpan(
                                                                                       text: ' Poin',
                                                                                       style: GoogleFonts.plusJakartaSans(
                                                                                         fontSize: 22.0,
                                                                                         fontWeight: FontWeight.w800,
                                                                                         color: titleColor,
                                                                                         height: 1.0,
                                                                                       ),
                                                                                     ),
                                                                                   ],
                                                                                 ),
                                                                                 maxLines: 1,
                                                                                 overflow: TextOverflow.ellipsis,
                                                                               ),
                                                                               const SizedBox(height: 11),
                                                                               Text(
                                                                                 quizScores.isNotEmpty
                                                                                     ? (last5Scores.length == 1
                                                                                         ? '1 kuis diselesaikan'
                                                                                         : 'Rata-rata ${last5Scores.length} kuis terakhir')
                                                                                     : 'Belum ada quiz yang dikerjakan',
                                                                                 style: GoogleFonts.dmSans(
                                                                                   fontSize: 13.5,
                                                                                   fontWeight: FontWeight.w600,
                                                                                   color: subtitleColor,
                                                                                   height: 1.15,
                                                                                 ),
                                                                                 maxLines: 1,
                                                                                 overflow: TextOverflow.ellipsis,
                                                                               ),
                                                                             ],
                                                                           ),
                                                                         ),
                                                                         if (last5Scores.isNotEmpty) ...[
                                                                           const SizedBox(width: 8),
                                                                           Expanded(
                                                                             flex: 5,
                                                                             child: SizedBox(
                                                                               height: 78,
                                                                               child: CustomPaint(
                                                                                 size: Size.infinite,
                                                                                 painter: _StressStyleBarChartPainter(
                                                                                   values: last5Scores,
                                                                                   isDark: isDark,
                                                                                   barColor: isDark ? Colors.white : const Color(0xFF3B82F6),
                                                                                   lineColor: isDark ? Colors.white : const Color(0xFF1D4ED8),
                                                                                 ),
                                                                               ),
                                                                             ),
                                                                           ),
                                                                         ],
                                                                       ],
                                                                     )
                                                                   : Row(
                                                                       key: const ValueKey('quiz_mode_2'),
                                                                       crossAxisAlignment: CrossAxisAlignment.center,
                                                                       children: [
                                                                         Expanded(
                                                                           child: Column(
                                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                                             mainAxisAlignment: MainAxisAlignment.center,
                                                                             children: [
                                                                               Row(
                                                                                 children: [
                                                                                   Icon(
                                                                                     Icons.workspace_premium_rounded,
                                                                                     size: 15,
                                                                                     color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                                                                                   ),
                                                                                   const SizedBox(width: 5),
                                                                                   Text(
                                                                                     'SKOR TERAKHIR',
                                                                                     style: GoogleFonts.plusJakartaSans(
                                                                                       fontSize: 12.5,
                                                                                       fontWeight: FontWeight.w800,
                                                                                       letterSpacing: 0.6,
                                                                                       color: isDark ? Colors.white70 : const Color(0xFF0369A1),
                                                                                     ),
                                                                                   ),
                                                                                 ],
                                                                               ),
                                                                               const SizedBox(height: 12),
                                                                               Text.rich(
                                                                                 TextSpan(
                                                                                   children: [
                                                                                     TextSpan(
                                                                                       text: scoreText == '-' ? '0' : scoreText,
                                                                                       style: GoogleFonts.plusJakartaSans(
                                                                                         fontSize: 38.0,
                                                                                         fontWeight: FontWeight.w900,
                                                                                         color: titleColor,
                                                                                         height: 1.0,
                                                                                       ),
                                                                                     ),
                                                                                     TextSpan(
                                                                                       text: ' Poin',
                                                                                       style: GoogleFonts.plusJakartaSans(
                                                                                         fontSize: 22.0,
                                                                                         fontWeight: FontWeight.w800,
                                                                                         color: titleColor,
                                                                                         height: 1.0,
                                                                                       ),
                                                                                     ),
                                                                                   ],
                                                                                 ),
                                                                                 maxLines: 1,
                                                                                 overflow: TextOverflow.ellipsis,
                                                                               ),
                                                                               const SizedBox(height: 11),
                                                                               Text(
                                                                                 quizScores.isNotEmpty
                                                                                     ? (quizScores.last >= 80
                                                                                         ? 'Pencapaian sangat luar biasa!'
                                                                                         : 'Performa stabil, tingkatkan terus!')
                                                                                     : 'Selesaikan kuis pertamamu!',
                                                                                 style: GoogleFonts.dmSans(
                                                                                   fontSize: 13.5,
                                                                                   fontWeight: FontWeight.w600,
                                                                                   color: subtitleColor,
                                                                                   height: 1.15,
                                                                                 ),
                                                                                 maxLines: 1,
                                                                                 overflow: TextOverflow.ellipsis,
                                                                               ),
                                                                             ],
                                                                           ),
                                                                         ),
                                                                         const SizedBox(width: 10),
                                                                         Container(
                                                                           width: 66,
                                                                           height: 66,
                                                                           decoration: BoxDecoration(
                                                                             shape: BoxShape.circle,
                                                                             color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.92),
                                                                             border: Border.all(
                                                                               color: isDark ? Colors.white24 : const Color(0xFFBAE6FD),
                                                                               width: 1.5,
                                                                             ),
                                                                           ),
                                                                           child: const Center(
                                                                             child: _TrophySvgIcon(size: 40),
                                                                           ),
                                                                         ),
                                                                       ],
                                                                     )),
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                           ),
                                           const SizedBox(width: 10),
                                           Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: List.generate(3, (index) {
                                               final bool isActive = index == _quizCardMode;
                                               return AnimatedContainer(
                                                 duration: const Duration(milliseconds: 220),
                                                 margin: const EdgeInsets.symmetric(vertical: 4),
                                                 width: 8,
                                                 height: 8,
                                                 decoration: BoxDecoration(
                                                   shape: BoxShape.circle,
                                                   color: isActive ? dotActive : Colors.transparent,
                                                   border: isActive
                                                       ? null
                                                       : Border.all(color: dotInactive, width: 1.8),
                                                 ),
                                               );
                                             }),
                                           ),
                                           const SizedBox(width: 14),
                                         ],
                                       );
                                     }

                                    int _todayActivityIndex = 0;

                                    Widget todayCardsSlider = StatefulBuilder(
                                      builder: (context, setActivityState) {
                                        final tagBgColor = isDark ? const Color(0xFF27272A) : const Color(0xFF18181B);
                                        const tagTxtColor = Colors.white;

                                        final List<Map<String, dynamic>> activityItems = [
                                          {
                                            'tag': 'Jadwal Kuis',
                                            'tagColor': tagBgColor,
                                            'tagTextColor': tagTxtColor,
                                            'title': todayQuizDeadlines.isEmpty ? '"Bebas Kuis"' : '"${todayQuizDeadlines.length} Kuis Aktif"',
                                            'subtitle': todayQuizDeadlines.isEmpty
                                                ? 'Tidak ada kuis aktif untuk tanggal ini.'
                                                : '${todayQuizDeadlines.first['title']} (${todayQuizDeadlines.first['projectName']})',
                                            'doodle': _QuizPuzzleDoodle(width: 96, height: 60, isDark: isDark),
                                          },
                                          {
                                            'tag': 'Deadline Tugas',
                                            'tagColor': tagBgColor,
                                            'tagTextColor': tagTxtColor,
                                            'title': todayTugasDeadlines.isEmpty ? '"Bebas Tugas"' : '"${todayTugasDeadlines.length} Tugas Deadline"',
                                            'subtitle': todayTugasDeadlines.isEmpty
                                                ? 'Tidak ada tugas deadline untuk tanggal ini.'
                                                : '${todayTugasDeadlines.first['title']} (${todayTugasDeadlines.first['projectName']})',
                                            'doodle': _TaskDeadlineDoodle(width: 96, height: 60, isDark: isDark),
                                          },
                                          {
                                            'tag': 'Jadwal Kelas',
                                            'tagColor': tagBgColor,
                                            'tagTextColor': tagTxtColor,
                                            'title': activeSchedules.isEmpty ? '"Bebas Kelas"' : '"${activeSchedules.length} Kelas Terjadwal"',
                                            'subtitle': activeSchedules.isEmpty
                                                ? 'Tidak ada jadwal kelas untuk tanggal ini.'
                                                : '${activeSchedules.first['time'] ?? ''} · ${activeSchedules.first['projectName'] ?? 'Classroom'}',
                                            'doodle': _ClassScheduleDoodle(width: 96, height: 60, isDark: isDark),
                                          },
                                        ];

                                        final currentItem = activityItems[_todayActivityIndex % activityItems.length];

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: currentItem['tagColor'] as Color,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      currentItem['tag'] as String,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: currentItem['tagTextColor'] as Color,
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () {
                                                          HapticFeedback.selectionClick();
                                                          setActivityState(() {
                                                            _todayActivityIndex = (_todayActivityIndex - 1 + activityItems.length) % activityItems.length;
                                                          });
                                                        },
                                                        child: Container(
                                                          width: 44,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                          child: Center(
                                                            child: Icon(
                                                              Icons.arrow_back_rounded,
                                                              size: 18,
                                                              color: isDark ? Colors.white : Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      GestureDetector(
                                                        onTap: () {
                                                          HapticFeedback.selectionClick();
                                                          setActivityState(() {
                                                            _todayActivityIndex = (_todayActivityIndex + 1) % activityItems.length;
                                                          });
                                                        },
                                                        child: Container(
                                                          width: 44,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                          child: Center(
                                                            child: Icon(
                                                              Icons.arrow_forward_rounded,
                                                              size: 18,
                                                              color: isDark ? Colors.white : Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          currentItem['title'] as String,
                                                          style: AppTypography.pageTitle(
                                                            fontSize: 24.0,
                                                            fontWeight: FontWeight.w900,
                                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                            height: 1.2,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          currentItem['subtitle'] as String,
                                                          style: AppTypography.chatBody(
                                                            fontSize: 15.5,
                                                            fontWeight: FontWeight.w500,
                                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                            height: 1.4,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  currentItem['doodle'] as Widget,
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 1. Horizontal Slider for Tugas & Quiz Cards
                                        StatefulBuilder(
                                          builder: (context, setStateSlider) {
                                            return Column(
                                              children: [
                                                SizedBox(
                                                  height: 158,
                                                  child: PageView(
                                                    clipBehavior: Clip.none,
                                                    controller: _taskQuizPageController,
                                                    onPageChanged: (idx) {
                                                      setStateSlider(() {
                                                        _taskQuizPageIndex = idx;
                                                      });
                                                    },
                                                    children: [
                                                      buildQuizPillCard(),
                                                      buildTugasPillCard(),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: List.generate(2, (index) {
                                                    final bool isCurrent = index == _taskQuizPageIndex;
                                                    return AnimatedContainer(
                                                      duration: const Duration(milliseconds: 250),
                                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                                      height: 4,
                                                      width: isCurrent ? 18 : 6,
                                                      decoration: BoxDecoration(
                                                        color: isCurrent
                                                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                                            : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        // 1. Calendar Slider (Di atas)
                                        _buildCalendarSlider(allUserTasks, role),
                                        const SizedBox(height: 20),
                                        // 2. Frameless Today Activity (Di bawah kalender: Jadwal Kelas, Tugas, Kuis)
                                        todayCardsSlider,
                                      ],
                                    );
                                 },
                               ),
                               const SizedBox(height: 24),
                                // Frameless White Card Container (Login Page Model) wrapping Search Bar & Classroom Cards
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Search Bar + Manage Classes Button
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _ClassroomSearchBar(
                                              isDark: isDark,
                                              onSearchChanged: (query) {
                                                _searchQueryNotifier.value = query;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ValueListenableBuilder<bool>(
                                            valueListenable: _isClassroomGridNotifier,
                                            builder: (context, isGrid, _) {
                                              return BouncyButton(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  _isClassroomGridNotifier.value = !isGrid;
                                                },
                                                child: Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                   child: AnimatedSwitcher(
                                                     duration: const Duration(milliseconds: 200),
                                                     transitionBuilder: (child, animation) =>
                                                         ScaleTransition(scale: animation, child: child),
                                                     child: Icon(
                                                       isGrid
                                                           ? Icons.view_agenda_rounded
                                                           : Icons.grid_view_rounded,
                                                      key: ValueKey<bool>(isGrid),
                                                       color: isDark ? Colors.white : Colors.black87,
                                                       size: 20,
                                                     ),
                                                   ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Underline Join Classroom input + Scanner Button
                                      _ClassroomJoinInputBar(
                                        isDark: isDark,
                                        onJoin: (id) => _processJoinProject(id, ''),
                                        onScan: () => _openScannerForJoin(context),
                                      ),

                                      // Invitations list if any
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('projectInvitations')
                                            .where(
                                              'invitedUid',
                                              isEqualTo:
                                                  FirebaseAuth.instance.currentUser?.uid,
                                            )
                                            .where('status', isEqualTo: 'pending')
                                            .snapshots(),
                                        builder: (context, invSnap) {
                                          if (!invSnap.hasData ||
                                              invSnap.data!.docs.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 12),
                                              Text(
                                                'Undangan Kelas',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ListView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: invSnap.data!.docs.length,
                                                itemBuilder: (ctx, idx) {
                                                  final invDoc = invSnap.data!.docs[idx];
                                                  final invData =
                                                      invDoc.data() as Map<String, dynamic>;
                                                  final invId = invDoc.id;
                                                  final projName =
                                                      invData['projectName'] ?? 'Kelas';
                                                  final projId =
                                                      invData['projectId'] ?? '';
                                                  final invIconPath =
                                                      invData['iconPath'] ??
                                                      'assets/icon_pack/project/project_1.png';

                                                  return Container(
                                                    margin: const EdgeInsets.only(bottom: 8),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Image.asset(
                                                            invIconPath,
                                                            width: 34,
                                                            height: 34,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            projName,
                                                            style: GoogleFonts.plusJakartaSans(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                              color: isDark ? Colors.white : Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 14),

                                      if (projectIds.isEmpty && role.toLowerCase() != 'guru')
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Belum ada kelas. Silakan gabung atau buat kelas baru.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 14.5,
                                              color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                          ),
                                        )
                                      else
                                        ValueListenableBuilder<String>(
                                          valueListenable: _searchQueryNotifier,
                                          builder: (context, searchQuery, _) {
                                            final bool isDark = AppColors.isDarkMode;
                                            final q = searchQuery.toLowerCase().trim();

                                             // SEARCH FOR ELEMEN CP, TUGAS, MATERI & QUIZ DENGAN TARGET NAVIGASI SPESIFIK
                                             if (q.isNotEmpty) {
                                               final List<Map<String, dynamic>> matchedItems = [];

                                               for (int pIdx = 0; pIdx < projectDocs.length; pIdx++) {
                                                 try {
                                                   final projDoc = projectDocs[pIdx];
                                                   final pData = projDoc.data() as Map<String, dynamic>? ?? {};
                                                   final projId = projDoc.id;
                                                   final projTitle = (pData['name'] ?? 'Classroom').toString();
                                                   final gradeLevel = (pData['gradeLevel'] ?? '').toString();
                                                   final major = (pData['major'] ?? '').toString();
                                                   final stages = pData['stages'] as List? ?? [];
                                                   final dynamic rawColorIdx = pData['colorIndex'];
                                                   int patternIndex = 0;
                                                   if (rawColorIdx is int) {
                                                     patternIndex = rawColorIdx;
                                                   } else if (rawColorIdx is String) {
                                                     patternIndex = int.tryParse(rawColorIdx) ?? 0;
                                                   } else {
                                                     patternIndex = pIdx;
                                                   }

                                                   final Color cardColor = isDark
                                                       ? _classroomCardDarkColors[patternIndex % _classroomCardDarkColors.length]
                                                       : _classroomCardColors[patternIndex % _classroomCardColors.length];
                                                   final Color accentColor = _classroomAccentColors[patternIndex % _classroomAccentColors.length];
                                                   final bool isOwner = (pData['ownerUid']?.toString() ?? '') == (FirebaseAuth.instance.currentUser?.uid ?? '');

                                                   for (int sIdx = 0; sIdx < stages.length; sIdx++) {
                                                     try {
                                                       final stage = stages[sIdx];
                                                       if (stage is! Map) continue;
                                                       if (stage['isArchived'] == true) continue;

                                                       final stageTitle = (stage['title'] ?? stage['name'] ?? 'Elemen ${sIdx + 1}').toString();
                                                       final stageDesc = (stage['description'] ?? stage['desc'] ?? '').toString();
                                                       final materis = stage['materis'] as List? ?? [];
                                                       final stageTasks = stage['tasks'] as List? ?? [];

                                                       // 1. Check CP / Elemen Stage Match
                                                       if (stageTitle.toLowerCase().contains(q) || stageDesc.toLowerCase().contains(q)) {
                                                         matchedItems.add({
                                                           'itemType': 'cp',
                                                           'projectId': projId,
                                                           'projectTitle': projTitle,
                                                           'gradeLevel': gradeLevel,
                                                           'major': major,
                                                           'stageIdx': sIdx,
                                                           'title': stageTitle,
                                                           'subtitle': '$projTitle · $gradeLevel $major',
                                                           'badgeText': 'Capaian Pembelajaran',
                                                           'actionLabel': role.toLowerCase() == 'guru' ? 'Buka CP' : 'Buka',
                                                           'cardColor': cardColor,
                                                           'accentColor': accentColor,
                                                           'isOwner': isOwner,
                                                         });
                                                       }

                                                       // 2. Check Materis & Nested Tasks
                                                       for (int mIdx = 0; mIdx < materis.length; mIdx++) {
                                                         final m = materis[mIdx];
                                                         if (m is! Map) continue;
                                                         if (m['isArchived'] == true) continue;
                                                         final mTitle = (m['title'] ?? 'Materi').toString();
                                                         final mDoc = (m['doc'] ?? '').toString();
                                                         final mMaterisTasks = m['tasks'] as List? ?? [];

                                                         if (mTitle.toLowerCase().contains(q)) {
                                                           matchedItems.add({
                                                             'itemType': 'materi',
                                                             'projectId': projId,
                                                             'projectTitle': projTitle,
                                                             'gradeLevel': gradeLevel,
                                                             'major': major,
                                                             'stageIdx': sIdx,
                                                             'materiIdx': mIdx,
                                                             'title': mTitle,
                                                             'subtitle': '$projTitle · $stageTitle',
                                                             'badgeText': 'Materi Pembelajaran',
                                                             'actionLabel': 'Lihat Materi',
                                                             'cardColor': cardColor,
                                                             'accentColor': accentColor,
                                                             'isOwner': isOwner,
                                                             'docName': mDoc,
                                                             'taskKey': '${sIdx}_${mIdx}_0',
                                                           });
                                                         }

                                                         for (int tIdx = 0; tIdx < mMaterisTasks.length; tIdx++) {
                                                           final t = mMaterisTasks[tIdx];
                                                           if (t is! Map) continue;
                                                           final tTitle = (t['title'] ?? t['name'] ?? 'Tugas').toString();
                                                           final tType = (t['type'] ?? 'tugas').toString().toLowerCase();

                                                           if (tTitle.toLowerCase().contains(q)) {
                                                             if (tType == 'quiz') {
                                                               matchedItems.add({
                                                                 'itemType': 'quiz',
                                                                 'projectId': projId,
                                                                 'projectTitle': projTitle,
                                                                 'gradeLevel': gradeLevel,
                                                                 'major': major,
                                                                 'stageIdx': sIdx,
                                                                 'materiIdx': mIdx,
                                                                 'taskIdx': tIdx,
                                                                 'title': tTitle,
                                                                 'subtitle': '$projTitle · $stageTitle · Quiz',
                                                                 'badgeText': 'Kuis / Evaluasi',
                                                                 'actionLabel': 'Kerjakan Quiz',
                                                                 'cardColor': cardColor,
                                                                 'accentColor': accentColor,
                                                                 'isOwner': isOwner,
                                                                 'taskData': t,
                                                                 'taskKey': '${sIdx}_${mIdx}_$tIdx',
                                                               });
                                                             } else if (tType == 'pdf' || tType == 'materi') {
                                                               matchedItems.add({
                                                                 'itemType': 'materi',
                                                                 'projectId': projId,
                                                                 'projectTitle': projTitle,
                                                                 'gradeLevel': gradeLevel,
                                                                 'major': major,
                                                                 'stageIdx': sIdx,
                                                                 'materiIdx': mIdx,
                                                                 'taskIdx': tIdx,
                                                                 'title': tTitle,
                                                                 'subtitle': '$projTitle · $stageTitle · Materi',
                                                                 'badgeText': 'Materi / Dokumen',
                                                                 'actionLabel': 'Lihat Materi',
                                                                 'cardColor': cardColor,
                                                                 'accentColor': accentColor,
                                                                 'isOwner': isOwner,
                                                                 'docName': (t['doc'] ?? mDoc).toString(),
                                                                 'taskData': t,
                                                                 'taskKey': '${sIdx}_${mIdx}_$tIdx',
                                                               });
                                                             } else {
                                                               matchedItems.add({
                                                                 'itemType': 'tugas',
                                                                 'projectId': projId,
                                                                 'projectTitle': projTitle,
                                                                 'gradeLevel': gradeLevel,
                                                                 'major': major,
                                                                 'stageIdx': sIdx,
                                                                 'materiIdx': mIdx,
                                                                 'taskIdx': tIdx,
                                                                 'title': tTitle,
                                                                 'subtitle': '$projTitle · $stageTitle · Tugas',
                                                                 'badgeText': 'Tugas Kelas',
                                                                 'actionLabel': 'Kerjakan Tugas',
                                                                 'cardColor': cardColor,
                                                                 'accentColor': accentColor,
                                                                 'isOwner': isOwner,
                                                                 'taskData': t,
                                                                 'taskKey': '${sIdx}_${mIdx}_$tIdx',
                                                               });
                                                             }
                                                           }
                                                         }
                                                       }

                                                       // 3. Check Direct Stage Tasks
                                                       for (int tIdx = 0; tIdx < stageTasks.length; tIdx++) {
                                                         final t = stageTasks[tIdx];
                                                         if (t is! Map) continue;
                                                         final tTitle = (t['title'] ?? t['name'] ?? 'Tugas').toString();
                                                         final tType = (t['type'] ?? 'tugas').toString().toLowerCase();

                                                         if (tTitle.toLowerCase().contains(q)) {
                                                           if (tType == 'quiz') {
                                                             matchedItems.add({
                                                               'itemType': 'quiz',
                                                               'projectId': projId,
                                                               'projectTitle': projTitle,
                                                               'gradeLevel': gradeLevel,
                                                               'major': major,
                                                               'stageIdx': sIdx,
                                                               'title': tTitle,
                                                               'subtitle': '$projTitle · $stageTitle · Quiz',
                                                               'badgeText': 'Kuis / Evaluasi',
                                                               'actionLabel': 'Kerjakan Quiz',
                                                               'cardColor': cardColor,
                                                               'accentColor': accentColor,
                                                               'isOwner': isOwner,
                                                               'taskData': t,
                                                               'taskKey': '${sIdx}_0_$tIdx',
                                                             });
                                                           } else if (tType == 'pdf' || tType == 'materi') {
                                                             matchedItems.add({
                                                               'itemType': 'materi',
                                                               'projectId': projId,
                                                               'projectTitle': projTitle,
                                                               'gradeLevel': gradeLevel,
                                                               'major': major,
                                                               'stageIdx': sIdx,
                                                               'title': tTitle,
                                                               'subtitle': '$projTitle · $stageTitle · Materi',
                                                               'badgeText': 'Materi / Dokumen',
                                                               'actionLabel': 'Lihat Materi',
                                                               'cardColor': cardColor,
                                                               'accentColor': accentColor,
                                                               'isOwner': isOwner,
                                                               'docName': (t['doc'] ?? '').toString(),
                                                               'taskData': t,
                                                               'taskKey': '${sIdx}_0_$tIdx',
                                                             });
                                                           } else {
                                                             matchedItems.add({
                                                               'itemType': 'tugas',
                                                               'projectId': projId,
                                                               'projectTitle': projTitle,
                                                               'gradeLevel': gradeLevel,
                                                               'major': major,
                                                               'stageIdx': sIdx,
                                                               'title': tTitle,
                                                               'subtitle': '$projTitle · $stageTitle · Tugas',
                                                               'badgeText': 'Tugas Kelas',
                                                               'actionLabel': 'Kerjakan Tugas',
                                                               'cardColor': cardColor,
                                                               'accentColor': accentColor,
                                                               'isOwner': isOwner,
                                                               'taskData': t,
                                                               'taskKey': '${sIdx}_0_$tIdx',
                                                             });
                                                           }
                                                         }
                                                       }
                                                     } catch (_) {}
                                                   }
                                                 } catch (_) {}
                                               }

                                               if (matchedItems.isEmpty) {
                                                 return Container(
                                                   width: double.infinity,
                                                   padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                                                   decoration: BoxDecoration(
                                                     color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                                                     borderRadius: BorderRadius.circular(22),
                                                     border: Border.all(
                                                       color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                                     ),
                                                   ),
                                                   child: Column(
                                                     mainAxisAlignment: MainAxisAlignment.center,
                                                     children: [
                                                       Icon(
                                                         Icons.search_off_rounded,
                                                         size: 44,
                                                         color: isDark ? Colors.white38 : Colors.black26,
                                                       ),
                                                       const SizedBox(height: 12),
                                                       Text(
                                                         'Hasil Tidak Ditemukan',
                                                         style: GoogleFonts.plusJakartaSans(
                                                           fontSize: 15.5,
                                                           fontWeight: FontWeight.bold,
                                                           color: isDark ? Colors.white : Colors.black87,
                                                         ),
                                                       ),
                                                       const SizedBox(height: 6),
                                                       Text(
                                                         'Tidak ada kelas, materi, tugas, atau kuis yang cocok dengan "$searchQuery"',
                                                         textAlign: TextAlign.center,
                                                         style: GoogleFonts.dmSans(
                                                           fontSize: 14.0,
                                                           color: isDark ? Colors.white54 : Colors.black45,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 );
                                               }

                                               return Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 children: [
                                                   Padding(
                                                     padding: const EdgeInsets.only(left: 4, bottom: 10),
                                                     child: Text(
                                                       'Daftar Ditemukan (${matchedItems.length})',
                                                       style: GoogleFonts.plusJakartaSans(
                                                         fontSize: 14.0,
                                                         fontWeight: FontWeight.w700,
                                                         color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                       ),
                                                     ),
                                                   ),
                                                   ListView.separated(
                                                     shrinkWrap: true,
                                                     physics: const NeverScrollableScrollPhysics(),
                                                     itemCount: matchedItems.length,
                                                     separatorBuilder: (_, __) => Divider(
                                                       height: 20,
                                                       thickness: 1,
                                                       color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                     ),
                                                     itemBuilder: (context, index) {
                                                       final item = matchedItems[index];
                                                       final String itemType = item['itemType']?.toString() ?? 'cp';
                                                       final String itemTitle = item['title']?.toString() ?? 'Item';
                                                       final String subtitle = item['subtitle']?.toString() ?? '';
                                                       final String badgeText = item['badgeText']?.toString() ?? '';
                                                       final String actionLabel = item['actionLabel']?.toString() ?? 'Buka';
                                                       final String projId = item['projectId']?.toString() ?? '';
                                                       final String projTitle = item['projectTitle']?.toString() ?? 'Classroom';
                                                       final Color cardColor = item['cardColor'] as Color? ?? Colors.white;
                                                       final Color accentColor = item['accentColor'] as Color? ?? const Color(0xFF7F52FC);

                                                       void performAction() {
                                                         final bool isGuru = role.toLowerCase() == 'guru';
                                                         if (isGuru) {
                                                           if (MediaQuery.of(context).size.width > 800) {
                                                             Navigator.of(context).push(
                                                               MaterialPageRoute(
                                                                 builder: (_) => DesktopClassroomPage(
                                                                   projectId: projId,
                                                                   projectTitle: projTitle,
                                                                 ),
                                                               ),
                                                             );
                                                           } else {
                                                             Navigator.of(context).push(
                                                               MaterialPageRoute(
                                                                 builder: (_) => DetailCpPage(
                                                                   projectId: projId,
                                                                   projectTitle: projTitle,
                                                                   stageIdx: item['stageIdx'] ?? 0,
                                                                   isOwner: item['isOwner'] ?? false,
                                                                   accentColor: accentColor,
                                                                   cardColor: cardColor,
                                                                 ),
                                                               ),
                                                             );
                                                           }
                                                           return;
                                                         }

                                                         // Navigation for Student:
                                                         final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                                         final taskData = item['taskData'] as Map? ?? {};
                                                         final String taskKey = item['taskKey']?.toString() ?? '0_0_0';

                                                         if (itemType == 'cp') {
                                                           if (widget.onNavigateTab != null) {
                                                             widget.onNavigateTab!(3, projectId: projId);
                                                           } else {
                                                             Navigator.of(context).push(
                                                               MaterialPageRoute(
                                                                 builder: (_) => MonitoringPage(initialProjectId: projId),
                                                               ),
                                                             );
                                                           }
                                                         } else if (itemType == 'tugas') {
                                                           Navigator.of(context).push(
                                                             MaterialPageRoute(
                                                               builder: (_) => MengerjakanTugasPage(
                                                                 title: itemTitle,
                                                                 projectId: projId,
                                                                 studentUid: currentUid,
                                                                 taskKey: taskKey,
                                                                 onCompleted: () {},
                                                                 assignmentType: taskData['assignmentType']?.toString() ?? 'individu',
                                                                 studentsMasterList: const [],
                                                                 taskText: taskData['tugasText']?.toString() ?? '',
                                                                 docName: taskData['doc']?.toString() ?? '',
                                                               ),
                                                             ),
                                                           );
                                                         } else if (itemType == 'quiz') {
                                                           Navigator.of(context).push(
                                                             MaterialPageRoute(
                                                               builder: (_) => MengerjakanQuizPage(
                                                                 title: itemTitle,
                                                                 durationStr: taskData['quizDuration']?.toString() ?? '15',
                                                                 startTime: taskData['quizStartTime']?.toString() ?? '',
                                                                 projectId: projId,
                                                                 studentUid: currentUid,
                                                                 taskKey: taskKey,
                                                                 onCompleted: () {},
                                                               ),
                                                             ),
                                                           );
                                                         } else if (itemType == 'materi') {
                                                           Navigator.of(context).push(
                                                             MaterialPageRoute(
                                                               builder: (_) => BacaMateriPage(
                                                                 title: itemTitle,
                                                                 docName: item['docName']?.toString() ?? '',
                                                                 onCompleted: () {},
                                                               ),
                                                             ),
                                                           );
                                                         }
                                                       }

                                                       IconData getBadgeIcon() {
                                                         switch (itemType) {
                                                           case 'quiz':
                                                             return Icons.quiz_rounded;
                                                           case 'materi':
                                                             return Icons.menu_book_rounded;
                                                           case 'tugas':
                                                             return Icons.assignment_rounded;
                                                           default:
                                                             return Icons.layers_rounded;
                                                         }
                                                       }

                                                       Color getBadgeColor() {
                                                         switch (itemType) {
                                                           case 'quiz':
                                                             return isDark ? const Color(0xFF3F1D2E) : const Color(0xFFFCE7F3);
                                                           case 'materi':
                                                             return isDark ? const Color(0xFF1D2E3F) : const Color(0xFFE0F2FE);
                                                           case 'tugas':
                                                             return isDark ? const Color(0xFF1D3F2B) : const Color(0xFFDCFCE7);
                                                           default:
                                                             return isDark ? const Color(0xFF372744) : const Color(0xFFF3E8FF);
                                                         }
                                                       }

                                                       Color getBadgeTextColor() {
                                                         switch (itemType) {
                                                           case 'quiz':
                                                             return isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
                                                           case 'materi':
                                                             return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
                                                           case 'tugas':
                                                             return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
                                                           default:
                                                             return isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA);
                                                         }
                                                       }

                                                       return InkWell(
                                                         borderRadius: BorderRadius.circular(12),
                                                         onTap: performAction,
                                                         child: Padding(
                                                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                           child: Row(
                                                             children: [
                                                               Expanded(
                                                                 child: Column(
                                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                                   children: [
                                                                     Row(
                                                                       children: [
                                                                         Container(
                                                                           padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                                           decoration: BoxDecoration(
                                                                             color: getBadgeColor(),
                                                                             borderRadius: BorderRadius.circular(6),
                                                                           ),
                                                                           child: Row(
                                                                             mainAxisSize: MainAxisSize.min,
                                                                             children: [
                                                                               Icon(
                                                                                 getBadgeIcon(),
                                                                                 size: 11,
                                                                                 color: getBadgeTextColor(),
                                                                               ),
                                                                               const SizedBox(width: 4),
                                                                               Text(
                                                                                 badgeText,
                                                                                 style: GoogleFonts.dmSans(
                                                                                   fontSize: 11.5,
                                                                                   fontWeight: FontWeight.bold,
                                                                                   color: getBadgeTextColor(),
                                                                                 ),
                                                                               ),
                                                                             ],
                                                                           ),
                                                                         ),
                                                                       ],
                                                                     ),
                                                                     const SizedBox(height: 4),
                                                                     Text(
                                                                       itemTitle,
                                                                       style: GoogleFonts.plusJakartaSans(
                                                                         fontSize: 16.0,
                                                                         fontWeight: FontWeight.w800,
                                                                         color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                                       ),
                                                                       maxLines: 1,
                                                                       overflow: TextOverflow.ellipsis,
                                                                     ),
                                                                     const SizedBox(height: 2),
                                                                     Text(
                                                                       subtitle,
                                                                       style: GoogleFonts.dmSans(
                                                                         fontSize: 13.0,
                                                                         fontWeight: FontWeight.w500,
                                                                         color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                                       ),
                                                                       maxLines: 1,
                                                                       overflow: TextOverflow.ellipsis,
                                                                     ),
                                                                   ],
                                                                 ),
                                                               ),
                                                               const SizedBox(width: 10),
                                                               BouncyButton(
                                                                 scaleDown: 0.90,
                                                                 onTap: performAction,
                                                                 child: Container(
                                                                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                                                   decoration: BoxDecoration(
                                                                     color: isDark ? Colors.white : Colors.black,
                                                                     borderRadius: BorderRadius.circular(24),
                                                                   ),
                                                                   child: Row(
                                                                     mainAxisSize: MainAxisSize.min,
                                                                     children: [
                                                                       Text(
                                                                         actionLabel,
                                                                         style: GoogleFonts.plusJakartaSans(
                                                                           fontSize: 13.0,
                                                                           fontWeight: FontWeight.bold,
                                                                           color: isDark ? Colors.black : Colors.white,
                                                                         ),
                                                                       ),
                                                                       const SizedBox(width: 4),
                                                                       Icon(
                                                                         Icons.arrow_forward_ios_rounded,
                                                                         size: 10,
                                                                         color: isDark ? Colors.black : Colors.white,
                                                                       ),
                                                                     ],
                                                                   ),
                                                                 ),
                                                               ),
                                                             ],
                                                           ),
                                                         ),
                                                       );
                                                     },
                                                   ),
                                                 ],
                                               );
                                             }
                                            final activeProjectDocs = projectDocs.where((doc) {
                                              final pData = doc.data() as Map<String, dynamic>? ?? {};
                                              final pId = (pData['projectId'] ?? doc.id).toString();
                                              return !_deletedProjectIds.contains(doc.id) && !_deletedProjectIds.contains(pId);
                                            }).toList();

                                            return ValueListenableBuilder<bool>(
                                              valueListenable: _isClassroomGridNotifier,
                                              builder: (context, isGrid, _) {
                                                final List<Widget> projectCards = List.generate(
                                                  activeProjectDocs.length,
                                                  (index) {
                                                    final projectData = activeProjectDocs[index].data()
                                                        as Map<String, dynamic>;
                                                    final projId = (projectData['projectId'] != null && projectData['projectId'].toString().isNotEmpty)
                                                        ? projectData['projectId'].toString()
                                                        : activeProjectDocs[index].id;
                                                    final projTitle =
                                                        projectData['name'] ?? 'Project';
                                                    final stages =
                                                        projectData['stages'] as List? ?? [];

                                                    final dynamic rawColorIdx = projectData['colorIndex'];
                                                    int patternIndex = 0;
                                                    if (rawColorIdx is int) {
                                                      patternIndex = rawColorIdx;
                                                    } else if (rawColorIdx is String) {
                                                      patternIndex = int.tryParse(rawColorIdx) ?? 0;
                                                    } else if (rawColorIdx is num) {
                                                      patternIndex = rawColorIdx.toInt();
                                                    } else {
                                                      patternIndex = index;
                                                    }
                                                    final cardColor = isDark
                                                        ? _classroomCardDarkColors[patternIndex %
                                                            _classroomCardDarkColors.length]
                                                        : _classroomCardColors[patternIndex %
                                                            _classroomCardColors.length];
                                                    final accentColor =
                                                        _classroomAccentColors[patternIndex %
                                                            _classroomAccentColors.length];

                                                    final iconFileName =
                                                        projectData['icon'] as String? ??
                                                        'project_1.png';
                                                    final iconPath =
                                                        'assets/icon_pack/project/$iconFileName';

                                                    if (role.toLowerCase() == 'guru') {
                                                      return _buildTeacherProjectCard(
                                                        context: context,
                                                        projectId: projId,
                                                        title: projTitle,
                                                        backgroundColor: cardColor,
                                                        accentColor: accentColor,
                                                        patternIndex: patternIndex,
                                                        iconPath: iconPath,
                                                        stages: stages,
                                                        schedules: List.from(
                                                          projectData['schedules'] ?? [],
                                                        ),
                                                        gradeLevel: projectData['gradeLevel'] ?? '-',
                                                        major: projectData['major'] ?? '',
                                                        ownerUid: projectData['ownerUid'] ?? '',
                                                        studentsMasterList: projectData['studentsMasterList'] as List? ?? [],
                                                        membersList: projectData['members'] as List? ?? [],
                                                        isCompact2Column: isGrid,
                                                      );
                                                    }

                                                    final currentUid =
                                                        FirebaseAuth.instance.currentUser?.uid ??
                                                        '';
                                                    return StreamBuilder<DocumentSnapshot>(
                                                      stream: FirebaseFirestore.instance
                                                          .collection('projects')
                                                          .doc(projId)
                                                          .collection('userProgress')
                                                          .doc(currentUid)
                                                          .snapshots(),
                                                      builder: (context, snapshot) {
                                                        int completedTugas = 0;
                                                        int totalTugas = 0;
                                                        int completedPdf = 0;
                                                        int totalPdf = 0;
                                                        int completedQuiz = 0;
                                                        int totalQuiz = 0;
                                                        final List<int> quizScores = [];

                                                        if (snapshot.hasData &&
                                                            snapshot.data!.exists) {
                                                          final progressData =
                                                              snapshot.data!.data()
                                                                  as Map<String, dynamic>;
                                                          final completedTasks =
                                                              (progressData['completedTasks']
                                                                      as List?) ??
                                                              [];

                                                          for (var stage in stages) {
                                                            final materis =
                                                                stage['materis'] as List? ?? [];
                                                            for (var m in materis) {
                                                              final tasks =
                                                                  m['tasks'] as List? ?? [];
                                                              for (var t in tasks) {
                                                                final taskId =
                                                                    t['id'] as String? ?? '';
                                                                final type =
                                                                    t['type'] as String? ??
                                                                    'tugas';
                                                                final isCompleted =
                                                                    completedTasks.contains(taskId);

                                                                if (type == 'tugas') {
                                                                  totalTugas++;
                                                                  if (isCompleted) completedTugas++;
                                                                } else if (type == 'pdf') {
                                                                  totalPdf++;
                                                                  if (isCompleted) completedPdf++;
                                                                } else if (type == 'quiz') {
                                                                  totalQuiz++;
                                                                  if (isCompleted) {
                                                                    completedQuiz++;
                                                                    final scoreVal =
                                                                        progressData['quizScore_'];
                                                                    if (scoreVal != null) {
                                                                      final int score =
                                                                          (scoreVal as num).toInt();
                                                                      quizScores.add(score);
                                                                    }
                                                                  }
                                                                }
                                                              }
                                                            }
                                                          }
                                                        }

                                                        final int totalAll =
                                                            totalTugas + totalPdf + totalQuiz;
                                                        final int completedAll =
                                                            completedTugas +
                                                            completedPdf +
                                                            completedQuiz;
                                                        final double progressValue = totalAll > 0
                                                            ? completedAll / totalAll
                                                            : 0.0;
                                                        final String progressText = '$completedAll/$totalAll';

                                                        return _buildProjectCard(
                                                          context: context,
                                                          projectId: projId,
                                                          title: projTitle,
                                                          backgroundColor: cardColor,
                                                          accentColor: accentColor,
                                                          patternIndex: patternIndex,
                                                          iconPath: iconPath,
                                                          progressColor: accentColor,
                                                          progressValue: progressValue,
                                                          progressText: progressText,
                                                          completedTugas: completedTugas,
                                                          totalTugas: totalTugas,
                                                          completedPdf: completedPdf,
                                                          totalPdf: totalPdf,
                                                          completedQuiz: completedQuiz,
                                                          totalQuiz: totalQuiz,
                                                          gradeLevel: projectData['gradeLevel'] ?? '-',
                                                          major: projectData['major'] ?? '',
                                                          ownerUid: projectData['ownerUid'] ?? '',
                                                          schedules: List.from(projectData['schedules'] ?? []),
                                                          isCompact2Column: isGrid,
                                                        );
                                                      },
                                                    );
                                                  },
                                                );

                                                if (role.toLowerCase() == 'guru') {
                                                  projectCards.add(const AddClassroomPlaceholderCard());
                                                }

                                                if (MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.shortestSide >= 700) {
                                                  final double screenW = MediaQuery.of(context).size.width;
                                                  final int cols = screenW > 1350
                                                      ? 4
                                                      : (screenW > 980 ? 3 : 2);
                                                  final double ratio = screenW > 1350
                                                      ? 1.44
                                                      : (screenW > 980 ? 1.40 : 1.44);

                                                  return GridView.builder(
                                                    shrinkWrap: true,
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount: projectCards.length,
                                                    gridDelegate:
                                                        SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: cols,
                                                          crossAxisSpacing: 10,
                                                          mainAxisSpacing: 10,
                                                          childAspectRatio: ratio,
                                                        ),
                                                    itemBuilder: (context, index) =>
                                                        projectCards[index],
                                                  );
                                                } else {
                                                  if (isGrid) {
                                                    final leftCards = <Widget>[];
                                                    final rightCards = <Widget>[];
                                                    for (int i = 0; i < projectCards.length; i++) {
                                                      if (i.isEven) {
                                                        leftCards.add(projectCards[i]);
                                                      } else {
                                                        rightCards.add(projectCards[i]);
                                                      }
                                                    }
                                                    return Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                              for (int i = 0; i < leftCards.length; i++) ...[
                                                                if (i > 0) const SizedBox(height: 8),
                                                                leftCards[i],
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                              for (int i = 0; i < rightCards.length; i++) ...[
                                                                if (i > 0) const SizedBox(height: 8),
                                                                rightCards[i],
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    return ListView.separated(
                                                      shrinkWrap: true,
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemCount: projectCards.length,
                                                      separatorBuilder: (_, i) =>
                                                          const SizedBox(height: 8),
                                                      itemBuilder: (context, index) =>
                                                          projectCards[index],
                                                    );
                                                  }
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

            // 2. Sticky Glassmorphic Header Bar (Transparan Glassmorphic Blur 20px - Muncul saat di-scroll)
            if (!isDesktop)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _headerScrollOffsetNotifier,
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
                            child: Row(
                              children: [
                                // Profile Avatar
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  ),
                                  child: ClipOval(
                                    child: Transform.scale(
                                      scale: 1.45,
                                      child: userPhoto.isNotEmpty
                                          ? (userPhoto.startsWith('http')
                                              ? Image.network(
                                                  userPhoto,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(
                                                    child: Text(
                                                      userName.isNotEmpty
                                                          ? userName.substring(0, (userName.length >= 2 ? 2 : 1)).toUpperCase()
                                                          : 'P',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.white : Colors.black,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Image.asset(
                                                  userPhoto,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(
                                                    child: Text(
                                                      userName.isNotEmpty
                                                          ? userName.substring(0, (userName.length >= 2 ? 2 : 1)).toUpperCase()
                                                          : 'P',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w800,
                                                        color: isDark ? Colors.white : Colors.black,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ))
                                          : Center(
                                              child: Text(
                                                userName.isNotEmpty
                                                    ? userName.substring(0, (userName.length >= 2 ? 2 : 1)).toUpperCase()
                                                    : 'P',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Name & Role
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Hai, $capitalizedName',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                          height: 1.15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        roleSubtitle,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: genderRoleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Dark / Light Mode Toggle
                                ValueListenableBuilder<String>(
                                  valueListenable: HubnerApp.themeNotifier,
                                  builder: (context, currentTheme, _) {
                                    final bool isDarkTheme = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                    return BouncyButton(
                                      onTap: () => _toggleThemeWithBounce(context, isDarkTheme),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                        child: Icon(
                                          isDarkTheme ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                          color: isDarkTheme ? const Color(0xFFFBBF24) : Colors.black87,
                                          size: 22,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),

                                // Notification Bell
                                ValueListenableBuilder<String>(
                                  valueListenable: HubnerApp.themeNotifier,
                                  builder: (context, currentTheme, _) {
                                    final bool isDarkTheme = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                    return NotificationBellIcon(
                                      isDark: isDarkTheme,
                                      size: 34,
                                      showFrame: false,
                                    );
                                  },
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
        );
      },
    );
  },
),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildTeacherProjectCard({
    required BuildContext context,
    required String projectId,
    required String title,
    required Color backgroundColor,
    required Color accentColor,
    required int patternIndex,
    required String iconPath,
    required List stages,
    required List schedules,
    required String gradeLevel,
    required String major,
    required String ownerUid,
    List studentsMasterList = const [],
    List membersList = const [],
    bool isCompact2Column = false,
  }) {
    final latestMaterial = _getLatestMaterialTitle(stages);
    final scheduleText = _getScheduleSummary(schedules);
    final bool isDark = AppColors.isDarkMode;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
      builder: (context, userSnap) {
        String teacherName = 'Pak Dimas Supriadi, M.Pd';
        if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
          final uData = userSnap.data!.data() as Map<String, dynamic>;
          final rawName = uData['name'] as String? ?? 'Dimas Supriadi, M.Pd';
          final gender = uData['gender'] as String? ?? uData['jenisKelamin'] as String?;
          teacherName = _formatTeacherTitle(rawName, gender);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('members')
              .snapshots(),
          builder: (context, membersSnap) {
            int totalStudents = 0;
            if (studentsMasterList.isNotEmpty) {
              totalStudents = studentsMasterList.where((s) {
                if (s is Map) {
                  return s['joined'] == true && (s['uid'] ?? '').toString().isNotEmpty;
                }
                return false;
              }).length;
            }
            if (totalStudents == 0 && membersSnap.hasData && membersSnap.data!.docs.isNotEmpty) {
              totalStudents = membersSnap.data!.docs.length;
            } else if (totalStudents == 0 && membersList.isNotEmpty) {
              totalStudents = membersList.length;
            }

            bool isStatsFlipped = false;
            bool isBarcodeFlipped = false;

            return Dismissible(
              key: ValueKey('project_$projectId'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                AppSoundService.playDeleteWhoosh();
                return await _confirmDeleteProject(context, projectId, title);
              },
              onUpdate: (details) {
                if (details.reached && !details.previousReached) {
                  AppSoundService.playDeleteWhoosh();
                }
              },
              onDismissed: (direction) {
                if (mounted) {
                  setState(() {
                    _deletedProjectIds.add(projectId);
                  });
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
                    const SizedBox(width: 6),
                    Text(
                      'Hapus',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              child: StatefulBuilder(
                builder: (cardContext, cardSetState) {
                  return BouncyButton(
                    scaleDown: 0.985,
                    enableSquash: false,
                    duration: const Duration(milliseconds: 70),
                    onTap: () {
                      if (MediaQuery.of(cardContext).size.width > 800) {
                        Navigator.of(cardContext).push(
                          MaterialPageRoute(
                            builder: (_) => DesktopClassroomPage(
                              projectId: projectId,
                              projectTitle: title,
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(cardContext).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                                    ClassPage(projectId: projectId, projectTitle: title),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: isCompact2Column
                          ? null
                          : ((MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700) ? 168 : 195),
                      constraints: isCompact2Column
                          ? const BoxConstraints(minHeight: 100)
                          : null,
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(22),
                        border: isDark
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.0,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (!isStatsFlipped && !isBarcodeFlipped)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: ClassroomCardPatternPainter(
                                  patternIndex: patternIndex,
                                  accentColor: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                          Padding(
                            padding: isCompact2Column
                                ? const EdgeInsets.all(10)
                                : ((MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700)
                                    ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
                                    : const EdgeInsets.all(16)),
                            child: _buildTeacherGeneralView(
                                context: cardContext,
                                projectId: projectId,
                                title: title,
                                iconPath: iconPath,
                                gradeLevel: gradeLevel,
                                major: major,
                                teacherName: teacherName,
                                totalStudents: totalStudents,
                                accentColor: accentColor,
                                backgroundColor: backgroundColor,
                                schedules: schedules,
                                ownerUid: ownerUid,
                                isCompact2Column: isCompact2Column,
                                onShowStats: () {
                                  _showAnalyticsDialog(cardContext, projectId, title, stages, membersSnap);
                                },
                                onShowBarcode: () {
                                  if (MediaQuery.of(cardContext).size.width > 900) {
                                    cardSetState(() {
                                      isBarcodeFlipped = true;
                                    });
                                  } else {
                                    _showClassBarcodeDialog(cardContext, projectId, title, accentColor);
                                  }
                                },
                              ),
                            ),
                        if (!isStatsFlipped && !isBarcodeFlipped && !(MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700))
                          Positioned(
                            right: 18,
                            bottom: 18,
                            child: BouncyButton(
                              scaleDown: 0.90,
                              onTap: () {
                                _showAnalyticsDialog(cardContext, projectId, title, stages, membersSnap);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Statistik',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 12,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isManagingClassesNotifier,
                          builder: (context, isManaging, _) {
                            return Positioned.fill(
                              child: IgnorePointer(
                                ignoring: !isManaging,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isManaging ? 1.0 : 0.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.78)
                                          : Colors.white.withValues(alpha: 0.82),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ManagementActionButton(
                                            icon: Icons.edit_rounded,
                                            baseColor: const Color(0xFF4F46E5),
                                            onTap: () {
                                              Navigator.push(
                                                cardContext,
                                                PageRouteBuilder(
                                                  opaque: false,
                                                  barrierColor: Colors.transparent,
                                                  pageBuilder: (context, _, __) => EditClassPage(
                                                    projectId: projectId,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 14),
                                          ManagementActionButton(
                                            icon: Icons.upload_file_rounded,
                                            baseColor: const Color(0xFF10B981),
                                            onTap: () async {
                                              final snap = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
                                              if (snap.exists && cardContext.mounted) {
                                                ClassroomExportService.exportClassroom(
                                                  context: cardContext,
                                                  projectData: snap.data() ?? {},
                                                );
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 14),
                                          ManagementActionButton(
                                            icon: Icons.delete_outline_rounded,
                                            baseColor: const Color(0xFFEF4444),
                                            onTap: () => _confirmDeleteProject(cardContext, projectId, title),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

  IconData _getPremiumIconForSubject(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('komputer') || lowerTitle.contains('jaringan') || lowerTitle.contains('teknologi')) {
      return Icons.dns_rounded;
    } else if (lowerTitle.contains('web') || lowerTitle.contains('pemograman') || lowerTitle.contains('code')) {
      return Icons.code_rounded;
    } else if (lowerTitle.contains('desain') || lowerTitle.contains('visual') || lowerTitle.contains('dkv') || lowerTitle.contains('komunikasi') || lowerTitle.contains('gambar')) {
      return Icons.palette_rounded;
    } else if (lowerTitle.contains('fisika') || lowerTitle.contains('sains') || lowerTitle.contains('science')) {
      return Icons.science_rounded;
    }
    return Icons.school_rounded;
  }

  Widget _buildTeacherGeneralView({
    required BuildContext context,
    required String projectId,
    required String title,
    required String iconPath,
    required String gradeLevel,
    required String major,
    required String teacherName,
    required int totalStudents,
    required Color accentColor,
    required Color backgroundColor,
    required List schedules,
    required VoidCallback onShowStats,
    required VoidCallback onShowBarcode,
    String ownerUid = '',
    bool isCompact2Column = false,
  }) {
    final majorText = major.isEmpty ? 'Umum' : major;
    final bool isMobile = MediaQuery.of(context).size.width < 700 || MediaQuery.of(context).size.shortestSide < 700;
    final bool isDark = AppColors.isDarkMode;

    if (isMobile) {
      if (isCompact2Column) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedScheduleCapsule(
              schedules: schedules,
              accentColor: accentColor,
              cardColor: backgroundColor,
              isCompact: true,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (totalStudents > 0) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 12,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Total $totalStudents Siswa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    size: 13,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      majorText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      double calculatedFontSize = 19.5;
      if (title.length > 55) {
        calculatedFontSize = 16.0;
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AnimatedScheduleCapsule(
                  schedules: schedules,
                  accentColor: accentColor,
                  cardColor: backgroundColor,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0, right: 4.0),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: calculatedFontSize,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: _MembersAvatarStackReadOnly(
                    projectId: projectId,
                    ownerUid: ownerUid,
                    avatarSize: 34.0,
                    overlap: 12.0,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flash_on_rounded,
                              size: 13,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              majorText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_alt_rounded,
                                size: 13,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$totalStudents Siswa',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
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
          const SizedBox(width: 10),
          // Right Side: 2x Bigger Class Icon (68x68) + Vertically Aligned Stats Button
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 68,
                width: 68,
                child: ColorFiltered(
                  colorFilter: isDark
                      ? ColorFilter.mode(Colors.black.withValues(alpha: 0.12), BlendMode.darken)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShowStats,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final bool isYellow = _isYellowCardColor(accentColor);
    final Color textColor = isYellow ? Colors.black : Colors.white;
    final Color subtextColor = isYellow ? Colors.black87 : Colors.white70;
    final Color boxBgColor = isYellow ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12);
    final Color circleBgColor = isYellow ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.15);
    final Color circleBorderColor = isYellow ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.4);

    return Column(
      key: const ValueKey('general'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Class icon & name on left, QR Button on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: circleBorderColor,
                          width: 1,
                        ),
                        color: circleBgColor,
                      ),
                      child: Image.asset(
                        iconPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.assignment_outlined,
                          color: textColor,
                          size: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      majorText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onShowBarcode,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isYellow ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 14,
                      color: isYellow ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title (Max 3 lines, flexible font size, never truncated)
            Text(
              title,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(
                fontSize: title.length > 55 ? 14.5 : 16.4,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        // Translucent Metadata Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6, right: 88),
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 13, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pengajar: $teacherName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.groups_rounded, size: 13, color: subtextColor),
                  const SizedBox(width: 6),
                  Text(
                    'Total $totalStudents Siswa Aktif',
                    style: GoogleFonts.dmSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherStatsView({
    required BuildContext context,
    required String projectId,
    required String title,
    required List stages,
    required String latestMaterial,
    required String scheduleText,
    required AsyncSnapshot<QuerySnapshot> progressSnap,
    required VoidCallback onBack,
    Color accentColor = Colors.transparent,
  }) {
    final bool isYellow = _isYellowCardColor(accentColor);
    final Color textColor = isYellow ? Colors.black : Colors.white;
    final Color backBtnBg = isYellow ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.2);

    double progressVal = 0.0;
    int totalStudents = progressSnap.data?.docs.length ?? 0;

    int totalTasksCount = 0;
    int totalElementsCount = stages.length;

    for (var stage in stages) {
      final bool isStageArchived = stage['isArchived'] == true;
      if (isStageArchived) continue;
      final List rawMateris = stage['materis'] as List? ?? [];
      for (var m in rawMateris) {
        final bool isMateriArchived = m['isArchived'] == true;
        if (isMateriArchived) continue;
        final List tasks = m['tasks'] as List? ?? [];
        totalTasksCount += tasks.length;
      }
    }

    if (totalStudents > 0 && totalTasksCount > 0) {
      int totalCompletedTasksAllStudents = 0;
      final docs = progressSnap.data!.docs;
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final completedList = data['completedTasks'] as List? ?? [];
        int activeCompletedCount = 0;
        for (var key in completedList) {
          try {
            final parts = key.toString().split('_');
            if (parts.length == 3) {
              final sIdx = int.parse(parts[0]);
              final mIdx = int.parse(parts[1]);
              final tIdx = int.parse(parts[2]);
              if (sIdx < stages.length) {
                final stage = stages[sIdx] as Map;
                if (stage['isArchived'] != true) {
                  final List rawMateris = stage['materis'] as List? ?? [];
                  if (mIdx < rawMateris.length) {
                    final m = rawMateris[mIdx] as Map;
                    if (m['isArchived'] != true) {
                      final List tasks = m['tasks'] as List? ?? [];
                      if (tIdx < tasks.length) {
                        activeCompletedCount++;
                      }
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
        totalCompletedTasksAllStudents += activeCompletedCount;
      }
      progressVal = totalCompletedTasksAllStudents / (totalStudents * totalTasksCount);
    }

    final percentText = '${(progressVal * 100).toInt()}%';

    return Column(
      key: const ValueKey('stats'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back Header
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: backBtnBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: textColor,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Statistik Belajar Siswa',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // Progress Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress Pembelajaran Kelas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    percentText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Badges Wrap directly on colored background
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildYellowBadge(Icons.groups_rounded, '$totalStudents Siswa'),
            _buildYellowBadge(Icons.menu_book_rounded, '$totalElementsCount Elemen'),
            _buildYellowBadge(Icons.assignment_rounded, '$totalTasksCount Tugas'),
          ],
        ),
      ],
    );
  }

  Widget _buildYellowBadge(IconData icon, String text) {
    final bool isDark = AppColors.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.18),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.white : Colors.black87),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDialog(
    BuildContext context,
    String projectId,
    String title,
    List stages,
    AsyncSnapshot<QuerySnapshot> progressSnap,
  ) {
    final bool isDark = AppColors.isDarkMode;
    int totalStudents = progressSnap.data?.docs.length ?? 0;

    int totalTugasCount = 0;
    int totalPdfCount = 0;
    int totalQuizCount = 0;

    for (var stage in stages) {
      if (stage['isArchived'] == true) continue;
      final List rawMateris = stage['materis'] as List? ?? [];
      for (var m in rawMateris) {
        if (m['isArchived'] == true) continue;
        final List tasks = m['tasks'] as List? ?? [];
        for (var t in tasks) {
          final type = t['type'] as String? ?? 'tugas';
          if (type == 'tugas') {
            totalTugasCount++;
          } else if (type == 'pdf') {
            totalPdfCount++;
          } else if (type == 'quiz') {
            totalQuizCount++;
          }
        }
      }
    }

    int completedTugas = 0;
    int completedPdf = 0;
    int completedQuiz = 0;
    int totalCompletedTasksAllStudents = 0;
    List<int> quizScores = [];

    if (totalStudents > 0 && progressSnap.hasData) {
      final docs = progressSnap.data!.docs;
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final completedList = data['completedTasks'] as List? ?? [];
        for (var key in completedList) {
          try {
            final parts = key.toString().split('_');
            if (parts.length == 3) {
              final sIdx = int.parse(parts[0]);
              final mIdx = int.parse(parts[1]);
              final tIdx = int.parse(parts[2]);
              if (sIdx < stages.length) {
                final stage = stages[sIdx] as Map;
                if (stage['isArchived'] != true) {
                  final List rawMateris = stage['materis'] as List? ?? [];
                  if (mIdx < rawMateris.length) {
                    final m = rawMateris[mIdx] as Map;
                    if (m['isArchived'] != true) {
                      final List tasks = m['tasks'] as List? ?? [];
                      if (tIdx < tasks.length) {
                        final task = tasks[tIdx] as Map;
                        final type = task['type'] as String? ?? 'tugas';
                        if (type == 'tugas') {
                          completedTugas++;
                        } else if (type == 'pdf') {
                          completedPdf++;
                        } else if (type == 'quiz') {
                          completedQuiz++;
                        }
                        totalCompletedTasksAllStudents++;
                      }
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }

        data.forEach((key, val) {
          if (key.startsWith('quizScore_') && val is num) {
            quizScores.add(val.toInt());
          }
        });
      }
    }

    double tugasProgress = (totalStudents > 0 && totalTugasCount > 0) ? (completedTugas / (totalStudents * totalTugasCount)) : 0.0;
    double pdfProgress = (totalStudents > 0 && totalPdfCount > 0) ? (completedPdf / (totalStudents * totalPdfCount)) : 0.0;
    double quizProgress = (totalStudents > 0 && totalQuizCount > 0) ? (completedQuiz / (totalStudents * totalQuizCount)) : 0.0;

    double avgQuizScore = 0.0;
    if (quizScores.isNotEmpty) {
      avgQuizScore = quizScores.reduce((a, b) => a + b) / quizScores.length;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Magenta style identical to Slider Statistik
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFFA82658) : const Color(0xFFF794BE),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.insights_rounded,
                                color: isDark ? Colors.white : Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Preview Statistik',
                                  style: AppTypography.cardTitle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ringkasan Progres & Nilai Kelas',
                                  style: AppTypography.timestamp(
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : Colors.white.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body: Progress Cards
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                    // Segmented Progress Cards (Without Icons, Clean & Round)
                    _buildStatProgressCard(
                      context,
                      isDark: isDark,
                      percent: tugasProgress,
                      categoryLabel: 'Tugas',
                      headlineText: tugasProgress > 0
                          ? '${(tugasProgress * 100).toInt()}% Selesai'
                          : '0% Selesai',
                      color: const Color(0xFF2563EB), // Blue
                    ),
                    _buildStatProgressCard(
                      context,
                      isDark: isDark,
                      percent: pdfProgress,
                      categoryLabel: 'Materi',
                      headlineText: pdfProgress > 0
                          ? '${(pdfProgress * 100).toInt()}% Dibaca'
                          : '0% Dibaca',
                      color: const Color(0xFFEF4444), // Red
                    ),
                    _buildStatProgressCard(
                      context,
                      isDark: isDark,
                      percent: quizProgress,
                      categoryLabel: 'Kuis',
                      headlineText: quizProgress > 0
                          ? '${(quizProgress * 100).toInt()}% Selesai'
                          : '0% Selesai',
                      color: const Color(0xFFF59E0B), // Amber / Yellow
                    ),
                    _buildStatProgressCard(
                      context,
                      isDark: isDark,
                      percent: avgQuizScore > 0 ? (avgQuizScore / 100).clamp(0.0, 1.0) : 0.0,
                      categoryLabel: 'Rerata Nilai',
                      headlineText: avgQuizScore > 0
                          ? 'Skor: ${avgQuizScore.toInt()}'
                          : 'Belum Ada',
                      color: const Color(0xFF10B981), // Emerald Green
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
      },
    );
  }

  Widget _buildStatProgressCard(
    BuildContext context, {
    required bool isDark,
    required double percent,
    required String categoryLabel,
    required String headlineText,
    String? trailingSubtext,
    required Color color,
  }) {
    final double clampedPercent = percent.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryLabel,
                style: AppTypography.timestamp(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              if (trailingSubtext != null && trailingSubtext.isNotEmpty)
                Text(
                  trailingSubtext,
                  style: AppTypography.timestamp(
                    fontSize: 11.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            headlineText,
            style: AppTypography.chatHeaderTitle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // 1. Base Track
                  Container(
                    height: 12,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  // 2. Filled Progress with rounded ends
                  if (clampedPercent > 0)
                    Container(
                      height: 12,
                      width: (totalWidth * clampedPercent).clamp(12.0, totalWidth),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                  // 3. Segmented Milestone Dots
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (index) {
                          final double stepFraction = index / 3.0;
                          final bool isPassed = clampedPercent >= stepFraction && clampedPercent > 0;
                          return Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPassed
                                  ? Colors.white.withValues(alpha: 0.95)
                                  : (isDark ? Colors.white38 : Colors.black26),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard({
    required BuildContext context,
    required String projectId,
    required String title,
    required Color backgroundColor,
    required Color accentColor,
    required int patternIndex,
    required String iconPath,
    required Color progressColor,
    required double progressValue,
    required String progressText,
    required int completedTugas,
    required int totalTugas,
    required int completedPdf,
    required int totalPdf,
    required int completedQuiz,
    required int totalQuiz,
    required String gradeLevel,
    required String major,
    required String ownerUid,
    List schedules = const [],
    bool isCompact2Column = false,
  }) {
    final bool isDark = AppColors.isDarkMode;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
      builder: (context, userSnap) {
        String teacherName = 'Pak Dimas Supriadi, M.Pd';
        if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
          final uData = userSnap.data!.data() as Map<String, dynamic>;
          final rawName = uData['name'] as String? ?? 'Dimas Supriadi, M.Pd';
          final gender = uData['gender'] as String? ?? uData['jenisKelamin'] as String?;
          teacherName = _formatTeacherTitle(rawName, gender);
        }

        bool isStatsFlipped = false;
        bool isBarcodeFlipped = false;

        return StatefulBuilder(
          builder: (cardContext, cardSetState) {
            return BouncyButton(
              scaleDown: 0.985,
              enableSquash: false,
              duration: const Duration(milliseconds: 70),
              onTap: () {
                if (MediaQuery.of(cardContext).size.width > 800) {
                  Navigator.of(cardContext).push(
                    MaterialPageRoute(
                      builder: (_) => DesktopClassroomPage(
                        projectId: projectId,
                        projectTitle: title,
                      ),
                    ),
                  );
                } else {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(3, projectId: projectId);
                  } else {
                    Navigator.of(cardContext).push(
                      MaterialPageRoute(
                        builder: (_) => MonitoringPage(initialProjectId: projectId),
                      ),
                    );
                  }
                }
              },
              child: Container(
                height: isCompact2Column
                    ? null
                    : ((MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700) ? 168 : 195),
                constraints: isCompact2Column
                    ? const BoxConstraints(minHeight: 100)
                    : null,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(22),
                  border: isDark
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.0,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (!isStatsFlipped && !isBarcodeFlipped)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: ClassroomCardPatternPainter(
                            patternIndex: patternIndex,
                            accentColor: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    Padding(
                      padding: isCompact2Column
                          ? const EdgeInsets.all(10)
                          : ((MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700)
                              ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
                              : const EdgeInsets.all(16)),
                      child: isBarcodeFlipped
                            ? _buildInlineBarcodeView(
                                context: cardContext,
                                projectId: projectId,
                                title: title,
                                accentColor: accentColor,
                                onBack: () {
                                  cardSetState(() {
                                    isBarcodeFlipped = false;
                                  });
                                },
                              )
                            : isStatsFlipped
                                ? _buildStudentStatsView(
                                    context: cardContext,
                                    projectId: projectId,
                                    progressValue: progressValue,
                                    progressText: progressText,
                                    completedTugas: completedTugas,
                                    totalTugas: totalTugas,
                                    completedPdf: completedPdf,
                                    totalPdf: totalPdf,
                                    completedQuiz: completedQuiz,
                                    totalQuiz: totalQuiz,
                                    accentColor: accentColor,
                                    onBack: () {
                                      cardSetState(() {
                                        isStatsFlipped = false;
                                      });
                                    },
                                  )
                                : _buildStudentGeneralView(
                                    context: cardContext,
                                    projectId: projectId,
                                    title: title,
                                    iconPath: iconPath,
                                    gradeLevel: gradeLevel,
                                    major: major,
                                    teacherName: teacherName,
                                    accentColor: accentColor,
                                    backgroundColor: backgroundColor,
                                    schedules: schedules,
                                    ownerUid: ownerUid,
                                    isCompact2Column: isCompact2Column,
                                    progressValue: progressValue,
                                    onShowStats: () {
                                      cardSetState(() {
                                        isStatsFlipped = true;
                                      });
                                    },
                                    onShowBarcode: () {
                                      if (MediaQuery.of(cardContext).size.width > 900) {
                                        cardSetState(() {
                                          isBarcodeFlipped = true;
                                        });
                                      } else {
                                        _showClassBarcodeDialog(cardContext, projectId, title, accentColor);
                                      }
                                    },
                                  ),
                    ),
                    if (!isStatsFlipped && !isBarcodeFlipped && !(MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700))
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: BouncyButton(
                          scaleDown: 0.90,
                          onTap: () {
                            cardSetState(() {
                              isStatsFlipped = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Statistik',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isManagingClassesNotifier,
                      builder: (context, isManaging, _) {
                        return Positioned.fill(
                          child: IgnorePointer(
                            ignoring: !isManaging,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isManaging ? 1.0 : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.78)
                                      : Colors.white.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ManagementActionButton(
                                        icon: Icons.edit_rounded,
                                        baseColor: const Color(0xFF4F46E5),
                                        onTap: () {
                                          Navigator.push(
                                            cardContext,
                                            PageRouteBuilder(
                                              opaque: false,
                                              barrierColor: Colors.transparent,
                                              pageBuilder: (context, _, __) => EditClassPage(
                                                projectId: projectId,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      ManagementActionButton(
                                        icon: Icons.delete_outline_rounded,
                                        baseColor: const Color(0xFFEF4444),
                                        onTap: () => _confirmDeleteProject(cardContext, projectId, title),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentGeneralView({
    required BuildContext context,
    required String projectId,
    required String title,
    required String iconPath,
    required String gradeLevel,
    required String major,
    required String teacherName,
    required Color accentColor,
    required Color backgroundColor,
    required List schedules,
    required VoidCallback onShowStats,
    required VoidCallback onShowBarcode,
    String ownerUid = '',
    bool isCompact2Column = false,
    double progressValue = 0.0,
  }) {
    final majorText = major.isEmpty ? 'Umum' : major;
    final bool isMobile = MediaQuery.of(context).size.width < 700 || MediaQuery.of(context).size.shortestSide < 700;
    final bool isDark = AppColors.isDarkMode;

    if (isMobile) {
      if (isCompact2Column) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedScheduleCapsule(
              schedules: schedules,
              accentColor: accentColor,
              cardColor: backgroundColor,
              isCompact: true,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (teacherName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 12,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flash_on_rounded,
                          size: 13,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            majorText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Circular progress indicator without card, percentage in center
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progressValue.clamp(0.0, 1.0),
                        strokeWidth: 2.6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressValue >= 1.0
                              ? const Color(0xFF10B981)
                              : (progressValue >= 0.5
                                  ? const Color(0xFF3B82F6)
                                  : (progressValue > 0.0
                                      ? const Color(0xFFF59E0B)
                                      : (isDark ? Colors.white60 : Colors.black54))),
                        ),
                      ),
                      Text(
                        '${(progressValue * 100).toInt()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }

      double calculatedFontSize = 19.5;
      if (title.length > 55) {
        calculatedFontSize = 16.0;
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AnimatedScheduleCapsule(
                  schedules: schedules,
                  accentColor: accentColor,
                  cardColor: backgroundColor,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0, right: 4.0),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: calculatedFontSize,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: _MembersAvatarStackReadOnly(
                    projectId: projectId,
                    ownerUid: ownerUid,
                    avatarSize: 34.0,
                    overlap: 12.0,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flash_on_rounded,
                              size: 13,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              majorText,
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (teacherName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.65),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                teacherName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right Side: 2x Bigger Class Icon (68x68) + Vertically Aligned Stats Button
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 68,
                width: 68,
                child: ColorFiltered(
                  colorFilter: isDark
                      ? ColorFilter.mode(Colors.black.withValues(alpha: 0.12), BlendMode.darken)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShowStats,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final bool isYellow = _isYellowCardColor(accentColor);
    final Color textColor = isYellow ? Colors.black : Colors.white;
    final Color subtextColor = isYellow ? Colors.black87 : Colors.white70;
    final Color boxBgColor = isYellow ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12);
    final Color circleBgColor = isYellow ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.15);
    final Color circleBorderColor = isYellow ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.4);

    return Column(
      key: const ValueKey('general'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: circleBorderColor,
                          width: 1,
                        ),
                        color: circleBgColor,
                      ),
                      child: Image.asset(
                        iconPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.assignment_outlined,
                          color: textColor,
                          size: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      majorText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 3,
              style: AppTypography.cardTitle(
                color: textColor,
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6, right: 88),
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 13, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pengajar: $teacherName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentStatsView({
    required BuildContext context,
    required String projectId,
    required double progressValue,
    required String progressText,
    required int completedTugas,
    required int totalTugas,
    required int completedPdf,
    required int totalPdf,
    required int completedQuiz,
    required int totalQuiz,
    required VoidCallback onBack,
    Color accentColor = Colors.transparent,
  }) {
    final bool isDark = AppColors.isDarkMode;
    final bool isYellow = _isYellowCardColor(accentColor);
    final Color textColor = isYellow ? Colors.black : Colors.white;
    final Color backBtnBg = isYellow ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.2);
    final percentText = '${(progressValue * 100).toInt()}%';

    return Column(
      key: const ValueKey('stats'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back Header
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: backBtnBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Statistik Belajar Anda',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Progress Section (fully rounded slider track with sliding egg pill)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progress Belajar Mandiri',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double totalWidth = constraints.maxWidth;
                  final double pillWidth = 46.0;
                  final double maxSlide = (totalWidth - pillWidth).clamp(0.0, totalWidth);
                  final double slidePosition = maxSlide * progressValue.clamp(0.0, 1.0);
                  final Color activeColor = progressValue >= 1.0
                      ? const Color(0xFF10B981)
                      : (progressValue >= 0.5
                          ? const Color(0xFF3B82F6)
                          : (progressValue > 0.0 ? const Color(0xFFF59E0B) : (isDark ? Colors.white54 : Colors.black45)));

                  return SizedBox(
                    height: 26,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background Track (Full Rounded)
                        Container(
                          height: 8,
                          width: totalWidth,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        // Filled Progress Track (Full Rounded)
                        if (progressValue > 0)
                          Container(
                            height: 8,
                            width: (slidePosition + pillWidth / 2).clamp(8.0, totalWidth),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: progressValue >= 1.0
                                    ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                    : (progressValue >= 0.5
                                        ? [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]
                                        : [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]),
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        // Floating Egg/Pill Capsule following progress (Full Stadium Rounded)
                        Positioned(
                          left: slidePosition,
                          child: Container(
                            width: pillWidth,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                percentText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Badges Wrap directly on colored background (all fully rounded)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildYellowBadge(Icons.assignment_outlined, 'Tugas: $completedTugas/$totalTugas'),
            _buildYellowBadge(Icons.description_outlined, 'Materi: $completedPdf/$totalPdf'),
            _buildYellowBadge(Icons.help_outline_rounded, 'Quiz: $completedQuiz/$totalQuiz'),
          ],
        ),
      ],
    );
  }

  // Inline barcode view shown on card (desktop only) - 2 column layout
  Widget _buildInlineBarcodeView({
    required BuildContext context,
    required String projectId,
    required String title,
    required VoidCallback onBack,
    Color accentColor = Colors.transparent,
  }) {
    final bool isYellow = _isYellowCardColor(accentColor);
    final Color textColor = isYellow ? Colors.black : Colors.white;
    final Color subtextColor = isYellow ? Colors.black87 : Colors.white70;
    final Color backBtnBg = isYellow ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.2);
    final Color codeBoxBg = isYellow ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15);

    return Column(
      key: const ValueKey('barcode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back button row
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: backBtnBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: textColor,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Barcode Kelas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 2-column: Left=QR, Right=Code+Copy
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: QR Code directly on background (no card wrapper, BLACK color, minimal margin)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: projectId,
                version: QrVersions.auto,
                size: 80,
                gapless: false,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right: Code card + Copy button (BLACK text/icon)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KODE KELAS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: codeBoxBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      projectId,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: projectId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode kelas berhasil disalin!'),
                          backgroundColor: Color(0xFF7C3AED),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 12, color: Colors.black),
                          const SizedBox(width: 4),
                          Text(
                            'Salin Kode',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
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
            ),
          ],
        ),
      ],
    );
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

  Widget _buildMonthlyCalendar(
    List<Map<String, dynamic>> allTasks,
    String role,
  ) {
    final bool isDark = AppColors.isDarkMode;
    final int year = _currentCalendarMonth.year;
    final int month = _currentCalendarMonth.month;
    final String currentMonthYearStr = ' ';

    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final int prefixEmptyDays = firstDayOfMonth.weekday - 1;

    final List<Widget> dayWidgets = [];
    final List<String> weekdays = [
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
      'Min',
    ];

    for (int i = 0; i < prefixEmptyDays; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final DateTime dayDate = DateTime(year, month, d);
      final bool isSelected =
          _selectedCalendarDay.day == d &&
          _selectedCalendarDay.month == month &&
          _selectedCalendarDay.year == year;

      final bool isToday =
          DateTime.now().day == d &&
          DateTime.now().month == month &&
          DateTime.now().year == year;

      final bool hasTasks = _hasTaskOnDay(dayDate, allTasks);
      final Color activeBgColor = _getDayCardBg(dayDate.weekday);
      final Color dayTextColor = _getDayTextColor(dayDate.weekday);

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedCalendarDay = dayDate;
            });
            if (role.toLowerCase() != 'guru') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TodoPage(initialDate: dayDate),
                ),
              );
            }
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? activeBgColor
                  : (isToday ? const Color(0xFFF1F5F9) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: (isSelected || isToday)
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelected
                        ? dayTextColor
                        : (isToday ? Colors.black : Colors.black87),
                  ),
                ),
                if (hasTasks)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? dayTextColor
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentCalendarMonth = DateTime(year, month - 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentCalendarMonth = DateTime(year, month + 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((w) {
              return SizedBox(
                width: 32,
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: dayWidgets,
          ),
        ],
      ),
    );
  }


  String _getFullFormattedDate(DateTime date) {
    const fullDays = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final dayName = fullDays[date.weekday - 1];
    final monthName = _getMonthName(date.month);
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  Widget _buildCalendarSlider([
    List<Map<String, dynamic>> allTasks = const [],
    String role = 'siswa',
  ]) {
    final bool isDark = AppColors.isDarkMode;
    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);
    final List<DateTime> calendarDays = List.generate(14, (index) {
      return todayDate
          .subtract(const Duration(days: 3))
          .add(Duration(days: index));
    });

    final fullDateStr = _getFullFormattedDate(_selectedCalendarDay);

    String getSingleDayLetter(int weekday) {
      const letters = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      return letters[weekday - 1];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Hari, Tanggal Bulan Tahun + Tombol + untuk Catatan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  fullDateStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              BouncyButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NoteEditorPage(
                        noteId: null,
                        initialTitle: '',
                        initialContent: '',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.separated(
              key: const PageStorageKey('home_calendar_slider'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: calendarDays.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final day = calendarDays[index];
                final bool isSelected =
                    _selectedCalendarDay.day == day.day &&
                    _selectedCalendarDay.month == day.month &&
                    _selectedCalendarDay.year == day.year;

                final bool hasTasks = _hasTaskOnDay(day, allTasks);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedCalendarDay = day;
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
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
                        if (hasTasks)
                          Positioned(
                            bottom: 5,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.black54 : Colors.white70)
                                    : const Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _hasTaskOnDay(DateTime day, List<Map<String, dynamic>> allTasks) {
    for (var task in allTasks) {
      final startStr = task['start'] as String? ?? '';
      final endStr = task['end'] as String? ?? '';
      if (startStr.isEmpty || endStr.isEmpty || startStr == 'DD/MM/YYYY')
        continue;

      final startDate = _parseDateString(startStr);
      final endDate = _parseDateString(endStr);
      if (startDate == null || endDate == null) continue;

      final targetDay = DateTime(day.year, day.month, day.day);
      final normStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normEnd = DateTime(endDate.year, endDate.month, endDate.day);

      if ((targetDay.isAfter(normStart) ||
              targetDay.isAtSameMomentAs(normStart)) &&
          (targetDay.isBefore(normEnd) ||
              targetDay.isAtSameMomentAs(normEnd))) {
        return true;
      }
    }
    return false;
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[weekday - 1];
  }
}

class BlueCardPatternPainter extends CustomPainter {
  final bool isDark;
  const BlueCardPatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)).withValues(alpha: isDark ? 0.05 : 0.07)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(size.width * 0.45, 0);
    path1.cubicTo(
      size.width * 0.65,
      size.height * 0.35,
      size.width * 0.35,
      size.height * 0.75,
      size.width * 0.9,
      size.height,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(size.width, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = (isDark ? Colors.white : Colors.white).withValues(alpha: isDark ? 0.04 : 0.35)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(size.width * 0.65, 0);
    path2.cubicTo(
      size.width * 0.85,
      size.height * 0.4,
      size.width * 0.55,
      size.height * 0.8,
      size.width,
      size.height * 0.7,
    );
    path2.lineTo(size.width, 0);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LavenderCardPatternPainter extends CustomPainter {
  final bool isDark;
  const LavenderCardPatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)).withValues(alpha: isDark ? 0.04 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final center = Offset(size.width * 0.85, size.height * 0.5);
    canvas.drawCircle(center, 24, paint);
    canvas.drawCircle(center, 44, paint);

    final paintFill = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.03 : 0.25)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.6, 0);
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.4,
      size.width,
      size.height * 0.9,
    );
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paintFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AmberCardPatternPainter extends CustomPainter {
  final bool isDark;
  const AmberCardPatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)).withValues(alpha: isDark ? 0.04 : 0.06)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(size.width * 0.55, 0);
    path1.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.5,
      size.width * 0.85,
      size.height,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(size.width, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paintStroke = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.03 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final path2 = Path();
    path2.moveTo(size.width * 0.68, 0);
    path2.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.45,
      size.width * 0.88,
      size.height,
    );
    canvas.drawPath(path2, paintStroke);
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
        // Pattern 1: Wave & Smooth Ribbon (Curved waves flowing down right side)
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
        // Pattern 2: Concentric Swirls & Rings (Arcs centered top-right)
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
        // Pattern 3: Floating Soft Circles / Bubbles
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
        // Pattern 4: Modern Geometric Mesh / Node Grid
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
        // Pattern 5: Organic Diagonal Rays / Leaf Curves
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

class HoverFloatingButton extends StatefulWidget {
  final VoidCallback onTap;
  const HoverFloatingButton({super.key, required this.onTap});

  @override
  State<HoverFloatingButton> createState() => _HoverFloatingButtonState();
}

class _HoverFloatingButtonState extends State<HoverFloatingButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B52DF),
                  Color(0xFF7D2AE8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class AddClassroomPlaceholderCard extends StatefulWidget {
  const AddClassroomPlaceholderCard({super.key});

  @override
  State<AddClassroomPlaceholderCard> createState() =>
      _AddClassroomPlaceholderCardState();
}

class _AddClassroomPlaceholderCardState extends State<AddClassroomPlaceholderCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final Color dashedColor = isDark
        ? const Color(0xFFE9E2FC).withValues(alpha: _isHovered ? 0.8 : 0.6)
        : const Color(0xFF7C3AED).withValues(alpha: _isHovered ? 0.5 : 0.28);
    final Color iconColor = isDark
        ? const Color(0xFFE9E2FC)
        : const Color(0xFF7C3AED);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.transparent,
              pageBuilder: (context, _, __) => const AddClassPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return child;
              },
            ),
          );
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.01 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 154,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (isDark
                      ? const Color(0xFFE9E2FC).withValues(alpha: 0.05)
                      : const Color(0xFF7C3AED).withValues(alpha: 0.03))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: DashedBorderPainter(
                      color: dashedColor,
                      strokeWidth: 1.8,
                      dashWidth: 8,
                      dashSpace: 5,
                      borderRadius: 22,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: iconColor, // Tombol + warna ungu soft putih di mode dark
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);

    final Path dashedPath = Path();
    double distance = 0.0;
    for (final PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashedPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ManagementActionButton extends StatefulWidget {
  final IconData icon;
  final Color baseColor;
  final VoidCallback onTap;

  const ManagementActionButton({
    super.key,
    required this.icon,
    required this.baseColor,
    required this.onTap,
  });

  @override
  State<ManagementActionButton> createState() => _ManagementActionButtonState();
}

class _ManagementActionButtonState extends State<ManagementActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isHovered ? 1.0 : 0.5,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _isHovered ? 1.1 : 1.0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.baseColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MembersAvatarStackReadOnly extends StatelessWidget {
  final String projectId;
  final String ownerUid;
  final double avatarSize;
  final double overlap;

  const _MembersAvatarStackReadOnly({
    super.key,
    required this.projectId,
    required this.ownerUid,
    this.avatarSize = 26.0,
    this.overlap = 9.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('projectIds', arrayContains: projectId)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        final studentDocs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final role = (data['role'] ?? '').toString().toLowerCase();
          if (d.id == ownerUid) return false;
          if (role == 'guru' ||
              role == 'teacher' ||
              role == 'pengajar' ||
              role == 'admin') {
            return false;
          }
          return true;
        }).toList();

        if (studentDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        final int totalCount = studentDocs.length;
        final int displayCount = totalCount > 4 ? 3 : totalCount;
        final bool hasMore = totalCount > 4;
        final int extraCount = totalCount - 3;
        final int totalSlots = hasMore ? 4 : displayCount;
        final double totalWidth = totalSlots * (avatarSize - overlap) + overlap + 4.0;

        return IgnorePointer(
          child: SizedBox(
            height: avatarSize,
            width: totalWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < displayCount; i++)
                  Positioned(
                    left: i * (avatarSize - overlap),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scale: 1.45,
                          child: _buildAvatar(
                            studentDocs[i].data() as Map<String, dynamic>? ?? {},
                            i,
                            size: avatarSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (hasMore)
                  Positioned(
                    left: displayCount * (avatarSize - overlap),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '+$extraCount',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: avatarSize * 0.38,
                          ),
                        ),
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

  Widget _buildAvatar(Map<String, dynamic> userData, int index, {required double size}) {
    final photo = (userData['profileImageUrl'] ??
            userData['photoUrl'] ??
            userData['avatarUrl'] ??
            userData['avatar'] ??
            '')
        .toString()
        .trim();
    final name = (userData['name'] ?? 'U').toString().trim();

    if (photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return Image.network(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(name, index, size: size),
        );
      } else {
        String assetPath = photo;
        if (!assetPath.startsWith('assets/')) {
          if (assetPath.startsWith('avatar/') || assetPath.startsWith('chat/')) {
            assetPath = 'assets/icon_pack/$assetPath';
          } else {
            assetPath = 'assets/icon_pack/avatar/$assetPath';
          }
        }
        return Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(name, index, size: size),
        );
      }
    }
    return _buildFallback(name, index, size: size);
  }

  Widget _buildFallback(String name, int index, {required double size}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    const colors = [
      Color(0xFFFEF08A),
      Color(0xFFBBF7D0),
      Color(0xFFFBCFE8),
      Color(0xFFBAE6FD),
      Color(0xFFDDD6FE),
    ];
    final Color bgColor = colors[index % colors.length];

    return Container(
      width: size,
      height: size,
      color: bgColor,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.42,
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AnimatedScheduleCapsule extends StatefulWidget {
  final List schedules;
  final Color accentColor;
  final Color cardColor;
  final bool isCompact;
  const _AnimatedScheduleCapsule({
    super.key,
    required this.schedules,
    this.accentColor = const Color(0xFF7F52FC),
    this.cardColor = Colors.white,
    this.isCompact = false,
  });

  @override
  State<_AnimatedScheduleCapsule> createState() => _AnimatedScheduleCapsuleState();
}

class _AnimatedScheduleCapsuleState extends State<_AnimatedScheduleCapsule> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.schedules.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.schedules.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final bool isCompact = widget.isCompact;

    if (widget.schedules.isEmpty) {
      return Container(
        padding: isCompact
            ? const EdgeInsets.only(left: 3, right: 8, top: 3, bottom: 3)
            : const EdgeInsets.only(left: 4, right: 14, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isCompact ? 20 : 28,
              height: isCompact ? 20 : 28,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : widget.accentColor.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: isCompact ? 12 : 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(width: isCompact ? 5 : 8),
            Flexible(
              child: Text(
                'Jadwal belum diatur',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isCompact
                    ? GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    : AppTypography.timestamp(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
              ),
            ),
          ],
        ),
      );
    }

    final s = widget.schedules[_currentIndex];
    String timeStr = '08:00 - 10:00';
    String dayStr = 'Hari ini';
    if (s is Map) {
      final day = s['day'] ?? '';
      final time = s['time'] ?? '';
      if (time.isNotEmpty) timeStr = time;
      if (day.isNotEmpty) dayStr = day;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Container(
        key: ValueKey<int>(_currentIndex),
        padding: isCompact
            ? const EdgeInsets.only(left: 3, right: 8, top: 3, bottom: 3)
            : const EdgeInsets.only(left: 4, right: 14, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isCompact ? 20 : 28,
              height: isCompact ? 20 : 28,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : widget.accentColor.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: isCompact ? 12 : 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(width: isCompact ? 5 : 8),
            Flexible(
              child: Text(
                '$dayStr, $timeStr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isCompact
                    ? GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    : AppTypography.timestamp(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassroomSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearchChanged;
  final bool isDark;

  const _ClassroomSearchBar({
    super.key,
    required this.onSearchChanged,
    required this.isDark,
  });

  @override
  State<_ClassroomSearchBar> createState() => _ClassroomSearchBarState();
}

class _ClassroomSearchBarState extends State<_ClassroomSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        widget.onSearchChanged(val.trim().toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.15),
                  selectionHandleColor: isDark ? Colors.white : Colors.black87,
                  cursorColor: isDark ? Colors.white : Colors.black,
                ),
              ),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                cursorColor: isDark ? Colors.white : Colors.black,
                onChanged: (val) {
                  setState(() {});
                  _onChanged(val);
                },
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari kelas atau materi...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                setState(() {});
                widget.onSearchChanged('');
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassroomJoinInputBar extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onJoin;
  final VoidCallback onScan;

  const _ClassroomJoinInputBar({
    super.key,
    required this.isDark,
    required this.onJoin,
    required this.onScan,
  });

  @override
  State<_ClassroomJoinInputBar> createState() => _ClassroomJoinInputBarState();
}

class _ClassroomJoinInputBarState extends State<_ClassroomJoinInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onJoin(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0, bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: widget.isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.15),
                  selectionHandleColor: widget.isDark ? Colors.white : Colors.black87,
                  cursorColor: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                cursorColor: widget.isDark ? Colors.white : Colors.black,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: 6, left: 2, right: 4),
                  hintText: 'Masukkan ID classroom...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.normal,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.isDark ? Colors.white24 : Colors.black26,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.isDark ? Colors.white : Colors.black,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          BouncyButton(
            scaleDown: 0.94,
            onTap: _submit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Gabung Kelas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          BouncyButton(
            scaleDown: 0.90,
            onTap: widget.onScan,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 24,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassroomQrScannerPage extends StatefulWidget {
  const ClassroomQrScannerPage({super.key});

  @override
  State<ClassroomQrScannerPage> createState() => _ClassroomQrScannerPageState();
}

class _ClassroomQrScannerPageState extends State<ClassroomQrScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late AnimationController _animController;
  late Animation<double> _animValue;
  bool _isTorchOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _animValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _isProcessing = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, code.trim());
        break;
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final barcodes = await _scannerController.analyzeImage(image.path);
        if (barcodes != null && barcodes.barcodes.isNotEmpty) {
          final code = barcodes.barcodes.first.rawValue;
          if (code != null && code.trim().isNotEmpty && mounted) {
            _isProcessing = true;
            HapticFeedback.mediumImpact();
            Navigator.pop(context, code.trim());
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ditemukan kode QR pada gambar yang dipilih.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses gambar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen Mobile Scanner Camera Feed
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),

          // Dark Tint Overlay with Cutout in Center
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerCutoutPainter(
                cutoutSize: scanAreaSize,
              ),
            ),
          ),

          // Clearly Defined White Box Viewfinder in Center
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white,
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      children: [
                        // Animated Scanning Line
                        AnimatedBuilder(
                          animation: _animValue,
                          builder: (context, _) {
                            return Positioned(
                              top: _animValue.value * (scanAreaSize - 4),
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF38BDF8),
                                      Color(0xFFBAE6FD),
                                      Color(0xFF38BDF8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.95),
                                      blurRadius: 12,
                                      spreadRadius: 2,
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
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Posisikan QR code kelas di dalam kotak',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Header (Back Button + Title)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scan Kode Classroom',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Buttons + Footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Upload / Gallery Button
                        GestureDetector(
                          onTap: _pickImageFromGallery,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.black87,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Flash / Torch Toggle Button
                        GestureDetector(
                          onTap: () async {
                            await _scannerController.toggleTorch();
                            setState(() {
                              _isTorchOn = !_isTorchOn;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _isTorchOn ? const Color(0xFF38BDF8) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                  color: Colors.black87,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isTorchOn ? 'Matikan Flash' : 'Nyalakan Flash',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Powered By ',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white60,
                          ),
                        ),
                        Text(
                          'Hubner Edu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerCutoutPainter extends CustomPainter {
  final double cutoutSize;

  _ScannerCutoutPainter({required this.cutoutSize});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 - 24),
        width: cutoutSize,
        height: cutoutSize,
      ),
      const Radius.circular(24),
    );

    final cutoutPath = Path()..addRRect(cutoutRect);

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCutoutPainter oldDelegate) =>
      oldDelegate.cutoutSize != cutoutSize;
}


class _QuizSparklinePainter extends CustomPainter {
  final List<int> scores;
  final Color lineColor;
  final Color dotColor;
  final bool isDark;

  _QuizSparklinePainter({
    required this.scores,
    required this.lineColor,
    required this.dotColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final displayScores = scores.length >= 3
        ? scores.sublist(scores.length - 3)
        : scores;

    if (displayScores.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      final p = Paint()..color = dotColor..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4, p);
      return;
    }

    const double minScore = 0;
    const double maxScore = 100;
    const double scoreRange = maxScore - minScore;

    final points = <Offset>[];
    final double stepX = size.width / (displayScores.length - 1);

    for (int i = 0; i < displayScores.length; i++) {
      final s = displayScores[i].clamp(0, 100);
      final double normalizedY = 1.0 - ((s - minScore) / scoreRange);
      final double y = 5 + normalizedY * (size.height - 10);
      final double x = i * stepX;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;
    final dotStroke = Paint()..color = isDark ? Colors.black : Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (var pt in points) {
      canvas.drawCircle(pt, 3.5, dotPaint);
      canvas.drawCircle(pt, 3.5, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _QuizSparklinePainter oldDelegate) => true;
}

/// 0. Trophy SVG Icon for Student Banner (2-Tone Model: Golden Yellow & Warm Brown/Bronze)
class _TrophySvgIcon extends StatelessWidget {
  final double size;
  const _TrophySvgIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrophySvgPainter(),
      ),
    );
  }
}

class _TrophySvgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 2-Tone Color Palette: Golden Yellow & Warm Brown/Bronze
    final Paint goldBright = Paint()..color = const Color(0xFFFBBF24)..style = PaintingStyle.fill;
    final Paint goldLight = Paint()..color = const Color(0xFFFEF08A)..style = PaintingStyle.fill;
    final Paint bronzeDark = Paint()..color = const Color(0xFF92400E)..style = PaintingStyle.fill;
    final Paint bronzeShade = Paint()..color = const Color(0xFFB45309)..style = PaintingStyle.fill;

    // 1. Trophy Ear Handles (Outer Brown/Bronze with Inner Gold)
    // Left Handle
    final Path leftHandle = Path()
      ..moveTo(w * 0.28, h * 0.22)
      ..cubicTo(w * 0.04, h * 0.22, w * 0.04, h * 0.52, w * 0.32, h * 0.50)
      ..lineTo(w * 0.32, h * 0.42)
      ..cubicTo(w * 0.14, h * 0.44, w * 0.14, h * 0.28, w * 0.28, h * 0.28)
      ..close();
    canvas.drawPath(leftHandle, bronzeShade);

    // Right Handle
    final Path rightHandle = Path()
      ..moveTo(w * 0.72, h * 0.22)
      ..cubicTo(w * 0.96, h * 0.22, w * 0.96, h * 0.52, w * 0.68, h * 0.50)
      ..lineTo(w * 0.68, h * 0.42)
      ..cubicTo(w * 0.86, h * 0.44, w * 0.86, h * 0.28, w * 0.72, h * 0.28)
      ..close();
    canvas.drawPath(rightHandle, bronzeDark);

    // 2. Base Pedestal (Brownish Base)
    // Bottom Block
    final RRect bottomBlock = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.82, w * 0.52, h * 0.14),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(bottomBlock, bronzeDark);

    // Pedestal Plate (Gold Accent on Base)
    final RRect basePlate = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.32, h * 0.74, w * 0.36, h * 0.08),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(basePlate, bronzeShade);

    // Stem / Pillar
    final RRect stem = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.43, h * 0.58, w * 0.14, h * 0.18),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(stem, bronzeShade);

    // Stem Ring (Golden Yellow)
    final RRect stemRing = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.38, h * 0.65, w * 0.24, h * 0.05),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(stemRing, goldBright);

    // 3. Main Trophy Cup Body
    // Left half (Golden Yellow)
    final Path cupLeft = Path()
      ..moveTo(w * 0.22, h * 0.15)
      ..lineTo(w * 0.50, h * 0.15)
      ..lineTo(w * 0.50, h * 0.58)
      ..cubicTo(w * 0.38, h * 0.58, w * 0.22, h * 0.44, w * 0.22, h * 0.15)
      ..close();
    canvas.drawPath(cupLeft, goldBright);

    // Right half (Shaded Brownish Bronze)
    final Path cupRight = Path()
      ..moveTo(w * 0.50, h * 0.15)
      ..lineTo(w * 0.78, h * 0.15)
      ..cubicTo(w * 0.78, h * 0.44, w * 0.62, h * 0.58, w * 0.50, h * 0.58)
      ..close();
    canvas.drawPath(cupRight, bronzeShade);

    // 4. Cup Top Rim (Oval Lid/Rim)
    final RRect rimLeft = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.11, w * 0.32, h * 0.08),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(rimLeft, goldLight);

    final RRect rimRight = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.50, h * 0.11, w * 0.32, h * 0.08),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(rimRight, bronzeShade);

    // 5. Star / Emblem on Cup (Light Yellow / Bright Highlight)
    final Path star = Path()
      ..moveTo(w * 0.50, h * 0.25)
      ..lineTo(w * 0.525, h * 0.32)
      ..lineTo(w * 0.60, h * 0.32)
      ..lineTo(w * 0.54, h * 0.365)
      ..lineTo(w * 0.565, h * 0.435)
      ..lineTo(w * 0.50, h * 0.39)
      ..lineTo(w * 0.435, h * 0.435)
      ..lineTo(w * 0.46, h * 0.365)
      ..lineTo(w * 0.40, h * 0.32)
      ..lineTo(w * 0.475, h * 0.32)
      ..close();
    canvas.drawPath(star, goldLight);
  }

  @override
  bool shouldRepaint(covariant _TrophySvgPainter oldDelegate) => false;
}

/// 1. Premium 3D Material Design Illustration for Jadwal Kelas
class _ClassScheduleDoodle extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;
  const _ClassScheduleDoodle({
    super.key,
    this.width = 96,
    this.height = 60,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/images/home_schedule_card.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// 2. Premium 3D Material Design Illustration for Deadline Tugas
class _TaskDeadlineDoodle extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;
  const _TaskDeadlineDoodle({
    super.key,
    this.width = 96,
    this.height = 60,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/images/home_task_card.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// 3. Premium 3D Material Design Illustration for Jadwal Kuis
class _QuizPuzzleDoodle extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;
  const _QuizPuzzleDoodle({
    super.key,
    this.width = 96,
    this.height = 60,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/images/home_quiz_card.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _StressStyleBarChartPainter extends CustomPainter {
  final List<int> values;
  final bool isDark;
  final Color barColor;
  final Color lineColor;

  _StressStyleBarChartPainter({
    required this.values,
    required this.isDark,
    required this.barColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final displayValues = values.length > 5 ? values.sublist(values.length - 5) : values;
    final int count = displayValues.length;

    final double barWidth;
    final double spacing;
    final double startX;

    if (count == 1) {
      barWidth = 14.0;
      spacing = 0.0;
      startX = (size.width - barWidth) / 2;
    } else {
      barWidth = (size.width / (count * 1.8)).clamp(8.0, 16.0);
      spacing = (size.width - (count * barWidth)) / (count - 1);
      startX = 0.0;
    }

    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final double val = (displayValues[i] / 100.0).clamp(0.20, 1.0);
      final double barH = val * (size.height - 14);
      final double x = startX + i * (barWidth + spacing);
      final double y = size.height - barH;

      // Draw capsule vertical bar
      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(5),
      );
      final Paint barPaint = Paint()
        ..color = barColor.withValues(alpha: isDark ? 0.35 + (i * 0.12) : 0.30 + (i * 0.14))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, barPaint);

      points.add(Offset(x + barWidth / 2, y - 4));
    }

    // Draw connecting line & point dots
    if (points.length == 1) {
      final Paint dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, 3.5, dotPaint);
    } else if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }
      final Paint linePaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);

      final Paint dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      for (var pt in points) {
        canvas.drawCircle(pt, 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StressStyleBarChartPainter oldDelegate) => true;
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

    // Facet 2: Angular top wedge / notch (matching reference origami facet)
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
