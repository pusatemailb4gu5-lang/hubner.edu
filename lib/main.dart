import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'features/landing/presentation/pages/landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Pre-load Poppins fonts to prevent splash screen font flicker / layout shift
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
    ]);
  } catch (_) {
    // If offline, fallback will be used immediately without visual jumps
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  // System UI: transparent status bar + transparent navigation bar with dark icons (black 3-button nav)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  final prefs = await SharedPreferences.getInstance();
  final hasSavedLogin = prefs.getBool('isLoggedIn') ?? false;
  final hasFirebaseAuthUser = FirebaseAuth.instance.currentUser != null;
  final isLoggedIn = hasSavedLogin || hasFirebaseAuthUser;

  if (hasFirebaseAuthUser && !hasSavedLogin) {
    await prefs.setBool('isLoggedIn', true);
  }

  final savedTheme = prefs.getString('themeMode') ?? 'Terang';
  final savedLanguage = prefs.getString('language') ?? 'Bahasa Indonesia';

  HubnerApp.themeNotifier.value = savedTheme;
  HubnerApp.languageNotifier.value = savedLanguage;

  runApp(HubnerApp(isLoggedIn: isLoggedIn));
}

class HubnerApp extends StatelessWidget {
  final bool isLoggedIn;
  const HubnerApp({super.key, required this.isLoggedIn});

  static final themeNotifier = ValueNotifier<String>('Terang');
  static final isThemeTransitioning = ValueNotifier<bool>(false);
  static final languageNotifier = ValueNotifier<String>('Bahasa Indonesia');
  static final projectTypeNotifier = ValueNotifier<String?>('Individu');
  static final gdriveNotifier = ValueNotifier<bool>(false);
  static final workspaceNotifier = ValueNotifier<String>('');
  static final addProjectTrigger = ValueNotifier<VoidCallback?>(null);
  static final showBorderNotifier = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, child) {
        AppColors.themeMode = themeMode;
        return MaterialApp(
          title: 'Hubner Edu',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          builder: (context, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: showBorderNotifier,
              builder: (context, showBorder, _) {
                Widget currentBody = child!;
                final double screenWidth = MediaQuery.of(context).size.width;
                final double responsiveFontScale = screenWidth < 500
                    ? (screenWidth / 500).clamp(0.78, 1.0)
                    : 1.0;

                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(responsiveFontScale),
                  ),
                  child: Stack(
                    children: [
                      currentBody,
                      ValueListenableBuilder<bool>(
                        valueListenable: HubnerApp.isThemeTransitioning,
                        builder: (context, isTransitioning, _) {
                          if (!isTransitioning) return const SizedBox.shrink();
                          return const FullScreenThemeTransitionBlur();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          home: kIsWeb && !isLoggedIn ? const LandingPage() : const SplashPage(),
        );
      },
    );
  }
}

class FullScreenThemeTransitionBlur extends StatefulWidget {
  const FullScreenThemeTransitionBlur({super.key});

  @override
  State<FullScreenThemeTransitionBlur> createState() => _FullScreenThemeTransitionBlurState();
}

class _FullScreenThemeTransitionBlurState extends State<FullScreenThemeTransitionBlur>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const List<Color> _dotColors = [
    Color(0xFF8B5CF6), // Ungu (Purple Violet)
    Color(0xFFFBBF24), // Kuning (Amber Yellow)
    Color(0xFFEC4899), // Magenta (Pink Magenta)
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Full-screen backdrop blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                child: Container(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.62)
                      : Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
            // Centered Animated Colorful Floating Dots (Without background container)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final Color color = _dotColors[index];
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final double delay = index * 0.22;
                      final double progress = (_controller.value - delay) % 1.0;
                      final double bounce = (progress < 0.5)
                          ? -16.0 * (1 - ((progress - 0.25).abs() / 0.25))
                          : 0.0;

                      return Transform.translate(
                        offset: Offset(0, bounce.clamp(-16.0, 0.0)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.65),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

