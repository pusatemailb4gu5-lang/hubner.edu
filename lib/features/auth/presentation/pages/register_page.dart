import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';
import 'setup_choice_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'login_page.dart';
import 'package:google_fonts/google_fonts.dart';


class RegisterPage extends StatefulWidget {
  /// If provided, user came from Google Sign-In flow.
  final String? googleEmail;
  final String? googleDisplayName;
  final String? googleUid;
  final bool isGoogleSignIn;

  const RegisterPage({
    super.key,
    this.googleEmail,
    this.googleDisplayName,
    this.googleUid,
    this.isGoogleSignIn = false,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _classController = TextEditingController(text: '1');
  final _classFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String _selectedGender = 'Laki-laki'; // Default gender
  String _selectedRole = 'Siswa'; // Default role ('Siswa' di kiri, 'Guru' di kanan)
  String _selectedJenjang = 'SD'; // 'SD', 'SMP', 'SMA/SMK'

  String getStudentSchoolLevel() {
    if (_selectedJenjang == 'SMA/SMK') {
      return 'SMA';
    }
    return _selectedJenjang;
  }

  StreamSubscription? _googleSignInSubscription;
  bool? _canPop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canPop ??= Navigator.of(context).canPop();
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_clearError);
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
    _classController.addListener(_clearError);
    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
    _classFocus.addListener(() => setState(() {}));
    // Pre-fill fields if coming from Google Sign-In
    if (widget.isGoogleSignIn) {
      _emailController.text = widget.googleEmail ?? '';
      _nameController.text = widget.googleDisplayName ?? '';
    }
    _googleSignInSubscription = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _processGoogleRegister(event.user);
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

  @override
  void dispose() {
    _nameController.removeListener(_clearError);
    _emailController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _confirmPasswordController.removeListener(_clearError);
    _classController.removeListener(_clearError);
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _classFocus.dispose();
    _googleSignInSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _classController.dispose();
    super.dispose();
  }


  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Semua data formulir pendaftaran wajib diisi.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Konfirmasi kata sandi tidak cocok. Silakan periksa kembali.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Kata sandi terlalu pendek. Gunakan minimal 6 karakter.';
      });
      return;
    }

    if (_selectedRole == 'Siswa') {
      final classText = _classController.text.trim();
      if (classText.isEmpty) {
        setState(() {
          _errorMessage = 'Silakan masukkan angka kelas.';
        });
        return;
      }
      final classNum = int.tryParse(classText);
      if (classNum == null) {
        setState(() {
          _errorMessage = 'Kelas harus berupa angka yang valid.';
        });
        return;
      }
      if (_selectedJenjang == 'SD' && (classNum < 1 || classNum > 6)) {
        setState(() {
          _errorMessage = 'Untuk jenjang SD, kelas yang valid adalah 1 sampai 6.';
        });
        return;
      }
      if (_selectedJenjang == 'SMP' && (classNum < 7 || classNum > 9)) {
        setState(() {
          _errorMessage = 'Untuk jenjang SMP, kelas yang valid adalah 7 sampai 9.';
        });
        return;
      }
      if (_selectedJenjang == 'SMA/SMK' && (classNum < 10 || classNum > 12)) {
        setState(() {
          _errorMessage = 'Untuk jenjang SMA/SMK, kelas yang valid adalah 10 sampai 12.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Generate Initial User ID with role-based prefix (gr for Guru, sw for Siswa)
      final namePart = name.replaceAll(' ', '').toLowerCase();
      final cleanName = namePart.length >= 4 ? namePart.substring(0, 4) : namePart;
      final randomDigits = (1000 + Random().nextInt(9000)).toString();
      final prefix = _selectedRole == 'Guru' ? 'gr' : 'sw';
      final generatedUserId = '$prefix$cleanName$randomDigits';

      if (_selectedRole == 'Guru') {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SetupChoicePage(
                uid: null,
                name: name,
                email: email,
                password: password,
                initialUserId: generatedUserId,
                gender: _selectedGender,
                role: _selectedRole,
                schoolLevel: _selectedJenjang == 'SMA/SMK' ? 'SMA' : _selectedJenjang,
              ),
            ),
          );
        }
      } else {
        // Siswa registers directly without SetupChoicePage
        UserCredential userCredential;
        try {
          userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            try {
              userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            } catch (_) {
              throw FirebaseAuthException(
                code: 'email-already-in-use',
                message: 'Email ini sudah terdaftar dengan kata sandi berbeda.',
              );
            }
          } else {
            rethrow;
          }
        }

        final uid = userCredential.user?.uid ?? '';
        if (uid.isEmpty) throw Exception('Gagal mendaftarkan akun.');

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email ini sudah terdaftar. Silakan Masuk (Login) menggunakan halaman utama.',
          );
        }

        final defaultAvatar = _selectedGender == 'Perempuan'
            ? 'assets/icon_pack/avatar/guru_6.png'
            : 'assets/icon_pack/avatar/guru_1.png';

        // Save User Document to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': email,
          'userId': generatedUserId,
          'gender': _selectedGender,
          'avatar': defaultAvatar,
          'role': _selectedRole,
          'schoolLevel': getStudentSchoolLevel(),
          'grade': _classController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'projectIds': [],
          'companyProfile': null,
        });

        // Update Shared Preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainNavigationPage()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Pendaftaran belum berhasil. Silakan periksa kembali data Anda.';
      if (e.code == 'email-already-in-use') {
        message = 'Email ini sudah terdaftar. Silakan Masuk (Login) menggunakan akun Anda.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid. Pastikan penulisan email sudah benar.';
      } else if (e.code == 'weak-password') {
        message = 'Kata sandi terlalu lemah. Gunakan kombinasi huruf dan angka minimal 6 karakter.';
      } else if (e.code == 'network-request-failed' || e.code == 'unavailable') {
        message = 'Koneksi internet bermasalah. Pastikan perangkat Anda terhubung ke internet.';
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

  Future<void> _processGoogleRegister(GoogleSignInAccount user) async {
    setState(() => _isLoading = true);
    try {
      // Check if email already exists in Firestore
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        // User already registered - sign them in with idToken
        final credential = GoogleAuthProvider.credential(
          idToken: user.authentication.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainNavigationPage()),
            (route) => false,
          );
        }
        return;
      }


      // New user - go to SetupChoicePage or register directly
      final namePart = user.displayName?.replaceAll(' ', '').toLowerCase() ?? 'user';
      final cleanName = namePart.length >= 4 ? namePart.substring(0, 4) : namePart;
      final randomDigits = (1000 + Random().nextInt(9000)).toString();
      final prefix = _selectedRole == 'Guru' ? 'gr' : 'sw';
      final generatedUserId = '$prefix$cleanName$randomDigits';

      if (_selectedRole == 'Guru') {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SetupChoicePage(
                uid: user.id,
                name: user.displayName ?? 'User',
                email: user.email,
                password: null,
                initialUserId: generatedUserId,
                gender: _selectedGender,
                role: _selectedRole,
                schoolLevel: _selectedJenjang == 'SMA/SMK' ? 'SMA' : _selectedJenjang,
              ),
            ),
          );
        }
      } else {
        // Siswa: register directly
        final uid = user.id;
        final sLevel = getStudentSchoolLevel();
        final prefix = sLevel == 'SD' ? 'sd' : (sLevel == 'SMP' ? 'smp' : 'sma');
        final defaultAvatar = _selectedGender == 'Perempuan'
            ? 'assets/icon_pack/avatar/${prefix}_6.png'
            : 'assets/icon_pack/avatar/${prefix}_1.png';

        // Save User Document to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': user.displayName ?? 'User',
          'email': user.email,
          'userId': generatedUserId,
          'gender': _selectedGender,
          'avatar': defaultAvatar,
          'role': _selectedRole,
          'schoolLevel': getStudentSchoolLevel(),
          'grade': _classController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'projectIds': [],
          'companyProfile': null,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainNavigationPage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (_isCancellationError(e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal daftar dengan Google. Silakan coba lagi.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleRegister() async {
    // Google Register button only shown when NOT in Google sign-in flow
    // In Google sign-in flow, the main 'Daftar' button handles everything
    // This is the standalone Google register from register page
    setState(() => _isLoading = true);
    try {
      try {
        await GoogleSignIn.instance.initialize(
          clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
          serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
        );
      } catch (_) {
        // Safe to ignore if already initialized
      }

      final user = await GoogleSignIn.instance.authenticate();
      await _processGoogleRegister(user);
    } catch (e) {
      if (_isCancellationError(e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal daftar dengan Google. Silakan coba lagi.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  MaterialPageRoute(builder: (_) => const LoginPage()),
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
            onTap: _isLoading ? null : _handleGoogleRegister,
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
          
          // 1. CARD 1: Title, Subtitle, Registration Form Inputs & Submit Button (Tanpa Bayangan & Border Halus Tipis)
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
                  isTablet ? 'Buat Akun' : 'Daftar',
                  style: AppTypography.pageTitle(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                // Terms / Subtitle Text Inside Card
                Text(
                  isTablet
                      ? 'Daftar untuk mengelola tugas Anda dengan mudah.'
                      : 'Dengan mendaftar, Anda menyetujui Ketentuan Layanan kami.',
                  style: AppTypography.chatBody(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Full Name Input Box (In-box Stacked Label - Toska saat fokus, Hitam saat tidak)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _nameFocus.hasFocus
                          ? const Color(0xFF68CECA) // Tosca saat diklik
                          : (isDark ? const Color(0xFF3F3F46) : const Color(0xFF0F172A)), // Hitam
                      width: _nameFocus.hasFocus ? 1.5 : 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nama Lengkap',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: _nameFocus.hasFocus
                              ? (isDark ? const Color(0xFF68CECA) : const Color(0xFF0D9488))
                              : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        cursorColor: isDark ? Colors.white : const Color(0xFF0D9488),
                        keyboardType: TextInputType.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama lengkap Anda...',
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

                // 2. Email Address Input Box (In-box Stacked Label - Toska saat fokus, Hitam saat tidak)
                if (widget.isGoogleSignIn) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Terverifikasi Google',
                              style: AppTypography.buttonLabel(color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isGoogleSignIn
                        ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9))
                        : (isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _emailFocus.hasFocus
                          ? const Color(0xFF68CECA) // Tosca saat diklik
                          : (isDark ? const Color(0xFF3F3F46) : const Color(0xFF0F172A)), // Hitam
                      width: _emailFocus.hasFocus ? 1.5 : 1.2,
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
                              'Email',
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
                              readOnly: widget.isGoogleSignIn,
                              enabled: !widget.isGoogleSignIn,
                              cursorColor: isDark ? Colors.white : const Color(0xFF0D9488),
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: widget.isGoogleSignIn ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Masukkan alamat email Anda...',
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
                                disabledBorder: InputBorder.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isGoogleSignIn)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0, top: 4.0),
                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Password Input Box (In-box Stacked Label - Toska saat fokus, Hitam saat tidak)
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
                                hintText: 'Buat kata sandi baru...',
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
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
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
                const SizedBox(height: 14),

                // 4. Confirm Password Input Box (In-box Stacked Label - Toska saat fokus, Hitam saat tidak)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _confirmPasswordFocus.hasFocus
                          ? const Color(0xFF68CECA) // Tosca saat diklik
                          : (isDark ? const Color(0xFF3F3F46) : const Color(0xFF0F172A)), // Hitam
                      width: _confirmPasswordFocus.hasFocus ? 1.5 : 1.2,
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
                              'Konfirmasi Kata Sandi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: _confirmPasswordFocus.hasFocus
                                    ? (isDark ? const Color(0xFF68CECA) : const Color(0xFF0D9488))
                                    : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocus,
                              obscureText: _obscureConfirmPassword,
                              cursorColor: isDark ? Colors.white : const Color(0xFF0D9488),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ulangi kata sandi Anda...',
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
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                          child: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Gender Selection (Laki-laki Tosca, Perempuan Magenta, Frameless & Kurangi Round)
                Text(
                  'Jenis Kelamin',
                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'Laki-laki'),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: _selectedGender == 'Laki-laki'
                                ? const Color(0xFF68CECA) // Tosca
                                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.male_rounded,
                                color: _selectedGender == 'Laki-laki'
                                    ? const Color(0xFF0F172A)
                                    : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Laki-laki',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedGender == 'Laki-laki'
                                      ? const Color(0xFF0F172A)
                                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'Perempuan'),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: _selectedGender == 'Perempuan'
                                ? const Color(0xFFEC4899) // Magenta
                                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.female_rounded,
                                color: _selectedGender == 'Perempuan'
                                    ? Colors.white
                                    : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Perempuan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedGender == 'Perempuan'
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role Selection Slide Switch (Full-Round Toggle: Siswa di Kiri, Guru di Kanan)
                Text(
                  'Peran / Role Pengguna (Geser untuk memilih)',
                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! > 100) {
                        // Geser ke kanan -> Guru
                        setState(() => _selectedRole = 'Guru');
                      } else if (details.primaryVelocity! < -100) {
                        // Geser ke kiri -> Siswa
                        setState(() => _selectedRole = 'Siswa');
                      }
                    }
                  },
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30), // Full round toggle
                    ),
                    child: Stack(
                      children: [
                        // Sliding Stabilo Indicator Thumb
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: _selectedRole == 'Siswa' ? Alignment.centerLeft : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            heightFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCF585), // Indikator Stabilo Lime
                                borderRadius: BorderRadius.circular(26), // Full round thumb
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDCF585).withValues(alpha: 0.40),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Interactive Labels: Siswa (Kiri / Default) & Guru (Kanan / Geser Mentok)
                        Row(
                          children: [
                            // 1. Siswa (Default di Kiri)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _selectedRole = 'Siswa'),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        color: _selectedRole == 'Siswa'
                                            ? const Color(0xFF0F172A) // Hitam pekat di atas stabilo
                                            : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Siswa',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14.0,
                                          fontWeight: _selectedRole == 'Siswa' ? FontWeight.w800 : FontWeight.w600,
                                          color: _selectedRole == 'Siswa'
                                              ? const Color(0xFF0F172A)
                                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 2. Guru (Geser Mentok di Kanan)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _selectedRole = 'Guru'),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        color: _selectedRole == 'Guru'
                                            ? const Color(0xFF0F172A) // Hitam pekat di atas stabilo
                                            : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Guru',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14.0,
                                          fontWeight: _selectedRole == 'Guru' ? FontWeight.w800 : FontWeight.w600,
                                          color: _selectedRole == 'Guru'
                                              ? const Color(0xFF0F172A)
                                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Jenjang Sekolah (3 Baris: SD, SMP, SMA/SMK Tanpa Card, Textbox Garis Bawah "___" di Sebelah Kanan yang Dipilih)
                Text(
                  'Jenjang Sekolah',
                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    // Baris 1: SD
                    _buildJenjangRowItem(
                      jenjang: 'SD',
                      rangeLabel: '1 - 6',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    // Baris 2: SMP
                    _buildJenjangRowItem(
                      jenjang: 'SMP',
                      rangeLabel: '7 - 9',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    // Baris 3: SMA
                    _buildJenjangRowItem(
                      jenjang: 'SMA',
                      rangeLabel: '10 - 12',
                      isDark: isDark,
                    ),
                  ],
                ),

                // Inline Error Alert Box
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 14),
                ] else ...[
                  const SizedBox(height: 20),
                ],

                // Submit Button (Warna Toska, Frameless & Kurangi Round Jadi 14px)
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF68CECA), // Warna Tosca
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                              'Daftar',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A), // Hitam pekat
                                fontWeight: FontWeight.w800,
                                fontSize: 16.0,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link Sudah punya akun? Masuk (Teks "Masuk" warna Orange)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah punya akun? ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Masuk',
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
              height: 520, // 30% larger (400 * 1.3)
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 455,
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
              // Right Column: Registration Form inside pres white card
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

  Widget _buildJenjangRowItem({
    required String jenjang,
    required String rangeLabel,
    required bool isDark,
  }) {
    final isSelected = _selectedJenjang == jenjang || (_selectedJenjang == 'SMA/SMK' && jenjang == 'SMA');
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _selectedJenjang = jenjang;
              final currentClass = int.tryParse(_classController.text);
              if (jenjang == 'SD' && (currentClass == null || currentClass < 1 || currentClass > 6)) {
                _classController.text = '1';
              } else if (jenjang == 'SMP' && (currentClass == null || currentClass < 7 || currentClass > 9)) {
                _classController.text = '7';
              } else if ((jenjang == 'SMA' || jenjang == 'SMA/SMK') && (currentClass == null || currentClass < 10 || currentClass > 12)) {
                _classController.text = '10';
              }
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFEA580C) // Orange
                        : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    width: 2.0,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEA580C), // Titik Orange
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                jenjang,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),

        // Textbox Angka Garis Bawah "___" di sebelah kanannya jika Siswa & dipilih
        if (_selectedRole == 'Siswa' && isSelected) ...[
          const SizedBox(width: 20),
          Text(
            'Kelas :',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: TextField(
              controller: _classController,
              focusNode: _classFocus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              cursorColor: const Color(0xFF68CECA),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: '___',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 2),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white38 : const Color(0xFF0F172A),
                    width: 1.8,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF68CECA), // Tosca saat fokus
                    width: 2.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($rangeLabel)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ],
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
