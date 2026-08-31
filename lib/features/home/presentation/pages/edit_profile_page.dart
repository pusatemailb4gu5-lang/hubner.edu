import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Widget _buildDualToneSvgIcon(String iconType, String accentHex, bool isDark, {double size = 20}) {
    final String mainColor = isDark ? '#FFFFFF' : '#18181B';
    String svgStr;

    switch (iconType) {
      case 'person':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="8" r="4.5" stroke="$mainColor" stroke-width="2"/>
          <path d="M4 20c0-4.418 3.582-8 8-8s8 3.582 8 8" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <circle cx="12" cy="8" r="2.2" fill="$accentHex"/>
        </svg>''';
        break;

      case 'gender':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="8" r="4.5" stroke="$mainColor" stroke-width="2"/>
          <path d="M4 20c0-4.418 3.582-8 8-8s8 3.582 8 8" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <circle cx="12" cy="8" r="2.2" fill="$accentHex"/>
        </svg>''';
        break;

      case 'school':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 3L2 8l10 5 10-5-10-5z" stroke="$mainColor" stroke-width="2" stroke-linejoin="round"/>
          <path d="M6 10.6v5.4c0 3.3 2.7 6 6 6s6-2.7 6-6v-5.4" stroke="$mainColor" stroke-width="2" stroke-linecap="round"/>
          <path d="M22 8v7" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
          <circle cx="22" cy="15.5" r="1.5" fill="$accentHex"/>
        </svg>''';
        break;

      case 'grade':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" stroke="$mainColor" stroke-width="2" stroke-linejoin="round"/>
          <circle cx="12" cy="11" r="2" fill="$accentHex"/>
        </svg>''';
        break;

      case 'timezone':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="$mainColor" stroke-width="2"/>
          <path d="M12 7v5l3.5 2" stroke="$accentHex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <circle cx="12" cy="12" r="1.5" fill="$accentHex"/>
        </svg>''';
        break;

      case 'language':
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="$mainColor" stroke-width="2"/>
          <path d="M3.6 9h16.8M3.6 15h16.8" stroke="$mainColor" stroke-width="1.8" stroke-linecap="round"/>
          <path d="M12 3a14 14 0 010 18M12 3a14 14 0 000 18" stroke="$accentHex" stroke-width="2" stroke-linecap="round"/>
        </svg>''';
        break;

      default:
        svgStr = '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="$mainColor" stroke-width="2"/>
          <circle cx="12" cy="12" r="3" fill="$accentHex"/>
        </svg>''';
    }

    return SvgPicture.string(
      svgStr,
      width: size,
      height: size,
    );
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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AppBar(
              backgroundColor: (isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC)).withValues(alpha: 0.75),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              // Tombol Back Tanpa Card / Tanpa Lingkaran Solid
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                splashRadius: 24,
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Edit Profil',
                style: AppTypography.chatHeaderTitle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppTypography.screenHorizontalMargin,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Informasi Profil (Langsung tanpa Card pembungkus)
              _buildSectionTitle('Informasi Profil', isDark),
              const SizedBox(height: 12),

              // Nama Lengkap
              _buildFieldLabel('Nama Lengkap', isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: AppTypography.messageInput(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _inputDecoration(
                  hintText: 'Masukkan nama lengkap',
                  prefixSvg: _buildDualToneSvgIcon('person', '#8B5CF6', isDark, size: 20),
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // Jenis Kelamin
              _buildFieldLabel('Jenis Kelamin', isDark),
              const SizedBox(height: 8),
              _buildCustomDropdownField(
                dropdownKey: _genderKey,
                prefixSvg: _buildDualToneSvgIcon('gender', '#EC4899', isDark, size: 20),
                selectedValue: _selectedGender,
                items: genderOptions,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _selectedGender = val);
                },
              ),
              const SizedBox(height: 16),

              // Tingkat Sekolah
              _buildFieldLabel('Tingkat Sekolah', isDark),
              const SizedBox(height: 8),
              _buildCustomDropdownField(
                dropdownKey: _schoolLevelKey,
                prefixSvg: _buildDualToneSvgIcon('school', '#14B8A6', isDark, size: 20),
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
                const SizedBox(height: 16),
                _buildFieldLabel('Tingkat Kelas', isDark),
                const SizedBox(height: 8),
                _buildCustomDropdownField(
                  dropdownKey: _classKey,
                  prefixSvg: _buildDualToneSvgIcon('grade', '#F59E0B', isDark, size: 20),
                  selectedValue: _getValidGradeForLevel(_selectedSchoolLevel, _selectedClass),
                  items: gradeOptions,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _selectedClass = val);
                  },
                ),
              ],
              const SizedBox(height: 24),

              // 2. Pengaturan Regional (Langsung tanpa Card pembungkus)
              _buildSectionTitle('Pengaturan Regional', isDark),
              const SizedBox(height: 12),

              // Zona Waktu
              _buildFieldLabel('Zona Waktu', isDark),
              const SizedBox(height: 8),
              _buildCustomDropdownField(
                dropdownKey: _timezoneKey,
                prefixSvg: _buildDualToneSvgIcon('timezone', '#F59E0B', isDark, size: 20),
                selectedValue: _selectedTimezone,
                items: timezoneOptions,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _selectedTimezone = val);
                },
              ),
              const SizedBox(height: 16),

              // Bahasa
              _buildFieldLabel('Bahasa Aplikasi', isDark),
              const SizedBox(height: 8),
              _buildCustomDropdownField(
                dropdownKey: _languageKey,
                prefixSvg: _buildDualToneSvgIcon('language', '#3B82F6', isDark, size: 20),
                selectedValue: _selectedLanguage,
                items: languageOptions,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _selectedLanguage = val);
                },
              ),
              const SizedBox(height: 32),

              // 3. Solid Black/Dark Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Simpan Perubahan',
                          style: AppTypography.cardTitle(
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4, top: 4),
      child: Text(
        title,
        style: AppTypography.sectionHeader(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
        ),
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
    required Widget prefixSvg,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.messageInput(
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: prefixSvg,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      filled: true,
      fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
          color: isDark ? Colors.white : const Color(0xFF18181B),
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildCustomDropdownField({
    required GlobalKey dropdownKey,
    required Widget prefixSvg,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            prefixSvg,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.messageInput(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
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
    final double top = offset.dy + size.height - 15;
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
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final val = item['value']!;
                          final label = item['label']!;
                          final isSelected = val == selectedValue;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                Divider(
                                  height: 1,
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                ),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  onChanged(val);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.0,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF60A5FA)
                                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xFF60A5FA),
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
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
