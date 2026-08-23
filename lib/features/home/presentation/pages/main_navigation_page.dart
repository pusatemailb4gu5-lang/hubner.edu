import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/core/widgets/google_sign_in_button.dart';
import 'home_page.dart';
import 'chat_room_page.dart';
import 'manage_friends_page.dart';
import 'package:hubner/features/todo/presentation/pages/todo_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/features/notifications/presentation/pages/notifications_page.dart';

import 'package:hubner/features/projects/presentation/pages/laporan_page.dart' hide BouncyButton;
import 'package:hubner/features/projects/presentation/pages/monitoring_page.dart';
import 'package:hubner/features/splash/presentation/pages/splash_page.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';
import 'dart:ui' as ui;

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  String? _selectedProjectId;
  final Map<String, int> _lastUnreadCounts = {};

  // Persistent page instances to prevent flicker
  String? _lastRole;
  late List<Widget> _pages;
  bool _pagesInitialized = false;
  bool _isSidebarCollapsed = false;

  void _onNavigateTab(int index, {String? projectId}) {
    setState(() {
      _currentIndex = index;
      if (projectId != null) {
        _selectedProjectId = projectId;
        // Only rebuild monitoring page when projectId changes
        if (_lastRole != null && _lastRole!.toLowerCase() != 'guru') {
          _pages[3] = MonitoringPage(
            key: ValueKey(projectId),
            initialProjectId: projectId,
          );
        }
      }
    });
    _saveLastTab(index);
  }

  void _buildPages(bool isGuru) {
    _pages = [
      HomePage(onNavigateTab: _onNavigateTab),
      isGuru ? const LaporanPage() : const TodoPage(),
      const DiscussionTab(),
      isGuru
          ? const DocumentsTab()
          : MonitoringPage(
              key: ValueKey(_selectedProjectId ?? 'monitoring_default'),
              initialProjectId: _selectedProjectId,
            ),
      const ProfilePage(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadLastTab();
  }

  Future<void> _loadLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTab = prefs.getInt('lastTabIndex') ?? 0;
    if (mounted) {
      setState(() {
        _currentIndex = lastTab;
      });
    }
  }

  Future<void> _saveLastTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastTabIndex', index);
  }

  void _updateIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
    _saveLastTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
      builder: (context, userSnap) {
        Map<String, dynamic>? userData;
        String role = 'Siswa';

        if (userSnap.hasData && userSnap.data?.data() != null) {
          userData = userSnap.data!.data() as Map<String, dynamic>;
          role = userData['role'] ?? 'Siswa';
          
          if (!_pagesInitialized || _lastRole != role) {
            _lastRole = role;
            _pagesInitialized = true;
            _buildPages(role.toLowerCase() == 'guru');
          }
        } else if (!_pagesInitialized) {
          // Fallback initial build before stream resolves
          _pagesInitialized = true;
          _lastRole = 'Siswa';
          _buildPages(false);
        } else {
          role = _lastRole ?? 'Siswa';
        }

        final bool isGuru = role.toLowerCase() == 'guru';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('discussions').snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            int totalUnread = 0;
            
            // Calculate total unread count and trigger notifications
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final memberUids = data['memberUids'] as List?;
              if (memberUids != null && memberUids.contains(currentUid)) {
                final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
                final int unreadCount = unreadCounts?[currentUid] as int? ?? 0;
                totalUnread += unreadCount;
                
                final docId = doc.id;
                final lastKnown = _lastUnreadCounts[docId] ?? 0;

                if (!_lastUnreadCounts.containsKey(docId)) {
                  _lastUnreadCounts[docId] = unreadCount;
                } else if (unreadCount > lastKnown) {
                  _lastUnreadCounts[docId] = unreadCount;
                  
                  final channelName = data['channel'] ?? '#general';
                  final lastMsg = data['lastMessage'] ?? '';
                  
                  final bool isGroupChat = channelName.startsWith('#');
                  final displayMsg = isGroupChat ? '$channelName: $lastMsg' : lastMsg;
                  
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        key: ValueKey(docId),
                        content: Row(
                          children: [
                            const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.black,
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: 'Balas',
                          textColor: Colors.amber,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomPage(
                                  discussionId: docId,
                                  channelName: channelName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  });
                } else if (unreadCount < lastKnown) {
                  _lastUnreadCounts[docId] = unreadCount;
                }
              }
            }

            return ValueListenableBuilder<String>(
              valueListenable: HubnerApp.themeNotifier,
              builder: (context, themeMode, _) {
                final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';
                AppColors.themeMode = themeMode;

                final double screenWidth = MediaQuery.of(context).size.width;
                final double shortestSide = MediaQuery.of(context).size.shortestSide;
                final bool isTablet = screenWidth >= 700 && shortestSide >= 700;

                if (isTablet) {
                  return Scaffold(
                    backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    body: Container(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        // ─── Unified Gradient Header Bar (full width, no breaks) ───
                        Container(
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
                           GestureDetector(
                             onTap: () {
                               setState(() {
                                 _isSidebarCollapsed = !_isSidebarCollapsed;
                               });
                             },
                             behavior: HitTestBehavior.opaque,
                             child: MouseRegion(
                               cursor: SystemMouseCursors.click,
                               child: AnimatedContainer(
                                 duration: const Duration(milliseconds: 200),
                                 width: _isSidebarCollapsed ? 72 - 24 : 170 - 24,
                                 clipBehavior: Clip.antiAlias,
                                 decoration: const BoxDecoration(
                                   color: Colors.transparent,
                                 ),
                                 child: _isSidebarCollapsed
                                     ? Center(
                                         child: FittedBox(
                                           fit: BoxFit.scaleDown,
                                           child: _buildCutoutEduBadge(),
                                         ),
                                       )
                                     : Row(
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
                               ),
                             ),
                           ),

                          const SizedBox(width: 24), // gap to match sidebar right padding + content left padding

                          // Search field (glassmorphic)
                          Container(
                            width: 280,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1.0),
                            ),
                            child: TextField(
                              style: GoogleFonts.dmSans(fontSize: 15.2, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Cari sesuatu...',
                                hintStyle: GoogleFonts.dmSans(color: Colors.white70, fontSize: 15.2),
                                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),

                           const Spacer(),

                           // Notification Icon (glassmorphic)
                           GestureDetector(
                             onTap: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (_) => const NotificationsPage(),
                                 ),
                               );
                             },
                             child: Container(
                               width: 36,
                               height: 36,
                               decoration: BoxDecoration(
                                 color: Colors.white.withValues(alpha: 0.16),
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.0),
                               ),
                               child: const Icon(
                                 Icons.notifications_none_rounded,
                                 color: Colors.white,
                                 size: 20,
                               ),
                             ),
                           ),
                           const SizedBox(width: 16),

                           // User role label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Profile avatar
                          GestureDetector(
                            onTap: () {
                              _updateIndex(4);
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _currentIndex == 4 ? Colors.white : Colors.white60,
                                  width: _currentIndex == 4 ? 2 : 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  userData?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Row(
                        children: [
                          // Navigation Sidebar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isSidebarCollapsed ? 72 : 170,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                  right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  // Navigation Menu Items
                                  Expanded(
                                    child: ListView(
                                      padding: EdgeInsets.zero,
                                      children: [
                                        _buildSidebarItem(
                                          icon: Icons.grid_view_rounded,
                                          label: 'Beranda',
                                          index: 0,
                                        ),
                                        _buildSidebarItem(
                                          icon: Icons.assignment_outlined,
                                          label: isGuru ? 'Laporan' : 'Tugas',
                                          index: 1,
                                        ),
                                        _buildSidebarItem(
                                          icon: Icons.chat_bubble_outline_rounded,
                                          label: 'Diskusi',
                                          index: 2,
                                          unreadCount: totalUnread,
                                        ),
                                        _buildSidebarItem(
                                          icon: isGuru ? Icons.article_outlined : Icons.analytics_outlined,
                                          label: isGuru ? 'Dokumen' : 'Monitoring',
                                          index: 3,
                                        ),
                                        _buildSidebarItem(
                                          icon: Icons.person_outline_rounded,
                                          label: 'Profil',
                                          index: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Main Content Area
                          Expanded(
                            child: IndexedStack(index: _currentIndex, children: _pages),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: Scaffold(
                backgroundColor: isDark ? Colors.black : Colors.white,
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: IndexedStack(index: _currentIndex, children: _pages),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 14
                          : 26,
                      child: _FluidIPhoneBottomNavBar(
                        currentIndex: _currentIndex,
                        onTabSelected: _updateIndex,
                        isDark: isDark,
                        isGuru: isGuru,
                        totalUnread: totalUnread,
                      ),
                    ),
                  ],
                ),
              ),
            );
              },
            );
          }
        );
      }
    );
  }

  Widget _buildCutoutEduBadge() {
    return CustomPaint(
      size: const Size(38, 20),
      painter: CutoutTextPainter(
        text: 'edu',
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    int unreadCount = 0,
  }) {
    return SidebarNavigationItem(
      icon: icon,
      label: label,
      index: index,
      isSelected: _currentIndex == index,
      isCollapsed: _isSidebarCollapsed,
      unreadCount: unreadCount,
      onTap: () => _updateIndex(index),
    );
  }
}

class _FluidIPhoneBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isDark;
  final bool isGuru;
  final int totalUnread;

  const _FluidIPhoneBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.isDark,
    required this.isGuru,
    required this.totalUnread,
  });

  @override
  State<_FluidIPhoneBottomNavBar> createState() => _FluidIPhoneBottomNavBarState();
}

