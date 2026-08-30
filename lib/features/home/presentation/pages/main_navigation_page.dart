import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/core/widgets/google_sign_in_button.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
import 'home_page.dart';
import 'student_home_page.dart';
import 'chat_room_page.dart';
import 'manage_friends_page.dart';
import 'package:hubner/features/todo/presentation/pages/todo_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/features/notifications/presentation/pages/notifications_page.dart';
import 'package:hubner/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:hubner/core/widgets/in_app_chat_overlay.dart';
import 'edit_profile_page.dart';
import 'package:hubner/features/notifications/domain/notification_service.dart';

import 'package:hubner/features/projects/presentation/pages/laporan_page.dart';
import 'package:hubner/features/projects/presentation/pages/monitoring_page.dart';
import 'package:hubner/features/splash/presentation/pages/splash_page.dart';
import 'package:hubner/features/auth/presentation/pages/login_page.dart';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:hubner/features/home/presentation/widgets/in_app_file_viewer_dialog.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
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
      isGuru
          ? HomePage(onNavigateTab: _onNavigateTab)
          : StudentHomePage(onNavigateTab: _onNavigateTab),
      isGuru ? const LaporanPage() : const TodoPage(showBackButton: false),
      const DiscussionTab(),
      isGuru
          ? DocumentsTab(onBackToHome: () => _onNavigateTab(0))
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
                  
                  // Suppress notification if user is currently inside ChatRoomPage
                  if (!ChatRoomPage.isCurrentlyOpen) {
                    final channelName = data['channel'] ?? '#general';
                    final lastMsg = data['lastMessage'] ?? '';
                    final avatar = (data['avatar'] ?? '').toString();
                    final bool isDark = AppColors.isDarkMode;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      InAppChatOverlay.show(
                        context: context,
                        title: channelName,
                        message: lastMsg,
                        avatar: avatar,
                        isDark: isDark,
                        onReply: () {
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
                      );

                      // Android high-priority pop-up notification (WhatsApp style)
                      NotificationService.showPopUpNotification(
                        title: channelName,
                        body: lastMsg.isNotEmpty ? lastMsg : 'Pesan baru diterima',
                      );
                    });
                  }
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
                                             style: AppTypography.pageTitle(
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
                              style: AppTypography.subtitle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Cari sesuatu...',
                                hintStyle: AppTypography.subtitle(color: Colors.white70),
                                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),

                           const Spacer(),

                           // Notification Icon with Unread Badge
                           NotificationBellIcon(isDark: isDark, size: 36),
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
                              style: AppTypography.channelTag(color: Colors.white, fontWeight: FontWeight.w600),
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

            return PopScope(
              canPop: _currentIndex == 0,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                if (_currentIndex != 0) {
                  _onNavigateTab(0);
                }
              },
              child: AnnotatedRegion<SystemUiOverlayStyle>(
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
        textStyle: AppTypography.channelTag(fontWeight: FontWeight.bold),
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
    _pressScaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOut,
      ),
    );
    _pressStretchAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOut,
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

  Widget _buildNavSvg({
    required int index,
    required bool isActive,
    required bool isDark,
    required bool isGuru,
  }) {
    final mainColor = isActive
        ? (isDark ? '#FFFFFF' : '#0F172A')
        : (isDark ? '#71717A' : '#94A3B8');

    String svgStr;
    switch (index) {
      case 0: // Beranda (Grid Dashboard - 80% Black/White, 20% Violet Accent)
        final accentColor = isActive ? '#7C3AED' : (isDark ? '#71717A' : '#94A3B8');
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect x="3.5" y="3.5" width="7" height="7" rx="2.5" fill="$mainColor"/>
          <rect x="13.5" y="3.5" width="7" height="7" rx="2.5" fill="$accentColor"/>
          <rect x="3.5" y="13.5" width="7" height="7" rx="2.5" fill="$mainColor"/>
          <rect x="13.5" y="13.5" width="7" height="7" rx="2.5" fill="$mainColor"/>
        </svg>''';
        break;

      case 1: // Tugas / Laporan (Note & Pen - 80% Black/White, 20% Amber/Orange Accent)
        final accentColor = isActive ? '#F59E0B' : (isDark ? '#71717A' : '#94A3B8');
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M7 3H5a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2v-3" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M7 8h4M7 12h3M7 16h6" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M19.1 2.9a2.12 2.12 0 013 3L13.5 14.5l-4.5 1 1-4.5L19.1 2.9z" fill="$accentColor" stroke="$mainColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>''';
        break;

      case 2: // Diskusi (Chat Bubble - 80% Black/White, 20% Purple Accent Dots)
        final accentColor = isActive ? '#8B5CF6' : (isDark ? '#71717A' : '#94A3B8');
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 21a9.004 9.004 0 006.364-2.636A9 9 0 0021 12c0-4.97-4.03-9-9-9s-9 4.03-9 9c0 2.12.74 4.07 1.97 5.61L4 21l4.5-1.2A8.96 8.96 0 0012 21z" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <circle cx="8" cy="12" r="1.6" fill="$accentColor"/>
          <circle cx="12" cy="12" r="1.6" fill="$accentColor"/>
          <circle cx="16" cy="12" r="1.6" fill="$accentColor"/>
        </svg>''';
        break;

      case 3: // Monitoring / Dokumen (Analytics / Document - 80% Black/White, 20% Sky Blue Accent)
        final accentColor = isActive ? '#0284C7' : (isDark ? '#71717A' : '#94A3B8');
        if (isGuru) {
          svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6z" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M14 2v6h6" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="$accentColor"/>
            <path d="M8 13h8M8 17h5" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>''';
        } else {
          svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 21h18" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
            <rect x="5" y="12" width="3.5" height="6" rx="1.5" fill="$mainColor"/>
            <rect x="10.25" y="8" width="3.5" height="10" rx="1.5" fill="$mainColor"/>
            <rect x="15.5" y="4" width="3.5" height="14" rx="1.5" fill="$accentColor"/>
          </svg>''';
        }
        break;

      case 4: // Profil (User Profile - 80% Black/White, 20% Emerald Green Accent)
      default:
        final accentColor = isActive ? '#10B981' : (isDark ? '#71717A' : '#94A3B8');
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 11a4 4 0 100-8 4 4 0 000 8zM5 20.5a7 7 0 0114 0" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <circle cx="18" cy="5.5" r="2.2" fill="$accentColor"/>
        </svg>''';
        break;
    }

    return SvgPicture.string(
      svgStr,
      width: 21,
      height: 21,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final bool isGuru = widget.isGuru;

    final navItems = [
      {'label': 'Beranda'},
      {'label': isGuru ? 'Laporan' : 'Tugas'},
      {'label': 'Diskusi'},
      {'label': isGuru ? 'Dokumen' : 'Monitoring'},
      {'label': 'Profil'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double tabWidth = totalWidth / 5;

        // Fluid liquid pill calculation perfectly centered on the active tab
        final double pillWidth = tabWidth - 6.0;
        final double pillCenter = (_currentPillPosition + 0.5) * tabWidth;
        final double pillLeft = (pillCenter - (pillWidth / 2)).clamp(2.0, totalWidth - pillWidth - 2.0);

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
            height: 62,
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 1. Fluid Liquid Sliding Pill Indicator (Warna abu soft transparan, tanpa glass)
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
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFF0F172A).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : const Color(0xFF0F172A).withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Interactive Navigation Items (SVG + Text di bawah ikon)
                Row(
                  children: List.generate(5, (index) {
                    final item = navItems[index];
                    final String label = item['label'] as String;
                    final int unread = (index == 2) ? widget.totalUnread : 0;

                    // Calculate distance from continuous pill position
                    final double dist = (index - _currentPillPosition).abs();
                    final double activeFactor = (1.0 - dist).clamp(0.0, 1.0);
                    final bool isClosest = dist < 0.5;

                    return Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Transform.scale(
                                    scale: 1.0 + (activeFactor * 0.08),
                                    child: _buildNavSvg(
                                      index: index,
                                      isActive: isClosest,
                                      isDark: isDark,
                                      isGuru: isGuru,
                                    ),
                                  ),
                                  if (unread > 0)
                                     Positioned(
                                       top: -3,
                                       right: -7,
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                         decoration: BoxDecoration(
                                           color: const Color(0xFFEF4444),
                                           shape: BoxShape.circle,
                                           border: Border.all(
                                             color: isDark ? const Color(0xFF18181B) : Colors.white,
                                             width: 1.2,
                                           ),
                                         ),
                                         constraints: const BoxConstraints(
                                           minWidth: 17,
                                           minHeight: 17,
                                         ),
                                         child: Center(
                                           child: Text(
                                             unread > 99 ? '99+' : '$unread',
                                             style: const TextStyle(
                                               color: Colors.white,
                                               fontSize: 9.5,
                                               fontWeight: FontWeight.bold,
                                               height: 1.0,
                                             ),
                                           ),
                                         ),
                                       ),
                                     ),
                                ],
                              ),
                              const SizedBox(height: 2.5),
                              Text(
                                label,
                                style: AppTypography.microBadge(
                                  color: isDark
                                      ? (isClosest ? Colors.white : const Color(0xFF71717A))
                                      : (isClosest ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                                  fontWeight: isClosest ? FontWeight.w800 : FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
        'iconPath': doc.data()['iconPath'] ?? '',
        'avatar': doc.data()['avatar'] ?? '',
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
          'iconPath': doc.data()['iconPath'] ?? '',
          'avatar': doc.data()['avatar'] ?? '',
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

  Future<List<Map<String, dynamic>>> _loadFriends(String currentUid) async {
    if (currentUid.isEmpty) return [];
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final List<String> friendUids = List<String>.from(userDoc.data()?['friendUids'] ?? []);
      if (friendUids.isEmpty) return [];

      final List<Map<String, dynamic>> friends = [];
      const int chunkLimit = 10;
      for (var i = 0; i < friendUids.length; i += chunkLimit) {
        final chunk = friendUids.sublist(
          i,
          i + chunkLimit > friendUids.length ? friendUids.length : i + chunkLimit,
        );
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in query.docs) {
          friends.add({
            'uid': doc.id,
            'name': doc.data()['name'] ?? 'Teman',
            'userId': doc.data()['userId'] ?? '',
            'avatar': doc.data()['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
            'role': doc.data()['role'] ?? 'Siswa',
            'classroomName': 'Teman Saya',
            'isFriend': true,
          });
        }
      }
      return friends;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadClassroomGroupedContacts(String currentUid) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    try {
      final friends = await _loadFriends(currentUid);
      final projects = await _loadProjects(currentUid);

      if (friends.isNotEmpty) {
        grouped['Teman Saya'] = friends;
      }

      // 2. Load members of all projects in parallel
      if (projects.isNotEmpty) {
        final memberLists = await Future.wait(
          projects.map((p) => _loadProjectMembers(p['id'] as String)),
        );

        for (int i = 0; i < projects.length; i++) {
          final p = projects[i];
          final pName = (p['name'] ?? 'Classroom').toString();
          final members = memberLists[i];
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
      }
    } catch (_) {}

    if (grouped.isEmpty) {
      try {
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
      } catch (_) {}
    }

    return grouped;
  }

  Future<String?> _loadProjectName(String projectId) async {
    if (projectId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
    return doc.data()?['name'] as String?;
  }

  void _openDirectChatWithContact(BuildContext context, String currentUid, Map<String, dynamic> contact) {
    final String targetUid = contact['uid'];
    final String targetName = contact['name'];
    final String targetAvatar = contact['avatar'] ?? 'assets/icon_pack/chat/chat_1.png';

    // Instantly close modal and push chat room with draft state (zero delay)
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          discussionId: '',
          channelName: targetName,
          targetUserUid: targetUid,
          targetUserAvatar: targetAvatar,
          isPrivateDraft: true,
        ),
      ),
    );
  }

  void _showCreateDiscussionDialog(BuildContext context) {
    final bool isDark = HubnerApp.themeNotifier.value == 'Gelap' || HubnerApp.themeNotifier.value == 'Hitam';
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
          onLoadFriends: () => _loadFriends(currentUid),
          onLoadClassroomGroupedContacts: () => _loadClassroomGroupedContacts(currentUid),
          onDirectChatTap: (contact) => _openDirectChatWithContact(bottomSheetContext, currentUid, contact),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark, {bool isSticky = false, double height = 52.0}) {
    final double iconSize = height < 48 ? 18.0 : 22.0;
    final double fontSize = height < 48 ? 14.5 : 16.5;
    final double verticalPadding = height < 48 ? 8.0 : 12.0;
    final double borderRadius = height < 48 ? 22.0 : 28.0;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark
            ? (isSticky ? const Color(0xFF18181B).withValues(alpha: 0.65) : const Color(0xFF18181B))
            : (isSticky ? Colors.white.withValues(alpha: 0.70) : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? const Color(0xFF27272A).withValues(alpha: isSticky ? 0.6 : 1.0)
              : const Color(0xFFE2E8F0).withValues(alpha: isSticky ? 0.8 : 1.0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white60 : Colors.black45,
            size: iconSize,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: isDark ? Colors.white : Colors.black,
                  selectionColor: isDark ? Colors.white24 : Colors.black12,
                  selectionHandleColor: isDark ? Colors.white : Colors.black,
                ),
              ),
              child: TextField(
                controller: _searchController,
                cursorColor: isDark ? Colors.white : Colors.black,
                cursorWidth: 2.0,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: AppTypography.searchInput(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: fontSize,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari thread diskusi...',
                  hintStyle: AppTypography.searchInput(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: fontSize,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: verticalPadding),
                ),
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
    );
  }

  Widget _buildManageFriendsButton(bool isDark, {double iconSize = 24.0}) {
    return BouncyButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageFriendsPage()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          Icons.people_outline_rounded,
          color: isDark ? Colors.white : Colors.black87,
          size: iconSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final safeBottomPadding = MediaQuery.of(context).padding.bottom;
        final bool isDesktop = MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.shortestSide >= 700;

        final double bottomNavHeight = 64.0;
        final double bottomNavOffset = safeBottomPadding > 0 ? safeBottomPadding + 14 : 26;
        final double fabBottomPosition = bottomNavOffset + bottomNavHeight + 16;
        final double listBottomPadding = fabBottomPosition + 60;

    final Widget listContent = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('discussions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] ?? aData['time'];
          final bTime = bData['createdAt'] ?? bData['time'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return b.id.compareTo(a.id);
        });

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isPrivate = data['isPrivate'] == true;
          final memberUids = data['memberUids'] as List?;
          final creatorUid = data['creatorUid'] as String?;
          
          // Filter out chats/discussions where current user is not a participant or creator
          if (memberUids != null && memberUids.isNotEmpty) {
            if (!memberUids.contains(currentUid) && creatorUid != currentUid) {
              return false;
            }
          } else if (creatorUid != null && creatorUid.isNotEmpty && creatorUid != currentUid) {
            return false;
          }

          final bool isGroupChat = (data['channel'] ?? '').toString().startsWith('#') ||
              (data['projectId'] ?? '').toString().isNotEmpty;
          final bool isDirect = data['isDirect'] == true || isPrivate;
          final String lastMsg = (data['lastMessage'] ?? '').toString();
          final bool hasRealMessages = data['hasMessages'] == true ||
              (lastMsg.isNotEmpty &&
                  lastMsg != 'Mulai percakapan langsung...' &&
                  lastMsg != 'Mulai diskusi baru...');

          // If direct chat has no real messages yet, hide from list
          if (isDirect && !hasRealMessages) {
            return false;
          }

          // If chat was cleared / deleted for current user, hide from list
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
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Top Scrollable Header (Saat Diam: Row Diskusi + Ikon Teman 52x52, Dibawahnya Search Bar Full Width)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top In-List Header (Diskusi Title & Circular 52x52 Manage Friends Button seukuran note)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTypography.screenHorizontalMargin,
                      MediaQuery.of(context).padding.top + 10.0,
                      AppTypography.screenHorizontalMargin,
                      6.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Diskusi',
                          style: AppTypography.pageTitle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildManageFriendsButton(isDark, iconSize: 24.0),
                      ],
                    ),
                  ),

                  // Search Bar Full Width (52px height)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTypography.screenHorizontalMargin,
                      vertical: 6.0,
                    ),
                    child: _buildSearchBar(isDark),
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
                      style: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black45),
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
                                style: AppTypography.microBadge(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (isGroupChat) return false;
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text(
                                'Kosongkan Chat Pribadi?',
                                style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                'Chat ini akan dihapus dari daftar Anda dan hanya dikosongkan untuk Anda. Riwayat akan muncul kembali jika ada pesan baru.',
                                style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    'Batal',
                                    style: AppTypography.buttonLabel(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
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
                                    style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
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
                            ? (isDark ? const Color(0xFF18181B) : const Color(0xFFEFF6FF))
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
                                    projectId: projectId.isNotEmpty ? projectId : null,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
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
                                        Text(
                                          projectName.isNotEmpty
                                              ? '$channelName • Kelas $projectName'
                                              : ((chat['isFriendGroup'] == true || channelName.contains('teman'))
                                                  ? '$channelName • Teman'
                                                  : channelName),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.buttonLabel(
                                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF475569),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.chatHeaderTitle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.subtitle(
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      time,
                                      style: AppTypography.subtitle(
                                        color: unreadCount > 0
                                            ? (isDark ? const Color(0xFF14B8A6) : const Color(0xFF7C3AED))
                                            : (isDark ? Colors.white38 : Colors.black38),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    if (unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF14B8A6) : const Color(0xFF7C3AED),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          unreadCount > 99 ? '99+' : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 20),
                                  ],
                                ),
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
                ValueListenableBuilder<double>(
                  valueListenable: _headerScrollOffsetNotifier,
                  builder: (context, scrollOffset, _) {
                    if (scrollOffset <= 20.0) {
                      return const SizedBox.shrink();
                    }
                    final double scrollProgress = ((scrollOffset - 20.0) / 30.0).clamp(0.0, 1.0);
                    final double blurSigma = 20.0 * scrollProgress;
                    final double currentBarHeight = ui.lerpDouble(52.0, 42.0, scrollProgress)!;
                    final double currentIconSize = ui.lerpDouble(24.0, 20.0, scrollProgress)!;

                    return Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: scrollProgress,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: blurSigma > 0.1 ? blurSigma : 0.001,
                              sigmaY: blurSigma > 0.1 ? blurSigma : 0.001,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF000000).withValues(alpha: 0.50 * scrollProgress)
                                    : Colors.white.withValues(alpha: 0.55 * scrollProgress),
                                border: Border(
                                  bottom: BorderSide(
                                    color: (isDark
                                            ? const Color(0xFF27272A)
                                            : const Color(0xFFE2E8F0))
                                        .withValues(alpha: 0.85 * scrollProgress),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildSearchBar(isDark, isSticky: true, height: currentBarHeight),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildManageFriendsButton(isDark, iconSize: currentIconSize),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
                          style: AppTypography.replySubtitle(color: isDark ? Colors.white38 : Colors.black45),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    }

    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: Stack(
            children: [
              listContent,

              // Sticky Header (Like Todo Page: Glassmorphic blur, Search & Friends, Title Disappears!)
              ValueListenableBuilder<double>(
                valueListenable: _headerScrollOffsetNotifier,
                builder: (context, scrollOffset, _) {
                  if (scrollOffset <= 20.0) {
                    return const SizedBox.shrink();
                  }
                  final double scrollProgress = ((scrollOffset - 20.0) / 30.0).clamp(0.0, 1.0);
                  final double blurSigma = 20.0 * scrollProgress;
                  final double currentBarHeight = ui.lerpDouble(52.0, 42.0, scrollProgress)!;
                  final double currentIconSize = ui.lerpDouble(24.0, 20.0, scrollProgress)!;

                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Opacity(
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
                              ui.lerpDouble(10.0, 6.0, scrollProgress)!,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF000000).withValues(alpha: 0.50 * scrollProgress)
                                  : Colors.white.withValues(alpha: 0.55 * scrollProgress),
                              border: Border(
                                bottom: BorderSide(
                                  color: (isDark
                                          ? const Color(0xFF27272A)
                                          : const Color(0xFFE2E8F0))
                                      .withValues(alpha: 0.85 * scrollProgress),
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildSearchBar(isDark, isSticky: true, height: currentBarHeight),
                                ),
                                const SizedBox(width: 8),
                                _buildManageFriendsButton(isDark, iconSize: currentIconSize),
                              ],
                            ),
                          ),
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
      ),
    );
      },
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
  final Future<List<Map<String, dynamic>>> Function() onLoadFriends;
  final Future<Map<String, List<Map<String, dynamic>>>> Function() onLoadClassroomGroupedContacts;
  final Function(Map<String, dynamic> contact) onDirectChatTap;

  const _WhatsAppStyleNewChatModal({
    required this.currentUid,
    required this.isDark,
    required this.onLoadProjects,
    required this.onLoadProjectMembers,
    required this.onLoadFriends,
    required this.onLoadClassroomGroupedContacts,
    required this.onDirectChatTap,
  });

  @override
  State<_WhatsAppStyleNewChatModal> createState() => _WhatsAppStyleNewChatModalState();
}

class _WhatsAppStyleNewChatModalState extends State<_WhatsAppStyleNewChatModal> {
  // Step 0 = List Kontak dikelompokkan berdasarkan #Teman Saya & #Nama Kelas (dengan collapse/expand)
  // Step 1 = Pilih Classroom / Pilih Teman & Checklist Anggota
  // Step 2 = Info Detail Grup & Tumpukan Avatar Anggota
  int _step = 0;
  String _creationMode = 'classroom'; // 'classroom' or 'friend'

  String _contactSearch = '';
  String _memberSearch = '';
  final TextEditingController _modalSearchController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _channelController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  final GlobalKey _dropdownKey = GlobalKey();

  String? _selectedProjectId;
  String _selectedProjectName = '';
  Map<String, dynamic> _selectedProjectData = {};
  List<Map<String, dynamic>> _projectMembers = [];
  List<Map<String, dynamic>> _friendsList = [];
  List<String> _selectedMemberUids = []; // Non-checklist by default
  String _selectedAvatar = 'assets/icon_pack/chat/chat_1.png';
  bool _isDefaultGroupIcon = true;
  bool _showAvatarSlider = false;
  bool _isLoadingMembers = false;
  bool _isLoadingFriends = false;
  bool _isCreating = false;
  bool _createDriveFolder = false;
  List<String> _adminUids = [];
  bool _canAllMembersEditInfo = true;
  bool _canAllMembersInvite = true;

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

    final double top = offset.dy + size.height - 2;
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
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
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
                              _selectedProjectData = p;
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pName,
                                    style: AppTypography.dropdownItem(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFFD6A5F8) : const Color(0xFF7C3AED))
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: isDark ? const Color(0xFFD6A5F8) : const Color(0xFF7C3AED),
                                    size: 18,
                                  ),
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

  Widget _buildClassroomIcon(Map<String, dynamic> projectData, {double size = 36}) {
    final rawIcon = (projectData['icon'] ?? projectData['iconPath'] ?? '').toString();
    String iconPath = 'assets/icon_pack/project/project_1.png';
    if (rawIcon.isNotEmpty) {
      if (rawIcon.startsWith('assets/')) {
        iconPath = rawIcon;
      } else {
        iconPath = 'assets/icon_pack/project/$rawIcon';
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F766E).withValues(alpha: 0.15),
      ),
      child: ClipOval(
        child: Image.asset(
          iconPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.school_rounded,
            color: const Color(0xFF0F766E),
            size: size * 0.55,
          ),
        ),
      ),
    );
  }

  void _openManageMembersModal(BuildContext context) {
    final isDark = widget.isDark;
    final isFriendMode = _creationMode == 'friend';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final pool = isFriendMode ? _friendsList : _projectMembers;
            final selectedMembers = pool
                .where((m) => _selectedMemberUids.contains(m['uid']))
                .toList();
            final projectGuruUid = isFriendMode
                ? ''
                : (_selectedProjectData['teacherUid'] as String? ??
                    _selectedProjectData['guruUid'] as String? ??
                    '');

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kelola Anggota (${selectedMembers.length})',
                        style: AppTypography.cardTitle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Tambah anggota dari kelas / teman
                          Navigator.pop(modalCtx);
                          setState(() {
                            _step = 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isFriendMode
                                ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                : const Color(0xFF0F766E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_add_rounded,
                                size: 15,
                                color: isFriendMode ? const Color(0xFF6366F1) : const Color(0xFF0F766E),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+ Tambah',
                                style: AppTypography.channelTag(color: isFriendMode ? const Color(0xFF6366F1) : const Color(0xFF0F766E), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: selectedMembers.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        height: 1,
                        indent: 56,
                      ),
                      itemBuilder: (ctx, i) {
                        final m = selectedMembers[i];
                        final mUid = m['uid'] as String;
                        final name = m['name'] ?? 'User';
                        final avatarPath = m['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';
                        final bool isGuru = !isFriendMode && ((m['role'] == 'guru') || (mUid == projectGuruUid));
                        final bool isCreator = mUid == widget.currentUid;
                        final bool isAdmin = isGuru || isCreator || _adminUids.contains(mUid);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                            ),
                            child: ClipOval(
                              child: Transform.scale(
                                scale: 1.35,
                                child: Image.asset(avatarPath, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isGuru) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Guru',
                                    style: AppTypography.microBadge(color: const Color(0xFF0F766E), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ] else if (isAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: AppTypography.microBadge(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            isGuru
                                ? 'Admin Utama (Guru)'
                                : (isAdmin ? 'Admin Grup' : (isFriendMode ? 'Teman' : 'Anggota')),
                            style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Toggle Admin button
                              if (!isGuru && !isCreator)
                                TextButton(
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        if (_adminUids.contains(mUid)) {
                                          _adminUids.remove(mUid);
                                        } else {
                                          _adminUids.add(mUid);
                                        }
                                      });
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _adminUids.contains(mUid) ? 'Lepas Admin' : 'Jadikan Admin',
                                    style: AppTypography.microBadge(color: _adminUids.contains(mUid) ? Colors.orange : const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              // Hapus dari grup button
                              if (!isGuru && !isCreator)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setModalState(() {
                                      setState(() {
                                        _selectedMemberUids.remove(mUid);
                                        _adminUids.remove(mUid);
                                      });
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
            );
          },
        );
      },
    );
  }

  Widget _buildStackedAvatars(List<Map<String, dynamic>> selectedMembers, bool isDark) {
    if (selectedMembers.isEmpty) return const SizedBox.shrink();
    final int maxDisplay = 4;
    final int displayCount = selectedMembers.length > maxDisplay ? maxDisplay : selectedMembers.length;
    final int remaining = selectedMembers.length - displayCount;
    const double avatarSize = 38.0;
    const double overlap = 26.0;

    return SizedBox(
      height: avatarSize,
      width: (displayCount + (remaining > 0 ? 1 : 0)) * overlap + 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                ),
                child: ClipOval(
                  child: Transform.scale(
                    scale: 1.35,
                    child: Image.asset(
                      selectedMembers[i]['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayCount * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF181E2C),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: AppTypography.channelTag(color: Colors.white, fontWeight: FontWeight.bold),
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
    final isFriendMode = _creationMode == 'friend';

    if (ttl.isEmpty || (!isFriendMode && _selectedProjectId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama diskusi wajib diisi.')),
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

      final cleanTitle = ttl.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
      String channelName;
      if (chan.isNotEmpty) {
        channelName = chan.startsWith('#') ? chan : '#$chan';
      } else {
        channelName = isFriendMode
            ? '#teman${cleanTitle.isNotEmpty ? '-$cleanTitle' : ''}'
            : '#${cleanTitle.isNotEmpty ? cleanTitle : 'diskusi'}';
      }

      final List<String> finalAdminUids = List<String>.from(_adminUids);
      if (!finalAdminUids.contains(widget.currentUid)) {
        finalAdminUids.add(widget.currentUid);
      }
      if (!isFriendMode) {
        final projectGuruUid = _selectedProjectData['teacherUid'] as String? ??
            _selectedProjectData['guruUid'] as String? ??
            '';
        if (projectGuruUid.isNotEmpty && !finalAdminUids.contains(projectGuruUid)) {
          finalAdminUids.add(projectGuruUid);
        }
      }

      String? driveFolderId;
      String? driveFolderUrl;
      String? driveAccessToken;

      if (_createDriveFolder) {
        try {
          // Jika kelas: ambil dari folder kelas atau dokumen guru
          if (!isFriendMode && _selectedProjectId != null && _selectedProjectId!.isNotEmpty) {
            final pDoc = await FirebaseFirestore.instance.collection('projects').doc(_selectedProjectId).get();
            if (pDoc.exists) {
              final pFolderId = pDoc.data()?['driveFolderId'] as String?;
              final pFolderUrl = pDoc.data()?['driveFolderUrl'] as String?;
              final pToken = pDoc.data()?['driveAccessToken'] as String?;
              if (pFolderId != null && pFolderId.isNotEmpty) {
                driveFolderId = pFolderId;
                driveFolderUrl = pFolderUrl ?? 'https://drive.google.com/drive/folders/$pFolderId';
                driveAccessToken = pToken;
              }
            }
          }

          // Jika belum terisi, coba dari sesi akun Google / menu Dokumen user
          if (driveFolderId == null || driveFolderId.isEmpty) {
            try {
              var account = await GoogleSignIn.instance.attemptLightweightAuthentication();
              account ??= await GoogleSignIn.instance.authenticate();
              final auth = await account.authorizationClient.authorizeScopes([drive.DriveApi.driveFileScope]);
              driveAccessToken = auth.accessToken;
              driveFolderId = await GoogleDriveService.createClassroomFolder(driveAccessToken, ttl);
              driveFolderUrl = 'https://drive.google.com/drive/folders/$driveFolderId';
            } catch (_) {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get();
              final pubFolderId = userDoc.data()?['publicDriveFolderId'] as String?;
              final pubFolderUrl = userDoc.data()?['publicDriveFolderUrl'] as String?;
              if (pubFolderId != null && pubFolderId.isNotEmpty) {
                driveFolderId = pubFolderId;
                driveFolderUrl = pubFolderUrl ?? 'https://drive.google.com/drive/folders/$pubFolderId';
              }
            }
          }
        } catch (_) {}
      }

      final newDoc = await FirebaseFirestore.instance.collection('discussions').add({
        'projectId': isFriendMode ? '' : (_selectedProjectId ?? ''),
        'isFriendGroup': isFriendMode,
        'channel': channelName,
        'title': ttl,
        'avatar': _selectedAvatar,
        'lastMessage': '',
        'hasMessages': false,
        'time': 'Sekarang',
        'memberUids': finalMembers,
        'adminUids': finalAdminUids,
        'creatorUid': widget.currentUid,
        'canAllMembersEditInfo': _canAllMembersEditInfo,
        'canAllMembersInvite': _canAllMembersInvite,
        'createDriveFolder': _createDriveFolder,
        if (driveFolderId != null && driveFolderId.isNotEmpty) ...{
          'driveFolderId': driveFolderId,
          'driveFolderUrl': driveFolderUrl,
          'driveAccessToken': driveAccessToken,
          'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
        },
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
              projectId: isFriendMode ? '' : (_selectedProjectId ?? ''),
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFriendMode
                ? 'Grup diskusi teman berhasil dibuat!'
                : 'Grup diskusi kelas berhasil dibuat!'),
          ),
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

  Widget _buildSafeAvatarImage(String? avatar) {
    final av = (avatar ?? '').trim();
    if (av.startsWith('http://') || av.startsWith('https://')) {
      return Image.network(
        av,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Icon(
          Icons.person_rounded,
          size: 22,
          color: Colors.grey,
        ),
      );
    }
    return Image.asset(
      av.isNotEmpty ? av : 'assets/icon_pack/avatar/avatar_2.png',
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => const Icon(
        Icons.person_rounded,
        size: 22,
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenHeight = MediaQuery.of(context).size.height;
    final isFriendMode = _creationMode == 'friend';

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                          width: 42,
                          height: 42,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white : Colors.black,
                            size: 20,
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
                          width: 42,
                          height: 42,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    Text(
                      _step == 0
                          ? 'Diskusi Baru'
                          : (_step == 1
                              ? (isFriendMode ? 'Pilih Teman Diskusi' : 'Buat Diskusi Kelas')
                              : (isFriendMode ? 'Info Diskusi Teman' : 'Info Grup Diskusi')),
                      style: AppTypography.chatHeaderTitle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Right action (X on step 0, "Berikutnya" on step 1, "Buat" on step 2)
                if (_step == 0)
                  BouncyButton(
                    onTap: () => Navigator.pop(context),
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
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  )
                else if (_step == 1)
                  GestureDetector(
                    onTap: () {
                      if (!isFriendMode && _selectedProjectId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Silakan pilih classroom terlebih dahulu.')),
                        );
                        return;
                      }
                      if (_selectedMemberUids.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isFriendMode ? 'Pilih minimal 1 teman diskusi.' : 'Pilih minimal 1 anggota diskusi.')),
                        );
                        return;
                      }
                      setState(() {
                        if (isFriendMode && _channelController.text.trim().isEmpty) {
                          _channelController.text = '#teman';
                        }
                        _step = 2;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: ((isFriendMode || _selectedProjectId != null) && _selectedMemberUids.isNotEmpty)
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Selanjutnya',
                        style: AppTypography.buttonLabel(
                          fontWeight: FontWeight.bold,
                          color: ((isFriendMode || _selectedProjectId != null) && _selectedMemberUids.isNotEmpty)
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
                              style: AppTypography.buttonLabel(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // STEP 0: KONTAK LIST BERDASARKAN #TEMAN SAYA & #NAMA KELAS (COLLAPSIBLE / HIDEABLE)
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
                        style: AppTypography.chatBody(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Cari kontak, kelas, atau teman',
                          hintStyle: AppTypography.chatBody(color: isDark ? Colors.white38 : Colors.black38),
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

            // Opsi 1: Buat Diskusi Kelas Tile
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _creationMode = 'classroom';
                    _selectedMemberUids = [];
                    _channelController.clear();
                    _titleController.clear();
                    _step = 1;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF7C3AED),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
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
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih kelas & anggota untuk diskusi kelompok baru',
                              style: AppTypography.fileSize(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
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

            // Opsi 2: Buat Diskusi dengan Teman Tile
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _creationMode = 'friend';
                    _selectedProjectId = null;
                    _selectedProjectName = 'Teman';
                    _selectedProjectData = {};
                    _selectedMemberUids = [];
                    _channelController.text = '#teman';
                    _titleController.clear();
                    _step = 1;
                    _isLoadingFriends = true;
                  });
                  widget.onLoadFriends().then((friends) {
                    if (mounted) {
                      setState(() {
                        _friendsList = friends;
                        _isLoadingFriends = false;
                      });
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0D9488),
                        ),
                        child: const Icon(
                          Icons.diversity_3_rounded,
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
                              'Buat Diskusi dengan Teman',
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih teman untuk diskusi kelompok tanpa verifikasi kelas',
                              style: AppTypography.fileSize(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
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
                        style: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black45),
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
                        style: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black45),
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
                      final bool isFriendsGroup = className == 'Teman Saya';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header #Nama Kelas / #Teman Saya with collapse toggle
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
                                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '#',
                                    style: AppTypography.buttonLabel(color: isFriendsGroup ? const Color(0xFF10B981) : const Color(0xFF6366F1), fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      className,
                                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
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
                                      style: AppTypography.microBadge(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.w600),
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

                          // Contacts under this group (if not collapsed)
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
                                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: Transform.scale(
                                              scale: 1.35,
                                              child: _buildSafeAvatarImage(avatarPath),
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
                                                style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$role ${userId.isNotEmpty ? '· ID: $userId' : ''}',
                                                style: AppTypography.fileSize(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
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
                                            style: AppTypography.channelTag(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
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

          // STEP 1: PILIH ANGGOTA KELAS / PILIH TEMAN
          else if (_step == 1 && isFriendMode) ...[
            // STEP 1 UNTUK DISKUSI TEMAN (TANPA VERIFIKASI KELAS)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Friends Field
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
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
                              style: AppTypography.chatBody(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Cari teman',
                                hintStyle: AppTypography.chatBody(color: isDark ? Colors.white38 : Colors.black38),
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
                        'Pilih Teman (${_selectedMemberUids.length} dipilih)',
                        style: AppTypography.channelTag(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),

                    if (_isLoadingFriends)
                      const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                    else if (_friendsList.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum memiliki teman.',
                                style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tambahkan teman terlebih dahulu di menu Kelola Teman.',
                                textAlign: TextAlign.center,
                                style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black45),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ManageFriendsPage()),
                                  );
                                },
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text('Kelola Teman'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : Colors.black,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final filteredFriends = _friendsList.where((m) {
                              final name = (m['name'] ?? '').toString().toLowerCase();
                              final id = (m['userId'] ?? '').toString().toLowerCase();
                              return name.contains(_memberSearch) || id.contains(_memberSearch);
                            }).toList();

                            final bool isAllSelected = _friendsList.isNotEmpty &&
                                _selectedMemberUids.length >= _friendsList.length;

                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: (_memberSearch.isEmpty ? 1 : 0) + filteredFriends.length,
                              separatorBuilder: (_, __) => Divider(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                height: 1,
                                indent: 64,
                              ),
                              itemBuilder: (ctx, idx) {
                                // Index 0: Seluruh Teman
                                if (_memberSearch.isEmpty && idx == 0) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      ),
                                      child: const Icon(
                                        Icons.diversity_3_rounded,
                                        color: Color(0xFF6366F1),
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      'Seluruh Teman',
                                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'Semua ${_friendsList.length} teman Anda',
                                      style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black54),
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
                                          _selectedMemberUids = _friendsList.map((m) => m['uid'] as String).toList();
                                        }
                                      });
                                    },
                                  );
                                }

                                final memberIdx = _memberSearch.isEmpty ? idx - 1 : idx;
                                final m = filteredFriends[memberIdx];
                                final mUid = m['uid'] as String;
                                final isChecked = _selectedMemberUids.contains(mUid);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Transform.scale(
                                        scale: 1.35,
                                        child: _buildSafeAvatarImage(m['avatar'] as String?),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    m['name'] ?? 'Teman',
                                    style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    'ID: ${m['userId'] ?? '-'}',
                                    style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black38),
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
                ),
              ),
            ),
          ]

          // STEP 1 UNTUK DISKUSI KELAS (DROPDOWN PERSIS DI LAPORAN & CHECKLIST ANGGOTA)
          else if (_step == 1) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Classroom',
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
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
                            style: AppTypography.timestamp(color: Colors.redAccent),
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
                              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedProjectName.isNotEmpty
                                        ? _selectedProjectName
                                        : 'Pilih Classroom',
                                    style: AppTypography.dropdown(color: _selectedProjectName.isNotEmpty ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? Colors.white38 : Colors.black38), fontWeight: _selectedProjectName.isNotEmpty ? FontWeight.w600 : FontWeight.normal),
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
                          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
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
                                style: AppTypography.chatBody(color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: 'Cari anggota kelas',
                                  hintStyle: AppTypography.chatBody(color: isDark ? Colors.white38 : Colors.black38),
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
                          style: AppTypography.channelTag(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
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
                                        style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Semua ${_projectMembers.length} anggota di dalam kelas',
                                        style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black54),
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
                                          child: _buildSafeAvatarImage(m['avatar'] as String?),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '${m['name']}${isSelf ? ' (Anda)' : ''}',
                                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      'ID: ${m['userId'] ?? '-'}',
                                      style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black38),
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

          // STEP 2: INFO DETAIL DISKUSI, AVATAR, NAMA & CHANNEL + DETAIL KELAS / TEMAN
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
                    // Layout 35% - 65% (Kiri Avatar Grup, Kanan Nama Diskusi)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Kiri (35%): Avatar Preview (Tap to toggle frameless slider overlay)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAvatarSlider = !_showAvatarSlider;
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                ),
                                child: _isDefaultGroupIcon
                                    ? Center(
                                        child: Icon(
                                          isFriendMode ? Icons.diversity_3_rounded : Icons.groups_rounded,
                                          color: isFriendMode ? const Color(0xFF6366F1) : const Color(0xFF0F766E),
                                          size: 38,
                                        ),
                                      )
                                    : ClipOval(
                                        child: Transform.scale(
                                          scale: 1.35,
                                          child: Image.asset(_selectedAvatar, fit: BoxFit.cover),
                                        ),
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white : Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _showAvatarSlider ? Icons.check_rounded : Icons.camera_alt_rounded,
                                    size: 12,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Kanan (65%): Nama Diskusi (Wajib Diisi, Fully Rounded)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nama Diskusi',
                                style: AppTypography.channelTag(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _titleController,
                                style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: isFriendMode ? 'Nama Diskusi Teman (Wajib)' : 'Nama Diskusi (Wajib)',
                                  hintStyle: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black38),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Overlay Slider Full-Width Frameless 50% Transparan
                    if (_showAvatarSlider) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.50)
                                  : Colors.white.withValues(alpha: 0.50),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 1.0,
                              ),
                            ),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              itemCount: 11,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (ctx, i) {
                                final isDefaultGroup = i == 0;
                                final avatarPath = isDefaultGroup ? '' : 'assets/icon_pack/chat/chat_$i.png';
                                final isSelected = isDefaultGroup
                                    ? _isDefaultGroupIcon
                                    : (!_isDefaultGroupIcon && _selectedAvatar == avatarPath);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isDefaultGroup) {
                                        _isDefaultGroupIcon = true;
                                        _selectedAvatar = 'assets/icon_pack/chat/chat_1.png';
                                      } else {
                                        _isDefaultGroupIcon = false;
                                        _selectedAvatar = avatarPath;
                                      }
                                      _showAvatarSlider = false;
                                    });
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: isFriendMode ? const Color(0xFF6366F1) : const Color(0xFF0F766E),
                                              width: 2.2,
                                            )
                                          : Border.all(color: Colors.transparent, width: 2.2),
                                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                    ),
                                    child: isDefaultGroup
                                        ? Center(
                                            child: Icon(
                                              isFriendMode ? Icons.diversity_3_rounded : Icons.groups_rounded,
                                              color: isFriendMode ? const Color(0xFF6366F1) : const Color(0xFF0F766E),
                                              size: 26,
                                            ),
                                          )
                                        : ClipOval(
                                            child: Transform.scale(
                                              scale: 1.35,
                                              child: Image.asset(avatarPath, fit: BoxFit.cover),
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Saluran / Channel (Opsional, Full Width di bawahnya, Fully Rounded)
                    Text(
                      'Saluran (Channel)',
                      style: AppTypography.channelTag(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _channelController,
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: isFriendMode
                            ? 'Saluran (Opsional, contoh: #teman-belajar)'
                            : 'Saluran (Opsional, contoh: #diskusi)',
                        hintStyle: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black38),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Opsi Buat Folder Penyimpanan Data
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_shared_rounded,
                              color: Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Folder Penyimpanan Data',
                                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Buat folder arsip berkas grup otomatis',
                                  style: AppTypography.fileSize(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _createDriveFolder,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF7C3AED),
                            onChanged: (val) {
                              setState(() {
                                _createDriveFolder = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Detail Card (Classroom atau Teman) & Anggota Terpilih
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              isFriendMode
                                  ? Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      ),
                                      child: const Icon(
                                        Icons.diversity_3_rounded,
                                        color: Color(0xFF6366F1),
                                        size: 20,
                                      ),
                                    )
                                  : _buildClassroomIcon(_selectedProjectData, size: 38),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isFriendMode
                                          ? 'Diskusi Teman'
                                          : (_selectedProjectName.isNotEmpty ? _selectedProjectName : 'Classroom'),
                                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isFriendMode
                                          ? '${_selectedMemberUids.length} Teman Terpilih'
                                          : '${_selectedMemberUids.length} Anggota',
                                      style: AppTypography.fileSize(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isFriendMode ? 'Teman' : 'Anggota',
                            style: AppTypography.channelTag(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final pool = isFriendMode ? _friendsList : _projectMembers;
                              final selectedMembers = pool
                                  .where((m) => _selectedMemberUids.contains(m['uid']))
                                  .toList();
                              return InkWell(
                                onTap: () => _openManageMembersModal(context),
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStackedAvatars(selectedMembers, isDark),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.people_alt_rounded,
                                            size: 14,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Kelola',
                                            style: AppTypography.microBadge(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                                          ),
                                        ],
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

                    const SizedBox(height: 18),

                    // Pengaturan Hak Akses / Role Admin
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 18,
                                color: isFriendMode ? const Color(0xFF6366F1) : const Color(0xFF0F766E),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hak Akses Anggota',
                                style: AppTypography.channelTag(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Checkbox 1: Edit info grup
                          InkWell(
                            onTap: () {
                              setState(() {
                                _canAllMembersEditInfo = !_canAllMembersEditInfo;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _canAllMembersEditInfo
                                          ? (isDark ? Colors.white : Colors.black)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _canAllMembersEditInfo
                                            ? (isDark ? Colors.white : Colors.black)
                                            : (isDark ? Colors.white38 : Colors.black26),
                                        width: 2,
                                      ),
                                    ),
                                    child: _canAllMembersEditInfo
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: isDark ? Colors.black : Colors.white,
                                            size: 13,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Seluruh anggota dapat mengubah info grup',
                                      style: AppTypography.checkboxLabel(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Checkbox 2: Undang teman
                          InkWell(
                            onTap: () {
                              setState(() {
                                _canAllMembersInvite = !_canAllMembersInvite;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _canAllMembersInvite
                                          ? (isDark ? Colors.white : Colors.black)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _canAllMembersInvite
                                            ? (isDark ? Colors.white : Colors.black)
                                            : (isDark ? Colors.white38 : Colors.black26),
                                        width: 2,
                                      ),
                                    ),
                                    child: _canAllMembersInvite
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: isDark ? Colors.black : Colors.white,
                                            size: 13,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Seluruh anggota dapat mengundang teman',
                                      style: AppTypography.checkboxLabel(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFriendMode
                                ? '• Pembuat grup otomatis menjadi Admin.\n• Seluruh teman yang dipilih dapat bergabung dalam obrolan.'
                                : '• Pembuat grup dan Guru otomatis menjadi Admin.\n• Minimal 1 admin di dalam grup. Guru tidak dapat dilepas.',
                            style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black45),
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
  final VoidCallback? onBackToHome;

  const DocumentsTab({
    super.key,
    this.isDark = false,
    this.onBackToHome,
  });

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _FolderCrumb {
  final String id;
  final String name;
  const _FolderCrumb({required this.id, required this.name});
}

class _DocumentsTabState extends State<DocumentsTab> {
  GoogleSignInAccount? _driveAccount;
  bool _isConnecting = false;
  bool _isUploading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _driveInitialized = false;
  bool _driveAuthorized = false;
  String _driveEmail = '';

  // File Manager State
  final List<_FolderCrumb> _folderCrumbs = [];
  bool _isGridView = false;
  String _sortBy = 'date_desc'; // 'date_desc', 'name_asc', 'size_desc'

  String get _currentFolderId => _folderCrumbs.isEmpty ? '' : _folderCrumbs.last.id;
  String get _currentFolderName => _folderCrumbs.isEmpty ? 'Dokumen Utama' : _folderCrumbs.last.name;

  // Drive scopes for file access
  static const List<String> _driveScopes = [
    drive.DriveApi.driveFileScope,
  ];

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
    _ensureChatFilesFolderExists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureChatFilesFolderExists() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('driveDocuments')
          .where('name', isEqualTo: 'Berkas Diskusi')
          .where('isFolder', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await FirebaseFirestore.instance.collection('driveDocuments').add({
          'name': 'Berkas Diskusi',
          'mimeType': 'application/vnd.google-apps.folder',
          'isFolder': true,
          'parentFolderId': '',
          'driveFileId': '',
          'driveLink': '',
          'uploaderUid': currentUid,
          'uploaderName': 'Sistem',
          'fileSize': 0,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _initGoogleSignIn() async {
    try {
      if (!_driveInitialized) {
        try {
          await GoogleSignIn.instance.initialize(
            clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
            serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
          );
        } catch (_) {}
        _driveInitialized = true;
      }
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null && mounted) {
        setState(() {
          _driveAccount = account;
          _driveAuthorized = true;
          _driveEmail = account.email;
        });
      }
    } catch (_) {}
  }

  Future<bool> _ensureDriveAccount(bool isDriveConnected) async {
    if (!isDriveConnected) {
      final shouldConnect = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.isDarkMode ? const Color(0xFF18181B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Google Drive Belum Tersambung',
            style: AppTypography.buttonLabel(
              color: AppColors.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Anda perlu menghubungkan akun Google Drive untuk dapat mengunggah berkas atau membuat folder baru.',
            style: AppTypography.bodySubtitle(
              color: AppColors.isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Tutup', style: AppTypography.buttonLabel(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Hubungkan', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (shouldConnect == true) {
        await _connectGoogleDrive();
      }
      return false;
    }

    if (_driveAccount == null) {
      try {
        final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (account != null && mounted) {
          setState(() {
            _driveAccount = account;
            _driveAuthorized = true;
            _driveEmail = account.email;
          });
        }
      } catch (_) {}
    }
    return true;
  }

  Future<void> _connectGoogleDrive() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _isConnecting = true);
    try {
      if (kIsWeb) {
        if (_driveAccount != null) {
          await GoogleDriveService.setupUserPublicDriveFolder(
            uid: currentUid,
            folderName: 'Hubner Edu - Dokumen Bersama',
          );
          if (mounted) {
            setState(() => _driveAuthorized = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google Drive berhasil terhubung! Dokumen otomatis tersinkronisasi.'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        try {
          final result = await GoogleDriveService.setupUserPublicDriveFolder(
            uid: currentUid,
            folderName: 'Hubner Edu - Dokumen Bersama',
          );
          if (result != null && mounted) {
            final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
            if (mounted) {
              setState(() {
                _driveAccount = account;
                _driveAuthorized = true;
                _driveEmail = account?.email ?? '';
              });
              await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
                'isDriveConnected': true,
                'publicDriveConnectedEmail': account?.email ?? '',
                'publicDriveConnectedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
        } catch (_) {
          if (mounted) {
            await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
              'isDriveConnected': true,
              'publicDriveConnectedEmail': FirebaseAuth.instance.currentUser?.email ?? 'Google Drive Aktif',
              'publicDriveConnectedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Drive berhasil terhubung! Dokumen otomatis tersinkronisasi.'), backgroundColor: Colors.green),
          );
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
    final isDark = AppColors.isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Putuskan Google Drive?',
          style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Seluruh dokumen yang sudah tersimpan di database tetap dapat diakses dan dibuka bersama, namun Anda tidak dapat mengunggah berkas baru sampai terhubung kembali.',
          style: AppTypography.bodySubtitle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: AppTypography.buttonLabel(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              'Putuskan',
              style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
        'isDriveConnected': false,
      }).catchError((_) {});
    }
    if (mounted) {
      setState(() {
        _driveAccount = null;
        _driveAuthorized = false;
        _driveEmail = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Drive telah diputuskan.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<drive.DriveApi?> _getDriveApi(GoogleSignInAccount account, {bool prompt = true}) async {
    try {
      final clientAuth = prompt
          ? await account.authorizationClient.authorizeScopes(_driveScopes)
          : await account.authorizationClient.authorizationForScopes(_driveScopes);
      if (clientAuth == null) return null;
      final token = clientAuth.accessToken;
      final client = _GoogleAuthClient({'Authorization': 'Bearer $token'});
      return drive.DriveApi(client);
    } catch (e, stack) {
      debugPrint("Error in _getDriveApi: $e\n$stack");
      return null;
    }
  }

  Future<void> _createFolderInDrive({String? parentFolderId, required bool isDriveConnected}) async {
    final hasAccess = await _ensureDriveAccount(isDriveConnected);
    if (!hasAccess || !mounted) return;

    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.isDarkMode ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Buat Folder Baru',
          style: AppTypography.buttonLabel(color: AppColors.isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: AppTypography.timestamp(color: AppColors.isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nama Folder',
            hintStyle: AppTypography.timestamp(color: AppColors.isDarkMode ? Colors.white38 : Colors.black26),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: AppTypography.buttonLabel(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: Text('Buat', style: AppTypography.buttonLabel(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      String folderId = 'folder_${DateTime.now().millisecondsSinceEpoch}';
      String folderLink = '';

      if (_driveAccount != null) {
        try {
          final api = await _getDriveApi(_driveAccount!);
          if (api != null) {
            final driveFile = drive.File()
              ..name = name
              ..mimeType = 'application/vnd.google-apps.folder';

            final targetParent = _currentFolderId.isNotEmpty ? _currentFolderId : parentFolderId;
            if (targetParent != null && targetParent.isNotEmpty) {
              driveFile.parents = [targetParent];
            }

            final folder = await api.files.create(driveFile);
            if (folder.id != null) {
              folderId = folder.id!;
              folderLink = 'https://drive.google.com/drive/folders/$folderId';
              try {
                await api.permissions.create(
                  drive.Permission()
                    ..type = 'anyone'
                    ..role = 'writer',
                  folderId,
                );
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final uploaderName = userDoc.data()?['name'] ?? 'User';

      await FirebaseFirestore.instance.collection('driveDocuments').add({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        'isFolder': true,
        'parentFolderId': _currentFolderId,
        'driveFileId': folderId,
        'driveLink': folderLink,
        'uploaderUid': currentUid,
        'uploaderName': uploaderName,
        'fileSize': 0,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder berhasil dibuat!'), backgroundColor: Colors.green),
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

  Future<void> _uploadFileToDrive({String? targetFolderId, required bool isDriveConnected}) async {
    final hasAccess = await _ensureDriveAccount(isDriveConnected);
    if (!hasAccess || !mounted) return;

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
      final fileSize = file.lengthSync();

      String fileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
      String fileLink = '';

      if (_driveAccount != null) {
        try {
          final api = await _getDriveApi(_driveAccount!);
          if (api != null) {
            final driveFile = drive.File()
              ..name = fileName
              ..mimeType = mimeType;

            final effectiveTarget = _currentFolderId.isNotEmpty ? _currentFolderId : targetFolderId;
            if (effectiveTarget != null && effectiveTarget.isNotEmpty) {
              driveFile.parents = [effectiveTarget];
            }

            final uploadedFile = await api.files.create(
              driveFile,
              uploadMedia: drive.Media(file.openRead(), fileSize),
            );

            if (uploadedFile.id != null) {
              fileId = uploadedFile.id!;
              fileLink = 'https://drive.google.com/file/d/$fileId/view';
              try {
                await api.permissions.create(
                  drive.Permission()
                    ..type = 'anyone'
                    ..role = 'reader',
                  fileId,
                );
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final uploaderName = userDoc.data()?['name'] ?? 'User';
      final uploaderAvatar = userDoc.data()?['avatar'] ?? '';
      final projectIds = List<String>.from(userDoc.data()?['projectIds'] ?? []);

      await FirebaseFirestore.instance.collection('driveDocuments').add({
        'name': fileName,
        'mimeType': mimeType,
        'isFolder': false,
        'parentFolderId': _currentFolderId,
        'driveFileId': fileId,
        'driveLink': fileLink,
        'uploaderUid': currentUid,
        'uploaderName': uploaderName,
        'uploaderAvatar': uploaderAvatar,
        'projectIds': projectIds,
        'fileSize': file.lengthSync(),
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas berhasil diunggah!'), backgroundColor: Colors.green),
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

  Future<void> _renameItem(String docId, String currentName, bool isFolder) async {
    final textController = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.isDarkMode ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Ganti Nama ${isFolder ? "Folder" : "Berkas"}',
          style: AppTypography.buttonLabel(color: AppColors.isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: AppTypography.timestamp(color: AppColors.isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nama baru',
            hintStyle: AppTypography.timestamp(color: AppColors.isDarkMode ? Colors.white38 : Colors.black26),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: AppTypography.buttonLabel(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: Text('Simpan', style: AppTypography.buttonLabel(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await FirebaseFirestore.instance.collection('driveDocuments').doc(docId).update({
        'name': newName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama berhasil diperbarui!')),
        );
      }
    }
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _getFileIcon(String? mimeType, bool isFolder) {
    if (isFolder || (mimeType != null && mimeType.contains('folder'))) return Icons.folder_rounded;
    if (mimeType == null) return Icons.insert_drive_file_rounded;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mimeType.contains('image')) return Icons.image_rounded;
    if (mimeType.contains('video')) return Icons.videocam_rounded;
    if (mimeType.contains('audio')) return Icons.audiotrack_rounded;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) return Icons.table_chart_rounded;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow_rounded;
    if (mimeType.contains('document') || mimeType.contains('word')) return Icons.description_rounded;
    if (mimeType.contains('zip') || mimeType.contains('compressed')) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String? mimeType, bool isFolder) {
    if (isFolder || (mimeType != null && mimeType.contains('folder'))) return const Color(0xFFF59E0B);
    if (mimeType == null) return const Color(0xFF6B7280);
    if (mimeType.contains('pdf')) return const Color(0xFFEF4444);
    if (mimeType.contains('image')) return const Color(0xFF8B5CF6);
    if (mimeType.contains('video')) return const Color(0xFFDC2626);
    if (mimeType.contains('audio')) return const Color(0xFF10B981);
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) return const Color(0xFF059669);
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return const Color(0xFFD97706);
    if (mimeType.contains('document') || mimeType.contains('word')) return const Color(0xFF2563EB);
    return const Color(0xFF4B5563);
  }

  void _openFileInApp({
    required String fileName,
    required String? mimeType,
    required String driveLink,
    required String uploaderName,
    required String dateStr,
    required int fileSize,
  }) {
    InAppFileViewerDialog.show(
      context,
      fileName: fileName,
      mimeType: mimeType,
      fileUrl: driveLink,
      uploaderName: uploaderName,
      dateFormatted: dateStr,
      fileSize: fileSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';

        return StreamBuilder<DocumentSnapshot>(
          stream: currentUid.isNotEmpty
              ? FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots()
              : null,
          builder: (context, userSnap) {
            final bool isUserLoading = userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData;
            final userData = userSnap.data?.data() as Map<String, dynamic>?;
            final String publicDriveFolderId = userData?['publicDriveFolderId'] ?? '';
            final bool isDriveConnected = (userData?['isDriveConnected'] ?? publicDriveFolderId.isNotEmpty) == true;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('driveDocuments')
                  .orderBy('uploadedAt', descending: true)
                  .snapshots(),
              builder: (context, docSnap) {
                final docs = docSnap.data?.docs ?? [];

                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    if (_folderCrumbs.isNotEmpty) {
                      setState(() {
                        _folderCrumbs.removeLast();
                      });
                    } else if (widget.onBackToHome != null) {
                      widget.onBackToHome!();
                    }
                  },
                  child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Main Header (Title & Subtitle)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dokumen',
                                        style: AppTypography.pageTitle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Kelola & pratinjau berkas bersama',
                                        style: AppTypography.bodySubtitle(color: isDark ? Colors.white60 : Colors.black45),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isUploading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F52FC))),
                                  ),
                              ],
                            ),
                          ),

                          // Status Bar Google Drive: Terhubung (Google Drive -> Terhubung dengan dot hijau -> Tombol Putuskan di bawahnya)
                          if (isDriveConnected)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const GoogleDriveLogoWidget(size: 26),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Google Drive',
                                                style: AppTypography.buttonLabel(
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Terhubung',
                                                    style: AppTypography.fileSize(
                                                      color: const Color(0xFF10B981),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: BouncyButton(
                                        onTap: _disconnectGoogleDrive,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isDark ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFFECACA),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.link_off_rounded, color: Color(0xFFDC2626), size: 14),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Putuskan',
                                                style: AppTypography.buttonLabel(
                                                  color: const Color(0xFFDC2626),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (!isUserLoading)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 4.0),
                              child: _buildDriveNotConnectedCard(isDark),
                            ),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_folderCrumbs.isNotEmpty) {
                                    setState(() {
                                      _folderCrumbs.removeLast();
                                    });
                                  } else {
                                    widget.onBackToHome?.call();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _folderCrumbs.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _folderCrumbs.isEmpty
                                        ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.home_rounded,
                                        size: 16,
                                        color: _folderCrumbs.isEmpty ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Root',
                                        style: AppTypography.channelTag(color: _folderCrumbs.isEmpty ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87), fontWeight: _folderCrumbs.isEmpty ? FontWeight.bold : FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              for (int i = 0; i < _folderCrumbs.length; i++) ...[
                                Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _folderCrumbs.removeRange(i + 1, _folderCrumbs.length);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: i == _folderCrumbs.length - 1
                                          ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _folderCrumbs[i].name,
                                      style: AppTypography.channelTag(color: i == _folderCrumbs.length - 1 ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87), fontWeight: i == _folderCrumbs.length - 1 ? FontWeight.bold : FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Search Input with Upload Button placed next to it
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) {
                                          setState(() {
                                            _searchQuery = val.trim().toLowerCase();
                                          });
                                        },
                                        style: AppTypography.searchInput(color: isDark ? Colors.white : Colors.black87),
                                        decoration: InputDecoration(
                                          hintText: 'Cari berkas...',
                                          hintStyle: AppTypography.searchInput(color: isDark ? Colors.white38 : Colors.black38),
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
                                          color: isDark ? Colors.white54 : Colors.black45,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BouncyButton(
                              onTap: () => _uploadFileToDrive(
                                targetFolderId: publicDriveFolderId,
                                isDriveConnected: isDriveConnected,
                              ),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF97316), // Orange
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sub-Bar: Sort text with A Arrow Up icon ("A Panah Naik") & Add Folder below textbox + View Mode Toggle
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (_sortBy == 'name_asc') {
                                    _sortBy = 'name_desc';
                                  } else if (_sortBy == 'name_desc') {
                                    _sortBy = 'date_desc';
                                  } else {
                                    _sortBy = 'name_asc';
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sort_by_alpha_rounded,
                                      size: 16,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _sortBy == 'name_asc'
                                          ? 'Nama (A - Z)'
                                          : (_sortBy == 'name_desc' ? 'Nama (Z - A)' : 'Terbaru'),
                                      style: AppTypography.timestamp(
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortBy == 'name_desc' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      size: 13,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BouncyButton(
                                  onTap: () => _createFolderInDrive(
                                    parentFolderId: publicDriveFolderId,
                                    isDriveConnected: isDriveConnected,
                                  ),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Icon(
                                      Icons.create_new_folder_rounded,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                BouncyButton(
                                  onTap: () => setState(() => _isGridView = !_isGridView),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Icon(
                                      _isGridView ? Icons.format_list_bulleted_rounded : Icons.grid_view_rounded,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // File Explorer List / Grid from Firestore
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (docSnap.connectionState == ConnectionState.waiting && !docSnap.hasData) {
                              return const SizedBox.shrink();
                            }

                            // Filter by current folder (or search globally if query is not empty)
                            final filtered = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final parentId = (data['parentFolderId'] ?? '').toString();

                              if (_searchQuery.isNotEmpty) {
                                return name.contains(_searchQuery);
                              }
                              // Hierarchy matching:
                              if (_folderCrumbs.isEmpty) {
                                return parentId.isEmpty || parentId == publicDriveFolderId;
                              }
                              return parentId == _folderCrumbs.last.id;
                            }).toList();

                            // Sort filtered items
                            filtered.sort((a, b) {
                              final dataA = a.data() as Map<String, dynamic>;
                              final dataB = b.data() as Map<String, dynamic>;
                              final bool isFolderA = dataA['isFolder'] == true;
                              final bool isFolderB = dataB['isFolder'] == true;
                              if (isFolderA != isFolderB) {
                                return isFolderA ? -1 : 1;
                              }
                              if (_sortBy == 'name_asc') {
                                return (dataA['name'] ?? '').toString().compareTo((dataB['name'] ?? '').toString());
                              } else if (_sortBy == 'size_desc') {
                                final sizeA = (dataA['fileSize'] ?? 0) as num;
                                final sizeB = (dataB['fileSize'] ?? 0) as num;
                                return sizeB.compareTo(sizeA);
                              } else {
                                final timeA = dataA['uploadedAt'] as Timestamp?;
                                final timeB = dataB['uploadedAt'] as Timestamp?;
                                if (timeA == null) return 1;
                                if (timeB == null) return -1;
                                return timeB.compareTo(timeA);
                              }
                            });

                            if (filtered.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.folder_open,
                                      size: 48,
                                      color: isDark ? Colors.white12 : Colors.black12,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Tidak ada berkas cocok dengan pencarian.'
                                          : 'Folder ini masih kosong.\nUpload berkas atau buat folder baru!',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black38),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (_isGridView) {
                              return GridView.builder(
                                padding: EdgeInsets.only(left: AppTypography.screenHorizontalMargin, right: AppTypography.screenHorizontalMargin, bottom: 120.0, top: 8),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final docSnap = filtered[index];
                                  final data = docSnap.data() as Map<String, dynamic>;
                                  return _buildGridItem(context, docSnap.id, data, currentUid, isDark);
                                },
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.only(left: 0, right: 0, bottom: 120.0, top: 4),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 0.8,
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                indent: 56 + AppTypography.screenHorizontalMargin,
                                endIndent: AppTypography.screenHorizontalMargin,
                              ),
                              itemBuilder: (context, index) {
                                final docSnap = filtered[index];
                                final data = docSnap.data() as Map<String, dynamic>;
                                return _buildListItem(context, docSnap.id, data, currentUid, isDark);
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
        },
      );
    },
  );
},
);
}

  Widget _buildListItem(BuildContext context, String docId, Map<String, dynamic> data, String currentUid, bool isDark) {
    final fileName = data['name'] ?? 'Untitled';
    final mimeType = data['mimeType'] as String?;
    final isFolder = data['isFolder'] == true || (mimeType != null && mimeType.contains('folder'));
    final driveLink = data['driveLink'] ?? '';
    final driveFileId = data['driveFileId'] ?? '';
    final uploaderName = data['uploaderName'] ?? 'User';
    final uploaderUid = data['uploaderUid'] ?? '';
    final fileSize = data['fileSize'] ?? 0;
    final isMyFile = uploaderUid == currentUid;
    final uploadedAt = data['uploadedAt'] as Timestamp?;
    final dateStr = uploadedAt != null
        ? '${uploadedAt.toDate().day}/${uploadedAt.toDate().month}/${uploadedAt.toDate().year}'
        : '';

    final fileColor = _getFileColor(mimeType, isFolder);
    final fileIcon = _getFileIcon(mimeType, isFolder);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isFolder) {
            setState(() {
              _folderCrumbs.add(_FolderCrumb(id: driveFileId.isNotEmpty ? driveFileId : docId, name: fileName));
            });
          } else {
            _openFileInApp(
              fileName: fileName,
              mimeType: mimeType,
              driveLink: driveLink,
              uploaderName: uploaderName,
              dateStr: dateStr,
              fileSize: fileSize is int ? fileSize : 0,
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: fileColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(fileIcon, color: fileColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.documentTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        isFolder ? 'Folder' : (isMyFile ? 'Saya' : uploaderName),
                        style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black38),
                      ),
                      if (!isFolder && fileSize > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatBytes(fileSize.toDouble()),
                          style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '',
              icon: Icon(Icons.more_vert, size: 18, color: isDark ? Colors.white38 : Colors.black38),
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) async {
                if (val == 'view') {
                  if (isFolder) {
                    setState(() {
                      _folderCrumbs.add(_FolderCrumb(id: driveFileId.isNotEmpty ? driveFileId : docId, name: fileName));
                    });
                  } else {
                    _openFileInApp(
                      fileName: fileName,
                      mimeType: mimeType,
                      driveLink: driveLink,
                      uploaderName: uploaderName,
                      dateStr: dateStr,
                      fileSize: fileSize is int ? fileSize : 0,
                    );
                  }
                } else if (val == 'download') {
                  final uri = Uri.parse(driveLink);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } else if (val == 'rename') {
                  _renameItem(docId, fileName, isFolder);
                } else if (val == 'copy') {
                  Clipboard.setData(ClipboardData(text: driveLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tautan berhasil disalin!')),
                  );
                } else if (val == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                      title: Text(
                        'Hapus ${isFolder ? "Folder" : "Berkas"}',
                        style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      ),
                      content: Text(
                        'Hapus "$fileName" dari repositori?',
                        style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Batal', style: AppTypography.buttonLabel(color: Colors.black54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Hapus', style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseFirestore.instance.collection('driveDocuments').doc(docId).delete();
                  }
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(isFolder ? Icons.folder_open : Icons.visibility, size: 16),
                      const SizedBox(width: 8),
                      Text(isFolder ? 'Buka Folder' : 'Buka / Pratinjau', style: AppTypography.buttonLabel()),
                    ],
                  ),
                ),
                if (!isFolder && driveLink.isNotEmpty)
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        const Icon(Icons.download_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text('Unduh', style: AppTypography.buttonLabel(color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 16),
                      const SizedBox(width: 8),
                      Text('Ganti Nama', style: AppTypography.buttonLabel()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16),
                      const SizedBox(width: 8),
                      Text('Salin Tautan', style: AppTypography.buttonLabel()),
                    ],
                  ),
                ),
                if (isMyFile) ...[
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text('Hapus', style: AppTypography.buttonLabel(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildGridItem(BuildContext context, String docId, Map<String, dynamic> data, String currentUid, bool isDark) {
    final fileName = data['name'] ?? 'Untitled';
    final mimeType = data['mimeType'] as String?;
    final isFolder = data['isFolder'] == true || (mimeType != null && mimeType.contains('folder'));
    final driveLink = data['driveLink'] ?? '';
    final driveFileId = data['driveFileId'] ?? '';
    final uploaderName = data['uploaderName'] ?? 'User';
    final uploaderUid = data['uploaderUid'] ?? '';
    final fileSize = data['fileSize'] ?? 0;
    final isMyFile = uploaderUid == currentUid;
    final uploadedAt = data['uploadedAt'] as Timestamp?;
    final dateStr = uploadedAt != null
        ? '${uploadedAt.toDate().day}/${uploadedAt.toDate().month}/${uploadedAt.toDate().year}'
        : '';

    final fileColor = _getFileColor(mimeType, isFolder);
    final fileIcon = _getFileIcon(mimeType, isFolder);

    return GestureDetector(
      onTap: () {
        if (isFolder) {
          setState(() {
            _folderCrumbs.add(_FolderCrumb(id: driveFileId.isNotEmpty ? driveFileId : docId, name: fileName));
          });
        } else {
          _openFileInApp(
            fileName: fileName,
            mimeType: mimeType,
            driveLink: driveLink,
            uploaderName: uploaderName,
            dateStr: dateStr,
            fileSize: fileSize is int ? fileSize : 0,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: fileColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(fileIcon, color: fileColor, size: 20),
                ),
                PopupMenuButton<String>(
                  tooltip: '',
                  icon: Icon(Icons.more_horiz_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) async {
                    if (val == 'view') {
                      if (isFolder) {
                        setState(() {
                          _folderCrumbs.add(_FolderCrumb(id: driveFileId.isNotEmpty ? driveFileId : docId, name: fileName));
                        });
                      } else {
                        _openFileInApp(
                          fileName: fileName,
                          mimeType: mimeType,
                          driveLink: driveLink,
                          uploaderName: uploaderName,
                          dateStr: dateStr,
                          fileSize: fileSize is int ? fileSize : 0,
                        );
                      }
                    } else if (val == 'download') {
                      final uri = Uri.parse(driveLink);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } else if (val == 'rename') {
                      _renameItem(docId, fileName, isFolder);
                    } else if (val == 'copy') {
                      Clipboard.setData(ClipboardData(text: driveLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tautan berhasil disalin!')),
                      );
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                          title: Text(
                            'Hapus ${isFolder ? "Folder" : "Berkas"}',
                            style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'Hapus "$fileName" dari repositori?',
                            style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Batal', style: AppTypography.buttonLabel(color: Colors.black54)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Hapus', style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance.collection('driveDocuments').doc(docId).delete();
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Text(isFolder ? 'Buka Folder' : 'Buka di Aplikasi', style: AppTypography.buttonLabel()),
                    ),
                    if (!isFolder && driveLink.isNotEmpty)
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            const Icon(Icons.download_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Text('Unduh', style: AppTypography.buttonLabel(color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Ganti Nama', style: AppTypography.buttonLabel()),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Text('Salin Tautan', style: AppTypography.buttonLabel()),
                    ),
                    if (isMyFile) ...[
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus', style: AppTypography.buttonLabel(color: Colors.redAccent)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.documentTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isFolder ? 'Folder' : (fileSize > 0 ? _formatBytes(fileSize.toDouble()) : (isMyFile ? 'Saya' : uploaderName)),
                  style: AppTypography.fileSize(color: isDark ? Colors.white38 : Colors.black38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriveNotConnectedCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6), // Ungu seperti di halaman laporan
        borderRadius: BorderRadius.circular(28), // Round sesuai tema
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CustomPaint(
          painter: _PurplePatternPainter(patternColor: Colors.white.withValues(alpha: 0.16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: GoogleDriveLogoWidget(size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sinkronisasi Google Drive',
                  style: AppTypography.cardTitle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hubungkan sekali untuk mengaktifkan folder bersama seluruh anggota.',
                  textAlign: TextAlign.center,
                  style: AppTypography.fileSize(color: Colors.white.withValues(alpha: 0.9), height: 1.35),
                ),
                const SizedBox(height: 18),
                if (kIsWeb && _driveAccount == null)
                  const GoogleSignInWebButton()
                else
                  BouncyButton(
                    onTap: _isConnecting ? null : _connectGoogleDrive,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black, // Tombol round warna hitam
                        borderRadius: BorderRadius.circular(24), // Round
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isConnecting)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          else
                            const GoogleDriveLogoWidget(size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _isConnecting ? 'Menghubungkan...' : 'Hubungkan Google Drive',
                            style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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

class _PurplePatternPainter extends CustomPainter {
  final Color patternColor;
  _PurplePatternPainter({required this.patternColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = patternColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = patternColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.92, -15), 75, fillPaint);
    canvas.drawCircle(Offset(size.width * 0.92, -15), 75, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.92, -15), 105, strokePaint);

    canvas.drawCircle(Offset(10, size.height + 25), 85, fillPaint);
    canvas.drawCircle(Offset(10, size.height + 25), 85, strokePaint);
    canvas.drawCircle(Offset(10, size.height + 25), 115, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileHeroMicroPatternPainter extends CustomPainter {
  final String avatarPath;
  final bool isDark;
  final double progress;

  _ProfileHeroMicroPatternPainter({
    required this.avatarPath,
    required this.isDark,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rand = Random(avatarPath.hashCode);
    final int patternType = avatarPath.hashCode.abs() % 5;

    // Subtle dark/light opacity for geometric shapes matching reference image
    final geoColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.10);
    final accentGeoColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.26);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Smooth subtle floating drift
    final driftX = sin(progress * 2 * pi) * 6.0;
    final driftY = cos(progress * 2 * pi) * 4.0;
    final rotAngle = progress * 2 * pi;

    switch (patternType) {
      case 0:
        // === Variation 0: Bauhaus Arches, Wedges & Triangles ===
        fillPaint.color = geoColor;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(15 + driftX, 15 + driftY), radius: 38),
          0,
          pi / 2,
          true,
          fillPaint,
        );

        fillPaint.color = accentGeoColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(size.width - 35 - driftX, 32 + driftY), width: 34, height: 34),
            const Radius.circular(10),
          ),
          fillPaint,
        );

        fillPaint.color = geoColor;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(30 + driftX, size.height * 0.48 - driftY), radius: 30),
          pi * 0.2,
          pi * 1.5,
          true,
          fillPaint,
        );

        fillPaint.color = accentGeoColor;
        final triPath = Path()
          ..moveTo(size.width - 15 - driftX, size.height * 0.40 + driftY)
          ..lineTo(size.width - 50 - driftX, size.height * 0.50 + driftY)
          ..lineTo(size.width - 15 - driftX, size.height * 0.58 + driftY)
          ..close();
        canvas.drawPath(triPath, fillPaint);

        fillPaint.color = geoColor;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(size.width - 20 + driftX, size.height * 0.86 - driftY), radius: 38),
          pi,
          pi / 2,
          true,
          fillPaint,
        );
        break;

      case 1:
        // === Variation 1: Memphis Waves, Capsules & Diamond Stars ===
        fillPaint.color = geoColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(10 + driftX, 15 + driftY, 60, 24),
            const Radius.circular(12),
          ),
          fillPaint,
        );

        fillPaint.color = accentGeoColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 55 - driftX, 20 + driftY, 42, 42),
            const Radius.circular(21),
          ),
          fillPaint,
        );

        // Diamond star on middle left with gentle rotation
        fillPaint.color = accentGeoColor;
        canvas.save();
        canvas.translate(35 + driftX, size.height * 0.50 + driftY);
        canvas.rotate(rotAngle * 0.25);
        final dS = 18.0;
        final dPath = Path()
          ..moveTo(0, -dS)
          ..lineTo(dS, 0)
          ..lineTo(0, dS)
          ..lineTo(-dS, 0)
          ..close();
        canvas.drawPath(dPath, fillPaint);
        canvas.restore();

        // Concentric waves / arcs on right
        strokePaint.color = geoColor;
        strokePaint.strokeWidth = 3.5;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(size.width - 20 - driftX, size.height * 0.52 + driftY), radius: 32),
          pi * 0.7,
          pi * 1.1,
          false,
          strokePaint,
        );
        canvas.drawArc(
          Rect.fromCircle(center: Offset(size.width - 20 - driftX, size.height * 0.52 + driftY), radius: 46),
          pi * 0.7,
          pi * 1.1,
          false,
          strokePaint,
        );
        break;

      case 2:
        // === Variation 2: Modern Concentric Rings & Grid Arrays ===
        strokePaint.color = accentGeoColor;
        strokePaint.strokeWidth = 3.0;
        canvas.drawCircle(Offset(28 + driftX, 30 + driftY), 22, strokePaint);
        canvas.drawCircle(Offset(28 + driftX, 30 + driftY), 34, strokePaint);

        fillPaint.color = geoColor;
        canvas.drawCircle(Offset(size.width - 32 - driftX, 36 + driftY), 26, fillPaint);

        // Diagonal pill strips on bottom
        fillPaint.color = geoColor;
        canvas.save();
        canvas.translate(size.width - 45 - driftX, size.height * 0.58 + driftY);
        canvas.rotate(-pi / 4 + sin(rotAngle) * 0.1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-30, -10, 60, 20),
            const Radius.circular(10),
          ),
          fillPaint,
        );
        canvas.restore();

        fillPaint.color = accentGeoColor;
        canvas.save();
        canvas.translate(35 + driftX, size.height * 0.56 - driftY);
        canvas.rotate(pi / 6 - sin(rotAngle) * 0.1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-25, -8, 50, 16),
            const Radius.circular(8),
          ),
          fillPaint,
        );
        canvas.restore();
        break;

      case 3:
        // === Variation 3: Playful 4-Point Starbursts & Organic Crescents ===
        fillPaint.color = accentGeoColor;
        // Starburst top left with gentle rotation
        canvas.save();
        canvas.translate(30 + driftX, 28 + driftY);
        canvas.rotate(rotAngle * 0.3);
        final sPath = Path()
          ..moveTo(0, -18)
          ..quadraticBezierTo(0, 0, 18, 0)
          ..quadraticBezierTo(0, 0, 0, 18)
          ..quadraticBezierTo(0, 0, -18, 0)
          ..quadraticBezierTo(0, 0, 0, -18)
          ..close();
        canvas.drawPath(sPath, fillPaint);
        canvas.restore();

        // Crescent top right
        fillPaint.color = geoColor;
        final cPath = Path()
          ..addOval(Rect.fromCircle(center: Offset(size.width - 35 - driftX, 35 + driftY), radius: 25));
        final cutPath = Path()
          ..addOval(Rect.fromCircle(center: Offset(size.width - 44 - driftX, 30 + driftY), radius: 22));
        final diffPath = Path.combine(PathOperation.difference, cPath, cutPath);
        canvas.drawPath(diffPath, fillPaint);

        // Pebble blob middle right
        fillPaint.color = accentGeoColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 50 - driftX, size.height * 0.46 + driftY, 44, 32),
            const Radius.circular(16),
          ),
          fillPaint,
        );

        // Double arc bottom left
        strokePaint.color = geoColor;
        strokePaint.strokeWidth = 3.0;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(20 + driftX, size.height * 0.65 - driftY), radius: 26),
          -pi * 0.2,
          pi * 1.2,
          false,
          strokePaint,
        );
        break;

      case 4:
      default:
        // === Variation 4: Dynamic Hexagons, Ribbons & Rounded Cutouts ===
        fillPaint.color = geoColor;
        // Hexagon top left with gentle rotation
        canvas.save();
        canvas.translate(32 + driftX, 32 + driftY);
        canvas.rotate(rotAngle * 0.15);
        final hPath = Path();
        final hRadius = 24.0;
        for (int i = 0; i < 6; i++) {
          final angle = pi / 3 * i;
          final pX = hRadius * cos(angle);
          final pY = hRadius * sin(angle);
          if (i == 0) {
            hPath.moveTo(pX, pY);
          } else {
            hPath.lineTo(pX, pY);
          }
        }
        hPath.close();
        canvas.drawPath(hPath, fillPaint);
        canvas.restore();

        // Chevron arrow right
        fillPaint.color = accentGeoColor;
        final chPath = Path()
          ..moveTo(size.width - 48 - driftX, size.height * 0.38 + driftY)
          ..lineTo(size.width - 24 - driftX, size.height * 0.46 + driftY)
          ..lineTo(size.width - 48 - driftX, size.height * 0.54 + driftY)
          ..lineTo(size.width - 36 - driftX, size.height * 0.46 + driftY)
          ..close();
        canvas.drawPath(chPath, fillPaint);

        // Rounded pill ribbon on bottom right
        fillPaint.color = geoColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 65 - driftX, size.height * 0.80 + driftY, 55, 20),
            const Radius.circular(10),
          ),
          fillPaint,
        );
        break;
    }

    // Common scattered playful micro-dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 7; i++) {
      final x = ((rand.nextDouble() * 0.86 + 0.07) * size.width) + sin(progress * 2 * pi + i) * 4.0;
      final y = ((rand.nextDouble() * 0.86 + 0.07) * size.height) + cos(progress * 2 * pi + i) * 4.0;
      dotPaint.color = (i % 2 == 0 ? accentGeoColor : geoColor);
      canvas.drawCircle(Offset(x, y), 2.5 + rand.nextDouble() * 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileHeroMicroPatternPainter oldDelegate) {
    return oldDelegate.avatarPath != avatarPath ||
        oldDelegate.isDark != isDark ||
        oldDelegate.progress != progress;
  }
}

// --- Dynamic Profile Page Tab ---
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _cachedUserData;
  bool _showAvatarOverlay = false;
  late AnimationController _animController;
  ScrollController? _scrollController;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  ScrollController get scrollController {
    if (_scrollController == null) {
      _scrollController = ScrollController()
        ..addListener(() {
          _scrollOffsetNotifier.value = _scrollController?.offset ?? 0.0;
        });
    }
    return _scrollController!;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        _scrollOffsetNotifier.value = _scrollController?.offset ?? 0.0;
      });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _scrollOffsetNotifier.dispose();
    _animController.dispose();
    super.dispose();
  }

  // 10 Pasangan Warna Resmi Identitas Classroom dari desain.md
  static const List<Color> _classroomCardColors = [
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

  static const List<Color> _classroomCardDarkColors = [
    Color(0xFF6B3BA3), // 01. Deep Lilac (Core)
    Color(0xFF2864A8), // 02. Deep Sky Blue
    Color(0xFF147D75), // 03. Deep Teal / Tosca
    Color(0xFFC76D10), // 04. Deep Amber / Orange
    Color(0xFFA82658), // 05. Deep Rose Magenta (dari desain.md)
    Color(0xFF4338CA), // 06. Deep Indigo Violet
    Color(0xFF4D7C0F), // 07. Deep Olive Lime (dari desain.md)
    Color(0xFF0E7490), // 08. Deep Ocean Cyan
    Color(0xFFA16207), // 09. Deep Amber Gold
    Color(0xFF334155), // 10. Deep Slate Steel
  ];

  Color _getHeroColor(String avatarPath, bool isDark) {
    int idx = 0;
    final match = RegExp(r'(\d+)').firstMatch(avatarPath);
    if (match != null) {
      idx = (int.tryParse(match.group(1) ?? '1') ?? 1) - 1;
    } else {
      idx = avatarPath.hashCode.abs();
    }
    final colors = isDark ? _classroomCardDarkColors : _classroomCardColors;
    return colors[idx % colors.length];
  }

  void _deleteAccount(BuildContext context, String currentUid) async {
    final bool isDark = AppColors.isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Hapus Akun',
          style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Yakin ingin menghapus akun Anda secara permanen? Semua data proyek dan tugas Anda akan dihapus selamanya.',
          style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: AppTypography.buttonLabel(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus Permanen', style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
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

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
      child: Text(
        title,
        style: AppTypography.sectionHeader(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDualToneSvgIcon(String iconType, String accentHex, bool isDark, {double size = 20}) {
    final String mainColor = isDark ? '#FFFFFF' : '#18181B';
    String svgStr;

    switch (iconType) {
      case 'email':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect x="3" y="5" width="18" height="14" rx="3" stroke="$mainColor" stroke-width="2"/>
          <path d="M3 7l9 6 9-6" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <circle cx="12" cy="12" r="2.2" fill="$accentHex"/>
        </svg>''';
        break;

      case 'gender':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="8" r="4.5" stroke="$mainColor" stroke-width="2"/>
          <path d="M4 20c0-4.418 3.582-8 8-8s8 3.582 8 8" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <circle cx="12" cy="8" r="2.2" fill="$accentHex"/>
        </svg>''';
        break;

      case 'school':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 3L2 8l10 5 10-5-10-5z" stroke="$mainColor" stroke-width="2" stroke-linejoin="round"/>
          <path d="M6 10.6v5.4c0 3.3 2.7 6 6 6s6-2.7 6-6v-5.4" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <path d="M22 8v7" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
          <circle cx="22" cy="15.5" r="1.5" fill="$accentHex"/>
        </svg>''';
        break;

      case 'timezone':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="$mainColor" stroke-width="2"/>
          <path d="M12 7v5l3.5 2" stroke="$accentHex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <circle cx="12" cy="12" r="1.5" fill="$accentHex"/>
        </svg>''';
        break;

      case 'language':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="$mainColor" stroke-width="2"/>
          <path d="M3.6 9h16.8M3.6 15h16.8" stroke="$mainColor" stroke-width="1.8" stroke-linecap="round"/>
          <path d="M12 3a14 14 0 010 18M12 3a14 14 0 000 18" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
        </svg>''';
        break;

      case 'password':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect x="4" y="10" width="16" height="11" rx="3" stroke="$mainColor" stroke-width="2"/>
          <path d="M8 10V7a4 4 0 118 0v3" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <circle cx="12" cy="15.5" r="1.8" fill="$accentHex"/>
          <path d="M12 17.3v1.7" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
        </svg>''';
        break;

      case 'security':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 3L4 6.5v6c0 5 3.4 9.6 8 10.5 4.6-.9 8-5.5 8-10.5v-6L12 3z" stroke="$mainColor" stroke-width="2" stroke-linejoin="round"/>
          <path d="M9 12l2 2 4-4" stroke="$accentHex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>''';
        break;

      case 'theme':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 3a9 9 0 100 18 3.5 3.5 0 003.5-3.5c0-.9-.4-1.7-.4-2.5 0-1.7 1.3-3 3-3h1.9A9 9 0 0012 3z" stroke="$mainColor" stroke-width="2"/>
          <circle cx="7.5" cy="10.5" r="1.6" fill="$accentHex"/>
          <circle cx="12" cy="7.5" r="1.6" fill="$accentHex"/>
          <circle cx="16.5" cy="10.5" r="1.6" fill="$accentHex"/>
        </svg>''';
        break;

      case 'notification':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M13.73 21a2 2 0 01-3.46 0" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <circle cx="18" cy="5" r="2.5" fill="$accentHex"/>
        </svg>''';
        break;

      case 'about':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="$mainColor" stroke-width="2"/>
          <circle cx="12" cy="8" r="1.6" fill="$accentHex"/>
          <path d="M12 11.5v5" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
        </svg>''';
        break;

      case 'cache':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M19 11l-8-8-8 8M4 11v9a2 2 0 002 2h12a2 2 0 002-2v-9" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M15 5l2-2 2 2-2 2-2-2zM9 13l1.5-1.5 1.5 1.5-1.5 1.5L9 13z" fill="$accentHex"/>
        </svg>''';
        break;

      case 'delete_account':
      default:
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2" stroke="$mainColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M10 11v6M14 11v6" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
        </svg>''';
        break;
    }

    return SvgPicture.string(
      svgStr,
      width: size,
      height: size,
    );
  }

  Widget _buildInfoTile({
    required String iconType,
    required String accentHex,
    required String title,
    required String value,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Dual-tone 60% Black/White + 40% Accent Color SVG Icon
            _buildDualToneSvgIcon(iconType, accentHex, isDark, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.timestamp(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isNotEmpty ? value : '-',
                    style: AppTypography.cardTitle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String iconType,
    required String accentHex,
    required String title,
    required String trailing,
    required VoidCallback onTap,
    required bool isDark,
    Color? titleColor,
  }) {
    final effectiveTitleColor = titleColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Dual-tone 60% Black/White + 40% Accent Color SVG Icon
            _buildDualToneSvgIcon(iconType, accentHex, isDark, size: 20),
            const SizedBox(width: 14),
            Text(
              title,
              maxLines: 1,
              style: AppTypography.cardTitle(
                color: effectiveTitleColor,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
            const Spacer(),
            if (trailing.isNotEmpty) ...[
              Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTypography.timestamp(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, activeTheme, _) {
        final bool isDark = activeTheme == 'Gelap' || activeTheme == 'Hitam';

        Future<void> logOut() async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Keluar dari Akun',
                style: AppTypography.buttonLabel(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Apakah Anda yakin ingin keluar dari akun ini?',
                style: AppTypography.buttonLabel(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Batal',
                    style: AppTypography.buttonLabel(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Keluar',
                    style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );

          if (confirm != true) return;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('isLoggedIn');
            await FirebaseAuth.instance.signOut();
            try {
              await GoogleSignIn.instance.signOut();
            } catch (_) {}
          } catch (e) {
            debugPrint('Logout error: $e');
          }

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
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
            final String grade = userData?['grade'] ?? '-';
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

            final heroColor = _getHeroColor(avatarPath, isDark);
            final heroTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

            final int cacheBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
            final double cacheMb = cacheBytes / (1024 * 1024);
            final String cacheDisplay = cacheMb >= 1.0
                ? '${cacheMb.toStringAsFixed(1)} MB'
                : (cacheBytes > 0 ? '${(cacheBytes / 1024).toStringAsFixed(0)} KB' : '0 KB');

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
              body: Stack(
                children: [
                  // Main Scrollable Content
                  SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        left: AppTypography.screenHorizontalMargin,
                        right: AppTypography.screenHorizontalMargin,
                        top: 14,
                        bottom: MediaQuery.of(context).padding.bottom + 80 + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Unscrolled top row: "Profil" Title on the left, Red Logout Button on the right
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Profil',
                                style: AppTypography.pageTitle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              BouncyButton(
                                onTap: logOut,
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Rectangular Hero Profile Card (With Hero Color & Micro Pattern)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: double.infinity,
                              color: heroColor,
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, _) => CustomPaint(
                                  painter: _ProfileHeroMicroPatternPainter(
                                    avatarPath: avatarPath,
                                    isDark: isDark,
                                    progress: _animController.value,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Action inside Card: "Edit Profil" Button on top-right (With Background Capsule)
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: BouncyButton(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EditProfilePage(
                                                    uid: currentUid,
                                                    initialData: userData,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFF1E293B),
                                                borderRadius: BorderRadius.circular(20),
                                                border: isDark
                                                    ? Border.all(color: const Color(0xFF3F3F46), width: 1.0)
                                                    : null,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Edit Profil',
                                                    style: AppTypography.buttonLabel(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12.0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Content Row: Left Avatar (aligned to edge) + Right Info
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Left Avatar (Lurus rata kiri dengan ikon kartu di bawah, ukuran +20% & tanpa border)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _showAvatarOverlay = !_showAvatarOverlay;
                                                });
                                              },
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.bottomRight,
                                                children: [
                                                  Container(
                                                    width: 86,
                                                    height: 86,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isDark
                                                          ? const Color(0xFF27272A)
                                                          : const Color(0xFFF1F5F9),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.15),
                                                          blurRadius: 10,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: ClipOval(
                                                      child: Transform.scale(
                                                        scale: 1.45,
                                                        child: Image.asset(
                                                          avatarPath,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (ctx, err, st) => Container(
                                                            color: isDark
                                                                ? const Color(0xFF27272A)
                                                                : const Color(0xFFF1F5F9),
                                                            child: Icon(
                                                              Icons.person_rounded,
                                                              size: 48,
                                                              color: heroTextColor.withValues(alpha: 0.5),
                                                            ),
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
                                                      decoration: BoxDecoration(
                                                        color: _showAvatarOverlay
                                                            ? const Color(0xFF7C3AED)
                                                            : const Color(0xFFF59E0B),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        _showAvatarOverlay
                                                            ? Icons.keyboard_arrow_up_rounded
                                                            : Icons.edit_rounded,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Right: Name, Role, ID
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: AppTypography.pageTitle(
                                                      color: heroTextColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 22.0,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 5,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: roleDb.toLowerCase() == 'guru'
                                                              ? const Color(0xFF7C3AED)
                                                              : const Color(0xFF2563EB),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Text(
                                                          roleDb,
                                                          style: AppTypography.timestamp(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        borderRadius: BorderRadius.circular(20),
                                                        onTap: () {
                                                          Clipboard.setData(ClipboardData(text: userId));
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('ID User berhasil disalin ke clipboard!'),
                                                              duration: Duration(seconds: 1),
                                                            ),
                                                          );
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: isDark
                                                                ? Colors.black.withValues(alpha: 0.35)
                                                                : Colors.white.withValues(alpha: 0.55),
                                                            borderRadius: BorderRadius.circular(20),
                                                            border: Border.all(
                                                              color: isDark
                                                                  ? Colors.white.withValues(alpha: 0.15)
                                                                  : Colors.black.withValues(alpha: 0.08),
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                'ID: $userId',
                                                                style: AppTypography.timestamp(
                                                                  color: heroTextColor,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Icon(
                                                                Icons.copy_rounded,
                                                                size: 11,
                                                                color: heroTextColor,
                                                              ),
                                                            ],
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

                                        // Floating In-Card Avatar Slider Overlay (if toggled)
                                        if (_showAvatarOverlay) ...[
                                          const SizedBox(height: 14),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              width: double.infinity,
                                              height: 58,
                                              padding: const EdgeInsets.symmetric(vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.black.withValues(alpha: 0.50)
                                                    : Colors.white.withValues(alpha: 0.50),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.white.withValues(alpha: 0.16)
                                                      : Colors.black.withValues(alpha: 0.10),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: ListView.separated(
                                                scrollDirection: Axis.horizontal,
                                                physics: const BouncingScrollPhysics(),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                itemCount: () {
                                                  if (roleDb.toLowerCase() == 'guru') {
                                                    return 10;
                                                  } else if (schoolLevel == 'SD') {
                                                    return 20;
                                                  } else {
                                                    return 10;
                                                  }
                                                }(),
                                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                                itemBuilder: (context, idx) {
                                                  final String avPath;
                                                  if (roleDb.toLowerCase() == 'guru') {
                                                    avPath = 'assets/icon_pack/avatar/guru_${idx + 1}.png';
                                                  } else if (schoolLevel == 'SD') {
                                                    avPath = idx < 10
                                                        ? 'assets/icon_pack/avatar/sd_${idx + 1}.png'
                                                        : 'assets/icon_pack/avatar/avatar_${idx - 9}.png';
                                                  } else if (schoolLevel == 'SMP') {
                                                    avPath = 'assets/icon_pack/avatar/smp_${idx + 1}.png';
                                                  } else {
                                                    avPath = 'assets/icon_pack/avatar/sma_${idx + 1}.png';
                                                  }

                                                  final bool isSelected = avPath == avatarPath;

                                                  return GestureDetector(
                                                    onTap: () async {
                                                      if (currentUid.isNotEmpty) {
                                                        await FirebaseFirestore.instance
                                                            .collection('users')
                                                            .doc(currentUid)
                                                            .update({'avatar': avPath});
                                                      }
                                                    },
                                                    child: Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: isSelected
                                                            ? Border.all(
                                                                color: const Color(0xFF7C3AED),
                                                                width: 2.5,
                                                              )
                                                            : Border.all(
                                                                color: Colors.transparent,
                                                                width: 1.5,
                                                            ),
                                                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                                      ),
                                                      child: ClipOval(
                                                        child: Transform.scale(
                                                          scale: 1.45,
                                                          child: Image.asset(
                                                            avPath,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) => const Icon(
                                                              Icons.person_rounded,
                                                              size: 22,
                                                              color: Color(0xFF7C3AED),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Section 1: Informasi Akun (Read-only Overview)
                          _buildSectionHeader('Informasi Akun', isDark),
                          _buildSectionCard([
                            _buildInfoTile(
                              iconType: 'email',
                              accentHex: '#8B5CF6',
                              title: 'Email',
                              value: email,
                              isDark: isDark,
                            ),
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildInfoTile(
                              iconType: 'gender',
                              accentHex: '#EC4899',
                              title: 'Jenis Kelamin',
                              value: gender,
                              isDark: isDark,
                            ),
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildInfoTile(
                              iconType: 'school',
                              accentHex: '#14B8A6',
                              title: 'Tingkat Sekolah',
                              value: roleDb.toLowerCase() == 'siswa' && grade != '-'
                                  ? '$schoolLevel (Kelas $grade)'
                                  : schoolLevel,
                              isDark: isDark,
                            ),
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildInfoTile(
                              iconType: 'timezone',
                              accentHex: '#F59E0B',
                              title: 'Zona Waktu',
                              value: timezone,
                              isDark: isDark,
                            ),
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildInfoTile(
                              iconType: 'language',
                              accentHex: '#3B82F6',
                              title: 'Bahasa',
                              value: language,
                              isDark: isDark,
                            ),
                          ], isDark),

                          // Section 2: Keamanan
                          _buildSectionHeader('Keamanan', isDark),
                          _buildSectionCard([
                            _buildSettingTile(
                              iconType: 'password',
                              accentHex: '#EF4444',
                              title: 'Ubah Password',
                              trailing: 'Atur Ulang',
                              isDark: isDark,
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
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildSettingTile(
                              iconType: 'security',
                              accentHex: '#3B82F6',
                              title: 'Otentikasi 2 Langkah',
                              trailing: twoFactorEnabled ? 'Aktif' : 'Nonaktif',
                              isDark: isDark,
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
                          ], isDark),

                          // Section 3: Tampilan & Notifikasi
                          _buildSectionHeader('Tampilan & Notifikasi', isDark),
                          _buildSectionCard([
                            _buildSettingTile(
                              iconType: 'theme',
                              accentHex: '#F59E0B',
                              title: 'Tema Tampilan',
                              trailing: themeMode == 'Dark' ? 'Gelap' : 'Terang',
                              isDark: isDark,
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
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildSettingTile(
                              iconType: 'notification',
                              accentHex: '#10B981',
                              title: 'Notifikasi',
                              trailing: 'Atur Notifikasi',
                              isDark: isDark,
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
                          ], isDark),

                          // Section 4: Lainnya
                          _buildSectionHeader('Lainnya', isDark),
                          _buildSectionCard([
                            _buildSettingTile(
                              iconType: 'about',
                              accentHex: '#06B6D4',
                              title: 'Tentang Aplikasi',
                              trailing: 'Hubner Edu v1.1.0',
                              isDark: isDark,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                    title: Text(
                                      'Tentang Hubner Edu',
                                      style: AppTypography.buttonLabel(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      'Hubner Edu adalah platform manajemen kelas online dan pembelajaran interaktif secara real-time.',
                                      style: AppTypography.buttonLabel(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(
                                          'Tutup',
                                          style: AppTypography.buttonLabel(
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildSettingTile(
                              iconType: 'cache',
                              accentHex: '#3B82F6',
                              title: 'Hapus Cache',
                              trailing: cacheDisplay,
                              isDark: isDark,
                              onTap: () {
                                final int freedBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
                                final int count = PaintingBinding.instance.imageCache.currentSize;
                                PaintingBinding.instance.imageCache.clear();
                                PaintingBinding.instance.imageCache.clearLiveImages();
                                setState(() {});
                                final String freedStr = freedBytes >= 1024 * 1024
                                    ? '${(freedBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                                    : '${(freedBytes / 1024).toStringAsFixed(0)} KB';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(freedBytes > 0
                                        ? 'Cache gambar dan memori ($freedStr, $count objek) berhasil dibersihkan!'
                                        : 'Cache memori sudah dalam kondisi bersih (0 KB).'),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            Divider(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              height: 1,
                              indent: 52,
                            ),
                            _buildSettingTile(
                              iconType: 'delete_account',
                              accentHex: '#EF4444',
                              titleColor: Colors.redAccent,
                              title: 'Hapus Akun',
                              trailing: '',
                              isDark: isDark,
                              onTap: () => _deleteAccount(context, currentUid),
                            ),
                          ], isDark),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Top Header Bar (Hanya muncul saat di-scroll melewati Edit Profil di kartu)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollOffsetNotifier,
                      builder: (context, scrollOffset, _) {
                        if (scrollOffset <= 80.0) {
                          return const SizedBox.shrink();
                        }
                        final double progress = ((scrollOffset - 80.0) / 35.0).clamp(0.0, 1.0);
                        final double blurSigma = 16.0 * progress;

                        return Opacity(
                          opacity: progress,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: blurSigma > 0.1 ? blurSigma : 0.001,
                                sigmaY: blurSigma > 0.1 ? blurSigma : 0.001,
                              ),
                              child: Container(
                                color: (isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC))
                                    .withValues(alpha: 0.75 * progress),
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppTypography.screenHorizontalMargin,
                                      vertical: 8.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Kiri: Edit Profil Button (Tanpa Background / Frameless di Sticky Header)
                                        BouncyButton(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EditProfilePage(
                                                  uid: currentUid,
                                                  initialData: userData,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.edit_rounded,
                                                  size: 16,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Edit Profil',
                                                  style: AppTypography.buttonLabel(
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Kanan: Red Logout Button (Tanpa Background & Border)
                                        BouncyButton(
                                          onTap: logOut,
                                          child: const Padding(
                                            padding: EdgeInsets.all(6.0),
                                            child: Icon(
                                              Icons.logout_rounded,
                                              color: Color(0xFFEF4444),
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
            );
          },
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
    final bool isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  border: Border.all(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          title,
          style: AppTypography.chatHeaderTitle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          padding: const EdgeInsets.all(20.0),
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
    final bool isDark = AppColors.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nama Lengkap',
          style: AppTypography.buttonLabel(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          style: AppTypography.replySubtitle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white : Colors.black,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
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
              backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 0,
            ),
            child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Simpan Perubahan', style: AppTypography.cardTitle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final bool isDark = AppColors.isDarkMode;
    final timezones = [
      'Asia/Jakarta (GMT+07:00)',
      'Asia/Makassar (GMT+08:00)',
      'Asia/Jayapura (GMT+09:00)',
    ];
    return ListView.separated(
      shrinkWrap: true,
      itemCount: timezones.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
      itemBuilder: (context, idx) {
        final tz = timezones[idx];
        final isSelected = tz == currentTz;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            tz,
            style: AppTypography.cardTitle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isSelected ? Icon(Icons.check_circle_rounded, color: isDark ? Colors.white : const Color(0xFF18181B)) : null,
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
    final bool isDark = AppColors.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kata Sandi Baru',
          style: AppTypography.buttonLabel(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: AppTypography.replySubtitle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white : Colors.black,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
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
              backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 0,
            ),
            child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Ubah Kata Sandi', style: AppTypography.cardTitle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final bool isDark = AppColors.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Otentikasi 2 Langkah',
          style: AppTypography.buttonLabel(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEnabled ? 'Aktif' : 'Nonaktif',
              style: AppTypography.chatHeaderTitle(
                color: isEnabled ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.bold,
              ),
            ),
            Switch.adaptive(
              value: isEnabled,
              activeTrackColor: isDark ? Colors.white : const Color(0xFF18181B),
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
          style: AppTypography.timestamp(
            color: isDark ? Colors.white38 : Colors.black38,
            height: 1.5,
          ),
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
    final bool isDark = AppColors.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perangkat yang Terhubung',
          style: AppTypography.buttonLabel(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perangkat saat ini',
                      style: AppTypography.buttonLabel(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Jakarta, Indonesia • Aktif Sekarang',
                      style: AppTypography.channelTag(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
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
}

// --- Form Tema Setup ---
class ThemeSetupForm extends StatelessWidget {
  final String currentTheme;
  final String uid;
  const ThemeSetupForm({super.key, required this.currentTheme, required this.uid});

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, activeTheme, _) {
        final themes = [
          {'key': 'System', 'label': 'Ikuti Pengaturan HP (Otomatis)'},
          {'key': 'Terang', 'label': 'Mode Terang (Light)'},
          {'key': 'Gelap', 'label': 'Mode Gelap (Dark)'},
        ];

        return ListView.separated(
          shrinkWrap: true,
          itemCount: themes.length,
          separatorBuilder: (_, __) => Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
          itemBuilder: (context, idx) {
            final th = themes[idx];
            final key = th['key']!;
            final isSelected = key == 'System'
                ? false
                : (activeTheme == key);

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                th['label']!,
                style: AppTypography.cardTitle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: isDark ? Colors.white : const Color(0xFF18181B))
                  : null,
              onTap: () async {
                String newTheme;
                final prefs = await SharedPreferences.getInstance();
                if (key == 'System') {
                  final sysBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
                  newTheme = sysBrightness == Brightness.dark ? 'Gelap' : 'Terang';
                  await prefs.setString('lastSystemBrightness', sysBrightness == Brightness.dark ? 'dark' : 'light');
                } else {
                  newTheme = key;
                }

                HubnerApp.themeNotifier.value = newTheme;
                await prefs.setString('themeMode', newTheme);
                if (uid.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'themeMode': newTheme}).catchError((_) {});
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            );
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
    final bool isDark = AppColors.isDarkMode;

    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: isDark ? Colors.white : const Color(0xFF18181B),
          title: Text(
            'Task Reminder',
            style: AppTypography.cardTitle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Kirim pengingat untuk tugas yang akan jatuh tempo.',
            style: AppTypography.channelTag(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          value: _taskReminder,
          onChanged: (val) async {
            setState(() => _taskReminder = val);
            await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'notifyTaskReminder': val});
          },
        ),
        Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: isDark ? Colors.white : const Color(0xFF18181B),
          title: Text(
            'Chat Mention',
            style: AppTypography.cardTitle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Beritahu saya saat seseorang menyebut nama saya di diskusi.',
            style: AppTypography.channelTag(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
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
                              style: AppTypography.microBadge(color: Colors.white, fontWeight: FontWeight.bold),
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
                    style: AppTypography.buttonLabel(color: textColor, fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500),
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


