import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/auth/presentation/pages/login_page.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/widgets/classroom_card_pattern_painter.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HubnerApp.showBorderNotifier.value = false;
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 750),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HubnerApp.showBorderNotifier.value = true;
    });
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double safeBottomPadding = MediaQuery.of(context).padding.bottom;
    final bool isDark = AppColors.isDarkMode;

    final double screenWidth = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        body: Stack(
          children: [
            // 1. Full Screen Pattern Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF130E20) : const Color(0xFF7F52FC),
                ),
                child: CustomPaint(
                  painter: ClassroomCardPatternPainter(
                    patternIndex: 0,
                    accentColor: const Color(0xFF7F52FC),
                    isDark: isDark,
                  ),
                ),
              ),
            ),

            if (isDark) ...[
              // Top-Left ambient glow
              Positioned(
                top: -30,
                left: -40,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF38104A).withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ],

            // 2. Full-Width Illustration resting right on top of Bottom Card
            Column(
              children: [
                SizedBox(height: statusBarHeight + 12.0),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: screenWidth,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Image.asset(
                          isDark ? 'assets/images/onboarding-dark.png' : 'assets/images/onboarding.png',
                          width: screenWidth,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.school_rounded,
                                size: 100,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Bottom Text Card Container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppTypography.screenHorizontalMargin,
                    24.0,
                    AppTypography.screenHorizontalMargin,
                    24.0 + safeBottomPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belajar & tumbuh bersama Hubner',
                        style: AppTypography.pageTitle(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Kelola kelas, tugas sekolah, dan kolaborasi belajar secara praktis dan menyenangkan.',
                        style: AppTypography.chatBody(
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F52FC), // Solid brand violet
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: ElevatedButton(
                          onPressed: _completeOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: Text(
                            'Masuk',
                            style: AppTypography.buttonLabel(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
