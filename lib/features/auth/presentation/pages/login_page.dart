import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/services/login_history_service.dart';
import 'package:hubner/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:google_fonts/google_fonts.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  String? _errorMessage;

  StreamSubscription? _googleSignInSubscription;
  bool? _canPop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canPop ??= Navigator.of(context).canPop();
  }

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _initGoogleSignIn();
    _googleSignInSubscription = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _processGoogleSignIn(event.user);
      }
    });
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
        serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _scrollController.dispose();
    _googleSignInSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty && password.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan masukkan Email atau User ID serta kata sandi Anda.';
      });
      return;
    }
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan masukkan Email atau User ID Anda.';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan masukkan kata sandi Anda.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String emailToLogin = input;

      // Check if input is a User ID (does not contain @)
      if (!input.contains('@')) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: input.toLowerCase())
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'ID User tidak ditemukan.',
          );
        }

        emailToLogin = querySnapshot.docs.first.get('email') as String;
      }

      // Login using Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToLogin,
        password: password,
      );

      final uid = userCredential.user?.uid ?? '';
      if (uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!userDoc.exists) {
          final email = userCredential.user?.email ?? emailToLogin;
          final namePart = email.split('@').first.replaceAll(' ', '').toLowerCase();
          final cleanName = namePart.length >= 4 ? namePart.substring(0, 4) : namePart;
          final randomDigits = (1000 + Random().nextInt(9000)).toString();
          final generatedUserId = 'gr$cleanName$randomDigits';
          final defaultAvatar = 'assets/icon_pack/avatar/avatar_2.png';

          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'name': email.split('@').first,
            'email': email,
            'userId': generatedUserId,
            'gender': 'Laki-laki',
            'avatar': defaultAvatar,
            'role': 'Guru',
            'schoolLevel': '-',
            'createdAt': FieldValue.serverTimestamp(),
            'projectIds': [],
            'companyProfile': null,
          });
        }
        final userData = userDoc.data();
        await LoginHistoryService.recordLogin(
          email: emailToLogin,
          role: userData?['role'] ?? 'Guru',
          displayName: userData?['name'] ?? emailToLogin,
          uid: uid,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainNavigationPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kendala saat masuk. Silakan periksa kembali data Anda.';
      if (e.code == 'user-not-found') {
        message = 'Akun tidak ditemukan. Periksa kembali email atau User ID Anda.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Kata sandi tidak sesuai. Silakan coba lagi atau gunakan opsi "Lupa Kata Sandi".';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid. Contoh: nama@gmail.com';
      } else if (e.code == 'network-request-failed' || e.code == 'unavailable') {
        message = 'Koneksi internet bermasalah. Pastikan perangkat Anda terhubung ke internet.';
      } else if (e.code == 'too-many-requests') {
        message = 'Terlalu banyak percobaan masuk yang gagal. Silakan coba beberapa saat lagi.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isGoogleLoading = false;

  bool _isCancellationError(dynamic e) {
    final str = e.toString().toLowerCase();
    return str.contains('cancel') ||
        str.contains('16') ||
        str.contains('12501') ||
        str.contains('abort') ||
        str.contains('interrupted') ||
        str.contains('dismiss') ||
        str.contains('closed');
  }

  Future<void> _processGoogleSignIn(GoogleSignInAccount googleUser) async {
    setState(() => _isGoogleLoading = true);
    try {
      // Check if this Google email is already registered in Firestore
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: googleUser.email)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        // User exists → sign in with Firebase using idToken
        final googleAuth = googleUser.authentication; // NOT async in v7
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        final userDocData = querySnap.docs.first.data();
        await LoginHistoryService.recordLogin(
          email: googleUser.email,
          role: userDocData['role'] ?? 'Guru',
          displayName: userDocData['name'] ?? (googleUser.displayName ?? googleUser.email),
          uid: querySnap.docs.first.id,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigationPage()),
          );
        }

      } else {
        // New user → redirect to RegisterPage with pre-filled Google info
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RegisterPage(
                googleEmail: googleUser.email,
                googleDisplayName: googleUser.displayName,
                googleUid: googleUser.id,
                isGoogleSignIn: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (_isCancellationError(e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal masuk dengan Google. Silakan coba lagi.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      // Initialize Google Sign-In (v7 API - singleton pattern)
      try {
        await GoogleSignIn.instance.initialize(
          clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
          serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
        );
      } catch (_) {
        // Safe to ignore if already initialized
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      await _processGoogleSignIn(googleUser);
    } catch (e) {
      if (_isCancellationError(e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal masuk dengan Google. Silakan coba lagi.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 500;
    final bool isDark = AppColors.isDarkMode;

    Widget topBar = Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 16.0 : 16.0,
        isTablet ? 16.0 : statusBarHeight + 8.0,
        isTablet ? 16.0 : 16.0,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top-Left Back Button: Tanpa background warna, dengan ikon + teks "Kembali"
          GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OnboardingPage()),
                );
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    size: 28,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Kembali',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top-Right Google "Masuk" Button (Border Sangat Tipis & Tanpa Bayangan Tebal)
          GestureDetector(
            onTap: _isGoogleLoading ? null : _handleGoogleLogin,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF27272A).withValues(alpha: 0.50)
                      : const Color(0xFFE2E8F0).withValues(alpha: 0.50),
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoogleLogoWidget(size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Masuk',
                    style: AppTypography.buttonLabel(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Widget formContent = SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isTablet ? 16.0 : 16.0,
        isTablet ? 16.0 : statusBarHeight + 8.0 + 52.0 + 12.0,
        isTablet ? 16.0 : 16.0,
        viewInsetsBottom > 0 ? (24.0 + viewInsetsBottom) : 0.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTablet) ...[
            topBar,
            const SizedBox(height: 14),
          ],
          // 1. CARD 1: Title, Subtitle, Form Inputs & Submit Button (Tanpa Bayangan & Border Halus Tipis)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF27272A).withValues(alpha: 0.50)
                      : const Color(0xFFE2E8F0).withValues(alpha: 0.50),
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Inside Card (Matching Onboarding Screen)
                  Text(
                    isTablet ? 'Selamat datang kembali!' : 'Masuk',
                    style: AppTypography.pageTitle(
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Subtitle / Terms Inside Card
                  Text(
                    isTablet
                        ? 'Masuk untuk mengelola tugas Anda dengan mudah.'
                        : 'Dengan masuk, Anda menyetujui Ketentuan Layanan kami.',
                    style: AppTypography.chatBody(
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 1. Email Input Box (In-box Stacked Label - Toska saat fokus, Hitam saat tidak)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _emailFocus.hasFocus
                            ? const Color(0xFF68CECA) // Tosca saat diklik
                            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFF0F172A)), // Hitam
                        width: _emailFocus.hasFocus ? 1.5 : 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Email atau ID Pengguna',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: _emailFocus.hasFocus
                                ? (isDark ? const Color(0xFF68CECA) : const Color(0xFF0D9488))
                                : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          cursorColor: isDark ? Colors.white : const Color(0xFF0D9488),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Masukkan email atau ID Anda...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Password Input Box (In-box Stacked Label - Toska saat fokus, Hitam saat tidak)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _passwordFocus.hasFocus
                            ? const Color(0xFF68CECA) // Tosca saat diklik
                            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFF0F172A)), // Hitam
                        width: _passwordFocus.hasFocus ? 1.5 : 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Kata Sandi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: _passwordFocus.hasFocus
                                      ? (isDark ? const Color(0xFF68CECA) : const Color(0xFF0D9488))
                                      : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                cursorColor: isDark ? Colors.white : const Color(0xFF0D9488),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Masukkan kata sandi Anda...',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                    color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                            child: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Forgot Password link (Tanpa Hover Card / Box)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: Text(
                          'Lupa Kata Sandi?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.timestamp(
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],

                  // Sign In Button (Warna Toska, Frameless & Kurangi Round Jadi 14px)
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF68CECA), // Warna Tosca
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                              ),
                            )
                          : Text(
                              'Masuk',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A), // Hitam pekat
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link Belum punya akun? Daftar Sekarang (Teks "Daftar Sekarang" warna Orange)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: Text(
                            'Daftar Sekarang',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFEA580C), // Warna Orange Cerah
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    Widget onboardingPanel = Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Hubner ',
                style: AppTypography.pageTitle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F52FC), // Solid brand violet
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'edu',
                  style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          Text(
            'Kelola\nclassroom Anda\ndengan mudah',
            style: AppTypography.chatBody(color: Colors.black, fontWeight: FontWeight.normal, height: 1.2),
          ),
          const Spacer(flex: 3),
          Center(
            child: Image.asset(
              'assets/images/onboarding.png',
              height: (MediaQuery.of(context).size.height - 350).clamp(200.0, 520.0),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: (MediaQuery.of(context).size.height - 350).clamp(200.0, 455.0),
                width: 455,
                decoration: const BoxDecoration(
                  color: Colors.transparent, // flat/no background
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 48, color: Colors.black26),
                ),
              ),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );

    Widget screenBody;
    if (isTablet) {
      screenBody = Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedRainbowBackground(
          child: Row(
            children: [
              // Left Column: Onboarding Panel
              Expanded(
                flex: 4,
                child: onboardingPanel,
              ),
              // Right Column: Login Form inside pres white card
              Expanded(
                flex: 5,
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                      constraints: const BoxConstraints(maxWidth: 440),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: formContent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      screenBody = Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Soft Pastel 4-Color Minimalist Background (Tosca 50%, Stabilo 25%, Magenta 25%)
              Positioned.fill(
                child: CustomPaint(
                  painter: _AuthPatternPainter(isDark: isDark),
                ),
              ),

              // 2. Form Content (Edge-to-edge scroll view)
              Positioned.fill(
                child: formContent,
              ),

              // 3. Floating Sticky Top Bar: Back & Google Buttons (No background)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: topBar,
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
      child: screenBody,
    );
  }


}

// Pixel-Perfect Vector Google 'G' Logo
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.scale(scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Blue Path (Right & Bar)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(24, 12.25)
      ..cubicTo(24, 10.65, 23.9, 9.15, 23.6, 7.75)
      ..lineTo(12, 7.75)
      ..lineTo(12, 12.25)
      ..lineTo(18.7, 12.25)
      ..cubicTo(18.4, 13.85, 17.5, 15.25, 16.2, 16.05)
      ..lineTo(20.2, 19.15)
      ..cubicTo(22.6, 16.95, 24, 13.75, 24, 12.25);
    canvas.drawPath(bluePath, paint);

    // Green Path (Bottom)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.2, 24, 18, 22.9, 20.2, 21.1)
      ..lineTo(16.2, 18)
      ..cubicTo(15.1, 18.7, 13.7, 19.1, 12, 19.1)
      ..cubicTo(8.8, 19.1, 6.1, 16.9, 5.2, 14)
      ..lineTo(1.1, 17.15)
      ..cubicTo(3.1, 21.25, 7.3, 24, 12, 24);
    canvas.drawPath(greenPath, paint);

    // Yellow Path (Left)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(5.2, 14)
      ..cubicTo(5, 13.3, 4.9, 12.6, 4.9, 11.9)
      ..cubicTo(4.9, 11.2, 5, 10.5, 5.2, 9.8)
      ..lineTo(1.1, 6.65)
      ..cubicTo(0.4, 8.25, 0, 10, 0, 11.9)
      ..cubicTo(0, 13.8, 0.4, 15.55, 1.1, 17.15)
      ..lineTo(5.2, 14);
    canvas.drawPath(yellowPath, paint);

    // Red Path (Top)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.8, 4.75, 15.3, 5.35, 16.6, 6.55)
      ..lineTo(20.1, 3.05)
      ..cubicTo(18, 1.15, 15.2, 0, 12, 0)
      ..cubicTo(7.3, 0, 3.1, 2.75, 1.1, 6.65)
      ..lineTo(5.2, 9.8)
      ..cubicTo(6.1, 6.9, 8.8, 4.75, 12, 4.75);
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

/// Custom painter: Clean, minimalist, and very soft pastel organic fields
/// Proportion: 50% Tosca, 25% Stabilo Lime, 25% Magenta
class _AuthPatternPainter extends CustomPainter {
  final bool isDark;

  const _AuthPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Ultra soft pastel tones for a clean, non-distracting minimalist aesthetic
    final Color toscaSoft = const Color(0xFF68CECA).withValues(alpha: isDark ? 0.14 : 0.16); // 50%
    final Color stabiloSoft = const Color(0xFFDCF585).withValues(alpha: isDark ? 0.18 : 0.28); // 25%
    final Color magentaSoft = const Color(0xFFF472B6).withValues(alpha: isDark ? 0.12 : 0.15); // 25%
    final Color baseBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    // Base background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = baseBg);

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

    // 4. Hairline ring di kanan atas
    final Paint pRingTosca = Paint()
      ..color = const Color(0xFF68CECA).withValues(alpha: isDark ? 0.15 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(w * 0.86, h * 0.14), w * 0.12, pRingTosca);

    // 5. Full Lingkaran di Pojok Kiri Bawah (Full circle di pojok kiri bawah)
    final Paint pRingMagenta = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: isDark ? 0.20 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(w * 0.15, h * 0.82), w * 0.14, pRingMagenta);
  }

  @override
  bool shouldRepaint(covariant _AuthPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
