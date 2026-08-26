import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'class_page.dart';
import 'manage_members_page.dart';
import '../../../home/presentation/pages/chat_room_page.dart';
import '../../../home/presentation/widgets/animated_rainbow_background.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';

// Import Modular Classroom Tabs
import 'desktop_classroom/desktop_detail_kelas_tab.dart';
import 'desktop_classroom/desktop_tahapan_pembelajaran_tab.dart';
import 'desktop_classroom/desktop_jadwal_pembelajaran_tab.dart';
import 'desktop_classroom/desktop_kelola_anggota_tab.dart';
import 'desktop_classroom/desktop_tugas_tab.dart';
import 'desktop_classroom/desktop_quiz_tab.dart';
import 'desktop_classroom/desktop_gudang_materi_tab.dart';
import 'desktop_classroom/desktop_diskusi_tab.dart';

class DesktopClassroomPage extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const DesktopClassroomPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<DesktopClassroomPage> createState() => _DesktopClassroomPageState();
}

class _DesktopClassroomPageState extends State<DesktopClassroomPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isExiting = false;
  int _selectedTabIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _userRole = 'Guru';
  Map<String, dynamic>? _userData;

  final List<Map<String, dynamic>> _sidebarMenus = [
    {
      'title': 'Detail Kelas',
      'icon': Icons.dashboard_customize_rounded,
      'color': const Color(0xFF0284C7), // Sky Blue
    },
    {
      'title': 'Tahapan Pembelajaran',
      'icon': Icons.account_tree_rounded,
      'color': const Color(0xFF7C3AED), // Violet
    },
    {
      'title': 'Jadwal Pembelajaran',
      'icon': Icons.calendar_today_rounded,
      'color': const Color(0xFF059669), // Emerald
    },
    {
      'title': 'Kelola Anggota',
      'icon': Icons.people_alt_rounded,
      'color': const Color(0xFF4F46E5), // Indigo
    },
    {
      'title': 'Tugas',
      'icon': Icons.assignment_rounded,
      'color': const Color(0xFFE11D48), // Rose
    },
    {
      'title': 'Quiz',
      'icon': Icons.quiz_rounded,
      'color': const Color(0xFFD97706), // Amber
    },
    {
      'title': 'Gudang Materi',
      'icon': Icons.folder_shared_rounded,
      'color': const Color(0xFF0D9488), // Teal
    },
    {
      'title': 'Kelola Chat Diskusi',
      'icon': Icons.forum_rounded,
      'color': const Color(0xFF9333EA), // Purple
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _isLoading = false;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _userData = doc.data();
          _userRole = doc.data()!['role'] as String? ?? 'Guru';
        });
      }
    }
  }

  Future<void> _handleExitClassroom() async {
    setState(() {
      _isExiting = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Classroom Layout
          AnimatedRainbowBackground(
            child: Column(
              children: [
                // Unified Top Gradient Header Bar (Exact match with Beranda Desktop)
                _buildTopHeaderBar(),
                Expanded(
                  child: Row(
                    children: [
                      // Sidebar Navigation
                      _buildSidebar(),
                      // Main Content Area
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            color: Colors.transparent,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: Container(
                                key: ValueKey(_selectedTabIndex),
                                child: _buildSelectedTabContent(),
                              ),
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

          // Translucent White Blur Loading Overlay (Initial Load & Exit Load)
          AnimatedOpacity(
            opacity: (_isLoading || _isExiting) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: (_isLoading || _isExiting)
                ? _buildWhiteBlurThreeDotsLoadingOverlay(
                    message: _isExiting ? 'Keluar Classroom...' : 'Memuat Classroom...',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ─── Translucent White Blur Overlay with 3-Dot Loader ───
  Widget _buildWhiteBlurThreeDotsLoadingOverlay({required String message}) {
    return const SizedBox.shrink();
  }

  // ─── Unified Desktop Top Bar ───
  Widget _buildTopHeaderBar() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Pengguna';

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00C4CC),
            Color(0xFF3B52DF),
            Color(0xFF7D2AE8),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          // Hubner Edu Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hubner',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.normal,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              _buildCutoutEduBadge(),
            ],
          ),
          const SizedBox(width: 24),

          // Search Field
          Container(
            width: 280,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
                width: 1.0,
              ),
            ),
            child: TextField(
              style: AppTypography.subtitle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari sesuatu...',
                hintStyle: AppTypography.subtitle(color: Colors.white70),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          const Spacer(),

          // Class Code Copy Button
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.projectId));
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.key_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Kode: ${widget.projectId}',
                    style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.copy_rounded,
                    size: 11,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),



          // Role Label Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _userRole,
              style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),

          // User Profile Avatar
          Builder(
            builder: (context) {
              final avatarAsset = _userData?['avatar'] as String? ??
                  'assets/icon_pack/avatar/avatar_2.png';
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    avatarAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCutoutEduBadge() {
    return CustomPaint(
      size: const Size(38, 20),
      painter: CutoutTextPainter(
        text: 'edu',
        textStyle: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Sidebar Navigation ───
  Widget _buildSidebar() {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Back Button in Sidebar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: GestureDetector(
              onTap: _handleExitClassroom,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: const Color(0xFF000000),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kembali',
                        style: AppTypography.buttonLabel(color: const Color(0xFF000000), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Sidebar Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _sidebarMenus.length,
              itemBuilder: (context, index) {
                final menu = _sidebarMenus[index];
                final isSelected = _selectedTabIndex == index;

                return DesktopSidebarItem(
                  icon: menu['icon'] as IconData,
                  label: menu['title'] as String,
                  accentColor: menu['color'] as Color,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Selected Content Views (Delegated to Standalone Tab Files) ───
  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return DesktopDetailKelasTab(
          projectId: widget.projectId,
          projectTitle: widget.projectTitle,
        );
      case 1:
        return DesktopTahapanPembelajaranTab(
          projectId: widget.projectId,
          projectTitle: widget.projectTitle,
        );
      case 2:
        return DesktopJadwalPembelajaranTab(
          projectId: widget.projectId,
        );
      case 3:
        return DesktopKelolaAnggotaTab(
          projectId: widget.projectId,
          projectTitle: widget.projectTitle,
        );
      case 4:
        return DesktopTugasTab(
          projectId: widget.projectId,
          title: 'Kelola Tugas Kelas',
        );
      case 5:
        return DesktopQuizTab(
          projectId: widget.projectId,
          title: 'Kelola Quiz & Evaluasi',
        );
      case 6:
        return DesktopGudangMateriTab(
          projectId: widget.projectId,
        );
      case 7:
        return DesktopDiskusiTab(
          currentProjectId: widget.projectId,
          currentProjectTitle: widget.projectTitle,
        );
      default:
        return DesktopDetailKelasTab(
          projectId: widget.projectId,
          projectTitle: widget.projectTitle,
        );
    }
  }
}

// ─── Desktop Sidebar Item Widget ───
class DesktopSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const DesktopSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<DesktopSidebarItem> createState() => _DesktopSidebarItemState();
}

class _DesktopSidebarItemState extends State<DesktopSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    Color textColor;
    BoxDecoration? iconDecoration;

    if (widget.isSelected) {
      iconColor = widget.accentColor;
      textColor = const Color(0xFF1E293B);
      iconDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      );
    } else if (_isHovered) {
      iconColor = Colors.black87;
      textColor = Colors.black87;
      iconDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      );
    } else {
      iconColor = Colors.black45;
      textColor = Colors.black54;
      iconDecoration = null;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: iconDecoration,
                child: Icon(
                  widget.icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTypography.buttonLabel(color: textColor, fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cutout Text Painter for "edu" Badge ───
class CutoutTextPainter extends CustomPainter {
  final String text;
  final TextStyle textStyle;

  CutoutTextPainter({required this.text, required this.textStyle});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle.copyWith(color: Colors.black)),
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: size.width);

    final textOffset = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRRect(rrect, bgPaint);

    final cutPaint = Paint()..blendMode = BlendMode.dstOut;
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), cutPaint);
    tp.paint(canvas, textOffset);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