class _FluidIPhoneBottomNavBarState extends State<_FluidIPhoneBottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnim;
  late Animation<double> _pressStretchAnim;
  late Animation<double> _anim;
  double _currentPillPosition = 0.0;
  bool _isDragging = false;
  int _lastHapticIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentPillPosition = widget.currentIndex.toDouble();
    _lastHapticIndex = widget.currentIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _pressScaleAnim = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.elasticOut,
      ),
    );
    _pressStretchAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _FluidIPhoneBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      _animateTo(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onPressStart() {
    _pressController.forward();
    HapticFeedback.selectionClick();
  }

  void _onPressEnd() {
    _pressController.reverse();
  }

  void _animateTo(double target) {
    _anim = Tween<double>(
      begin: _currentPillPosition,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    )..addListener(() {
        setState(() {
          _currentPillPosition = _anim.value;
        });
      });
    _animController.forward(from: 0.0);
  }

  void _handleDrag(double localDx, double totalWidth) {
    final double tabWidth = totalWidth / 5;
    final double rawPos = (localDx / tabWidth) - 0.5;
    final double clampedPos = rawPos.clamp(0.0, 4.0);

    final int targetIdx = clampedPos.round().clamp(0, 4);
    if (targetIdx != _lastHapticIndex) {
      HapticFeedback.selectionClick();
      _lastHapticIndex = targetIdx;
    }

    setState(() {
      _currentPillPosition = clampedPos;
    });
  }

  void _finishDrag() {
    final int finalIndex = _currentPillPosition.round().clamp(0, 4);
    _isDragging = false;
    _onPressEnd();
    _animateTo(finalIndex.toDouble());
    if (finalIndex != widget.currentIndex) {
      widget.onTabSelected(finalIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final bool isGuru = widget.isGuru;

    final navItems = [
      {'icon': Icons.grid_view_rounded, 'label': 'Beranda'},
      {'icon': Icons.assignment_outlined, 'label': isGuru ? 'Laporan' : 'Tugas'},
      {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Diskusi'},
      {'icon': isGuru ? Icons.article_outlined : Icons.analytics_outlined, 'label': isGuru ? 'Dokumen' : 'Monitoring'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profil'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double tabWidth = totalWidth / 5;

        // Fluid liquid pill calculation perfectly centered on the active tab
        final double pillWidth = tabWidth - 6.0;
        final double pillCenter = (_currentPillPosition + 0.5) * tabWidth;
        final double pillLeft = (pillCenter - (pillWidth / 2) - 2.0).clamp(2.0, totalWidth - pillWidth - 5.0);

        return GestureDetector(
          onTapDown: (details) {
            _onPressStart();
            final int index = (details.localPosition.dx / tabWidth).floor().clamp(0, 4);
            _animateTo(index.toDouble());
            widget.onTabSelected(index);
          },
          onTapUp: (_) => _onPressEnd(),
          onTapCancel: () => _onPressEnd(),
          onHorizontalDragStart: (details) {
            _isDragging = true;
            _onPressStart();
            _animController.stop();
            _handleDrag(details.localPosition.dx, totalWidth);
          },
          onHorizontalDragUpdate: (details) {
            _handleDrag(details.localPosition.dx, totalWidth);
          },
          onHorizontalDragEnd: (details) {
            _finishDrag();
          },
          onHorizontalDragCancel: () {
            _finishDrag();
          },
          child: Container(
            height: 58,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 1. Fluid Liquid Sliding Pill Indicator (Darker & Prominent on Active)
                Positioned(
                  left: pillLeft,
                  top: 4,
                  bottom: 4,
                  child: AnimatedBuilder(
                    animation: _pressController,
                    builder: (context, child) {
                      return Transform.scale(
                        scaleX: _pressStretchAnim.value,
                        scaleY: _pressScaleAnim.value,
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: Container(
                      width: pillWidth,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.28)
                              : const Color(0xFF0F172A).withValues(alpha: 0.12),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. Interactive Navigation Items (Protected with FittedBox against overflow)
              Row(
                children: List.generate(5, (index) {
                  final item = navItems[index];
                  final IconData icon = item['icon'] as IconData;
                  final String label = item['label'] as String;
                  final int unread = (index == 2) ? widget.totalUnread : 0;

                  // Calculate distance from continuous pill position
                  final double dist = (index - _currentPillPosition).abs();
                  final double activeFactor = (1.0 - dist).clamp(0.0, 1.0);
                  final bool isClosest = dist < 0.5;

                  return Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Transform.scale(
                                  scale: 1.0 + (activeFactor * 0.12),
                                  child: Icon(
                                    icon,
                                    color: isDark
                                        ? Color.lerp(Colors.white38, Colors.white, activeFactor)
                                        : Color.lerp(const Color(0xFF64748B), const Color(0xFF0F172A), activeFactor),
                                    size: 21,
                                  ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    top: -4,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$unread',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (isClosest && activeFactor > 0.3) ...[
                              const SizedBox(width: 4),
                              Opacity(
                                opacity: activeFactor,
                                child: Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );
    },
  );
}
}

// --- Dynamic Discussion Tab (Chat Threads) ---
class DiscussionTab extends StatefulWidget {
  const DiscussionTab({super.key});

  @override
  State<DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends State<DiscussionTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _discussionScrollController = ScrollController();
  final ValueNotifier<double> _headerScrollOffsetNotifier = ValueNotifier<double>(0.0);

  // Active chat/discussion state for Desktop split view
  String? _activeDiscussionId;
  String? _activeChannelName;
  String? _activeProjectId;

  @override
  void initState() {
    super.initState();
    _discussionScrollController.addListener(() {
      _headerScrollOffsetNotifier.value = _discussionScrollController.offset;
    });
  }

  @override
  void dispose() {
    _discussionScrollController.dispose();
    _headerScrollOffsetNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProjects(String currentUid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    final List<String> projectIds = List<String>.from(userDoc.data()?['projectIds'] ?? []);

    final ownedQuery = await FirebaseFirestore.instance
        .collection('projects')
        .where('ownerUid', isEqualTo: currentUid)
        .get();

    final Map<String, Map<String, dynamic>> projectMap = {};
    for (var doc in ownedQuery.docs) {
      projectMap[doc.id] = {
        'id': doc.id,
        'name': doc.data()['name'] ?? 'Proyek Tanpa Nama',
      };
    }

    if (projectIds.isNotEmpty) {
      final safeIds = projectIds.take(30).toList();
      final query = await FirebaseFirestore.instance
          .collection('projects')
          .where(FieldPath.documentId, whereIn: safeIds)
          .get();
      for (var doc in query.docs) {
        projectMap[doc.id] = {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Proyek Tanpa Nama',
        };
      }
    }

    return projectMap.values.toList();
  }

  Future<List<Map<String, dynamic>>> _loadProjectMembers(String projectId) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('projectIds', arrayContains: projectId)
        .get();

    return query.docs.map((doc) => {
      'uid': doc.id,
      'name': doc.data()['name'] ?? 'User',
      'userId': doc.data()['userId'] ?? '',
      'avatar': doc.data()['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
    }).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadClassroomGroupedContacts(String currentUid) async {
    final projects = await _loadProjects(currentUid);
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var p in projects) {
      final pId = p['id'] as String;
      final pName = (p['name'] ?? 'Classroom').toString();
      final members = await _loadProjectMembers(pId);
      final List<Map<String, dynamic>> classContacts = [];
      for (var m in members) {
        if (m['uid'] != currentUid) {
          classContacts.add({
            'uid': m['uid'],
            'name': m['name'] ?? 'User',
            'userId': m['userId'] ?? '',
            'avatar': m['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
            'role': m['role'] ?? 'Siswa',
            'classroomName': pName,
          });
        }
      }
      if (classContacts.isNotEmpty) {
        grouped[pName] = classContacts;
      }
    }

    if (grouped.isEmpty) {
      final query = await FirebaseFirestore.instance.collection('users').limit(20).get();
      final list = query.docs
          .where((d) => d.id != currentUid)
          .map((doc) => {
                'uid': doc.id,
                'name': doc.data()['name'] ?? 'User',
                'userId': doc.data()['userId'] ?? '',
                'avatar': doc.data()['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
                'role': doc.data()['role'] ?? 'Siswa',
                'classroomName': 'Kontak Umum',
              })
          .toList();
      if (list.isNotEmpty) {
        grouped['Kontak'] = list;
      }
    }

    return grouped;
  }

  Future<String?> _loadProjectName(String projectId) async {
    if (projectId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
    return doc.data()?['name'] as String?;
  }

  Future<void> _openDirectChatWithContact(BuildContext context, String currentUid, Map<String, dynamic> contact) async {
    final String targetUid = contact['uid'];
    final String targetName = contact['name'];
    final String targetAvatar = contact['avatar'] ?? 'assets/icon_pack/chat/chat_1.png';

    final existingQuery = await FirebaseFirestore.instance
        .collection('discussions')
        .where('memberUids', arrayContains: currentUid)
        .get();

    String? existingDocId;
    String? existingChannel;
    for (var doc in existingQuery.docs) {
      final data = doc.data();
      final List members = data['memberUids'] as List? ?? [];
      final bool isDirect = data['isDirect'] == true || (data['projectId'] ?? '').toString().isEmpty;
      if (isDirect && members.contains(targetUid) && members.length == 2) {
        existingDocId = doc.id;
        existingChannel = data['channel'] ?? targetName;
        break;
      }
    }

    if (existingDocId != null) {
      // Unhide if previously hidden for current user
      await FirebaseFirestore.instance.collection('discussions').doc(existingDocId).update({
        'hiddenForUids': FieldValue.arrayRemove([currentUid]),
        'clearedByUids': FieldValue.arrayRemove([currentUid]),
      });

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              discussionId: existingDocId!,
              channelName: existingChannel ?? targetName,
            ),
          ),
        );
      }
      return;
    }

    final newDoc = await FirebaseFirestore.instance.collection('discussions').add({
      'projectId': '',
      'isDirect': true,
      'channel': targetName,
      'title': targetName,
      'avatar': targetAvatar,
      'lastMessage': 'Mulai percakapan langsung...',
      'time': 'Sekarang',
      'memberUids': [currentUid, targetUid],
      'creatorUid': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'colorIndex': Random().nextInt(5),
      'unreadCounts': {
        currentUid: 0,
        targetUid: 0,
      },
    });

    if (context.mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            discussionId: newDoc.id,
            channelName: targetName,
          ),
        ),
      );
    }
  }

  void _showCreateDiscussionDialog(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _WhatsAppStyleNewChatModal(
          currentUid: currentUid,
          isDark: isDark,
          onLoadProjects: () => _loadProjects(currentUid),
          onLoadProjectMembers: (projectId) => _loadProjectMembers(projectId),
          onLoadClassroomGroupedContacts: () => _loadClassroomGroupedContacts(currentUid),
          onDirectChatTap: (contact) => _openDirectChatWithContact(bottomSheetContext, currentUid, contact),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final safeBottomPadding = MediaQuery.of(context).padding.bottom;
    final bool isDesktop = MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.shortestSide >= 700;
    final bool isDark = AppColors.isDarkMode;

    final double bottomNavHeight = 64.0;
    final double bottomNavOffset = safeBottomPadding > 0 ? safeBottomPadding + 14 : 26;
    final double fabBottomPosition = bottomNavOffset + bottomNavHeight + 16;
    final double listBottomPadding = fabBottomPosition + 60;

    final Widget listContent = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('discussions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final memberUids = data['memberUids'] as List?;
          if (memberUids != null && !memberUids.contains(currentUid)) {
            return false;
          }

          final bool isGroupChat = (data['channel'] ?? '').toString().startsWith('#') ||
              (data['projectId'] ?? '').toString().isNotEmpty;
          final bool isDirect = data['isDirect'] == true || !isGroupChat;
          final String lastMsg = (data['lastMessage'] ?? '').toString();
          final bool hasRealMessages = data['hasMessages'] == true ||
              (lastMsg.isNotEmpty &&
                  lastMsg != 'Mulai percakapan langsung...' &&
                  lastMsg != 'Mulai diskusi baru...');

          // Logic 1: If private chat has no messages sent yet, do not display in discussion list
          if (isDirect && !hasRealMessages) {
            return false;
          }

          // Logic 2: If private chat was cleared / deleted for current user, do not display
          final List hiddenForUids = (data['hiddenForUids'] ?? data['clearedByUids']) as List? ?? [];
          if (hiddenForUids.contains(currentUid)) {
            return false;
          }

          final title = (data['title'] ?? '').toString().toLowerCase();
          final channel = (data['channel'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return title.contains(q) || channel.contains(q);
        }).toList();

        if (isDesktop) {
          final bool activeExists = filteredDocs.any((d) => d.id == _activeDiscussionId);
          if (!activeExists && filteredDocs.isNotEmpty) {
            final firstDoc = filteredDocs[0];
            final firstData = firstDoc.data() as Map<String, dynamic>;
            _activeDiscussionId = firstDoc.id;
            _activeChannelName = firstData['channel'] ?? '#general';
            _activeProjectId = firstData['projectId'] as String?;
          }
        }

        return CustomScrollView(
          controller: _discussionScrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Top Scrollable Header & Search Bar (Scrolls away seamlessly!)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top In-List Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Diskusi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 23.4,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        BouncyButton(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ManageFriendsPage()),
                            );
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF18181B) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.people_outline_rounded,
                              color: isDark ? Colors.white : Colors.black87,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar (Rounded 28 & Styled match Home Page - scrolls away!)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Cari thread diskusi...',
                                hintStyle: GoogleFonts.dmSans(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white60 : Colors.black45,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            if (filteredDocs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 40),
                  child: Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Belum ada diskusi. Buat sekarang!'
                          : 'Tidak ada diskusi yang cocok.',
                      style: GoogleFonts.dmSans(
                        fontSize: 15.2,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: filteredDocs.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                  indent: 76,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final docId = filteredDocs[index].id;
                  final chat = filteredDocs[index].data() as Map<String, dynamic>;
                  final channelName = chat['channel'] ?? '#general';
                  final title = chat['title'] ?? 'Diskusi';
                  final lastMsg = chat['lastMessage'] ?? '';
                  final time = chat['time'] ?? '';
                  final avatar = chat['avatar'] as String? ?? 'assets/icon_pack/chat/chat_1.png';
                  final projectId = chat['projectId'] as String? ?? '';

                  final Map<String, dynamic>? unreadCounts = chat['unreadCounts'] as Map<String, dynamic>?;
                  final int unreadCount = unreadCounts?[currentUid] as int? ?? 0;

                  return FutureBuilder<String?>(
                    future: _loadProjectName(projectId),
                    builder: (context, projectSnapshot) {
                      final projectName = projectSnapshot.data ?? '';
                      final bool isGroupChat = channelName.startsWith('#') || projectId.isNotEmpty;

                      return Dismissible(
                        key: Key('disc_$docId'),
                        direction: isGroupChat ? DismissDirection.none : DismissDirection.endToStart,
                        background: Container(color: Colors.transparent),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.delete_sweep_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Hapus Chat',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (isGroupChat) return false;
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text(
                                'Kosongkan Chat Pribadi?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              content: Text(
                                'Chat ini akan dihapus dari daftar Anda dan hanya dikosongkan untuk Anda. Riwayat akan muncul kembali jika ada pesan baru.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    'Batal',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    'Hapus untuk Saya',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (direction) async {
                          await FirebaseFirestore.instance.collection('discussions').doc(docId).update({
                            'hiddenForUids': FieldValue.arrayUnion([currentUid]),
                            'clearedByUids': FieldValue.arrayUnion([currentUid]),
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Chat pribadi dengan $title telah dibersihkan.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Material(
                        color: (isDesktop && _activeDiscussionId == docId)
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (isDesktop) {
                              setState(() {
                                _activeDiscussionId = docId;
                                _activeChannelName = channelName;
                                _activeProjectId = projectId;
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomPage(
                                    discussionId: docId,
                                    channelName: channelName,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Transform.scale(
                                      scale: 1.35,
                                      child: Image.asset(
                                        avatar,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) => Icon(
                                          Icons.forum_outlined,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (isGroupChat) ...[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                projectName.isNotEmpty
                                                    ? '$channelName • Kelas $projectName'
                                                    : channelName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12.9,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              time,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12.9,
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          title,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ] else ...[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              time,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12.9,
                                                color: isDark ? Colors.white38 : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unreadCount > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white : Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$unreadCount',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isDark ? Colors.black : Colors.white,
                                          fontSize: 11.7,
                                          fontWeight: FontWeight.bold,
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
                      );
                    },
                  );
                },
              ),

            // Bottom space for floating bottom navigation & FAB
            SliverToBoxAdapter(
              child: SizedBox(
                height: isDesktop ? safeBottomPadding + 20 : listBottomPadding,
              ),
            ),
          ],
        );
      },
    );

    if (isDesktop) {
      return Row(
        children: [
          // Left Pane: Discussion list
          Container(
            width: 380,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: listContent,
                ),
                Positioned(
                  bottom: safeBottomPadding + 20,
                  right: 16,
                  child: BouncyButton(
                    onTap: () => _showCreateDiscussionDialog(context),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right Pane: Active Chat Room
          Expanded(
            child: _activeDiscussionId != null
                ? ChatRoomPage(
                    key: ValueKey(_activeDiscussionId),
                    discussionId: _activeDiscussionId!,
                    channelName: _activeChannelName!,
                    projectId: _activeProjectId,
                    isEmbedded: true,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pilih diskusi untuk memulai chat',
                          style: GoogleFonts.dmSans(
                            fontSize: 16.4,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
        ),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: listContent,
            ),

            // Sticky Header with blur/gradient when scrolling down (Like Home Page)
            ValueListenableBuilder<double>(
              valueListenable: _headerScrollOffsetNotifier,
              builder: (context, scrollOffset, _) {
                if (scrollOffset <= 20.0) {
                  return const SizedBox.shrink();
                }
                final double t = ((scrollOffset - 20.0) / 40.0).clamp(0.0, 1.0);

                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: t,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.of(context).padding.top + 6,
                        16,
                        16,
                      ),
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
                          const SizedBox(width: 42),
                          Text(
                            'Diskusi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          BouncyButton(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ManageFriendsPage()),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.people_outline_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Elevated Floating Action Button (+), well above bottom navigation menu
            Positioned(
              bottom: fabBottomPosition,
              right: 16,
              child: BouncyButton(
                onTap: () => _showCreateDiscussionDialog(context),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: isDark ? Colors.black : Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// WHATSAPP STYLE NEW CHAT / DISCUSSION BOTTOM SHEET MODAL
// =========================================================================
class _WhatsAppStyleNewChatModal extends StatefulWidget {
  final String currentUid;
  final bool isDark;
  final Future<List<Map<String, dynamic>>> Function() onLoadProjects;
  final Future<List<Map<String, dynamic>>> Function(String projectId) onLoadProjectMembers;
  final Future<Map<String, List<Map<String, dynamic>>>> Function() onLoadClassroomGroupedContacts;
  final Function(Map<String, dynamic> contact) onDirectChatTap;

  const _WhatsAppStyleNewChatModal({
    required this.currentUid,
    required this.isDark,
    required this.onLoadProjects,
    required this.onLoadProjectMembers,
    required this.onLoadClassroomGroupedContacts,
    required this.onDirectChatTap,
  });

  @override
  State<_WhatsAppStyleNewChatModal> createState() => _WhatsAppStyleNewChatModalState();
}

class _WhatsAppStyleNewChatModalState extends State<_WhatsAppStyleNewChatModal> {
  // Step 0 = List Kontak dikelompokkan berdasarkan #Nama Kelas (dengan collapse/expand)
  // Step 1 = Pilih Classroom (Dropdown persis di Laporan tanpa gap) & Checklist Anggota (Index 0 = Seluruh Anggota Kelas)
  // Step 2 = Info Detail Grup & Tumpukan Avatar Anggota
  int _step = 0;

  String _contactSearch = '';
  String _memberSearch = '';
  final TextEditingController _modalSearchController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _channelController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  final GlobalKey _dropdownKey = GlobalKey();

  String? _selectedProjectId;
  String _selectedProjectName = '';
  List<Map<String, dynamic>> _projectMembers = [];
  List<String> _selectedMemberUids = []; // Non-checklist by default
  String _selectedAvatar = 'assets/icon_pack/chat/chat_1.png';
  bool _isLoadingMembers = false;
  bool _isCreating = false;

  final Set<String> _collapsedClassrooms = {};

  @override
  void dispose() {
    _modalSearchController.dispose();
    _memberSearchController.dispose();
    _channelController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _openClassDropdownMenu(BuildContext context, List<Map<String, dynamic>> projects) {
    final RenderBox? renderBox = _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    final isDark = widget.isDark;

    Offset offset = Offset.zero;
    Size size = Size.zero;
    if (renderBox != null) {
      size = renderBox.size;
      offset = renderBox.localToGlobal(Offset.zero);
    }

    final double top = offset.dy + size.height;
    final double left = offset.dx;
    final double width = size.width;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) {
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
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final p = projects[index];
                        final pId = p['id'];
                        final pName = p['name'] ?? 'Classroom';
                        final bool isSelected = pId == _selectedProjectId;

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            setState(() {
                              _selectedProjectId = pId;
                              _selectedProjectName = pName;
                              _projectMembers = [];
                              _selectedMemberUids = []; // Non checklist by default
                              _isLoadingMembers = true;
                            });
                            widget.onLoadProjectMembers(pId).then((members) {
                              if (mounted) {
                                setState(() {
                                  _projectMembers = members;
                                  _isLoadingMembers = false;
                                });
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: Color(0xFF0F766E),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    pName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? const Color(0xFF0F766E)
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_rounded, color: Color(0xFF0F766E), size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStackedAvatars(List<Map<String, dynamic>> selectedMembers, bool isDark) {
    if (selectedMembers.isEmpty) return const SizedBox.shrink();
    final int maxDisplay = 5;
    final int displayCount = selectedMembers.length > maxDisplay ? maxDisplay : selectedMembers.length;
    final int remaining = selectedMembers.length - displayCount;

    return SizedBox(
      height: 38,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 24.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    width: 2.0,
                  ),
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                ),
                child: ClipOval(
                  child: Image.asset(
                    selectedMembers[i]['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayCount * 24.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createDiscussionGroup() async {
    final chan = _channelController.text.trim();
    final ttl = _titleController.text.trim();
    if (chan.isEmpty || ttl.isEmpty || _selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan lengkapi nama grup dan saluran.')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final List<String> finalMembers = List<String>.from(_selectedMemberUids);
      if (!finalMembers.contains(widget.currentUid)) {
        finalMembers.add(widget.currentUid);
      }

      final channelName = chan.startsWith('#') ? chan : '#$chan';
      final newDoc = await FirebaseFirestore.instance.collection('discussions').add({
        'projectId': _selectedProjectId,
        'channel': channelName,
        'title': ttl,
        'avatar': _selectedAvatar,
        'lastMessage': '',
        'hasMessages': false,
        'time': 'Sekarang',
        'memberUids': finalMembers,
        'creatorUid': widget.currentUid,
        'createdAt': FieldValue.serverTimestamp(),
        'colorIndex': Random().nextInt(5),
        'unreadCounts': {
          for (var mUid in finalMembers) mUid: 0
        },
        'hiddenForUids': [],
        'clearedByUids': [],
      });

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              discussionId: newDoc.id,
              channelName: channelName,
              projectId: _selectedProjectId,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup diskusi kelas berhasil dibuat!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat diskusi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left action / title
                Row(
                  children: [
                    if (_step == 1)
                      BouncyButton(
                        onTap: () {
                          setState(() {
                            _step = 0;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 19,
                          ),
                        ),
                      )
                    else if (_step == 2)
                      BouncyButton(
                        onTap: () {
                          setState(() {
                            _step = 1;
                          });
                        },
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
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 19,
                          ),
                        ),
                      ),
                    Text(
                      _step == 0
                          ? 'Diskusi Baru'
                          : (_step == 1 ? 'Buat Diskusi Kelas' : 'Info Grup Diskusi'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),

                // Right action (X on step 0, "Berikutnya" on step 1, "Buat" on step 2)
                if (_step == 0)
                  BouncyButton(
                    onTap: () => Navigator.pop(context),
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
                        size: 19,
                      ),
                    ),
                  )
                else if (_step == 1)
                  GestureDetector(
                    onTap: () {
                      if (_selectedProjectId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Silakan pilih classroom terlebih dahulu.')),
                        );
                        return;
                      }
                      if (_selectedMemberUids.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih minimal 1 anggota diskusi.')),
                        );
                        return;
                      }
                      setState(() {
                        _step = 2;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_selectedProjectId != null && _selectedMemberUids.isNotEmpty)
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Selanjutnya',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                          color: (_selectedProjectId != null && _selectedMemberUids.isNotEmpty)
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ),
                  )
                else if (_step == 2)
                  GestureDetector(
                    onTap: _isCreating ? null : _createDiscussionGroup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _isCreating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : Text(
                              'Buat',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // STEP 0: KONTAK LIST BERDASARKAN #NAMA KELAS (COLLAPSIBLE / HIDEABLE)
          if (_step == 0) ...[
            // Search Box (Home search pill style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
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
                      color: isDark ? Colors.white60 : Colors.black45,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _modalSearchController,
                        onChanged: (val) {
                          setState(() {
                            _contactSearch = val.trim().toLowerCase();
                          });
                        },
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari kontak atau kelas',
                          hintStyle: GoogleFonts.dmSans(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_contactSearch.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _modalSearchController.clear();
                          setState(() {
                            _contactSearch = '';
                          });
                        },
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white60 : Colors.black45,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Opsi Buat Diskusi Kelas Tile
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _step = 1;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0F766E),
                        ),
                        child: const Icon(
                          Icons.group_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat Diskusi Kelas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih kelas & anggota untuk diskusi kelompok baru',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
              height: 16,
              thickness: 1,
              indent: 16,
              endIndent: 16,
            ),

            Expanded(
              child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                future: widget.onLoadClassroomGroupedContacts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  final grouped = snapshot.data ?? {};
                  if (grouped.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada kontak ditemukan.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    );
                  }

                  // Filter by search query
                  final Map<String, List<Map<String, dynamic>>> filteredGrouped = {};
                  grouped.forEach((className, members) {
                    final matchingMembers = members.where((c) {
                      final name = (c['name'] ?? '').toString().toLowerCase();
                      final id = (c['userId'] ?? '').toString().toLowerCase();
                      final cName = className.toLowerCase();
                      return name.contains(_contactSearch) ||
                          id.contains(_contactSearch) ||
                          cName.contains(_contactSearch);
                    }).toList();

                    if (matchingMembers.isNotEmpty) {
                      filteredGrouped[className] = matchingMembers;
                    }
                  });

                  if (filteredGrouped.isEmpty) {
                    return Center(
                      child: Text(
                        'Tidak ada kontak yang cocok.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filteredGrouped.keys.length,
                    itemBuilder: (ctx, groupIdx) {
                      final className = filteredGrouped.keys.elementAt(groupIdx);
                      final members = filteredGrouped[className]!;
                      final bool isCollapsed = _collapsedClassrooms.contains(className);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header #Nama Kelas with collapse toggle
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isCollapsed) {
                                  _collapsedClassrooms.remove(className);
                                } else {
                                  _collapsedClassrooms.add(className);
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '#',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      className,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF27272A) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${members.length} Kontak',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    isCollapsed
                                        ? Icons.keyboard_arrow_down_rounded
                                        : Icons.keyboard_arrow_up_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white60 : Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Contacts under this class (if not collapsed)
                          if (!isCollapsed)
                            ...members.map((contact) {
                              final avatarPath = contact['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';
                              final name = contact['name'] ?? 'User';
                              final role = contact['role'] ?? 'Siswa';
                              final userId = contact['userId'] ?? '';

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onDirectChatTap(contact),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: Transform.scale(
                                              scale: 1.35,
                                              child: Image.asset(avatarPath, fit: BoxFit.cover),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$role ${userId.isNotEmpty ? '· ID: $userId' : ''}',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 12.0,
                                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Chat',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ]

          // STEP 1: PILIH CLASSROOM (DROPDOWN PERSIS DI LAPORAN) & CHECKLIST ANGGOTA
          else if (_step == 1) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Classroom',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: widget.onLoadProjects(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }

                        final projects = snapshot.data ?? [];
                        if (projects.isEmpty) {
                          return Text(
                            'Anda belum terhubung ke classroom.',
                            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.redAccent),
                          );
                        }

                        // Model dropdown sama persis dengan di Laporan
                        return GestureDetector(
                          key: _dropdownKey,
                          onTap: () => _openClassDropdownMenu(context, projects),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: Color(0xFF0F766E),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedProjectName.isNotEmpty
                                        ? _selectedProjectName
                                        : 'Pilih Classroom',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: _selectedProjectName.isNotEmpty
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _selectedProjectName.isNotEmpty
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? Colors.white38 : Colors.black38),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    if (_selectedProjectId != null) ...[
                      const SizedBox(height: 12),
                      // Search Members Field (Model sama persis dengan pencarian chat di halaman utama)
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: isDark ? Colors.white60 : Colors.black45,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _memberSearchController,
                                onChanged: (val) {
                                  setState(() {
                                    _memberSearch = val.trim().toLowerCase();
                                  });
                                },
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Cari anggota kelas',
                                  hintStyle: GoogleFonts.dmSans(
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontSize: 13.5,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            if (_memberSearch.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _memberSearchController.clear();
                                  setState(() {
                                    _memberSearch = '';
                                  });
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  color: isDark ? Colors.white60 : Colors.black45,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Header Counter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Pilih Anggota (${_selectedMemberUids.length} dipilih)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      if (_isLoadingMembers)
                        const SizedBox.shrink()
                      else ...[
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final filteredMembers = _projectMembers.where((m) {
                                final name = (m['name'] ?? '').toString().toLowerCase();
                                final id = (m['userId'] ?? '').toString().toLowerCase();
                                return name.contains(_memberSearch) || id.contains(_memberSearch);
                              }).toList();

                              final bool isAllSelected = _projectMembers.isNotEmpty &&
                                  _selectedMemberUids.length >= _projectMembers.length;

                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: (_memberSearch.isEmpty ? 1 : 0) + filteredMembers.length,
                                separatorBuilder: (_, __) => Divider(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                  height: 1,
                                  indent: 64,
                                ),
                                itemBuilder: (ctx, idx) {
                                  // Index 0: Seluruh Anggota Kelas dengan ikon grup
                                  if (_memberSearch.isEmpty && idx == 0) {
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                        ),
                                        child: const Icon(
                                          Icons.groups_rounded,
                                          color: Color(0xFF0F766E),
                                          size: 24,
                                        ),
                                      ),
                                      title: Text(
                                        'Seluruh Anggota Kelas',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Semua ${_projectMembers.length} anggota di dalam kelas',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.0,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      trailing: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isAllSelected
                                              ? (isDark ? Colors.white : Colors.black)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isAllSelected
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? Colors.white38 : Colors.black26),
                                            width: 2,
                                          ),
                                        ),
                                        child: isAllSelected
                                            ? Icon(
                                                Icons.check_rounded,
                                                color: isDark ? Colors.black : Colors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (isAllSelected) {
                                            _selectedMemberUids = [];
                                          } else {
                                            _selectedMemberUids = _projectMembers.map((m) => m['uid'] as String).toList();
                                          }
                                        });
                                      },
                                    );
                                  }

                                  final memberIdx = _memberSearch.isEmpty ? idx - 1 : idx;
                                  final m = filteredMembers[memberIdx];
                                  final mUid = m['uid'] as String;
                                  final isSelf = mUid == widget.currentUid;
                                  final isChecked = _selectedMemberUids.contains(mUid);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Transform.scale(
                                          scale: 1.35,
                                          child: Image.asset(
                                            m['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '${m['name']}${isSelf ? ' (Anda)' : ''}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${m['userId'] ?? '-'}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                    trailing: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isChecked
                                            ? (isDark ? Colors.white : Colors.black)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isChecked
                                              ? (isDark ? Colors.white : Colors.black)
                                              : (isDark ? Colors.white38 : Colors.black26),
                                          width: 2,
                                        ),
                                      ),
                                      child: isChecked
                                          ? Icon(
                                              Icons.check_rounded,
                                              color: isDark ? Colors.black : Colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (!isChecked) {
                                          _selectedMemberUids.add(mUid);
                                        } else {
                                          _selectedMemberUids.remove(mUid);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ]

          // STEP 2: INFO DETAIL DISKUSI, AVATAR, NAMA & CHANNEL + DETAIL KELAS & TUMPUKAN AVATAR
          else if (_step == 2) ...[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Preview & Horizontal Selector
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white : Colors.black,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Transform.scale(
                            scale: 1.25,
                            child: Image.asset(_selectedAvatar, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Pilih Avatar Diskusi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 10,
                        itemBuilder: (context, i) {
                          final avatarPath = 'assets/icon_pack/chat/chat_${i + 1}.png';
                          final isSelected = _selectedAvatar == avatarPath;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAvatar = avatarPath;
                              });
                            },
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2.2 : 1.0,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Transform.scale(
                                    scale: 1.25,
                                    child: Image.asset(avatarPath, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'Nama Diskusi / Judul Grup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Kelompok Diskusi Bab 1',
                        hintStyle: GoogleFonts.dmSans(
                          color: isDark ? Colors.white38 : Colors.black26,
                          fontSize: 14.5,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Nama Saluran (Channel)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _channelController,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: #diskusi-materi',
                        hintStyle: GoogleFonts.dmSans(
                          color: isDark ? Colors.white38 : Colors.black26,
                          fontSize: 14.5,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Detail Classroom & Tumpukan Avatar Anggota
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: Color(0xFF0F766E),
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedProjectName.isNotEmpty ? _selectedProjectName : 'Classroom',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '${_selectedMemberUids.length} Anggota Terpilih',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12.0,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tumpukan Anggota:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final selectedMembers = _projectMembers
                                  .where((m) => _selectedMemberUids.contains(m['uid']))
                                  .toList();
                              return _buildStackedAvatars(selectedMembers, isDark);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DocumentsTab extends StatefulWidget {
  final bool isDark;

  const DocumentsTab({
    super.key,
    this.isDark = false,
  });

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  GoogleSignInAccount? _driveAccount;
  bool _isConnecting = false;
  bool _isUploading = false;
  String _searchQuery = '';
  bool _driveInitialized = false;
  bool _driveAuthorized = false;
  bool _silentSignInActive = true;
  double _usedBytes = 0;
  double _totalBytes = 0;
  String _driveEmail = '';


  // Drive scopes for file access
  static const List<String> _driveScopes = [
    drive.DriveApi.driveFileScope,
  ];

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    try {
      if (!_driveInitialized) {
        try {
          await GoogleSignIn.instance.initialize(
            clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
            serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
          );
        } catch (_) {
          // Safe to ignore if already initialized
        }

        _driveInitialized = true;
      }

      setState(() => _silentSignInActive = true);

      // Instantly load current user if already authenticated
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt != null) {
        final currentUser = await attempt;
        if (currentUser != null && mounted) {
          setState(() {
            _driveAccount = currentUser;
          });
          _loadDriveStorageInfo(currentUser, prompt: false);
        }
      }
      
      // Listen for auth changes
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          if (mounted) {
            setState(() => _driveAccount = event.user);
            _loadDriveStorageInfo(event.user, prompt: !_silentSignInActive);
          }
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          if (mounted) setState(() { _driveAccount = null; _driveAuthorized = false; _usedBytes = 0; _totalBytes = 0; });
        }
      }).onError((_) {});
      
      // Try silent sign-in
      await GoogleSignIn.instance.attemptLightweightAuthentication();
      setState(() => _silentSignInActive = false);
    } catch (_) {}
  }

  Future<void> _connectGoogleDrive() async {
    setState(() => _isConnecting = true);
    try {
      if (kIsWeb) {
        if (_driveAccount != null) {
          await _loadDriveStorageInfo(_driveAccount!, prompt: true);
        }
      } else {
        final user = await GoogleSignIn.instance.authenticate();
        if (mounted) {
          setState(() => _driveAccount = user);
          await _loadDriveStorageInfo(user, prompt: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghubungkan Google Drive: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    await GoogleSignIn.instance.signOut();
    if (mounted) setState(() { _driveAccount = null; _driveAuthorized = false; _usedBytes = 0; _totalBytes = 0; });
  }

  Future<drive.DriveApi?> _getDriveApi(GoogleSignInAccount account, {bool prompt = true}) async {
    try {
      // Request Drive authorization
      final clientAuth = prompt
          ? await account.authorizationClient.authorizeScopes(_driveScopes)
          : await account.authorizationClient.authorizationForScopes(_driveScopes);
      if (clientAuth == null) return null;
      final token = clientAuth.accessToken;
      final client = _GoogleAuthClient({'Authorization': 'Bearer $token'});
      return drive.DriveApi(client);
    } catch (e, stack) {
      debugPrint("Error in _getDriveApi: $e\n$stack");
      rethrow;
    }
  }

  Future<void> _loadDriveStorageInfo(GoogleSignInAccount account, {bool prompt = true}) async {
    try {
      final api = await _getDriveApi(account, prompt: prompt);
      if (api == null) {
        if (mounted) {
          setState(() {
            _driveAccount = account;
            _driveAuthorized = false;
            _usedBytes = 0;
            _totalBytes = 0;
          });
        }
        return;
      }
      final about = await api.about.get($fields: 'storageQuota,user');
      if (mounted) {
        setState(() {
          _driveAccount = account;
          _driveAuthorized = true;
          _usedBytes = double.tryParse(about.storageQuota?.usage ?? '0') ?? 0;
          _totalBytes = double.tryParse(about.storageQuota?.limit ?? '0') ?? 0;
          _driveEmail = account.email;
        });
      }
    } catch (e) {
      debugPrint("Error loading drive info: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat Drive: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }



  Future<void> _createFolderInDrive() async {
    if (_driveAccount == null || !_driveAuthorized) return;

    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Buat Folder Baru', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nama Folder',
            hintStyle: GoogleFonts.dmSans(color: Colors.black26),
          ),
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: Text('Buat', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final api = await _getDriveApi(_driveAccount!);
      if (api == null) throw Exception('Gagal mendapat akses Drive');

      final driveFile = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder';

      final folder = await api.files.create(driveFile);
      final folderId = folder.id!;

      // Share folder as public writer so anyone can read/write inside
      try {
        await api.permissions.create(
          drive.Permission()
            ..type = 'anyone'
            ..role = 'writer',
          folderId,
        );
      } catch (_) {
        try {
          await api.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            folderId,
          );
        } catch (_) {}
      }

      final folderLink = 'https://drive.google.com/drive/folders/$folderId';

      // Save folder metadata to Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get();
      final uploaderName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'User';

      await FirebaseFirestore.instance.collection('driveDocuments').add({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        'driveFileId': folderId,
        'driveLink': folderLink,
        'uploaderUid': FirebaseAuth.instance.currentUser?.uid,
        'uploaderName': uploaderName,
        'fileSize': 0,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      await _loadDriveStorageInfo(_driveAccount!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder berhasil dibuat di Google Drive!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat folder: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadFileToDrive() async {
    if (_driveAccount == null || !_driveAuthorized) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: false,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;
      if (pickedFile.path == null) return;

      setState(() => _isUploading = true);

      final file = File(pickedFile.path!);
      final mimeType = lookupMimeType(pickedFile.path!) ?? 'application/octet-stream';
      final fileName = pickedFile.name;

      final api = await _getDriveApi(_driveAccount!);
      if (api == null) throw Exception('Gagal mendapat akses Drive');

      // Upload to Google Drive
      final driveFile = drive.File()
        ..name = fileName
        ..mimeType = mimeType;

      final uploadedFile = await api.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
      );

      // Make file accessible via link
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        uploadedFile.id!,
      );

      final fileId = uploadedFile.id!;
      final fileLink = 'https://drive.google.com/file/d/$fileId/view';

      // Get user info
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final uploaderName = userDoc.data()?['name'] ?? 'User';
      final uploaderAvatar = userDoc.data()?['avatar'] ?? '';

      // Get all project IDs of this user to associate doc with projects
      final projectIds = List<String>.from(userDoc.data()?['projectIds'] ?? []);

      // Save metadata to Firestore
      await FirebaseFirestore.instance.collection('driveDocuments').add({
        'name': fileName,
        'mimeType': mimeType,
        'driveFileId': fileId,
        'driveLink': fileLink,
        'uploaderUid': currentUid,
        'uploaderName': uploaderName,
        'uploaderAvatar': uploaderAvatar,
        'projectIds': projectIds,
        'fileSize': file.lengthSync(),
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      await _loadDriveStorageInfo(_driveAccount!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File berhasil diupload ke Google Drive!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.contains('folder')) return Icons.folder_open_rounded;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('image')) return Icons.image_outlined;
    if (mimeType.contains('video')) return Icons.videocam_outlined;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) return Icons.table_chart_outlined;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow_outlined;
    if (mimeType.contains('document') || mimeType.contains('word')) return Icons.description_outlined;
    if (mimeType.contains('zip') || mimeType.contains('compressed')) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _getFileColor(String? mimeType) {
    if (mimeType == null) return const Color(0xFF6B7280);
    if (mimeType.contains('folder')) return const Color(0xFFD97706);
    if (mimeType.contains('pdf')) return const Color(0xFFDB2777);
    if (mimeType.contains('image')) return const Color(0xFF7C3AED);
    if (mimeType.contains('video')) return const Color(0xFFDC2626);
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) return const Color(0xFF059669);
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return const Color(0xFFD97706);
    if (mimeType.contains('document') || mimeType.contains('word')) return const Color(0xFF2563EB);
    return const Color(0xFF4B5563);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dokumen',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 23.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
Row(
                      children: [
                        if (_driveAccount != null) ...
                          [
                            if (_isUploading)
                              const ThreeDotsLoader(size: 6, bounceHeight: 3)
                            else ...[
                              // Create Folder Button
                              GestureDetector(
                                onTap: _createFolderInDrive,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.create_new_folder_outlined, color: Colors.black87, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Upload Button
                              GestureDetector(
                                onTap: _uploadFileToDrive,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.drive_folder_upload_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ],
                      ],
                    )
                  ],
                ),
              ),

              // Google Drive Status Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _driveAccount == null || !_driveAuthorized
                    ? _buildDriveNotConnectedCard()
                    : _buildDriveConnectedCard(),
              ),
              const SizedBox(height: 16),

              // Search Bar (only when connected)
              if (_driveAccount != null && _driveAuthorized) ...

                [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Cari dokumen...',
                        hintStyle: GoogleFonts.dmSans(color: Colors.black26, fontSize: 15.2),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.black38, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

              // Documents List from Firestore
              Expanded(
                child: _driveAccount == null || !_driveAuthorized
                    ? const SizedBox.shrink()
                    : StreamBuilder<QuerySnapshot>(

                        stream: FirebaseFirestore.instance
                            .collection('driveDocuments')
                            .orderBy('uploadedAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final docs = snapshot.data?.docs ?? [];
                          final filtered = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['name'] ?? '').toString().toLowerCase();
                            return _searchQuery.isEmpty || name.contains(_searchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_open_outlined, size: 48, color: Colors.black12),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Belum ada dokumen.\nUpload file pertama Anda!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(fontSize: 15.2, color: Colors.black38),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 120.0),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final docSnap = filtered[index];
                              final data = docSnap.data() as Map<String, dynamic>;
                              final fileName = data['name'] ?? 'Untitled';
                              final mimeType = data['mimeType'] as String?;
                              final driveLink = data['driveLink'] ?? '';
                              final uploaderName = data['uploaderName'] ?? 'User';
                              final uploaderUid = data['uploaderUid'] ?? '';
                              final fileSize = data['fileSize'] ?? 0;
                              final isMyFile = uploaderUid == currentUid;
                              final uploadedAt = data['uploadedAt'] as Timestamp?;
                              final dateStr = uploadedAt != null
                                  ? '${uploadedAt.toDate().day}/${uploadedAt.toDate().month}/${uploadedAt.toDate().year}'
                                  : '';

                              final fileColor = _getFileColor(mimeType);
                              final fileIcon = _getFileIcon(mimeType);

                              return GestureDetector(
                                onTap: () async {
                                  if (driveLink.isNotEmpty) {
                                    final uri = Uri.parse(driveLink);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(
                                          color: fileColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(fileIcon, color: fileColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15.2,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  isMyFile ? 'Saya' : uploaderName,
                                                  style: GoogleFonts.dmSans(fontSize: 12.9, color: Colors.black38),
                                                ),
                                                if (dateStr.isNotEmpty) ...
                                                  [
                                                    const SizedBox(width: 6),
                                                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle)),
                                                    const SizedBox(width: 6),
                                                    Text(dateStr, style: GoogleFonts.dmSans(fontSize: 12.9, color: Colors.black38)),
                                                  ],
                                                if (fileSize > 0) ...
                                                  [
                                                    const SizedBox(width: 6),
                                                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle)),
                                                    const SizedBox(width: 6),
                                                    Text(_formatBytes(fileSize.toDouble()), style: GoogleFonts.dmSans(fontSize: 12.9, color: Colors.black38)),
                                                  ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.black26),
                                          if (isMyFile) ...
                                            [
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      backgroundColor: Colors.white,
                                                      title: Text('Hapus Dokumen', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                                      content: Text('Hapus "$fileName" dari Firestore? File di Google Drive tidak akan dihapus.', style: GoogleFonts.plusJakartaSans()),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54))),
                                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hapus', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await FirebaseFirestore.instance.collection('driveDocuments').doc(docSnap.id).delete();
                                                  }
                                                },
                                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                              ),
                                            ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
    );
  }

  Widget _buildDriveNotConnectedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EEF5), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: const Center(
              child: GoogleDriveLogoWidget(size: 28),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Google Drive belum terhubung',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.4,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hubungkan Google Drive untuk upload\ndan berbagi dokumen bersama tim.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          if (kIsWeb && _driveAccount == null)
            const GoogleSignInWebButton()
          else
            GestureDetector(
              onTap: _isConnecting ? null : _connectGoogleDrive,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isConnecting)
                      const ThreeDotsLoader(size: 5, bounceHeight: 2)
                    else
                      const GoogleDriveLogoWidget(size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _isConnecting ? 'Menghubungkan...' : 'Sambungkan Google Drive',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildDriveConnectedCard() {
    final totalGB = _totalBytes > 0 ? _totalBytes / (1024 * 1024 * 1024) : 15.0;
    final ratio = _totalBytes > 0 ? (_usedBytes / _totalBytes).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: GoogleDriveLogoWidget(size: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Drive',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                Text(
                  _driveEmail.isNotEmpty ? _driveEmail : 'Terhubung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 12.9, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(_usedBytes)} dari ${totalGB.toStringAsFixed(1)} GB terpakai',
                  style: GoogleFonts.dmSans(fontSize: 11.7, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _disconnectGoogleDrive,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Dynamic Profile Page Tab ---
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _showAvatarSelector = false;
  Map<String, dynamic>? _cachedUserData;

  void _showGenderSelector(BuildContext context, String currentUid, String currentGender) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final safeBottom = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Pilih Jenis Kelamin',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18.7,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.male_rounded, color: Colors.blueAccent),
                title: Text('Laki-laki', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                trailing: currentGender == 'Laki-laki' ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {
                  await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                    'gender': 'Laki-laki',
                    'avatar': 'assets/icon_pack/avatar/avatar_2.png',
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Jenis kelamin & avatar default laki-laki diperbarui!')),
                    );
                  }
                },
              ),
              const Divider(color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(Icons.female_rounded, color: Colors.pinkAccent),
                title: Text('Perempuan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                trailing: currentGender == 'Perempuan' ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {
                  await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                    'gender': 'Perempuan',
                    'avatar': 'assets/icon_pack/avatar/avatar_1.png',
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Jenis kelamin & avatar default perempuan diperbarui!')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSchoolLevelSelector(BuildContext context, String currentUid, String currentSchoolLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final safeBottom = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Pilih Tingkat Sekolah',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18.7,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ...['SD', 'SMP', 'SMA', 'SMK'].map((level) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.school_rounded, color: Colors.blueAccent),
                      title: Text(level, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                      trailing: currentSchoolLevel == level ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      onTap: () async {
                        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                          'schoolLevel': level,
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Tingkat sekolah diperbarui menjadi $level!')),
                          );
                        }
                      },
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showUpgradePlanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF08A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFEA580C), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Upgrade ke Hubner Pro',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 21.1),
              ),
              const SizedBox(height: 8),
              Text(
                'Dapatkan akses penuh ke semua fitur premium kolaborasi tim tanpa batas.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              _buildFeatureRow('Unlimited Proyek & Tugas'),
              _buildFeatureRow('Integrasi Google Drive Premium'),
              _buildFeatureRow('Kapasitas Anggota Tim Tanpa Batas'),
              _buildFeatureRow('Dukungan Prioritas 24/7'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Terima kasih! Anda berhasil ter-upgrade ke Hubner Pro.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDE047),
                    foregroundColor: const Color(0xFFEA580C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Mulai Berlangganan - Rp 99.000/bln',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF0F766E), size: 16),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context, String currentUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Hapus Akun', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text('Yakin ingin menghapus akun Anda secara permanen? Semua data proyek dan tugas Anda akan dihapus selamanya.', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus Permanen', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUid).delete();
        await FirebaseAuth.instance.currentUser?.delete();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isLoggedIn');
        await prefs.remove('seenOnboarding');
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus akun: $e\nSilakan login ulang terlebih dahulu.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.9,
          fontWeight: FontWeight.bold,
          color: Colors.black38,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String trailing,
    required VoidCallback onTap,
    Color iconColor = Colors.black54,
    Color titleColor = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.2,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (trailing.isNotEmpty)
                    Flexible(
                      child: Text(
                        trailing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<void> logOut() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('seenOnboarding');
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashPage()),
          (route) => false,
        );
      }
    }

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.data() != null) {
          _cachedUserData = snapshot.data!.data() as Map<String, dynamic>;
        }
        final userData = (snapshot.data?.data() as Map<String, dynamic>?) ?? _cachedUserData;
        
        final currentUser = FirebaseAuth.instance.currentUser;
        final fallbackName = currentUser?.displayName?.isNotEmpty == true
            ? currentUser!.displayName!
            : (currentUser?.email?.split('@').first ?? 'User');
        final fallbackUserId = currentUid.length >= 8 ? currentUid.substring(0, 8) : currentUid;

        final String name = (userData?['name'] as String?)?.isNotEmpty == true
            ? userData!['name'] as String
            : fallbackName;
        final String email = currentUser?.email ?? 'user@hubner.io';
        final String gender = userData?['gender'] ?? 'Laki-laki';
        final String userId = (userData?['userId'] as String?)?.isNotEmpty == true
            ? userData!['userId'] as String
            : fallbackUserId;
        final String roleDb = userData?['role'] ?? 'Siswa';
        final String schoolLevel = userData?['schoolLevel'] ?? '-';
        final bool isFemale = gender.toLowerCase() == 'perempuan';
        final String suffix = isFemale ? '6' : '1';
        String defaultAvatar = 'assets/icon_pack/avatar/sma_$suffix.png';
        if (roleDb.toLowerCase() == 'guru') {
          defaultAvatar = 'assets/icon_pack/avatar/guru_$suffix.png';
        } else {
          final String sL = schoolLevel.toUpperCase();
          if (sL == 'SD') {
            defaultAvatar = 'assets/icon_pack/avatar/sd_$suffix.png';
          } else if (sL == 'SMP') {
            defaultAvatar = 'assets/icon_pack/avatar/smp_$suffix.png';
          } else {
            defaultAvatar = 'assets/icon_pack/avatar/sma_$suffix.png';
          }
        }
        final String avatarPath = (userData?['avatar'] as String?)?.isNotEmpty == true
            ? userData!['avatar'] as String
            : defaultAvatar;

        final String timezone = userData?['timezone'] ?? 'Asia/Jakarta (GMT+07:00)';
        final String language = userData?['language'] ?? 'Bahasa Indonesia';
        final bool twoFactorEnabled = userData?['twoFactorEnabled'] ?? false;
        final String themeMode = userData?['themeMode'] ?? 'Light';
        final bool notifyTaskReminder = userData?['notifyTaskReminder'] ?? true;
        final bool notifyChatMention = userData?['notifyChatMention'] ?? true;

        return GestureDetector(
          onTap: () {
            if (_showAvatarSelector) {
              setState(() {
                _showAvatarSelector = false;
              });
            }
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
              child: SafeArea(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        top: 16.0,
                        bottom: MediaQuery.of(context).padding.bottom + 80 + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 23.4,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // User Profile Card
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => _showAvatarSelector = !_showAvatarSelector),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: Transform.scale(
                                            scale: 1.25,
                                            child: Image.asset(
                                              avatarPath,
                                              fit: BoxFit.cover,
                                              errorBuilder: (ctx, err, st) => Container(
                                                color: const Color(0xFFF1F5F9),
                                                child: const Icon(Icons.person_rounded, size: 40, color: Colors.black38),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 21.1,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  'ID User: $userId',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Group 1: Detail Akun
                          _buildSectionHeader('Detail Akun'),
                          _buildSectionCard([
                            _buildSettingTile(
                              icon: Icons.fingerprint_rounded,
                              iconColor: Colors.teal,
                              title: 'ID User',
                              trailing: userId,
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: userId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ID User berhasil disalin ke clipboard!')),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.person_outline_rounded,
                              iconColor: Colors.blueAccent,
                              title: 'Nama Lengkap',
                              trailing: name,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileSubPage(
                                      title: 'Ubah Nama Lengkap',
                                      child: EditNameForm(initialName: name, uid: currentUid),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.mail_outline_rounded,
                              iconColor: Colors.purpleAccent,
                              title: 'Email',
                              trailing: email,
                              onTap: () {},
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.wc_rounded,
                              iconColor: Colors.pinkAccent,
                              title: 'Jenis Kelamin',
                              trailing: gender,
                              onTap: () => _showGenderSelector(context, currentUid, gender),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.public_rounded,
                              iconColor: Colors.orangeAccent,
                              title: 'Zona Waktu',
                              trailing: timezone,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileSubPage(
                                      title: 'Ubah Zona Waktu',
                                      child: EditTimezoneForm(currentTz: timezone, uid: currentUid),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.language_rounded,
                              iconColor: Colors.indigoAccent,
                              title: 'Bahasa',
                              trailing: language,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: Text('Pilih Bahasa', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                    content: Text('Saat ini Hubner Edu hanya tersedia dalam Bahasa Indonesia.', style: GoogleFonts.plusJakartaSans()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text('OK', style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.assignment_ind_rounded,
                              iconColor: Colors.blueGrey,
                              title: 'Role',
                              trailing: roleDb,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Role tidak dapat diubah.')),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.school_rounded,
                              iconColor: Colors.teal,
                              title: 'Tingkat Sekolah',
                              trailing: schoolLevel,
                              onTap: () {
                                _showSchoolLevelSelector(context, currentUid, schoolLevel);
                              },
                            ),
                          ]),

                          // Group 2: Keamanan
                          _buildSectionHeader('Keamanan'),
                          _buildSectionCard([
                            _buildSettingTile(
                              icon: Icons.lock_outline_rounded,
                              iconColor: Colors.redAccent,
                              title: 'Ubah Password',
                              trailing: '',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileSubPage(
                                      title: 'Ubah Password',
                                      child: ChangePasswordForm(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.security_rounded,
                              iconColor: Colors.blueGrey,
                              title: 'Otentikasi 2 Langkah',
                              trailing: twoFactorEnabled ? 'Aktif' : 'Nonaktif',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileSubPage(
                                      title: 'Otentikasi 2 Langkah',
                                      child: TwoFactorSetupForm(isEnabled: twoFactorEnabled, uid: currentUid),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildSettingTile(
                              icon: Icons.devices_rounded,
                              iconColor: Colors.teal,
                              title: 'Sesi Aktif',
                              trailing: '1 Sesi Aktif',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileSubPage(
                                      title: 'Sesi Aktif',
                                      child: ActiveSessionsForm(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ]),

                          // Group 3: Tampilan
                          _buildSectionHeader('Tampilan'),
                          _buildSectionCard([
                            _buildSettingTile(
                              icon: Icons.palette_outlined,
                              iconColor: Colors.amber,
                              title: 'Tema',
                              trailing: themeMode,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileSubPage(
                                      title: 'Ubah Tema',
                                      child: ThemeSetupForm(currentTheme: themeMode, uid: currentUid),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ]),

                          // Group 4: Notifikasi
                          _buildSectionHeader('Notifikasi'),
                          _buildSectionCard([
                            _buildSettingTile(
                              icon: Icons.notifications_none_rounded,
                              iconColor: Colors.green,
                              title: 'Notifikasi',
                              trailing: 'Atur Notifikasi',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileSubPage(
                                      title: 'Pengaturan Notifikasi',
                                      child: NotificationSetupForm(
                                        taskReminder: notifyTaskReminder,
                                        chatMention: notifyChatMention,
                                        uid: currentUid,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ]),

                          // Group 5: Hapus Akun
                          _buildSectionHeader('Hapus Akun'),
                          _buildSectionCard([
                            _buildSettingTile(
                              icon: Icons.delete_forever_rounded,
                              iconColor: Colors.red,
                              titleColor: Colors.red,
                              title: 'Hapus Akun',
                              trailing: '',
                              onTap: () => _deleteAccount(context, currentUid),
                            ),
                          ]),

                          // Group 6: Tentang
                          _buildSectionHeader('Tentang'),
                          _buildSectionCard([
                            _buildSettingTile(
                              icon: Icons.info_outline_rounded,
                              iconColor: Colors.blueGrey,
                              title: 'Tentang Aplikasi',
                              trailing: 'Hubner Edu v1.1.0 beta',
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: Text('Hubner Edu', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                    content: Text(
                                      'Hubner Edu adalah platform manajemen kelas online dan pembelajaran interaktif secara real-time.',
                                      style: GoogleFonts.plusJakartaSans(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text('Tutup', style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          ]),

                          const SizedBox(height: 32),

                          // Log out button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: logOut,
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: Text(
                                'Keluar dari Akun',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                foregroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    if (_showAvatarSelector)
                      Positioned(
                        top: 155,
                        left: 24,
                        right: 24,
                        height: 72,
                        child: GestureDetector(
                          onTap: () {}, // prevent tap from propagation to background
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 10,
                                  itemBuilder: (context, idx) {
                                    final isGuru = roleDb.toLowerCase() == 'guru';
                                    String prefix = 'sma';
                                    if (isGuru) {
                                      prefix = 'guru';
                                    } else {
                                      final String sL = schoolLevel.toUpperCase();
                                      if (sL == 'SD') {
                                        prefix = 'sd';
                                      } else if (sL == 'SMP') {
                                        prefix = 'smp';
                                      } else {
                                        prefix = 'sma';
                                      }
                                    }
                                    final path = 'assets/icon_pack/avatar/${prefix}_${idx + 1}.png';
                                    final isSelected = path == avatarPath;
                                    return GestureDetector(
                                      onTap: () async {
                                        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                                          'avatar': path,
                                        });
                                        setState(() {
                                          _showAvatarSelector = false;
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
                                          );
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 12),
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
                                            width: isSelected ? 2.5 : 1.0,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(2.5),
                                        child: ClipOval(
                                          child: Transform.scale(
                                            scale: 1.25,
                                            child: Image.asset(path, fit: BoxFit.cover),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Custom Google Drive Logo Widget ---
class GoogleDriveLogoWidget extends StatelessWidget {
  final double size;
  const GoogleDriveLogoWidget({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/Google_Drive_icon_(2026).svg',
      width: size,
      height: size,
    );
  }
}

// --- Profile SubPage Container ---
class ProfileSubPage extends StatelessWidget {
  final String title;
  final Widget child;
  const ProfileSubPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontSize: 18.7,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          padding: const EdgeInsets.all(24.0),
          child: child,
        ),
      ),
    );
  }
}

// --- Form Edit Nama Lengkap ---
class EditNameForm extends StatefulWidget {
  final String initialName;
  final String uid;
  const EditNameForm({super.key, required this.initialName, required this.uid});
  @override
  State<EditNameForm> createState() => _EditNameFormState();
}
class _EditNameFormState extends State<EditNameForm> {
  late TextEditingController _controller;
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nama Lengkap',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
          style: GoogleFonts.dmSans(fontSize: 16.4),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () async {
              final newName = _controller.text.trim();
              if (newName.isEmpty) return;
              setState(() => _isLoading = true);
              await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'name': newName});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama berhasil diperbarui!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading 
                ? const ThreeDotsLoader(size: 5, bounceHeight: 2, colors: [Colors.white, Colors.white70, Colors.white60])
                : Text('Simpan Perubahan', style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// --- Form Edit Zona Waktu ---
class EditTimezoneForm extends StatelessWidget {
  final String currentTz;
  final String uid;
  const EditTimezoneForm({super.key, required this.currentTz, required this.uid});

  @override
  Widget build(BuildContext context) {
    final timezones = [
      'Asia/Jakarta (GMT+07:00)',
      'Asia/Makassar (GMT+08:00)',
      'Asia/Jayapura (GMT+09:00)',
    ];
    return ListView.separated(
      shrinkWrap: true,
      itemCount: timezones.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9)),
      itemBuilder: (context, idx) {
        final tz = timezones[idx];
        final isSelected = tz == currentTz;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tz, style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.black) : null,
          onTap: () async {
            await FirebaseFirestore.instance.collection('users').doc(uid).update({'timezone': tz});
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Zona waktu berhasil diubah ke $tz')),
              );
            }
          },
        );
      },
    );
  }
}

// --- Form Ubah Password ---
class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({super.key});
  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}
class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  @override
  void dispose() {
    _newPasswordController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kata Sandi Baru',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
          style: GoogleFonts.dmSans(fontSize: 16.4),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () async {
              final newPass = _newPasswordController.text.trim();
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kata sandi harus minimal 6 karakter!'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              setState(() => _isLoading = true);
              try {
                await FirebaseAuth.instance.currentUser?.updatePassword(newPass);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kata sandi berhasil diperbarui!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengubah password: $e\nSilakan login ulang terlebih dahulu jika sesi kedaluwarsa.'), backgroundColor: Colors.redAccent),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading 
                ? const ThreeDotsLoader(size: 5, bounceHeight: 2, colors: [Colors.white, Colors.white70, Colors.white60])
                : Text('Ubah Kata Sandi', style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// --- Form Otentikasi 2 Langkah ---
class TwoFactorSetupForm extends StatelessWidget {
  final bool isEnabled;
  final String uid;
  const TwoFactorSetupForm({super.key, required this.isEnabled, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Otentikasi 2 Langkah',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEnabled ? 'Aktif' : 'Nonaktif',
              style: GoogleFonts.plusJakartaSans(fontSize: 18.7, fontWeight: FontWeight.bold, color: isEnabled ? Colors.green : Colors.black87),
            ),
            Switch.adaptive(
              value: isEnabled,
              activeColor: Colors.black,
              onChanged: (val) async {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'twoFactorEnabled': val});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Otentikasi 2 langkah berhasil ${val ? 'diaktifkan' : 'dinonaktifkan'}!')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Otentikasi 2 langkah menambahkan lapisan keamanan ekstra ke akun Anda. Kode verifikasi akan diminta setiap kali Anda masuk di perangkat baru.',
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38, height: 1.5),
        ),
      ],
    );
  }
}

// --- Form Sesi Aktif ---
class ActiveSessionsForm extends StatelessWidget {
  const ActiveSessionsForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perangkat yang Terhubung',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_android_rounded, color: Colors.black87, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perangkat saat ini', style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.bold)),
                    Text('Jakarta, Indonesia • Aktif Sekarang', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.green, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Form Tema Setup ---
class ThemeSetupForm extends StatelessWidget {
  final String currentTheme;
  final String uid;
  const ThemeSetupForm({super.key, required this.currentTheme, required this.uid});

  @override
  Widget build(BuildContext context) {
    final themes = ['Light', 'Dark (Segera Hadir)'];
    return ListView.separated(
      shrinkWrap: true,
      itemCount: themes.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9)),
      itemBuilder: (context, idx) {
        final th = themes[idx];
        final isSelected = th == 'Light';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(th, style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: th.contains('Segera') ? Colors.black38 : Colors.black87)),
          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.black) : null,
          onTap: th.contains('Segera') ? null : () async {
            await FirebaseFirestore.instance.collection('users').doc(uid).update({'themeMode': th});
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
}

// --- Form Notifikasi Setup ---
class NotificationSetupForm extends StatefulWidget {
  final bool taskReminder;
  final bool chatMention;
  final String uid;
  const NotificationSetupForm({super.key, required this.taskReminder, required this.chatMention, required this.uid});

  @override
  State<NotificationSetupForm> createState() => _NotificationSetupFormState();
}
class _NotificationSetupFormState extends State<NotificationSetupForm> {
  late bool _taskReminder;
  late bool _chatMention;

  @override
  void initState() {
    super.initState();
    _taskReminder = widget.taskReminder;
    _chatMention = widget.chatMention;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeColor: Colors.black,
          title: Text('Task Reminder', style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold)),
          subtitle: Text('Kirim pengingat untuk tugas yang akan jatuh tempo.', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.black38)),
          value: _taskReminder,
          onChanged: (val) async {
            setState(() => _taskReminder = val);
            await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'notifyTaskReminder': val});
          },
        ),
        const Divider(color: Color(0xFFF1F5F9)),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeColor: Colors.black,
          title: Text('Chat Mention', style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold)),
          subtitle: Text('Beritahu saya saat seseorang menyebut nama saya di diskusi.', style: GoogleFonts.plusJakartaSans(fontSize: 12.9, color: Colors.black38)),
          value: _chatMention,
          onChanged: (val) async {
            setState(() => _chatMention = val);
            await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'notifyChatMention': val});
          },
        ),
      ],
    );
  }
}

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

    // Layout the text first
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle.copyWith(color: Colors.black)),
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: size.width);

    final textOffset = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );

    // Save layer so dstOut blend removes text pixels from the white rect
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw white rounded rectangle
    canvas.drawRRect(rrect, bgPaint);

    // 2. Paint text with dstOut to punch a transparent hole
    final cutPaint = Paint()..blendMode = BlendMode.dstOut;
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), cutPaint);
    tp.paint(canvas, textOffset);
    canvas.restore();

    // Restore the composited layer
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SidebarNavigationItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isSelected;
  final bool isCollapsed;
  final int unreadCount;
  final VoidCallback onTap;

  const SidebarNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.index,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  State<SidebarNavigationItem> createState() => _SidebarNavigationItemState();
}

class _SidebarNavigationItemState extends State<SidebarNavigationItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    Color textColor;
    BoxDecoration? iconDecoration;

    // Dynamic active colors per tab
    final List<Color> activeColors = [
      const Color(0xFF0284C7), // Beranda: Sky Blue
      const Color(0xFF7C3AED), // Laporan/Tugas: Purple
      const Color(0xFFE11D48), // Diskusi: Rose
      const Color(0xFF0D9488), // Dokumen/Monitoring: Teal
      const Color(0xFF4F46E5), // Profil: Indigo
    ];
    final Color activeColor = activeColors[widget.index % activeColors.length];

    if (widget.isSelected) {
      iconColor = activeColor;
      textColor = const Color(0xFF1E293B); // Dark slate for active text
      iconDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else if (_isHovered) {
      iconColor = Colors.black87;
      textColor = Colors.black87;
      iconDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
            mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: iconDecoration,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      widget.icon,
                      color: iconColor,
                      size: 24, // 30% larger than 18 (which is 23.4)
                    ),
                    if (widget.unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Center(
                            child: Text(
                              '${widget.unreadCount}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 9.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.7,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
