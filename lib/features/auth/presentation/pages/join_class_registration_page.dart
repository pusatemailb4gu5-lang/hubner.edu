import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';

class JoinClassRegistrationPage extends StatefulWidget {
  final Map<String, String> registrationData;

  const JoinClassRegistrationPage({
    super.key,
    required this.registrationData,
  });

  @override
  State<JoinClassRegistrationPage> createState() => _JoinClassRegistrationPageState();
}

class _JoinClassRegistrationPageState extends State<JoinClassRegistrationPage> {
  final _projectIdController = TextEditingController();
  bool _isLoading = false;
  bool _isScanning = false;

  // Two-step join variables
  bool _isClassroomLoaded = false;
  bool _isLoadingClassroom = false;
  String? _classroomName;
  List<String> _availableNames = [];
  String? _selectedName;
  String? _errorMessage;

  @override
  void dispose() {
    _projectIdController.dispose();
    super.dispose();
  }

  Future<void> _checkClassroom() async {
    final projectId = _projectIdController.text.trim();
    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan ID Classroom terlebih dahulu.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() {
      _isLoadingClassroom = true;
      _errorMessage = null;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
      if (!doc.exists) {
        setState(() {
          _errorMessage = 'ID Classroom tidak ditemukan. Periksa kembali.';
          _isLoadingClassroom = false;
        });
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final List masterList = data['studentsMasterList'] as List? ?? [];
      final List<String> names = [];
      for (var e in masterList) {
        if (e is Map) {
          final String name = e['name'] ?? '';
          final String uid = e['uid'] ?? '';
          final bool joined = e['joined'] ?? false;
          if (name.isNotEmpty && (uid.isEmpty || !joined)) {
            names.add(name);
          }
        }
      }
      setState(() {
        _classroomName = data['name'] ?? 'Classroom';
        _availableNames = names;
        _isClassroomLoaded = true;
        _isLoadingClassroom = false;
        if (names.isEmpty) {
          _errorMessage = masterList.isEmpty
              ? 'Daftar siswa induk belum diatur oleh guru kelas. Hubungi guru Anda.'
              : 'Semua siswa di daftar induk kelas ini sudah bergabung.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat kelas: $e';
        _isLoadingClassroom = false;
      });
    }
  }

  Future<void> _handleJoinAndRegister() async {
    final projectId = _projectIdController.text.trim();
    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan ID Proyek terlebih dahulu.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = widget.registrationData['name']!;
      final email = widget.registrationData['email']!;
      final password = widget.registrationData['password']!;
      final userId = widget.registrationData['userId']!;
      final gender = widget.registrationData['gender'] ?? 'Laki-laki';
      final sLevel = widget.registrationData['schoolLevel'] ?? 'SMA';
      final prefix = sLevel == 'SD' ? 'sd' : (sLevel == 'SMP' ? 'smp' : 'sma');
      final defaultAvatar = gender == 'Perempuan'
          ? 'assets/icon_pack/avatar/${prefix}_6.png'
          : 'assets/icon_pack/avatar/${prefix}_1.png';

      // 1. Validate project exists
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID Proyek tidak ditemukan. Periksa kembali.'), backgroundColor: Colors.redAccent),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final projectName = projectDoc.data()?['name'] ?? 'Proyek';
      final ownerUid = projectDoc.data()?['ownerUid'] ?? '';

      // 2. Register with Firebase Auth
      String uid = widget.registrationData['uid'] ?? '';
      if (uid.isEmpty) {
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
        if (uid.isEmpty) throw Exception('Gagal mendaftarkan pengguna.');
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Email ini sudah terdaftar. Silakan Masuk (Login) menggunakan halaman utama.',
        );
      }

      final role = widget.registrationData['role'] ?? 'Siswa';

      // 3. Save user document (no projects yet, waiting for approval)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'userId': userId,
        'gender': gender,
        'avatar': defaultAvatar,
        'role': role,
        'schoolLevel': widget.registrationData['schoolLevel'] ?? 'SMA',
        'grade': widget.registrationData['grade'] ?? '10',
        'createdAt': FieldValue.serverTimestamp(),
        'projectIds': [],
        'companyProfile': {
          'companyName': '-',
          'teamSize': '-',
          'workspaceName': '-',
        },
      });

