import 'dart:io' show Platform;
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
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
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
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
  }

  final prefs = await SharedPreferences.getInstance();
  final hasSavedLogin = prefs.getBool('isLoggedIn') ?? false;
  final hasFirebaseAuthUser = FirebaseAuth.instance.currentUser != null;
  final isLoggedIn = hasSavedLogin || hasFirebaseAuthUser;

  if (hasFirebaseAuthUser && !hasSavedLogin) {
    await prefs.setBool('isLoggedIn', true);
  }

  final currentSystemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final currentBrightnessStr = currentSystemBrightness == Brightness.dark ? 'dark' : 'light';
  final lastSavedSystemBrightness = prefs.getString('lastSystemBrightness');
  final savedTheme = prefs.getString('themeMode');

  String effectiveTheme;
  // If system brightness changed while app was closed (or first launch), follow the device theme!
  if (lastSavedSystemBrightness == null || lastSavedSystemBrightness != currentBrightnessStr) {
    effectiveTheme = currentSystemBrightness == Brightness.dark ? 'Gelap' : 'Terang';
    await prefs.setString('themeMode', effectiveTheme);
    await prefs.setString('lastSystemBrightness', currentBrightnessStr);
  } else {
    // System brightness has not changed, respect user's manual choice if saved
    effectiveTheme = savedTheme ?? (currentSystemBrightness == Brightness.dark ? 'Gelap' : 'Terang');
  }

  final savedLanguage = prefs.getString('language') ?? 'Bahasa Indonesia';

  HubnerApp.themeNotifier.value = effectiveTheme;
  HubnerApp.languageNotifier.value = savedLanguage;

  final bool initialIsDark = effectiveTheme == 'Gelap' || effectiveTheme == 'Hitam';
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: initialIsDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: initialIsDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ));

    HubnerApp.themeNotifier.addListener(() {
      final bool isDark = HubnerApp.themeNotifier.value == 'Gelap' || HubnerApp.themeNotifier.value == 'Hitam';
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ));
    });
  }

  runApp(HubnerApp(isLoggedIn: isLoggedIn));
}

class HubnerApp extends StatefulWidget {
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
  State<HubnerApp> createState() => _HubnerAppState();
}

class _HubnerAppState extends State<HubnerApp> with WidgetsBindingObserver {
  Brightness? _lastObservedBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastObservedBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final newBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // When the phone brightness changes, reset the theme to follow the new phone mode!
    if (_lastObservedBrightness != newBrightness) {
      _lastObservedBrightness = newBrightness;
      final newTheme = newBrightness == Brightness.dark ? 'Gelap' : 'Terang';
      HubnerApp.themeNotifier.value = newTheme;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('themeMode', newTheme);
        prefs.setString('lastSystemBrightness', newBrightness == Brightness.dark ? 'dark' : 'light');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, child) {
        AppColors.themeMode = themeMode;
        final bool isDark = themeMode == 'Gelap' || themeMode == 'Hitam';
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MaterialApp(
            title: 'Hubner Edu',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              scrollbars: false,
            ),
            builder: (context, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: HubnerApp.showBorderNotifier,
                builder: (context, showBorder, _) {
                  Widget currentBody = child!;
                  final double screenWidth = MediaQuery.of(context).size.width;
                  final double responsiveFontScale = screenWidth < 500
                      ? (screenWidth / 500).clamp(0.78, 1.0)
                      : 1.0;

                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlayStyle,
                    child: MediaQuery(
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
                    ),
                  );
                },
              );
            },
            home: kIsWeb && !widget.isLoggedIn ? const LandingPage() : const SplashPage(),
          ),
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
    Color(0xFF8B5CF6), // Violet Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
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
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
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
                          ? -14.0 * (1 - ((progress - 0.25).abs() / 0.25))
                          : 0.0;

                      return Transform.translate(
                        offset: Offset(0, bounce.clamp(-14.0, 0.0)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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


