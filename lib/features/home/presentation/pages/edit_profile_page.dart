import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';

class EditProfilePage extends StatefulWidget {
  final String uid;
  final Map<String, dynamic>? initialData;

  const EditProfilePage({
    super.key,
    required this.uid,
    required this.initialData,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late String _selectedGender;
  late String _selectedSchoolLevel;
  late String _selectedClass;
  late String _selectedTimezone;
  late String _selectedLanguage;
  late String _userRole;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _nameController = TextEditingController(text: data['name'] ?? '');
    _userRole = data['role'] ?? 'Siswa';
    _selectedGender = data['gender'] ?? 'Laki-laki';
    _selectedSchoolLevel = data['schoolLevel'] ?? (_userRole.toLowerCase() == 'guru' ? 'SMA' : 'SMA');
    _selectedClass = data['grade'] ?? '10';
    _selectedTimezone = data['timezone'] ?? 'Asia/Jakarta (GMT+07:00)';
    _selectedLanguage = data['language'] ?? 'Bahasa Indonesia';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap tidak boleh kosong.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'name': name,
        'gender': _selectedGender,
        'schoolLevel': _selectedSchoolLevel,
        'grade': _userRole.toLowerCase() == 'siswa' ? _selectedClass : '-',
        'timezone': _selectedTimezone,
        'language': _selectedLanguage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .set(updateData, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  border: Border.all(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Edit Profil',
          style: AppTypography.chatHeaderTitle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppTypography.screenHorizontalMargin,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Form Section Card (Solid Round Style with Colored Icons)
            _buildSectionTitle('Informasi Profil', isDark),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Lengkap
                  _buildFieldLabel('Nama Lengkap', isDark),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: AppTypography.cardTitle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'Masukkan nama lengkap',
                      prefixIcon: Icons.person_outline_rounded,
                      prefixIconColor: const Color(0xFF7F52FC), // Colored icon
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Jenis Kelamin
                  _buildFieldLabel('Jenis Kelamin', isDark),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    style: AppTypography.cardTitle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: _inputDecoration(
                      prefixIcon: Icons.wc_rounded,
                      prefixIconColor: const Color(0xFFEC4899), // Colored icon
                      isDark: isDark,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                      DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGender = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Tingkat Sekolah
                  _buildFieldLabel('Tingkat Sekolah', isDark),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSchoolLevel,
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    style: AppTypography.cardTitle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: _inputDecoration(
                      prefixIcon: Icons.school_outlined,
                      prefixIconColor: const Color(0xFF0D9488), // Colored icon
                      isDark: isDark,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SD', child: Text('SD (Sekolah Dasar)')),
                      DropdownMenuItem(value: 'SMP', child: Text('SMP (Sekolah Menengah Pertama)')),
                      DropdownMenuItem(value: 'SMA', child: Text('SMA (Sekolah Menengah Atas)')),
                      DropdownMenuItem(value: 'SMK', child: Text('SMK (Sekolah Menengah Kejuruan)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSchoolLevel = val;
                          if (val == 'SD') {
                            _selectedClass = '1';
                          } else if (val == 'SMP') {
                            _selectedClass = '7';
                          } else {
                            _selectedClass = '10';
                          }
                        });
                      }
                    },
                  ),

                  // Tingkat Kelas (Khusus Siswa)
                  if (_userRole.toLowerCase() == 'siswa') ...[
                    const SizedBox(height: 18),
                    _buildFieldLabel('Tingkat Kelas', isDark),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _getValidGradeForLevel(_selectedSchoolLevel, _selectedClass),
                      dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      style: AppTypography.cardTitle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: _inputDecoration(
                        prefixIcon: Icons.grade_outlined,
                        prefixIconColor: const Color(0xFFF59E0B), // Colored icon
                        isDark: isDark,
                      ),
                      items: _getGradeItemsForLevel(_selectedSchoolLevel),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClass = val);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Pengaturan Regional (Solid Round Style with Colored Icons)
            _buildSectionTitle('Pengaturan Regional', isDark),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zona Waktu
                  _buildFieldLabel('Zona Waktu', isDark),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTimezone,
                    dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    style: AppTypography.cardTitle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: _inputDecoration(
                      prefixIcon: Icons.public_rounded,
                      prefixIconColor: const Color(0xFF3B82F6), // Colored icon
                      isDark: isDark,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Asia/Jakarta (GMT+07:00)',
                        child: Text('WIB - Asia/Jakarta (GMT+07:00)'),
                      ),
                      DropdownMenuItem(
                        value: 'Asia/Makassar (GMT+08:00)',
                        child: Text('WITA - Asia/Makassar (GMT+08:00)'),
                      ),
                      DropdownMenuItem(
                        value: 'Asia/Jayapura (GMT+09:00)',
                        child: Text('WIT - Asia/Jayapura (GMT+09:00)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTimezone = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Bahasa
                  _buildFieldLabel('Bahasa Aplikasi', isDark),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    style: AppTypography.cardTitle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: _inputDecoration(
                      prefixIcon: Icons.language_rounded,
                      prefixIconColor: const Color(0xFF6366F1), // Colored icon
                      isDark: isDark,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Bahasa Indonesia',
                        child: Text('Bahasa Indonesia (ID)'),
                      ),
                      DropdownMenuItem(
                        value: 'English (US)',
                        child: Text('English (US)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLanguage = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Solid Round Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F52FC), // Solid brand primary
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32), // Solid round
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const ThreeDotsLoader(
                        size: 5,
                        bounceHeight: 2,
                        colors: [Colors.white, Colors.white70, Colors.white60],
                      )
                    : Text(
                        'Simpan Perubahan',
                        style: AppTypography.buttonLabel(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.channelTag(
        color: isDark ? Colors.white38 : const Color(0xFF64748B),
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: AppTypography.buttonLabel(
        color: isDark ? Colors.white70 : const Color(0xFF334155),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    required IconData prefixIcon,
    required Color prefixIconColor,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.buttonLabel(
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: prefixIconColor,
        size: 20,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20), // Solid round
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFF7F52FC),
          width: 1.8,
        ),
      ),
    );
  }

  String _getValidGradeForLevel(String level, String currentGrade) {
    if (level == 'SD') {
      final valid = ['1', '2', '3', '4', '5', '6'];
      return valid.contains(currentGrade) ? currentGrade : '1';
    } else if (level == 'SMP') {
      final valid = ['7', '8', '9'];
      return valid.contains(currentGrade) ? currentGrade : '7';
    } else {
      final valid = ['10', '11', '12'];
      return valid.contains(currentGrade) ? currentGrade : '10';
    }
  }

  List<DropdownMenuItem<String>> _getGradeItemsForLevel(String level) {
    if (level == 'SD') {
      return List.generate(6, (i) {
        final g = '${i + 1}';
        return DropdownMenuItem(value: g, child: Text('Kelas $g (SD)'));
      });
    } else if (level == 'SMP') {
      return List.generate(3, (i) {
        final g = '${i + 7}';
        return DropdownMenuItem(value: g, child: Text('Kelas $g (SMP)'));
      });
    } else {
      return List.generate(3, (i) {
        final g = '${i + 10}';
        return DropdownMenuItem(value: g, child: Text('Kelas $g (SMA/SMK)'));
      });
    }
  }
}
