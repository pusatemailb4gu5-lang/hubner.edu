import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/features/projects/presentation/pages/add_class_page.dart';
import 'join_class_registration_page.dart';

class SetupChoicePage extends StatefulWidget {
  final String? uid;
  final String name;
  final String email;
  final String? password;
  final String initialUserId;
  final String gender;
  final String role;
  final String schoolLevel;

  const SetupChoicePage({
    super.key,
    this.uid,
    required this.name,
    required this.email,
    this.password,
    required this.initialUserId,
    required this.gender,
    this.role = 'Guru',
    this.schoolLevel = '-',
  });

  @override
  State<SetupChoicePage> createState() => _SetupChoicePageState();
}

class _SetupChoicePageState extends State<SetupChoicePage> {
  late final TextEditingController _userIdController;
  bool _isCheckingId = false;
  bool _isIdUnique = true;
  bool _hasChecked = false;
  String? _idErrorMessage;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController(text: widget.initialUserId);
    // Perform initial check on generated ID to make sure it's unique
    _checkUserIdUnique(widget.initialUserId);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _checkUserIdUnique(String inputId) async {
    final cleanId = inputId.trim().toLowerCase();
    if (cleanId.length < 6) {
      setState(() {
        _isIdUnique = false;
        _hasChecked = true;
        _idErrorMessage = 'ID minimal harus 6 karakter.';
      });
      return;
    }

    setState(() {
      _isCheckingId = true;
      _idErrorMessage = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: cleanId)
          .get();

      setState(() {
        _isIdUnique = querySnapshot.docs.isEmpty;
        _hasChecked = true;
        _idErrorMessage = _isIdUnique ? null : 'ID User sudah digunakan.';
      });
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        // If Firestore rules require auth, assume unique during pre-registration
        setState(() {
          _isIdUnique = true;
          _hasChecked = true;
          _idErrorMessage = null;
        });
      } else {
        setState(() {
          _isIdUnique = false;
          _hasChecked = true;
          _idErrorMessage = 'Gagal memeriksa ID.';
        });
      }
    } finally {
      setState(() {
        _isCheckingId = false;
      });
    }
  }

  void _onChoiceSelected(bool isCreateProject) {
    final finalUserId = _userIdController.text.trim().toLowerCase();
    if (finalUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID User tidak boleh kosong.')),
      );
      return;
    }

    if (!_isIdUnique || _idErrorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_idErrorMessage ?? 'Silakan gunakan ID User yang unik dan valid.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final registrationData = {
      'uid': widget.uid ?? '',
      'name': widget.name,
      'email': widget.email,
      'password': widget.password ?? '',
      'userId': finalUserId,
      'gender': widget.gender,
      'role': widget.role,
      'schoolLevel': widget.schoolLevel,
    };

    if (isCreateProject) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, _, _) => AddClassPage(registrationData: registrationData),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JoinClassRegistrationPage(registrationData: registrationData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Halo, ${widget.name.split(' ')[0]}!',
                    style: AppTypography.pageTitle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Konfigurasikan ID User unik Anda sebelum memulai.',
                    style: AppTypography.subtitle(color: Colors.black45),
                  ),
                  const SizedBox(height: 32),

                  // User ID Field
                  Text(
                    'ID User Anda',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userIdController,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _hasChecked = false;
                            });
                          },
                          cursorColor: const Color(0xFF68CECA),
                          decoration: InputDecoration(
                            hintText: 'Contoh: marie12',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              color: const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF68CECA), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isCheckingId
                            ? null
                            : () => _checkUserIdUnique(_userIdController.text),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCF585), // Warna Stabilo Lime
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: _isCheckingId
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                                  ),
                                )
                              : Text(
                                  'Periksa',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF0F172A), // Teks Hitam
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_hasChecked) ...[
                    Row(
                      children: [
                        Icon(
                          _isIdUnique && _idErrorMessage == null
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          size: 16,
                          color: _isIdUnique && _idErrorMessage == null
                              ? const Color(0xFFEA580C) // Warna Orange
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isIdUnique && _idErrorMessage == null
                                ? 'ID tersedia dan dapat digunakan.'
                                : (_idErrorMessage ?? 'ID tidak valid.'),
                            style: GoogleFonts.plusJakartaSans(
                              color: _isIdUnique && _idErrorMessage == null
                                  ? const Color(0xFFEA580C) // Warna Orange
                                  : Colors.redAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),

                  Text(
                    'Pilih Cara Memulai',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Melengkapi Data Kelas (Tanpa Card, Ikon Tombol Warna Orange)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onChoiceSelected(true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED), // Soft Orange background
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.add_task_rounded,
                              color: Color(0xFFEA580C), // Ikon Warna Orange
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Melengkapi Data Kelas',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Atur nama kelas & materi pembelajaran (dapat diatur nanti).',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
