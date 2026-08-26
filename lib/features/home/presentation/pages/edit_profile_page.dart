import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';

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

  final GlobalKey _genderKey = GlobalKey();
  final GlobalKey _schoolLevelKey = GlobalKey();
  final GlobalKey _classKey = GlobalKey();
  final GlobalKey _timezoneKey = GlobalKey();
  final GlobalKey _languageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _nameController = TextEditingController(text: data['name'] ?? '');
    _userRole = data['role'] ?? 'Siswa';
    _selectedGender = data['gender'] ?? 'Laki-laki';
    _selectedSchoolLevel = data['schoolLevel'] ?? 'SMA';
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

    final genderOptions = [
      {'value': 'Laki-laki', 'label': 'Laki-laki'},
      {'value': 'Perempuan', 'label': 'Perempuan'},
    ];

    final schoolLevelOptions = [
      {'value': 'SD', 'label': 'SD (Sekolah Dasar)'},
      {'value': 'SMP', 'label': 'SMP (Sekolah Menengah Pertama)'},
      {'value': 'SMA', 'label': 'SMA (Sekolah Menengah Atas)'},
      {'value': 'SMK', 'label': 'SMK (Sekolah Menengah Kejuruan)'},
    ];

    final gradeOptions = _getGradeOptionsForLevel(_selectedSchoolLevel);

    final timezoneOptions = [
      {'value': 'Asia/Jakarta (GMT+07:00)', 'label': 'WIB - Asia/Jakarta (GMT+07:00)'},
      {'value': 'Asia/Makassar (GMT+08:00)', 'label': 'WITA - Asia/Makassar (GMT+08:00)'},
      {'value': 'Asia/Jayapura (GMT+09:00)', 'label': 'WIT - Asia/Jayapura (GMT+09:00)'},
    ];

    final languageOptions = [
      {'value': 'Bahasa Indonesia', 'label': 'Bahasa Indonesia (ID)'},
      {'value': 'English (US)', 'label': 'English (US)'},
    ];

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
                      prefixIconColor: const Color(0xFF7F52FC),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Jenis Kelamin
                  _buildFieldLabel('Jenis Kelamin', isDark),
                  const SizedBox(height: 8),
                  _buildCustomDropdownField(
                    dropdownKey: _genderKey,
                    prefixIcon: Icons.wc_rounded,
                    prefixIconColor: const Color(0xFFEC4899),
                    selectedValue: _selectedGender,
                    items: genderOptions,
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() => _selectedGender = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Tingkat Sekolah
                  _buildFieldLabel('Tingkat Sekolah', isDark),
                  const SizedBox(height: 8),
                  _buildCustomDropdownField(
                    dropdownKey: _schoolLevelKey,
                    prefixIcon: Icons.school_outlined,
                    prefixIconColor: const Color(0xFF0D9488),
                    selectedValue: _selectedSchoolLevel,
                    items: schoolLevelOptions,
                    isDark: isDark,
                    onChanged: (val) {
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
                    },
                  ),

                  // Tingkat Kelas (Khusus Siswa)
                  if (_userRole.toLowerCase() == 'siswa') ...[
                    const SizedBox(height: 18),
                    _buildFieldLabel('Tingkat Kelas', isDark),
                    const SizedBox(height: 8),
                    _buildCustomDropdownField(
                      dropdownKey: _classKey,
                      prefixIcon: Icons.grade_outlined,
                      prefixIconColor: const Color(0xFFF59E0B),
                      selectedValue: _getValidGradeForLevel(_selectedSchoolLevel, _selectedClass),
                      items: gradeOptions,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() => _selectedClass = val);
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
                  _buildCustomDropdownField(
                    dropdownKey: _timezoneKey,
                    prefixIcon: Icons.public_rounded,
                    prefixIconColor: const Color(0xFF3B82F6),
                    selectedValue: _selectedTimezone,
                    items: timezoneOptions,
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() => _selectedTimezone = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Bahasa
                  _buildFieldLabel('Bahasa Aplikasi', isDark),
                  const SizedBox(height: 8),
                  _buildCustomDropdownField(
                    dropdownKey: _languageKey,
                    prefixIcon: Icons.language_rounded,
                    prefixIconColor: const Color(0xFF6366F1),
                    selectedValue: _selectedLanguage,
                    items: languageOptions,
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() => _selectedLanguage = val);
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
                    ? CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
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
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: isDark ? Colors.white : Colors.black, // Focused border matching register page
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildCustomDropdownField({
    required GlobalKey dropdownKey,
    required IconData prefixIcon,
    required Color prefixIconColor,
    required String selectedValue,
    required List<Map<String, String>> items,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    final currentItem = items.firstWhere(
      (item) => item['value'] == selectedValue,
      orElse: () => items.isNotEmpty ? items.first : {'value': selectedValue, 'label': selectedValue},
    );
    final displayLabel = currentItem['label'] ?? selectedValue;

    return GestureDetector(
      key: dropdownKey,
      onTap: () => _openCustomDropdown(
        context: context,
        buttonKey: dropdownKey,
        items: items,
        selectedValue: selectedValue,
        onChanged: onChanged,
        isDark: isDark,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(prefixIcon, color: prefixIconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _openCustomDropdown({
    required BuildContext context,
    required GlobalKey buttonKey,
    required List<Map<String, String>> items,
    required String selectedValue,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    final RenderBox? renderBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final double width = size.width;
    final double top = offset.dy + size.height + 6;
    double left = offset.dx;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) {
        return Stack(
          children: [
            // Tap outside to close
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: top,
              left: left,
              width: width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final val = item['value']!;
                        final label = item['label']!;
                        final isSelected = val == selectedValue;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            onChanged(val);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: AppTypography.cardTitle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF7F52FC)
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF7F52FC),
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  List<Map<String, String>> _getGradeOptionsForLevel(String level) {
    if (level == 'SD') {
      return List.generate(6, (i) {
        final g = '${i + 1}';
        return {'value': g, 'label': 'Kelas $g (SD)'};
      });
    } else if (level == 'SMP') {
      return List.generate(3, (i) {
        final g = '${i + 7}';
        return {'value': g, 'label': 'Kelas $g (SMP)'};
      });
    } else {
      return List.generate(3, (i) {
        final g = '${i + 10}';
        return {'value': g, 'label': 'Kelas $g (SMA/SMK)'};
      });
    }
  }
}
