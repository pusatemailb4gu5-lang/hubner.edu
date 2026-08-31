import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/features/auth/presentation/pages/login_page.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/images/onboarding_slide_1.jpg',
      'fallback': 'assets/images/onboarding.png',
      'title': 'Siap belajar lebih cerdas bareng Hubner!',
      'desc': 'Kelola kelas, tugas sekolah, dan materi pembelajaran di mana aja, semua bisa.',
    },
    {
      'image': 'assets/images/onboarding_slide_2.jpg',
      'fallback': 'assets/images/home_task_card.png',
      'title': 'Pantau jadwal & deadline tugas otomatis!',
      'desc': 'Dapatkan pengingat tugas dan jadwal harian agar belajarmu selalu terencana rapi.',
    },
    {
      'image': 'assets/images/onboarding_slide_3.jpg',
      'fallback': 'assets/images/home_quiz_card.png',
      'title': 'Uji kemampuan lewat kuis interaktif!',
      'desc': 'Evaluasi pemahaman materi pelajaran secara instan dan raih prestasi terbaikmu.',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HubnerApp.showBorderNotifier.value = false;
    });

    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        final int nextPage = (_currentPage + 1) % _onboardingData.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
        setState(() {
          _currentPage = nextPage;
        });
        _progressController.reset();
        _progressController.forward();
      }
    });

    _progressController.forward();
  }

  Future<void> _completeOnboarding() async {
    _progressController.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HubnerApp.showBorderNotifier.value = true;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    const Color toskaColor = Color(0xFF68CECA);
    final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

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
        backgroundColor: bgColor,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full White Background with Tosca, Stabilo & Magenta Modern Patterns
              Positioned.fill(
                child: CustomPaint(
                  painter: _WondrStylePatternPainter(isDark: isDark),
                ),
              ),

              // 2. Main Content (Wondr App Model)
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP SECTION (Header, Story Progress, Title & Subtitle)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // TOP BAR: Logo Hubner edu
                          Row(
                            children: [
                              Text(
                                'Hubner',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCF585), // Stabilo lime
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'edu',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // SMOOTH STORY PROGRESS BAR (Panjang Dibagi 3 - Berjalan Halus 3 Detik per Slide)
                          AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return Row(
                                children: List.generate(
                                  _onboardingData.length,
                                  (lineIdx) {
                                    double progress = 0.0;
                                    if (lineIdx < _currentPage) {
                                      progress = 1.0;
                                    } else if (lineIdx == _currentPage) {
                                      progress = _progressController.value;
                                    } else {
                                      progress = 0.0;
                                    }

                                    return Expanded(
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: lineIdx < _onboardingData.length - 1 ? 6.0 : 0.0,
                                        ),
                                        height: 4.5,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white24
                                              : toskaColor.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                width: constraints.maxWidth * progress,
                                                decoration: BoxDecoration(
                                                  color: toskaColor,
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // HEADLINE & SUBTITLE DI ATAS (Dekat dengan Garis Dot)
                          SizedBox(
                            height: 108,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: SizedBox(
                                key: ValueKey<int>(_currentPage),
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      _onboardingData[_currentPage]['title']!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 26.0,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.6,
                                        height: 1.15,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _onboardingData[_currentPage]['desc']!,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // MIDDLE ILLUSTRATION SLIDER (Padding Kiri Kanan 0, Tanpa Background, Tanpa Border, Tanpa Bayangan)
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _onboardingData.length,
                        onPageChanged: (index) {
                          if (_currentPage != index) {
                            setState(() {
                              _currentPage = index;
                            });
                            _progressController.reset();
                            _progressController.forward();
                          }
                        },
                        itemBuilder: (context, index) {
                          final data = _onboardingData[index];
                          return Center(
                            child: Image.asset(
                              data['image']!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  data['fallback']!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.school_rounded,
                                        size: 100,
                                        color: Colors.black26,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // BOTTOM BUTTON: Mulai Sekarang (Padding Horizontal 24)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: toskaColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: toskaColor.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _completeOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Mulai Sekarang',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter: Clean, minimalist, and very soft pastel organic fields
/// Proportion: 50% Tosca, 25% Stabilo Lime, 25% Magenta
class _WondrStylePatternPainter extends CustomPainter {
  final bool isDark;

  const _WondrStylePatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Ultra soft pastel tones for a clean, non-distracting minimalist aesthetic
    final Color toscaSoft = const Color(0xFF68CECA).withValues(alpha: isDark ? 0.14 : 0.16); // 50%
    final Color stabiloSoft = const Color(0xFFDCF585).withValues(alpha: isDark ? 0.18 : 0.28); // 25%
    final Color magentaSoft = const Color(0xFFF472B6).withValues(alpha: isDark ? 0.12 : 0.15); // 25%

    // 1. Dominant Soft Tosca Organic Curved Field (Right Edge - 50%)
    final Path toscaField = Path()
      ..moveTo(w, h * 0.16)
      ..cubicTo(w * 0.58, h * 0.24, w * 0.52, h * 0.54, w, h * 0.62)
      ..close();
    canvas.drawPath(toscaField, Paint()..color = toscaSoft);

    // 2. Soft Stabilo Lime Field (Top-Left Corner - 25%)
    final Path stabiloField = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.36, 0)
      ..cubicTo(w * 0.26, h * 0.10, w * 0.04, h * 0.13, 0, h * 0.09)
      ..close();
    canvas.drawPath(stabiloField, Paint()..color = stabiloSoft);

    // 3. Soft Magenta Field (Bottom-Right Corner - 25%)
    final Path magentaField = Path()
      ..moveTo(w, h * 0.74)
      ..cubicTo(w * 0.70, h * 0.78, w * 0.74, h * 0.94, w * 0.88, h)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(magentaField, Paint()..color = magentaSoft);

    // 4. Very subtle minimalist hairline rings
    final Paint pRingTosca = Paint()
      ..color = const Color(0xFF68CECA).withValues(alpha: isDark ? 0.15 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(w * 0.86, h * 0.14), w * 0.12, pRingTosca);

    final Paint pRingMagenta = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: isDark ? 0.15 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(w * 0.12, h * 0.65), w * 0.10, pRingMagenta);
  }

  @override
  bool shouldRepaint(covariant _WondrStylePatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
