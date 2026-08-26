import 'dart:math';
import 'package:hubner/core/widgets/three_dots_loader.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String _selectedGender = 'Laki-laki'; // Default gender
  String _selectedRole = 'Guru'; // Default role ('Guru' or 'Siswa')
  String _selectedSchoolLevel = 'SMA'; // Default school level for Guru ('SD', 'SMP', 'SMA', 'SMK')
  String _selectedStudentClass = '1'; // Default student class ('1' to '12')
  String _selectedSchoolLevelForStudent = 'SMA'; // Default student school level for class 10-12 ('SMA', 'SMK')

  String getStudentSchoolLevel() {
    final intClass = int.tryParse(_selectedStudentClass) ?? 1;
    if (intClass >= 1 && intClass <= 6) {
      return 'SD';
    } else if (intClass >= 7 && intClass <= 9) {
      return 'SMP';
    } else {
      return _selectedSchoolLevelForStudent;
    }
  }

  StreamSubscription? _googleSignInSubscription;
  bool? _canPop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_canPop == null) {
      _canPop = Navigator.of(context).canPop();
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_clearError);
    _emailController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _confirmPasswordController.addListener(_clearError);
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
    _googleSignInSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                schoolLevel: _selectedSchoolLevel,
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
          'grade': _selectedStudentClass,
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
                schoolLevel: _selectedSchoolLevel,
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
          'grade': _selectedStudentClass,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal daftar dengan Google: $e'), backgroundColor: Colors.redAccent),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal daftar dengan Google: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCircularBackButton(BuildContext context, bool isDark) {
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
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: isDark ? Colors.white : Colors.black87,
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

    Widget formContent = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 16.0 : AppTypography.screenHorizontalMargin,
        isTablet ? 16.0 : 20.0,
        isTablet ? 16.0 : AppTypography.screenHorizontalMargin,
        16.0 + safeBottomPadding + viewInsetsBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTablet) _buildCircularBackButton(context, isDark),
          if (isTablet) const SizedBox(height: 32),
          
          // Create Account Title (Judul 20, Deskripsi 18)
          Text(
            isTablet ? 'Buat Akun' : 'Daftar',
            style: AppTypography.pageTitle(
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTablet
                ? 'Daftar untuk mengelola tugas Anda dengan mudah.'
                : 'Dengan mendaftar, Anda menyetujui Ketentuan Layanan kami.',
            style: AppTypography.chatBody(
              fontSize: 18,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Full Name Field
          Text(
            'Nama Lengkap',
            style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Masukkan nama lengkap Anda',
              hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
              filled: true,
              fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.2),
              ),
              prefixIcon: Icon(Icons.person_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          // Email Address Field
          Row(
            children: [
              Text(
                'Alamat Email',
                style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
              ),
              if (widget.isGoogleSignIn) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            readOnly: widget.isGoogleSignIn,
            enabled: !widget.isGoogleSignIn,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.timestamp(color: widget.isGoogleSignIn ? (isDark ? Colors.white38 : Colors.black38) : (isDark ? Colors.white : Colors.black87)),
            decoration: InputDecoration(
              hintText: 'Masukkan email Anda',
              hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
              filled: true,
              fillColor: widget.isGoogleSignIn
                  ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9))
                  : (isDark ? const Color(0xFF18181B) : Colors.white),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(
                  color: widget.isGoogleSignIn
                      ? (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0))
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0), width: 1.2),
              ),
              prefixIcon: Icon(Icons.mail_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
              suffixIcon: widget.isGoogleSignIn
                  ? const Padding(
                      padding: EdgeInsets.only(right: 16.0),
                      child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Password Field
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
              hintText: 'Buat kata sandi',
              hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
              filled: true,
              fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.2),
              ),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
              suffixIcon: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
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
          const SizedBox(height: 16),

          // Confirm Password Field
          Text(
            'Konfirmasi Kata Sandi',
            style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: AppTypography.timestamp(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Konfirmasi kata sandi Anda',
              hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
              filled: true,
              fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.2),
              ),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
              suffixIcon: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Icon(
                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gender Selection
          Text(
            'Jenis Kelamin',
            style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
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
                          ? (isDark ? const Color(0xFF7F52FC) : Colors.black)
                          : (isDark ? const Color(0xFF18181B) : Colors.white),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _selectedGender == 'Laki-laki'
                            ? (isDark ? const Color(0xFF7F52FC) : Colors.black)
                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.male_rounded,
                          color: _selectedGender == 'Laki-laki' ? Colors.white : (isDark ? Colors.white54 : Colors.black38),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Laki-laki',
                          style: AppTypography.buttonLabel(color: _selectedGender == 'Laki-laki' ? Colors.white : (isDark ? Colors.white70 : Colors.black38), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = 'Perempuan'),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedGender == 'Perempuan'
                          ? (isDark ? const Color(0xFF7F52FC) : Colors.black)
                          : (isDark ? const Color(0xFF18181B) : Colors.white),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _selectedGender == 'Perempuan'
                            ? (isDark ? const Color(0xFF7F52FC) : Colors.black)
                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.female_rounded,
                          color: _selectedGender == 'Perempuan' ? Colors.white : (isDark ? Colors.white54 : Colors.black38),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Perempuan',
                          style: AppTypography.buttonLabel(color: _selectedGender == 'Perempuan' ? Colors.white : (isDark ? Colors.white70 : Colors.black38), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Role Selection (Guru vs Siswa)
          Text(
            'Peran / Role Pengguna',
            style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'Guru'),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedRole == 'Guru' ? const Color(0xFF7F52FC) : (isDark ? const Color(0xFF18181B) : Colors.white),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFF7F52FC),
                        width: _selectedRole == 'Guru' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_rounded,
                          color: _selectedRole == 'Guru' ? Colors.white : (isDark ? Colors.white60 : Colors.black45),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Guru',
                          style: AppTypography.buttonLabel(color: _selectedRole == 'Guru' ? Colors.white : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'Siswa'),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedRole == 'Siswa' ? const Color(0xFF7F52FC) : (isDark ? const Color(0xFF18181B) : Colors.white),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFF7F52FC),
                        width: _selectedRole == 'Siswa' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: _selectedRole == 'Siswa' ? Colors.white : (isDark ? Colors.white60 : Colors.black45),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Siswa',
                          style: AppTypography.buttonLabel(color: _selectedRole == 'Siswa' ? Colors.white : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedRole == 'Guru') ...[
            const SizedBox(height: 16),
            Text(
              'Tingkat Sekolah',
              style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  borderRadius: BorderRadius.circular(20),
                  elevation: 3,
                  dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                  value: _selectedSchoolLevel,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSchoolLevel = newValue;
                      });
                    }
                  },
                  items: ['SD', 'SMP', 'SMA', 'SMK'].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          const Icon(Icons.domain_rounded, size: 18, color: Color(0xFF7F52FC)),
                          const SizedBox(width: 10),
                          Text(
                            'Jenjang $value',
                            style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          if (_selectedRole == 'Siswa') ...[
            const SizedBox(height: 16),
            Text(
              'Kelas Siswa',
              style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  borderRadius: BorderRadius.circular(20),
                  elevation: 3,
                  dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                  value: _selectedStudentClass,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStudentClass = newValue;
                      });
                    }
                  },
                  items: List.generate(12, (index) => (index + 1).toString()).map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          const Icon(Icons.class_rounded, size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 10),
                          Text(
                            'Kelas $value',
                            style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (int.parse(_selectedStudentClass) >= 10) ...[
              const SizedBox(height: 16),
              Text(
                'Tingkat Sekolah',
                style: AppTypography.timestamp(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    borderRadius: BorderRadius.circular(20),
                    elevation: 3,
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    value: _selectedSchoolLevelForStudent,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
                    style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSchoolLevelForStudent = newValue;
                        });
                      }
                    },
                    items: ['SMA', 'SMK'].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            const Icon(Icons.domain_rounded, size: 18, color: Color(0xFF7F52FC)),
                            const SizedBox(width: 10),
                            Text(
                              value,
                              style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],

          // Inline Error Alert Box (Di bawah textbox / card dengan bahasa ramah)
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
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

          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF7F52FC), // Solid brand violet
              borderRadius: BorderRadius.circular(32),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
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
                      child: ThreeDotsLoader(colors: [Colors.white]),
                    )
                  : Text(
                      'Daftar',
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
              onPressed: _isLoading ? null : _handleGoogleRegister,
              icon: const GoogleLogoWidget(size: 20),
              label: Text(
                'Daftar dengan Google',
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
                'Sudah punya akun? ',
                style: AppTypography.timestamp(color: isDark ? Colors.white60 : Colors.black54),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  'Masuk',
                  style: AppTypography.buttonLabel(color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9), fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        body: SafeArea(
          child: formContent,
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
