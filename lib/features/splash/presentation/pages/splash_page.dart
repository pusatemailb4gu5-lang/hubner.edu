import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hubner/features/landing/presentation/pages/landing_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/widgets/organic_blob_background.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _subOpacity;
  late Animation<Offset> _subSlide;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _subOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _subSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Show splash for 3.2 seconds
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final bool hasSavedLogin = prefs.getBool('isLoggedIn') ?? false;
    final bool isFirebaseLoggedIn = FirebaseAuth.instance.currentUser != null;

    if (hasSavedLogin || isFirebaseLoggedIn) {
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
      return;
    }

    if (!mounted) return;

    if (kIsWeb) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final widthToUse = screenWidth > 0 ? screenWidth : 375.0;
    final bool isDark = AppColors.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Organic Fluid Blob Pattern Background (Variant 0: Splash)
              Positioned.fill(
                child: OrganicBlobBackground(
                  isDark: isDark,
                  variant: 0,
                ),
              ),

            // Center App Logo Illustration
            Center(
              child: FadeTransition(
                opacity: _logoOpacity,
                child: SizedBox(
                  width: (widthToUse * 0.48).clamp(160.0, 240.0),
                  height: (widthToUse * 0.48).clamp(160.0, 240.0),
                  child: Image.asset(
                    isDark ? 'assets/iconapp/icon-dark.png' : 'assets/iconapp/icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/iconapp/icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.school_rounded,
                            size: 130,
                            color: isDark ? const Color(0xFFA78BFA) : Colors.white,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // Brand name at bottom
            Align(
              alignment: const Alignment(0, 0.82),
              child: FadeTransition(
                opacity: _subOpacity,
                child: SlideTransition(
                  position: _subSlide,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Hubner',
                        style: AppTypography.pageTitle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF18181B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF7F52FC) : const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'edu',
                          style: AppTypography.buttonLabel(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
    ),
  );
}
}