      // 4. Send join request with status pending
      await FirebaseFirestore.instance.collection('projectJoinRequests').add({
        'projectId': projectId,
        'projectName': projectName,
        'requesterUid': uid,
        'requesterName': name,
        'requesterUserId': userId,
        'ownerUid': ownerUid,
        'selectedMasterName': _selectedName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Save login state and navigate to dashboard
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permintaan bergabung ke "$projectName" dikirim! Menunggu persetujuan pemilik.'),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 4),
          ),
        );
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
          SnackBar(content: Text('Gagal mendaftar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_add_rounded, color: Color(0xFF16A34A), size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Gabung Classroom',
                    style: AppTypography.pageTitle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan ID Classroom atau scan QR code untuk bergabung. Permintaan akan dikirim ke Guru.',
                    style: AppTypography.timestamp(color: Colors.black45, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Anda akan masuk dashboard dengan status pending. Classroom aktif setelah Guru menyetujui.',
                            style: AppTypography.timestamp(color: const Color(0xFFD97706), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_isScanning) ...[
                    Container(
                      width: double.infinity,
                      height: 260,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: MobileScanner(
                        onDetect: (BarcodeCapture capture) {
                          for (final barcode in capture.barcodes) {
                            final code = barcode.rawValue;
                            if (code != null && code.isNotEmpty) {
                              setState(() {
                                _isScanning = false;
                                _projectIdController.text = code;
                              });
                              break;
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _isScanning = false),
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                        label: Text('Batal Scan',
                            style: AppTypography.buttonLabel(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (!_isClassroomLoaded) ...[
                    Text('ID Classroom',
                        style: AppTypography.buttonLabel(color: Colors.black54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _projectIdController,
                            style: AppTypography.cardTitle(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Masukkan ID Classroom...',
                              hintStyle: AppTypography.buttonLabel(color: Colors.black26, fontWeight: FontWeight.normal),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => _isScanning = !_isScanning),
                          child: Container(
                            height: 54,
                            width: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _isScanning ? Icons.close_rounded : Icons.qr_code_scanner_rounded,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: AppTypography.timestamp(color: Colors.redAccent, fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingClassroom ? null : _checkClassroom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _isLoadingClassroom
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(
                          'Periksa Kelas',
                          style: AppTypography.cardTitle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school_rounded, color: Colors.black87),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nama Kelas',
                                  style: AppTypography.buttonLabel(color: Colors.black45),
                                ),
                                Text(
                                  _classroomName ?? '',
                                  style: AppTypography.cardTitle(color: Colors.black87, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.timestamp(color: Colors.redAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isClassroomLoaded = false;
                              _errorMessage = null;
                            });
                          },
                          child: Text(
                            'Kembali',
                            style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Pilih Nama Anda dari Daftar Induk',
                        style: AppTypography.buttonLabel(color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                        ),
                        items: _availableNames.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name, style: AppTypography.buttonLabel(fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        value: _selectedName,
                        hint: Text('Pilih Nama Anda...', style: AppTypography.timestamp(color: Colors.black26)),
                        onChanged: (val) {
                          setState(() {
                            _selectedName = val;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _isClassroomLoaded = false;
                                  _selectedName = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Kembali',
                                style: AppTypography.buttonLabel(color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isLoading || _selectedName == null)
                                  ? null
                                  : _handleJoinAndRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Icon(Icons.group_add_rounded, size: 18),
                              label: Text(
                                _isLoading ? 'Mendaftar...' : 'Daftar & Gabung',
                                style: AppTypography.cardTitle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
