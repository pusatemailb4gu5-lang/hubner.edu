import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';

class CompleteCompanyProfilePage extends StatefulWidget {
  final Map<String, String> registrationData;

  const CompleteCompanyProfilePage({
    super.key,
    required this.registrationData,
  });

  @override
  State<CompleteCompanyProfilePage> createState() => _CompleteCompanyProfilePageState();
}

class _CompleteCompanyProfilePageState extends State<CompleteCompanyProfilePage> {
  final _companyNameController = TextEditingController();
  final _workspaceController = TextEditingController();
  String _selectedTeamSize = '1-5 Anggota Tim';
  bool _isLoading = false;

  final List<String> _teamSizes = [
    '1-5 Anggota Tim',
    '6-20 Anggota Tim',
    '21-50 Anggota Tim',
    '50+ Anggota Tim',
  ];

  @override
  void dispose() {
    _companyNameController.dispose();
    _workspaceController.dispose();
    super.dispose();
  }

  Future<void> _saveCompanyProfile() async {
    final companyName = _companyNameController.text.trim();
    final workspaceName = _workspaceController.text.trim();

    if (companyName.isEmpty || workspaceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field wajib diisi.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = widget.registrationData['name']!;
      final email = widget.registrationData['email']!;
      final password = widget.registrationData['password']!;
      final userId = widget.registrationData['userId']!;
      final gender = widget.registrationData['gender'] ?? 'Laki-laki';
      final defaultAvatar = gender == 'Perempuan'
          ? 'assets/icon_pack/avatar/guru_6.png'
          : 'assets/icon_pack/avatar/guru_1.png';
      String uid = widget.registrationData['uid'] ?? '';

      // 1. Register with Firebase Auth if uid is empty
      if (uid.isEmpty || uid == 'google_mock_uid') {
        // Only run real Firebase Auth if it's not a Google Sign-in flow or Google is mock
        if (uid != 'google_mock_uid') {
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
          uid = userCredential.user?.uid ?? '';
          if (uid.isEmpty) throw Exception('Gagal mendaftarkan pengguna baru.');
        } else {
          // Mock or real google login already has uid
          uid = 'google_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // 2. Create a Default Project for the user (so they have at least 1 project)
      final defaultProjRef = await FirebaseFirestore.instance.collection('projects').add({
        'name': 'Proyek Pertama Saya',
        'description': 'Ini adalah proyek perdana yang dibuat otomatis untuk workspace Anda.',
        'deadline': '31/12/2026',
        'icon': 'project_1.png',
        'ownerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'stages': [
          {
            'name': 'Persiapan',
            'tasks': [
              {
                'title': 'Lengkapi profil workspace',
                'start': '20/07/2026',
                'end': '22/07/2026',
                'assignee': name,
                'assigneeAvatar': 'assets/icon_pack/avatar/avatar_1.png',
                'doc': '',
                'isDone': true,
              }
            ]
          }
        ],
      });

      final defaultProjId = defaultProjRef.id;
      // Add projectId key to the document
      await defaultProjRef.update({'projectId': defaultProjId});

      // 3. Save User Document to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'userId': userId,
        'gender': gender,
        'avatar': defaultAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        'projectIds': [defaultProjId],
        'companyProfile': {
          'companyName': companyName,
          'teamSize': _selectedTeamSize,
          'workspaceName': workspaceName,
        }
      });

      // 4. Update Shared Preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // 5. Navigate to Main Navigation Page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainNavigationPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Pendaftaran gagal: ${e.message}';
      if (e.code == 'email-already-in-use') {
        message = 'Email ini sudah terdaftar.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid.';
      } else if (e.code == 'weak-password') {
        message = 'Kata sandi terlalu lemah.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
                  // App Bar / Back
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Lengkapi Profil Perusahaan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28.1,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Langkah terakhir sebelum mengelola proyek Anda.',
                    style: GoogleFonts.dmSans(
                      fontSize: 16.4,
                      color: Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Company Name Input
                  Text(
                    'Nama Perusahaan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _companyNameController,
                    style: GoogleFonts.dmSans(fontSize: 16.4),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Hubner Studio Tech',
                      hintStyle: GoogleFonts.dmSans(color: Colors.black26),
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
                  const SizedBox(height: 20),

                  // Workspace Name Input
                  Text(
                    'Nama Workspace',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _workspaceController,
                    style: GoogleFonts.dmSans(fontSize: 16.4),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Design Team Workspace',
                      hintStyle: GoogleFonts.dmSans(color: Colors.black26),
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
                  const SizedBox(height: 20),

                  // Team Size Dropdown
                  Text(
                    'Ukuran Tim',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTeamSize,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45),
                        style: GoogleFonts.dmSans(fontSize: 16.4, color: Colors.black87, fontWeight: FontWeight.w500),
                        items: _teamSizes.map((String size) {
                          return DropdownMenuItem<String>(
                            value: size,
                            child: Text(size),
                          );
                        }).toList(),
                        onChanged: (String? newVal) {
                          if (newVal != null) {
                            setState(() {
                              _selectedTeamSize = newVal;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCompanyProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Simpan & Mulai',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17.6,
                                fontWeight: FontWeight.w600,
                              ),
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
