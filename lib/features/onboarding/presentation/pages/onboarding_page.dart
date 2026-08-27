import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/auth/presentation/pages/login_page.dart';
import 'package:hubner/main.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/widgets/organic_blob_background.dart';

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
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Organic Fluid Blob Pattern Background (Variant 1: Onboarding)
              Positioned.fill(
                child: OrganicBlobBackground(
                  isDark: isDark,
                  variant: 1,
                ),
              ),

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

                // 3. Bottom Floating Squircle Card Container
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.fromLTRB(
                    12.0,
                    0.0,
                    12.0,
                    (safeBottomPadding > 0 ? safeBottomPadding : 12.0) + 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(38),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    22.0,
                    24.0,
                    22.0,
                    12.0,
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
                      const SizedBox(height: 12),
                      Text(
                        'Kelola kelas, tugas sekolah, dan kolaborasi belajar secara praktis dan menyenangkan.',
                        style: AppTypography.chatBody(
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : const Color(0xFF18181B), // Solid black button
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
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.black : Colors.white,
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
    ),
  );
}
}
