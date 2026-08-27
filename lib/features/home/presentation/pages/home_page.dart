import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
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
import 'package:hubner/features/todo/presentation/pages/todo_page.dart';
import 'note_editor_page.dart';
import 'package:hubner/features/projects/presentation/pages/add_class_page.dart';
import 'package:hubner/features/projects/presentation/pages/edit_class_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

class HomePage extends StatefulWidget {
  final Function(int index, {String? projectId})? onNavigateTab;
  const HomePage({super.key, this.onNavigateTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedCalendarDay = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  int _quizCardPage = 0;
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
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final GlobalKey _notesButtonKey = GlobalKey();
  final ScrollController _homeScrollController = ScrollController();
  final ValueNotifier<double> _headerScrollOffsetNotifier = ValueNotifier<double>(0.0);

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
    _homeScrollController.addListener(() {
      _headerScrollOffsetNotifier.value = _homeScrollController.offset;
    });
  }

  @override
  void dispose() {
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

                  return SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _homeScrollController,
                          padding: AppTypography.pagePadding(
                            top: 12.0,
                            bottom: 125.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Normal Top Header (Tampil asli di posisi awal halaman)
                              if (!isDesktop) ...[
                                if (role.toLowerCase() == 'guru') ...[
                                  // Teacher Top Controls (Kiri: Toggle Dark / Light Mode, Kanan: Notifikasi)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Pojok Kiri: Toggle Dark / Light Mode
                                      ValueListenableBuilder<String>(
                                        valueListenable: HubnerApp.themeNotifier,
                                        builder: (context, currentTheme, _) {
                                          final bool isDark = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                          return BouncyButton(
                                            onTap: () => _toggleThemeWithBounce(context, isDark),
                                            child: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF18181B)
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF27272A)
                                                      : const Color(0xFFF1F5F9),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Icon(
                                                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                                color: isDark ? const Color(0xFFFBBF24) : Colors.black87,
                                                size: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Pojok Kanan: Tombol Notifikasi
                                       ValueListenableBuilder<String>(
                                         valueListenable: HubnerApp.themeNotifier,
                                         builder: (context, currentTheme, _) {
                                           final bool isDark = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                           return NotificationBellIcon(isDark: isDark, size: 42);
                                         },
                                       ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Teacher Profile: Nama Pengajar di kiri & Avatar bulat di kanan (Sesuai desain asli)
                                  Builder(
                                    builder: (context) {
                                      final bool isDark = AppColors.isDarkMode;
                                      final String teacherRoleTitle = 'Pengajar · ${schoolLevel.isNotEmpty ? schoolLevel.toUpperCase() : 'SMA/SMK'}';

                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
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
                                                const SizedBox(height: 3),
                                                Text(
                                                  fullName,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 28.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : Colors.black,
                                                    height: 1.15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Container(
                                            width: 58,
                                            height: 58,
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
                                                                  fontSize: 20,
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
                                                                  fontSize: 20,
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
                                                            fontSize: 20,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Siswa · ${schoolLevel.isNotEmpty ? schoolLevel.toUpperCase() : 'SMA/SMK'}',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 13.5,
                                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              fullName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 28.0,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black,
                                                height: 1.15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          ValueListenableBuilder<String>(
                                            valueListenable: HubnerApp.themeNotifier,
                                            builder: (context, currentTheme, _) {
                                              final bool currentIsDark = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                              return BouncyButton(
                                                onTap: () => _toggleThemeWithBounce(context, currentIsDark),
                                                child: Container(
                                                  width: 42,
                                                  height: 42,
                                                  decoration: BoxDecoration(
                                                    color: currentIsDark
                                                        ? const Color(0xFF1C1C1E)
                                                        : Colors.white,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: currentIsDark
                                                          ? const Color(0xFF27272A)
                                                          : const Color(0xFFF1F5F9),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    currentIsDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                                    color: currentIsDark ? const Color(0xFFFBBF24) : Colors.black87,
                                                    size: 20,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 10),
                                           ValueListenableBuilder<String>(
                                             valueListenable: HubnerApp.themeNotifier,
                                             builder: (context, currentTheme, _) {
                                               final bool isDark = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                               return NotificationBellIcon(isDark: isDark, size: 42);
                                             },
                                           ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                              ],
                              const SizedBox(height: 4),
                              _HomeSearchAndNotesRow(
                                key: const ValueKey('home_search_and_notes_row'),
                                notesKey: _notesButtonKey,
                                onNotesTap: _showQuickNotesOverlay,
                                onSearchChanged: (query) {
                                  _searchQueryNotifier.value = query;
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),

                          if (role.toLowerCase() != 'guru') ...[
                            // Grid Layout for Today & Task States with student progress
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

                                // Deadlines for today
                                final now = DateTime.now();
                                final today = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
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
                                              today,
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

                                final bool isTablet =
                                    MediaQuery.of(context).size.width > 500;
                                final bool isDark = AppColors.isDarkMode;

                                Widget buildLeftCardSection({
                                  required IconData icon,
                                  required Color iconColor,
                                  required String title,
                                  required List<Widget> items,
                                }) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(icon, size: 14, color: iconColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            title,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ...items,
                                    ],
                                  );
                                }

                                Widget buildEmptyText(String text) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(
                                      text,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.0,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  );
                                }

                                Widget buildItemText(String text) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(
                                      text,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }

                                Widget todayCard = Container(
                                  height: 300,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : null,
                                    gradient: isDark
                                        ? null
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFFE0F2FE),
                                              Color(0xFFF0F9FF),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF27272A)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: BlueCardPatternPainter(
                                            isDark: isDark,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Hari Ini',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 17.6,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 9,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? const Color(0xFF27272A)
                                                        : Colors.white
                                                            .withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    selectedDayName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 14.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? const Color(0xFF60A5FA)
                                                          : const Color(
                                                              0xFF0369A1,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Expanded(
                                              child: Scrollbar(
                                                child: SingleChildScrollView(
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      buildLeftCardSection(
                                                        icon: Icons
                                                            .calendar_today_rounded,
                                                        iconColor: isDark
                                                            ? const Color(0xFF60A5FA)
                                                            : const Color(
                                                                0xFF0369A1,
                                                              ),
                                                        title:
                                                            'Jadwal Kelas Hari Ini',
                                                        items:
                                                            activeSchedules
                                                                .isEmpty
                                                            ? [
                                                                buildEmptyText(
                                                                  'Bebas kelas hari ini',
                                                                ),
                                                              ]
                                                            : activeSchedules.take(2).map((
                                                                item,
                                                              ) {
                                                                final String
                                                                time =
                                                                    item['time'] ??
                                                                    '';
                                                                final String
                                                                projName =
                                                                    item['projectName'] ??
                                                                    'Classroom';
                                                                return buildItemText(
                                                                  '$time - $projName',
                                                                );
                                                              }).toList(),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      buildLeftCardSection(
                                                        icon: Icons
                                                            .assignment_outlined,
                                                        iconColor: isDark
                                                            ? const Color(0xFFD6A5F8)
                                                            : const Color(
                                                                0xFF7E22CE,
                                                              ),
                                                        title:
                                                            'Deadline Tugas Hari Ini',
                                                        items:
                                                            todayTugasDeadlines
                                                                .isEmpty
                                                            ? [
                                                                buildEmptyText(
                                                                  'Bebas tugas hari ini',
                                                                ),
                                                              ]
                                                            : todayTugasDeadlines
                                                                  .take(2)
                                                                  .map((t) {
                                                                    return buildItemText(
                                                                      '${t['title']} (${t['projectName']})',
                                                                    );
                                                                  })
                                                                  .toList(),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      buildLeftCardSection(
                                                        icon:
                                                            Icons.quiz_outlined,
                                                        iconColor: isDark
                                                            ? const Color(0xFFFCD34D)
                                                            : const Color(
                                                                0xFFD97706,
                                                              ),
                                                        title:
                                                            'Jadwal Quiz Hari Ini',
                                                        items:
                                                            todayQuizDeadlines
                                                                .isEmpty
                                                            ? [
                                                                buildEmptyText(
                                                                  'Bebas quiz hari ini',
                                                                ),
                                                              ]
                                                            : todayQuizDeadlines
                                                                  .take(2)
                                                                  .map((q) {
                                                                    return buildItemText(
                                                                      '${q['title']} (${q['projectName']})',
                                                                    );
                                                                  })
                                                                  .toList(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                Widget progressCardsColumn = Column(
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
                                                colors: [
                                                  Color(0xFFF3E8FF),
                                                  Color(0xFFFAF5FF),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF27272A)
                                              : const Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: CustomPaint(
                                              painter:
                                                  LavenderCardPatternPainter(
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // Header Row
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF7C3AED, // Ungu Hubner Core
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              9,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .assignment_turned_in_rounded,
                                                        color: Colors.white,
                                                        size: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Tugas',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 14.7,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isDark
                                                                ? Colors.white
                                                                : Colors.black87,
                                                          ),
                                                    ),
                                                  ],
                                                ),

                                                // Middle 0/0 Stat Counter (Between Title and Percent)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 2,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .baseline,
                                                    textBaseline:
                                                        TextBaseline.alphabetic,
                                                    children: [
                                                      Text(
                                                        '$completedTugas',
                                                        style:
                                                            GoogleFonts.dmSans(
                                                              fontSize: 28.1,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              color: isDark
                                                                  ? const Color(0xFFD6A5F8)
                                                                  : const Color(
                                                                    0xFF6B21A8,
                                                                  ),
                                                              height: 1.0,
                                                            ),
                                                      ),
                                                      Text(
                                                        '/$totalTugas',
                                                        style:
                                                            GoogleFonts.dmSans(
                                                              fontSize: 15.2,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: isDark
                                                                  ? const Color(0xFFA5B4FC)
                                                                  : const Color(
                                                                    0xFF7E22CE,
                                                                  ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Bottom Percent & Progress Bar
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .baseline,
                                                      textBaseline: TextBaseline
                                                          .alphabetic,
                                                      children: [
                                                        Text(
                                                          '${(tugasRatio * 100).toInt()}%',
                                                          style:
                                                              GoogleFonts.dmSans(
                                                                fontSize: 16.4,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: isDark
                                                                    ? const Color(0xFFD6A5F8)
                                                                    : const Color(
                                                                      0xFF6B21A8,
                                                                    ),
                                                                height: 1.0,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          'tercapai',
                                                          style:
                                                              GoogleFonts.dmSans(
                                                                fontSize: 14.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: isDark
                                                                    ? Colors.white70
                                                                    : Colors.black54,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      child: LinearProgressIndicator(
                                                        value: tugasRatio,
                                                        backgroundColor: isDark
                                                            ? const Color(0xFF27272A)
                                                            : Colors.white,
                                                        valueColor:
                                                            const AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              Color(0xFF7C3AED), // Ungu Hubner
                                                            ),
                                                        minHeight: 6,
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
                                    StatefulBuilder(
                                      builder: (context, setStateLocal) {
                                        return GestureDetector(
                                          onTap: () {
                                            setStateLocal(() {
                                              _quizCardPage =
                                                  (_quizCardPage + 1) % 3;
                                            });
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            height: 142,
                                            width: double.infinity,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1C1C1E) : null,
                                              gradient: isDark
                                                  ? null
                                                  : const LinearGradient(
                                                      colors: [
                                                        Color(0xFFFEF3C7),
                                                        Color(0xFFFFFBEB),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF27272A)
                                                    : const Color(0xFFE2E8F0),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter:
                                                        AmberCardPatternPainter(
                                                      isDark: isDark,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      // Header Row
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      5,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(
                                                                    0xFFD97706,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        9,
                                                                      ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .quiz_rounded,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 13,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                'Quiz',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  fontSize: 14.7,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isDark
                                                                      ? Colors.white
                                                                      : Colors.black87,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          // Dots Page Indicator
                                                          Row(
                                                            children: List.generate(3, (
                                                              idx,
                                                            ) {
                                                              return Container(
                                                                margin:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          2.5,
                                                                    ),
                                                                width: 5,
                                                                height: 5,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color:
                                                                      _quizCardPage ==
                                                                          idx
                                                                      ? (isDark
                                                                          ? const Color(0xFFFCD34D)
                                                                          : const Color(0xFFB45309))
                                                                      : (isDark
                                                                          ? const Color(0xFF78350F)
                                                                          : const Color(0xFFFCD34D)),
                                                                ),
                                                              );
                                                            }),
                                                          ),
                                                        ],
                                                      ),

                                                      // Description Above Value
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 2,
                                                              top: 4,
                                                            ),
                                                        child: Text(
                                                          _quizCardPage == 0
                                                              ? 'Progres Pengerjaan Kuis'
                                                              : _quizCardPage ==
                                                                    1
                                                              ? 'Nilai Kuis Terakhir'
                                                              : 'Rata-rata Nilai Kuis',
                                                          style:
                                                              GoogleFonts.dmSans(
                                                                fontSize: 14.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: isDark
                                                                    ? const Color(0xFFFDE047)
                                                                    : const Color(
                                                                      0xFF9A3412,
                                                                    ),
                                                              ),
                                                        ),
                                                      ),

                                                      // Middle Value (0/0, Last Quiz Score, Average Score)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 2,
                                                            ),
                                                        child:
                                                            _quizCardPage == 0
                                                            ? Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .baseline,
                                                                textBaseline:
                                                                    TextBaseline
                                                                        .alphabetic,
                                                                children: [
                                                                  Text(
                                                                    '$completedQuiz',
                                                                    style: GoogleFonts.dmSans(
                                                                      fontSize: 25.7,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      color: isDark
                                                                          ? const Color(0xFFFCD34D)
                                                                          : const Color(
                                                                            0xFFB45309,
                                                                          ),
                                                                      height:
                                                                          1.0,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '/$totalQuiz',
                                                                    style: GoogleFonts.dmSans(
                                                                      fontSize: 15.2,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: isDark
                                                                          ? const Color(0xFFFDE047)
                                                                          : const Color(
                                                                            0xFFD97706,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            : _quizCardPage == 1
                                                            ? Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .baseline,
                                                                textBaseline:
                                                                    TextBaseline
                                                                        .alphabetic,
                                                                children: [
                                                                  Text(
                                                                    scoreText,
                                                                    style: GoogleFonts.dmSans(
                                                                      fontSize: 25.7,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      color: isDark
                                                                          ? const Color(0xFFFCD34D)
                                                                          : const Color(
                                                                            0xFFB45309,
                                                                          ),
                                                                      height:
                                                                          1.0,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    'poin',
                                                                    style: GoogleFonts.dmSans(
                                                                      fontSize: 14.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: isDark
                                                                          ? const Color(0xFFFDE047)
                                                                          : const Color(
                                                                            0xFFD97706,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            : Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .baseline,
                                                                textBaseline:
                                                                    TextBaseline
                                                                        .alphabetic,
                                                                children: [
                                                                  Text(
                                                                    avgScoreText,
                                                                    style: GoogleFonts.dmSans(
                                                                      fontSize: 25.7,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      color: isDark
                                                                          ? const Color(0xFFFCD34D)
                                                                          : const Color(
                                                                            0xFFB45309,
                                                                          ),
                                                                      height:
                                                                          1.0,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    'poin',
                                                                    style: GoogleFonts.dmSans(
                                                                      fontSize: 14.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: isDark
                                                                          ? const Color(0xFFFDE047)
                                                                          : const Color(
                                                                            0xFFD97706,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                      ),

                                                      // Bottom Progress and Bar
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .baseline,
                                                            textBaseline:
                                                                TextBaseline
                                                                    .alphabetic,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  _quizCardPage ==
                                                                          0
                                                                      ? '${(quizRatio * 100).toInt()}% kuis tercapai'
                                                                      : _quizCardPage ==
                                                                            1
                                                                      ? 'Diambil dari kuis yang baru saja Anda selesaikan'
                                                                      : 'Berdasarkan total nilai kuis yang Anda miliki',
                                                                  style: GoogleFonts.dmSans(
                                                                    fontSize: 14.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: isDark
                                                                        ? Colors.white70
                                                                        : Colors.black54,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                            child: LinearProgressIndicator(
                                                              value:
                                                                  _quizCardPage ==
                                                                      0
                                                                  ? quizRatio
                                                                  : (quizScores
                                                                            .isNotEmpty
                                                                        ? (_quizCardPage ==
                                                                                  1
                                                                              ? quizScores.last /
                                                                                    100.0
                                                                              : averageScore /
                                                                                    100.0)
                                                                        : 0.0),
                                                              backgroundColor: isDark
                                                                  ? const Color(0xFF27272A)
                                                                  : Colors.white,
                                                              valueColor:
                                                                  const AlwaysStoppedAnimation<
                                                                    Color
                                                                  >(
                                                                    Color(
                                                                      0xFFD97706,
                                                                    ),
                                                                  ),
                                                              minHeight: 6,
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
                                    ),
                                  ],
                                );

                                if (isTablet) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 11,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 11,
                                              child: todayCard,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 10,
                                              child: progressCardsColumn,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 10,
                                        child: _buildMonthlyCalendar(
                                          allUserTasks,
                                          role,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Expanded(
                                       child: todayCard,
                                     ),
                                     const SizedBox(width: 12),
                                     Expanded(
                                       child: progressCardsColumn,
                                     ),
                                   ],
                                 );
                              },
                            ),
                            if (MediaQuery.of(context).size.width < 700 || MediaQuery.of(context).size.shortestSide < 700) ...[
                              const SizedBox(height: 28),
                              _buildCalendarSlider(allUserTasks, role),
                              const SizedBox(height: 28),
                            ] else ...[
                              const SizedBox(height: 28),
                            ],
                          ],

                          // Projects Section Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Classroom Saya',
                                style: AppTypography.pageTitle(
                                  color: AppColors.isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: [


                                  // Tombol Kelola Kelas (Ikon Lingkaran Hitam & Centang Hijau Tanpa Background)
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _isManagingClassesNotifier,
                                    builder: (context, isManaging, _) {
                                      final bool isDark = AppColors.isDarkMode;

                                      if (isManaging) {
                                        // Saat Mengelola Aktif: Tanpa Background dengan Ikon Centang Hijau & Text Hijau
                                        return GestureDetector(
                                          onTap: () {
                                            _isManagingClassesNotifier.value = false;
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Color(0xFF7C3AED), // Warna Ungu Hubner
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Selesai',
                                                  style: AppTypography.buttonLabel(
                                                    color: const Color(0xFF7C3AED),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return BouncyButton(
                                        onTap: () {
                                          _isManagingClassesNotifier.value = !isManaging;
                                        },
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.dashboard_customize_rounded,
                                            color: isDark ? Colors.white : Colors.black87,
                                            size: 20,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Invitations list
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
                                  const SizedBox(height: 16),
                                  Text(
                                    'Undangan Kelas',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15.2,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
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
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // ... (Rest of Invitation Item Implementation)
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            },
                          ),

                          if (role.toLowerCase() != 'guru' || isDesktop) ...[
                            Text(
                              'Saat ini Anda memiliki kelas.',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (projectIds.isEmpty && role.toLowerCase() != 'guru')
                            Text(
                              'Belum ada kelas. Silakan buat kelas baru.',
                              style: GoogleFonts.dmSans(
                                fontSize: 15.2,
                                color: Colors.black45,
                              ),
                            )
                          else ...[
                              ValueListenableBuilder<String>(
                                valueListenable: _searchQueryNotifier,
                                builder: (context, searchQuery, _) {
                                  final bool isDark = AppColors.isDarkMode;
                                  final q = searchQuery.toLowerCase().trim();

                                  // SEARCH FOR ELEMEN CP & MATERI JIKA SEARCH AKTIF (SAFE PARSING)
                                  if (q.isNotEmpty) {
                                    final List<Map<String, dynamic>> matchedElements = [];

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

                                            final stageTitle = (stage['title'] ?? stage['name'] ?? 'Elemen ${sIdx + 1}').toString();
                                            final stageDesc = (stage['description'] ?? stage['desc'] ?? '').toString();
                                            final materis = stage['materis'] as List? ?? [];
                                            final stageTasks = stage['tasks'] as List? ?? [];

                                            bool isMatch = stageTitle.toLowerCase().contains(q) || stageDesc.toLowerCase().contains(q);
                                            String? matchedMateriName;

                                            for (var m in materis) {
                                              if (m is Map) {
                                                final mTitle = (m['title'] ?? '').toString();
                                                if (mTitle.toLowerCase().contains(q)) {
                                                  isMatch = true;
                                                  matchedMateriName = mTitle;
                                                  break;
                                                }
                                              }
                                            }

                                            if (!isMatch) {
                                              for (var t in stageTasks) {
                                                if (t is Map) {
                                                  final tTitle = (t['title'] ?? '').toString();
                                                  if (tTitle.toLowerCase().contains(q)) {
                                                    isMatch = true;
                                                    matchedMateriName = tTitle;
                                                    break;
                                                  }
                                                }
                                              }
                                            }

                                            if (isMatch) {
                                              matchedElements.add({
                                                'projectId': projId,
                                                'projectTitle': projTitle,
                                                'gradeLevel': gradeLevel,
                                                'major': major,
                                                'stageIdx': sIdx,
                                                'stageTitle': stageTitle,
                                                'stageDesc': stageDesc,
                                                'materiCount': materis.length,
                                                'taskCount': stageTasks.length,
                                                'cardColor': cardColor,
                                                'accentColor': accentColor,
                                                'isOwner': isOwner,
                                                'matchedMateri': matchedMateriName,
                                              });
                                            }
                                          } catch (_) {}
                                        }
                                      } catch (_) {}
                                    }

                                    if (matchedElements.isEmpty) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
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
                                              'Elemen Tidak Ditemukan',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Tidak ada elemen atau materi yang cocok dengan "$searchQuery"',
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
                                            'Daftar Elemen Ditemukan (${matchedElements.length})',
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
                                           itemCount: matchedElements.length,
                                           separatorBuilder: (_, __) => Divider(
                                             height: 24,
                                             thickness: 1,
                                             color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                           ),
                                           itemBuilder: (context, index) {
                                             final elem = matchedElements[index];
                                             final String stageTitle = elem['stageTitle']?.toString() ?? 'Elemen';
                                             final String projTitle = elem['projectTitle']?.toString() ?? 'Classroom';
                                             final String gradeLevel = elem['gradeLevel']?.toString() ?? '';
                                             final String major = elem['major']?.toString() ?? '';
                                             final Color cardColor = elem['cardColor'] as Color? ?? Colors.white;
                                             final Color accentColor = elem['accentColor'] as Color? ?? const Color(0xFF7F52FC);
                                             final String? matchedMateri = elem['matchedMateri']?.toString();

                                             return InkWell(
                                               borderRadius: BorderRadius.circular(12),
                                               onTap: () {
                                                 Navigator.of(context).push(
                                                   MaterialPageRoute(
                                                     builder: (_) => DetailCpPage(
                                                       projectId: elem['projectId'],
                                                       projectTitle: projTitle,
                                                       stageIdx: elem['stageIdx'],
                                                       isOwner: elem['isOwner'],
                                                       accentColor: accentColor,
                                                       cardColor: cardColor,
                                                     ),
                                                   ),
                                                 );
                                               },
                                               child: Padding(
                                                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                 child: Row(
                                                   children: [
                                                     Expanded(
                                                       child: Column(
                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                         children: [
                                                           Text(
                                                             stageTitle,
                                                             style: GoogleFonts.plusJakartaSans(
                                                               fontSize: 17.0,
                                                               fontWeight: FontWeight.w800,
                                                               color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                             ),
                                                             maxLines: 1,
                                                             overflow: TextOverflow.ellipsis,
                                                           ),
                                                           const SizedBox(height: 3),
                                                           Text(
                                                             '$projTitle · $gradeLevel $major',
                                                             style: GoogleFonts.dmSans(
                                                               fontSize: 14.0,
                                                               fontWeight: FontWeight.w500,
                                                               color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                             ),
                                                             maxLines: 1,
                                                             overflow: TextOverflow.ellipsis,
                                                           ),
                                                           if (matchedMateri != null) ...[
                                                             const SizedBox(height: 5),
                                                             Container(
                                                               padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                               decoration: BoxDecoration(
                                                                 color: isDark ? const Color(0xFF3F2D1D) : const Color(0xFFFEF3C7),
                                                                 borderRadius: BorderRadius.circular(6),
                                                               ),
                                                               child: Text(
                                                                 'Materi: $matchedMateri',
                                                                 style: GoogleFonts.dmSans(
                                                                   fontSize: 14.0,
                                                                   fontWeight: FontWeight.bold,
                                                                   color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                                                 ),
                                                                 maxLines: 1,
                                                                 overflow: TextOverflow.ellipsis,
                                                               ),
                                                             ),
                                                           ],
                                                         ],
                                                       ),
                                                     ),
                                                     const SizedBox(width: 10),
                                                     BouncyButton(
                                                       scaleDown: 0.90,
                                                       onTap: () {
                                                         Navigator.of(context).push(
                                                           MaterialPageRoute(
                                                             builder: (_) => DetailCpPage(
                                                               projectId: elem['projectId'],
                                                               projectTitle: projTitle,
                                                               stageIdx: elem['stageIdx'],
                                                               isOwner: elem['isOwner'],
                                                               accentColor: accentColor,
                                                               cardColor: cardColor,
                                                             ),
                                                           ),
                                                         );
                                                       },
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
                                                               'Buka CP',
                                                               style: GoogleFonts.plusJakartaSans(
                                                                 fontSize: 14.0,
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
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: ratio,
                                        ),
                                    itemBuilder: (context, index) =>
                                        projectCards[index],
                                  );
                                } else {
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: projectCards.length,
                                    separatorBuilder: (_, i) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, index) =>
                                        projectCards[index],
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isDesktop)
                      ValueListenableBuilder<double>(
                        valueListenable: _headerScrollOffsetNotifier,
                        builder: (context, scrollOffset, _) {
                          if (scrollOffset <= 20.0) {
                            return const SizedBox.shrink();
                          }
                          final bool isDark = AppColors.isDarkMode;
                          final double t = ((scrollOffset - 20.0) / 40.0).clamp(0.0, 1.0);

                          return Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Opacity(
                              opacity: t,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(14, 8, 14, 36),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      (isDark ? Colors.black : Colors.white).withValues(alpha: t * 0.98),
                                      (isDark ? Colors.black : Colors.white).withValues(alpha: t * 0.95),
                                      (isDark ? Colors.black : Colors.white).withValues(alpha: t * 0.45),
                                      (isDark ? Colors.black : Colors.white).withValues(alpha: 0.0),
                                    ],
                                    stops: const [0.0, 0.48, 0.75, 1.0],
                                  ),
                                ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Sebelah Kiri: Avatar di sebelah kirinya Nama dan Role
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (userPhoto.isNotEmpty) ...[
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                  ),
                                                  child: ClipOval(
                                                    child: Transform.scale(
                                                      scale: 1.45,
                                                      child: ColorFiltered(
                                                        colorFilter: isDark
                                                            ? ColorFilter.mode(Colors.black.withValues(alpha: 0.10), BlendMode.darken)
                                                            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
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
                                                                          fontSize: 20,
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
                                                                          fontSize: 20,
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
                                                                    fontSize: 20,
                                                                  ),
                                                                ),
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 9),
                                              ],
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        role.toLowerCase() == 'guru'
                                                            ? 'Pengajar · ${schoolLevel.isNotEmpty ? schoolLevel.toUpperCase() : 'SMA/SMK'}'
                                                            : 'Siswa · ${schoolLevel.isNotEmpty ? schoolLevel.toUpperCase() : 'SMA/SMK'}',
                                                        style: GoogleFonts.dmSans(
                                                          fontSize: 14.0,
                                                          fontWeight: FontWeight.w500,
                                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 1.0),
                                                      Text(
                                                        fullName.isNotEmpty ? fullName : userName,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 16.0,
                                                          fontWeight: FontWeight.w800,
                                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                          const SizedBox(width: 10),
                                          Row(
                                            children: [
                                              ValueListenableBuilder<String>(
                                                valueListenable: HubnerApp.themeNotifier,
                                                builder: (context, currentTheme, _) {
                                                  final bool currentIsDark = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                                  return BouncyButton(
                                                    onTap: () => _toggleThemeWithBounce(context, currentIsDark),
                                                    child: Container(
                                                      width: 42,
                                                      height: 42,
                                                      decoration: BoxDecoration(
                                                        color: currentIsDark
                                                            ? const Color(0xFF1C1C1E)
                                                            : Colors.white,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: currentIsDark
                                                              ? const Color(0xFF27272A)
                                                              : const Color(0xFFF1F5F9),
                                                          width: 1.2,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        currentIsDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                                        color: currentIsDark ? const Color(0xFFFBBF24) : Colors.black87,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 10),
                                              ValueListenableBuilder<String>(
                                                valueListenable: HubnerApp.themeNotifier,
                                                builder: (context, currentTheme, _) {
                                                  final bool isDark = currentTheme == 'Gelap' || currentTheme == 'Hitam';
                                                  return NotificationBellIcon(isDark: isDark, size: 42);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
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
  }) {
    final latestMaterial = _getLatestMaterialTitle(stages);
    final scheduleText = _getScheduleSummary(schedules);
    final bool isDark = AppColors.isDarkMode;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
      builder: (context, userSnap) {
        String teacherName = 'Pak Dimas Supriadi, M.Pd';
        if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
          teacherName = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? 'Pak Dimas Supriadi, M.Pd';
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
                      height: (MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700) ? 168 : 195,
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
                          Positioned.fill(
                            child: Padding(
                              padding: (MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700)
                                  ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
                                  : const EdgeInsets.all(16),
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
                                onShowStats: () {
                                  _showAnalyticsDialog(context, projectId, title, stages, membersSnap);
                                },
                                onShowBarcode: () {
                                  if (MediaQuery.of(cardContext).size.width > 900) {
                                    cardSetState(() {
                                      isBarcodeFlipped = true;
                                    });
                                  } else {
                                    _showClassBarcodeDialog(context, projectId, title, accentColor);
                                  }
                                },
                              ),
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
                                  color: isDark ? Colors.black : const Color(0xFFFFD600),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Statistik',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 12,
                                      color: isDark ? Colors.white : Colors.black,
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
                                            icon: Icons.file_download_outlined,
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
    } else if (lowerTitle.contains('matematika') || lowerTitle.contains('geometri') || lowerTitle.contains('hitung')) {
      return Icons.calculate_rounded;
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
  }) {
    final majorText = major.isEmpty ? 'Umum' : major;
    final bool isMobile = MediaQuery.of(context).size.width < 700 || MediaQuery.of(context).size.shortestSide < 700;
    final bool isDark = AppColors.isDarkMode;

    if (isMobile) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Illustration placed on right more centered and bigger (aligned with top controls)!
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                height: 102,
                width: 102,
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
            ),
          ),
          // Main content column
          Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Animated White Time Capsule (Frameless & Taller with larger circle closer to corner)
                _AnimatedScheduleCapsule(
                  schedules: schedules,
                  accentColor: accentColor,
                  cardColor: backgroundColor,
                ),
                const SizedBox(height: 4),
                // Middle: Complete Subject Title (Flexible, full size for 1-2 lines, max 3 lines, NEVER TRUNCATED)
                Padding(
                  padding: const EdgeInsets.only(left: 10.0, right: 110.0),
                  child: Builder(
                    builder: (context) {
                      double calculatedFontSize = 19.5;
                      if (title.length > 55) {
                        calculatedFontSize = 16.0;
                      }
                      return Text(
                        title,
                        maxLines: 3,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: calculatedFontSize,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                // Bottom Row: [ Kelas Tag ] [ Siswa Tag ] [ Spacer ] [ Circular Graphic Statistik Button ] on right
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 2.0, right: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    // Kelas / Jurusan Tag (Full rounded pill)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.08),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            size: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            majorText,
                            style: GoogleFonts.dmSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Total Siswa Tag (Full rounded pill)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.08),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$totalStudents Siswa',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Statistik button at bottom right: Circle button with graphic chart icon!
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onShowStats,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.bar_chart_rounded,
                            size: 20,
                            color: isDark ? Colors.white : Colors.black87,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD97706),
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
  }) {
    final bool isDark = AppColors.isDarkMode;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
      builder: (context, userSnap) {
        String teacherName = 'Pak Dimas Supriadi, M.Pd';
        if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
          teacherName = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? 'Pak Dimas Supriadi, M.Pd';
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
                height: (MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700) ? 168 : 195,
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
                    Positioned.fill(
                      child: Padding(
                        padding: (MediaQuery.of(cardContext).size.width < 700 || MediaQuery.of(cardContext).size.shortestSide < 700)
                            ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
                            : const EdgeInsets.all(16),
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
                              color: isDark ? Colors.black : const Color(0xFFFFD600),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Statistik',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: isDark ? Colors.white : Colors.black,
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
  }) {
    final majorText = major.isEmpty ? 'Umum' : major;
    final bool isMobile = MediaQuery.of(context).size.width < 700 || MediaQuery.of(context).size.shortestSide < 700;
    final bool isDark = AppColors.isDarkMode;

    if (isMobile) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                height: 102,
                width: 102,
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
            ),
          ),
          Padding(
            padding: EdgeInsets.zero,
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
                  padding: const EdgeInsets.only(left: 10.0, right: 110.0),
                  child: Builder(
                    builder: (context) {
                      double calculatedFontSize = 19.5;
                      if (title.length > 55) {
                        calculatedFontSize = 16.0;
                      }
                      return Text(
                        title,
                        maxLines: 3,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: calculatedFontSize,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 2.0, right: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.08),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on_rounded,
                              size: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              majorText,
                              style: GoogleFonts.dmSans(
                                fontSize: 14.0,
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
                            borderRadius: BorderRadius.circular(24),
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.08),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.18),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  teacherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onShowStats,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.bar_chart_rounded,
                              size: 20,
                              color: isDark ? Colors.white : Colors.black87,
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
                  color: textColor,
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
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Progress Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress Belajar Mandiri',
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
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Badges Wrap directly on colored background
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildYellowBadge(Icons.edit_note_rounded, 'Tugas: $completedTugas/$totalTugas'),
            _buildYellowBadge(Icons.picture_as_pdf_outlined, 'PDF: $completedPdf/$totalPdf'),
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

  Widget _buildCalendarSlider([
    List<Map<String, dynamic>> allTasks = const [],
    String role = 'guru',
  ]) {
    final bool isDark = AppColors.isDarkMode;
    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);

    final List<DateTime> calendarDays = List.generate(14, (index) {
      return todayDate
          .subtract(const Duration(days: 3))
          .add(Duration(days: index));
    });

    String getSingleDayLetter(int weekday) {
      const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return letters[weekday - 1];
    }

    return SizedBox(
      height: 68,
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

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedCalendarDay = day;
              });
              if (role.toLowerCase() != 'guru') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TodoPage(initialDate: day),
                  ),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 68,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF18181B))
                    : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F3F5)),
                borderRadius: BorderRadius.circular(26),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    getSingleDayLetter(day.weekday),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.black87 : Colors.white)
                          : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  void _showQuickNotesOverlay() {
    _openNotesDropdown(context, _notesButtonKey);
  }

  void _openNotesDropdown(BuildContext context, GlobalKey buttonKey) {
    final RenderBox? renderBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final isDark = AppColors.isDarkMode;

    Offset offset = Offset.zero;
    Size size = Size.zero;
    if (renderBox != null) {
      size = renderBox.size;
      offset = renderBox.localToGlobal(Offset.zero);
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double top = offset.dy + size.height - 10;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notes')
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            // Tentukan lebar dinamis secara otomatis:
            // Jika semua judul catatan pendek (<= 10 char) -> 240px
            // Jika ada yang sedang (11-20 char) -> 275px
            // Jika ada yang panjang (> 20 char) -> 315px (batas maksimal)
            int maxTitleLength = 0;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final t = (data['title'] ?? '').toString();
              if (t.length > maxTitleLength) {
                maxTitleLength = t.length;
              }
            }

            double calculatedWidth = 240.0;
            if (maxTitleLength > 20) {
              calculatedWidth = 315.0;
            } else if (maxTitleLength > 10) {
              calculatedWidth = 275.0;
            }

            final double width = math.min(calculatedWidth, screenWidth - 32.0);
            double left = offset.dx;
            if (left + width > screenWidth - 16.0) {
              left = screenWidth - width - 16.0;
            }
            if (left < 16.0) {
              left = 16.0;
            }

            return Stack(
              children: [
                Positioned(
                  top: top,
                  left: left,
                  width: width,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: _QuickNotesDropdownContent(
                        isDark: isDark,
                        docs: docs,
                        isLoading: snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData,
                      ),
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
}

class _QuickNotesDropdownContent extends StatelessWidget {
  final bool isDark;
  final List<QueryDocumentSnapshot> docs;
  final bool isLoading;

  const _QuickNotesDropdownContent({
    required this.isDark,
    required this.docs,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with + Tambah (Catatan Cepat removed per request)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BouncyButton(
                  scaleDown: 0.92,
                  onTap: () {
                    Navigator.pop(context);
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Tambah',
                          style: AppTypography.buttonLabel(
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F52FC)),
                  ),
                ),
              ),
            )
          else if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 28,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Belum ada catatan',
                      style: AppTypography.timestamp(
                        fontSize: 13.0,
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                itemCount: docs.length > 5 ? 5 : docs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                ),
                itemBuilder: (context, index) {
                  final noteData = docs[index].data() as Map<String, dynamic>;
                  final noteId = docs[index].id;
                  final title = (noteData['title'] ?? 'Tanpa Judul').toString();
                  final content = (noteData['content'] ?? '').toString();

                  String formatDate(dynamic ts) {
                    if (ts == null) return 'Baru saja';
                    DateTime? dt;
                    if (ts is Timestamp) {
                      dt = ts.toDate();
                    } else if (ts is DateTime) {
                      dt = ts;
                    }
                    if (dt == null) return 'Baru saja';

                    final now = DateTime.now();
                    final hour = dt.hour.toString().padLeft(2, '0');
                    final minute = dt.minute.toString().padLeft(2, '0');
                    final day = dt.day.toString().padLeft(2, '0');
                    final month = dt.month.toString().padLeft(2, '0');

                    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                      return '$hour:$minute';
                    }
                    return '$day/$month $hour:$minute';
                  }

                  final dynamic rawUpdated = noteData['updatedAt'];
                  final dynamic rawCreated = noteData['createdAt'];
                  final String dateStr = formatDate(rawUpdated ?? rawCreated);

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NoteEditorPage(
                            noteId: noteId,
                            initialTitle: title,
                            initialContent: content,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Judul Catatan
                          Expanded(
                            child: Text(
                              title.isNotEmpty ? title : 'Tanpa Judul',
                              style: AppTypography.cardTitle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tanggal sama dengan style tanggal di Notif
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dateStr,
                                style: AppTypography.timestamp(
                                  fontSize: 13.0,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ],
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

class _AnimatedScheduleCapsule extends StatefulWidget {
  final List schedules;
  final Color accentColor;
  final Color cardColor;
  const _AnimatedScheduleCapsule({
    super.key,
    required this.schedules,
    this.accentColor = const Color(0xFF7F52FC),
    this.cardColor = Colors.white,
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

    if (widget.schedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.only(left: 4, right: 14, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : widget.accentColor.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Jadwal belum diatur',
              style: AppTypography.timestamp(
                color: isDark ? Colors.white : Colors.black87,
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
        padding: const EdgeInsets.only(left: 4, right: 14, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : widget.accentColor.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$dayStr, $timeStr',
              style: AppTypography.timestamp(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchAndNotesRow extends StatefulWidget {
  final VoidCallback onNotesTap;
  final ValueChanged<String> onSearchChanged;
  final bool isDark;
  final GlobalKey? notesKey;

  const _HomeSearchAndNotesRow({
    super.key,
    required this.onNotesTap,
    required this.onSearchChanged,
    required this.isDark,
    this.notesKey,
  });

  @override
  State<_HomeSearchAndNotesRow> createState() => _HomeSearchAndNotesRowState();
}

class _HomeSearchAndNotesRowState extends State<_HomeSearchAndNotesRow> {
  bool _isExpanded = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() {
      _isExpanded = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _collapse() {
    _focusNode.unfocus();
    _debounceTimer?.cancel();
    setState(() {
      _isExpanded = false;
      _controller.clear();
    });
    widget.onSearchChanged('');
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
    final isDark = widget.isDark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _isExpanded
          ? Container(
              key: const ValueKey('home_search_bar_expanded'),
              height: 48,
              padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white60 : Colors.black45,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('home_search_input'),
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      autofocus: false,
                      onChanged: (val) {
                        setState(() {});
                        _onChanged(val);
                      },
                      style: AppTypography.timestamp(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari kelas atau materi...',
                        hintStyle: AppTypography.subtitle(
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _collapse,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Row(
              key: const ValueKey('home_search_bar_collapsed'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tombol Catatan (Pill Frameless Netral)
                BouncyButton(
                  key: widget.notesKey,
                  onTap: widget.onNotesTap,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E1065) : const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: isDark ? const Color(0xFFD6A5F8) : const Color(0xFFEA580C),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Catatan',
                          style: AppTypography.buttonLabel(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),

                // Tombol Cari Lingkaran Netral
                BouncyButton(
                  onTap: _expand,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
