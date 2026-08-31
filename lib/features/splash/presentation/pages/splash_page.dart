import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hubner/features/landing/presentation/pages/landing_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/core/theme/app_colors.dart';

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
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _subSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.04), // Transisi tipis sekali
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
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
    final bool isDark = AppColors.isDarkMode;
    final Color splashBgColor = isDark ? const Color(0xFF0F2625) : const Color(0xFF68CECA);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: splashBgColor,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Tosca Canvas with Educational Shapes, Numbers & Letters (Onboarding Style Pattern)
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashEducationalPatternPainter(isDark: isDark),
                ),
              ),

              // 2. Center: App Logo (Lebih besar 25% -> 165x165)
              Center(
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: SizedBox(
                    width: 165,
                    height: 165,
                    child: Image.asset(
                      'assets/iconapp/icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.school_rounded,
                            size: 105,
                            color: Color(0xFF0F172A),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 3. Bottom Footer: Tulisan Hubner edu (Tipografi Elegan & Proporsional)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 28.0, right: 28.0, bottom: 28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Brand Name: Hubner edu (Weight proporsional, tidak terlalu bold)
                        FadeTransition(
                          opacity: _subOpacity,
                          child: SlideTransition(
                            position: _subSlide,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Hubner',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 21.0,
                                    fontWeight: FontWeight.w700, // Elegan & proporsional
                                    letterSpacing: -0.4,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCF585), // Stabilo lime
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'edu',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF0F172A),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Deskripsi Statis
                        Text(
                          'Platform Pembelajaran & Manajemen Kelas Digital Cerdas',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                            height: 1.35,
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

/// Custom painter for Splash Screen:
/// - Precise motif specifications:
///   * 1 Lingkaran (Magenta)
///   * 1 Kotak (Stabilo Lime)
///   * 1 Segitiga (Sunlight Orange)
///   * 2 Huruf ('A' & 'H' ukuran berbeda)
///   * 2 Angka ('8' & '3' ukuran berbeda)
/// - Balanced, minimalist, onboarding-inspired aesthetic with rich Toska canvas
class _SplashEducationalPatternPainter extends CustomPainter {
  final bool isDark;

  const _SplashEducationalPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Harmonious Palette
    final Color toscaBase = isDark ? const Color(0xFF0F2625) : const Color(0xFF68CECA);
    const Color stabiloLime = Color(0xFFDCF585);
    const Color magentaPink = Color(0xFFEC4899);
    const Color sunlightOrange = Color(0xFFFB923C);
    const Color royalPurple = Color(0xFF8B5CF6);

    // 0. Base Tosca Background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = toscaBase);

    // ==============================================================
    // 1. KOTAK (Sangat Besar - Stabilo Lime di Pojok Kiri Atas, ~75% Terlihat)
    // ==============================================================
    _drawSolidSquare(
      canvas,
      center: Offset(w * 0.05, h * 0.05),
      size: 140,
      rotation: 0.32,
      color: stabiloLime,
    );

    // ==============================================================
    // 2. HURUF 'A' (Besar - Ungu Royal di Sisi Kiri Atas, ~80% Terlihat)
    // ==============================================================
    _drawSolidGlyph(
      canvas,
      'A',
      Offset(w * 0.12, h * 0.22),
      110,
      royalPurple,
      -0.15,
    );

    // ==============================================================
    // 3. LINGKARAN (Sangat Besar - Magenta di Pojok Kanan Atas, ~70% Terlihat)
    // ==============================================================
    canvas.drawCircle(
      Offset(w * 0.98, -h * 0.02),
      w * 0.36,
      Paint()..color = magentaPink,
    );

    // ==============================================================
    // 4. ANGKA '8' (Besar - Sunlight Orange di Sisi Kanan Atas, ~75% Terlihat)
    // ==============================================================
    _drawSolidGlyph(
      canvas,
      '8',
      Offset(w * 0.88, h * 0.32),
      125,
      sunlightOrange,
      0.12,
    );

    // ==============================================================
    // 5. HURUF 'H' (Sedang - Stabilo Lime di Tepi Kiri Bawah, ~75% Terlihat)
    // ==============================================================
    _drawSolidGlyph(
      canvas,
      'H',
      Offset(-w * 0.02, h * 0.74),
      85,
      stabiloLime,
      0.10,
    );

    // ==============================================================
    // 6. ANGKA '3' (Sedang - Ungu Royal di Tepi Kanan Bawah, ~80% Terlihat)
    // ==============================================================
    _drawSolidGlyph(
      canvas,
      '3',
      Offset(w * 0.92, h * 0.62),
      80,
      royalPurple,
      -0.08,
    );

    // ==============================================================
    // 7. SEGITIGA (Besar - Sunlight Orange di Pojok Kanan Bawah, ~70% Terlihat)
    // ==============================================================
    _drawSolidTriangle(
      canvas,
      center: Offset(w * 0.98, h * 0.88),
      radius: 90,
      rotation: 0.40,
      color: sunlightOrange,
    );
  }

  void _drawSolidTriangle(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double rotation,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final Path path = Path();
    for (int i = 0; i < 3; i++) {
      final double angle = (i * 2 * math.pi / 3) - (math.pi / 2);
      final double x = radius * math.cos(angle);
      final double y = radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawSolidSquare(
    Canvas canvas, {
    required Offset center,
    required double size,
    required double rotation,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      const Radius.circular(10),
    );

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  void _drawSolidGlyph(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize,
    Color color,
    double rotation,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashEducationalPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
