import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
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
          pageBuilder: (context, _, __) => AddClassPage(registrationData: registrationData),
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
                    style: AppTypography.buttonLabel(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userIdController,
                          style: AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.w600),
                          onChanged: (val) {
                            setState(() {
                              _hasChecked = false;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Contoh: marie12',
                            hintStyle: AppTypography.timestamp(color: Colors.black26),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.black),
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
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: _isCheckingId
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: const ThreeDotsLoader(),
                                )
                              : Text(
                                  'Periksa',
                                  style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.w600),
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
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isIdUnique && _idErrorMessage == null
                                ? 'ID tersedia dan dapat digunakan.'
                                : (_idErrorMessage ?? 'ID tidak valid.'),
                            style: AppTypography.timestamp(color: _isIdUnique && _idErrorMessage == null ? Colors.green : Colors.redAccent, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 48),

                  Text(
                    'Pilih Cara Memulai',
                    style: AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Create Project Card
                  GestureDetector(
                    onTap: () => _onChoiceSelected(true),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_task_rounded,
                              color: Color(0xFF2563EB),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Melengkapi Data Kelas',
                                  style: AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Atur nama kelas & materi pembelajaran (dapat diatur nanti).',
                                  style: AppTypography.timestamp(color: Colors.black38),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
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
