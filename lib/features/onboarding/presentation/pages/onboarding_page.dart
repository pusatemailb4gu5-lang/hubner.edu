import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/auth/presentation/pages/login_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_colors.dart';


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
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 500) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeOnboarding();
      });
      return const Scaffold(body: const Center(child: ThreeDotsLoader()));
    }

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double safeBottomPadding = MediaQuery.of(context).padding.bottom;
    final bool isDark = AppColors.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        body: Stack(
          children: [
            // Top Image/Illustration Container (occupying full width, extending deep behind card)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 180,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF130E20) : const Color(0xFF7F52FC),
                ),
                child: Stack(
                  children: [
                    // Decorative Clouds
                    Positioned(
                      top: statusBarHeight + 10,
                      left: -20,
                      child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.15), size: 120),
                    ),
                    Positioned(
                      top: statusBarHeight + 30,
                      right: -30,
                      child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18), size: 150),
                    ),
                    Positioned(
                      top: statusBarHeight + 20,
                      left: screenWidth * 0.4,
                      child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.10), size: 80),
                    ),
                    Positioned(
                      bottom: 40,
                      left: -10,
                      child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.12), size: 90),
                    ),

                    // Center Image (Bear character asset)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(28.0, statusBarHeight + 20.0, 28.0, 40.0),
                        child: Image.asset(
                          'assets/images/onboarding.png',
                          fit: BoxFit.contain,
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

                    // Illustrative star highlights
                    Positioned(
                      top: statusBarHeight + 40,
                      left: 60,
                      child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.6), size: 16),
                    ),
                    Positioned(
                      top: statusBarHeight + 80,
                      right: 70,
                      child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: isDark ? 0.45 : 0.8), size: 22),
                    ),
                    Positioned(
                      bottom: 80,
                      left: 40,
                      child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: isDark ? 0.3 : 0.5), size: 18),
                    ),
                    Positioned(
                      bottom: 110,
                      right: 50,
                      child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.6), size: 14),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Text Card Container
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: isDark ? const Border(top: BorderSide(color: Color(0xFF27272A), width: 1.0)) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  28.0,
                  28.0,
                  28.0,
                  24.0 + safeBottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belajar & tumbuh bersama Hubner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: screenWidth > 360 ? 32 : 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Kelola kelas, tugas sekolah, dan kolaborasi belajar secara praktis dan menyenangkan.',
                      style: GoogleFonts.dmSans(
                        fontSize: 18.0,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F52FC), // Solid brand violet
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7F52FC).withValues(alpha: 0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'Masuk',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
    );
  }
}
