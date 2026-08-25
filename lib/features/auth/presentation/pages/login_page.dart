import 'dart:math';
import 'package:hubner/core/widgets/three_dots_loader.dart';
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


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  StreamSubscription? _googleSignInSubscription;
  bool? _canPop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_canPop == null) {
      _canPop = Navigator.of(context).canPop();
    }
  }

  late final ScrollController _scrollController;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initGoogleSignIn();
    _googleSignInSubscription = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _processGoogleSignIn(event.user);
      }
    });
  }

  void _dismissBackToOnboarding() {
    if (_isPopping) return;
    _isPopping = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => const OnboardingPage(),
          transitionsBuilder: (_, animation, __, child) {
            const begin = Offset(0.0, -1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _onScroll() {
    if (_isPopping) return;
    if (_scrollController.hasClients && _scrollController.offset < -50.0) {
      _dismissBackToOnboarding();
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

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email/ID dan Kata Sandi wajib diisi.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
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
      String message = 'Masuk gagal: ${e.message}';
      if (e.code == 'user-not-found') {
        message = 'Pengguna tidak ditemukan.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Kata sandi salah atau kredensial tidak valid.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.redAccent),
        );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal masuk dengan Google: $e'), backgroundColor: Colors.redAccent),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal masuk dengan Google: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Widget _buildCircularBackButton(BuildContext context) {
    if (!(_canPop ?? false)) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomPadding = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 500;
    final bool isDark = AppColors.isDarkMode;

    Widget formContent = GestureDetector(
      onVerticalDragUpdate: (details) {
        if (!isTablet && details.primaryDelta != null && details.primaryDelta! > 10) {
          if (_scrollController.hasClients && _scrollController.offset <= 0) {
            _dismissBackToOnboarding();
          }
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          isTablet ? 16.0 : 20.0,
          isTablet ? 16.0 : 12.0,
          isTablet ? 16.0 : 28.0,
          16.0 + safeBottomPadding + viewInsetsBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isTablet) ...[
              Center(
                child: GestureDetector(
                  onTap: _dismissBackToOnboarding,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 4, bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
            ],

            // Welcome Titles (Judul 20, Deskripsi 18)
            Text(
              isTablet ? 'Selamat datang kembali!' : 'Masuk',
              style: AppTypography.pageTitle(
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isTablet
                  ? 'Masuk untuk mengelola tugas Anda dengan mudah.'
                  : 'Dengan masuk, Anda menyetujui Ketentuan Layanan kami.',
              style: AppTypography.chatBody(
                fontSize: 18,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Email Input Field (Styled like Home search box with focused border)
            Text(
              'Email / ID User',
              style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Masukkan email atau ID User Anda...',
                hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
                filled: true,
                fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.2,
                  ),
                ),
                prefixIcon: Icon(Icons.person_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Password Input Field (Styled like Home search box with clean eye icon)
            Text(
              'Kata Sandi',
              style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Masukkan kata sandi Anda',
                hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
                filled: true,
                fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white : Colors.black,
                    width: 1.2,
                  ),
                ),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                suffixIcon: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: isDark ? Colors.white38 : Colors.black38,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Forgot Password link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Lupa Kata Sandi?',
                  style: AppTypography.timestamp(color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Sign In Button
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF7F52FC), // Solid brand violet
                borderRadius: BorderRadius.circular(32),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: const ThreeDotsLoader(),
                      )
                    : Text(
                        'Masuk',
                        style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9), thickness: 1.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Atau lanjutkan dengan',
                    style: AppTypography.timestamp(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                Expanded(child: Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9), thickness: 1.5)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                icon: const GoogleLogoWidget(size: 20),
                label: Text(
                  'Masuk dengan Google',
                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                  side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Belum punya akun? ',
                style: AppTypography.timestamp(color: isDark ? Colors.white60 : Colors.black54),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                child: Text(
                  'Daftar Sekarang',
                  style: AppTypography.buttonLabel(color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
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
      final route = ModalRoute.of(context);
      final animation = route?.animation;

      screenBody = Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        body: animation != null
            ? AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - animation.value)),
                    child: Opacity(
                      opacity: animation.value.clamp(0.0, 1.0),
                      child: SafeArea(child: formContent),
                    ),
                  );
                },
              )
            : SafeArea(child: formContent),
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
