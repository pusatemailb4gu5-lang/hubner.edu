import 'dart:convert';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'dart:async';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/features/home/presentation/pages/main_navigation_page.dart';
import 'package:hubner/features/notifications/domain/notification_service.dart';
import 'package:hubner/core/theme/app_colors.dart';

class AddClassPage extends StatefulWidget {
  final Map<String, String>? registrationData;
  final String? editProjectId;
  final Map<String, dynamic>? initialClassData;

  const AddClassPage({
    super.key,
    this.registrationData,
    this.editProjectId,
    this.initialClassData,
  });

  @override
  State<AddClassPage> createState() => _AddClassPageState();
}

class _AddClassPageState extends State<AddClassPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _cpController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();

  String _selectedGradeLevel = 'Kelas 10 (SMA/SMK)'; // Default grade level
  final List<String> _gradeOptions = const [
    'Kelas 1 (SD)', 'Kelas 2 (SD)', 'Kelas 3 (SD)', 'Kelas 4 (SD)', 'Kelas 5 (SD)', 'Kelas 6 (SD)',
    'Kelas 7 (SMP)', 'Kelas 8 (SMP)', 'Kelas 9 (SMP)',
    'Kelas 10 (SMA/SMK)', 'Kelas 11 (SMA/SMK)', 'Kelas 12 (SMA/SMK)',
  ];

  final List<TextEditingController> _stageNameControllers = [];
  final List<TextEditingController> _stageSummaryControllers = [];
  final List<TextEditingController> _stageMaterialLinkControllers = [];
  final List<TextEditingController> _stageTaskLinkControllers = [];

  bool _isSaving = false;
  bool _isAiGenerating = false;

  final Map<int, int> _selectedMateriIndex = {};
  final List<List<TextEditingController>> _materiTitleControllers = [];

  int _selectedIconIndex = 0; // Default icon
  int _selectedColorIndex = 0; // Default color index
  final List<Color> _classroomAccentColors = const [
    Color(0xFFD6A5F8), // 01. Lilac Purple
    Color(0xFF9CC8FC), // 02. Sky Blue
    Color(0xFF7DE3D0), // 03. Emerald Mint / Tosca
    Color(0xFFF7BD84), // 04. Amber Peach / Orange
    Color(0xFFF794BE), // 05. Rose Magenta / Pink
    Color(0xFFA5B4FC), // 06. Indigo Violet
    Color(0xFFBEF264), // 07. Fresh Lime
    Color(0xFF67E8F9), // 08. Ocean Cyan
    Color(0xFFFDE047), // 09. Amber Gold
    Color(0xFFCBD5E1), // 10. Steel Slate
  ];

  final List<Color> _classroomDarkColors = const [
    Color(0xFF6B3BA3), // 01. Deep Lilac
    Color(0xFF2864A8), // 02. Deep Sky Blue
    Color(0xFF147D75), // 03. Deep Teal / Tosca
    Color(0xFFC76D10), // 04. Deep Amber / Orange
    Color(0xFFA82658), // 05. Deep Rose / Magenta
    Color(0xFF4338CA), // 06. Deep Indigo
    Color(0xFF4D7C0F), // 07. Deep Olive Lime
    Color(0xFF0E7490), // 08. Deep Ocean Cyan
    Color(0xFFA16207), // 09. Deep Amber Gold
    Color(0xFF334155), // 10. Deep Slate Steel
  ];
  final List<Map<String, dynamic>> _stages = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialClassData != null) {
      final data = widget.initialClassData!;
      _nameController.text = data['name'] ?? '';
      _descController.text = data['description'] ?? '';
      _cpController.text = data['cp'] ?? '';
      _majorController.text = data['major'] ?? '';
      if (data['gradeLevel'] != null && _gradeOptions.contains(data['gradeLevel'])) {
        _selectedGradeLevel = data['gradeLevel'];
      }
      if (data['colorIndex'] is int) {
        _selectedColorIndex = data['colorIndex'];
      }
      final rawIcon = (data['icon'] ?? '').toString();
      final iconMatch = RegExp(r'project_(\d+)').firstMatch(rawIcon);
      if (iconMatch != null) {
        final parsed = int.tryParse(iconMatch.group(1) ?? '1') ?? 1;
        _selectedIconIndex = (parsed - 1).clamp(0, 11);
      }
      final rawStages = data['stages'] as List? ?? [];
      for (var s in rawStages) {
        if (s is Map) {
          final sMap = Map<String, dynamic>.from(s);
          _stages.add(sMap);
          _stageNameControllers.add(TextEditingController(text: sMap['name'] ?? ''));
          _stageSummaryControllers.add(TextEditingController(text: sMap['summary'] ?? ''));
          _stageMaterialLinkControllers.add(TextEditingController(text: sMap['materialLink'] ?? ''));
          _stageTaskLinkControllers.add(TextEditingController(text: sMap['taskLink'] ?? ''));
          final rawMateris = sMap['materis'] as List? ?? [];
          final List<TextEditingController> mControllers = [];
          for (var m in rawMateris) {
            if (m is Map) {
              mControllers.add(TextEditingController(text: m['title'] ?? ''));
            } else {
              mControllers.add(TextEditingController());
            }
          }
          _materiTitleControllers.add(mControllers);
        }
      }
    }
  }

  void _populateFormFromData(Map<String, dynamic> data) {
    setState(() {
      _nameController.text = data['name'] ?? '';
      _descController.text = data['description'] ?? '';
      _cpController.text = data['cp'] ?? '';
      _majorController.text = data['major'] ?? '';
      if (data['gradeLevel'] != null && _gradeOptions.contains(data['gradeLevel'])) {
        _selectedGradeLevel = data['gradeLevel'];
      }
      if (data['colorIndex'] is int) {
        _selectedColorIndex = data['colorIndex'];
      }
      final rawIcon = (data['icon'] ?? '').toString();
      final iconMatch = RegExp(r'project_(\d+)').firstMatch(rawIcon);
      if (iconMatch != null) {
        final parsed = int.tryParse(iconMatch.group(1) ?? '1') ?? 1;
        _selectedIconIndex = (parsed - 1).clamp(0, 11);
      }
      _stages.clear();
      _stageNameControllers.clear();
      _stageSummaryControllers.clear();
      _stageMaterialLinkControllers.clear();
      _stageTaskLinkControllers.clear();
      _materiTitleControllers.clear();

      final rawStages = data['stages'] as List? ?? [];
      for (var s in rawStages) {
        if (s is Map) {
          final sMap = Map<String, dynamic>.from(s);
          _stages.add(sMap);
          _stageNameControllers.add(TextEditingController(text: sMap['name'] ?? ''));
          _stageSummaryControllers.add(TextEditingController(text: sMap['summary'] ?? ''));
          _stageMaterialLinkControllers.add(TextEditingController(text: sMap['materialLink'] ?? ''));
          _stageTaskLinkControllers.add(TextEditingController(text: sMap['taskLink'] ?? ''));
          final rawMateris = sMap['materis'] as List? ?? [];
          final List<TextEditingController> mControllers = [];
          for (var m in rawMateris) {
            if (m is Map) {
              mControllers.add(TextEditingController(text: m['title'] ?? ''));
            } else {
              mControllers.add(TextEditingController());
            }
          }
          _materiTitleControllers.add(mControllers);
        }
      }
    });
  }

  Future<void> _showCopyDataBottomSheet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isDark = AppColors.isDarkMode;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu untuk menyalin data kelas.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('ownerUid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox(height: 200, child: SizedBox.shrink());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada classroom yang dapat disalin',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Buat classroom pertama Anda atau lengkapi data di formulir.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Salin Data dari Classroom Lain',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih salah satu classroom untuk menyalin seluruh struktur materi & elemen ke form ini.',
                    style: GoogleFonts.dmSans(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final pData = docs[i].data() as Map<String, dynamic>;
                        final pName = pData['name'] ?? 'Classroom';
                        final pStages = (pData['stages'] as List? ?? []).length;
                        final pMajor = pData['major'] ?? '';
                        final pIcon = pData['icon'] ?? 'project_1.png';

                        return ListTile(
                          onTap: () {
                            _populateFormFromData(pData);
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Data dari "$pName" berhasil disalin ke form!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          },
                          tileColor: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                          ),
                          leading: Image.asset(
                            'assets/icon_pack/project/$pIcon',
                            width: 36,
                            height: 36,
                            errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Color(0xFF7C3AED)),
                          ),
                          title: Text(
                            pName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            '$pStages Elemen ${pMajor.isNotEmpty ? '· $pMajor' : ''}',
                            style: GoogleFonts.dmSans(
                              fontSize: 13.0,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          trailing: const Icon(Icons.content_copy_rounded, size: 18, color: Color(0xFF7C3AED)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // Stage circle colors rotating by order
  final List<Color> _stageColors = const [
    Color(0xFFFEF3C7), // Yellow
    Color(0xFFE2DCF7), // Purple/Lavender
    Color(0xFFEFF6FF), // Blue
    Color(0xFFFCE7F3), // Pink
    Color(0xFFE2ECE9), // Teal
  ];





  // Interactive Bottom Sheet matching the user's design image
  void _showAddTaskBottomSheet(int stageIndex, int materiIndex) {
    String taskTitle = '';
    String itemType = 'tugas'; // 'tugas', 'quiz', 'pdf'
    DateTime? startDate;
    DateTime? endDate;
    String docName = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> selectDate(bool isStart) async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialEntryMode: DatePickerEntryMode.input,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.black87,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black87,
                      ),

                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87,
                          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        ),
                      ),
                      datePickerTheme: DatePickerThemeData(
                        backgroundColor: Colors.white,
                        headerBackgroundColor: Colors.black87,
                        headerForegroundColor: Colors.white,
                        dayStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                        headerHeadlineStyle: GoogleFonts.plusJakartaSans(fontSize: 23.4, fontWeight: FontWeight.bold, color: Colors.white),
                        headerHelpStyle: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: Colors.white70),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setModalState(() {
                  if (isStart) {
                    startDate = picked;
                  } else {
                    endDate = picked;
                  }
                });
              }
            }

            void showAttachmentDialog() {
              final TextEditingController controller = TextEditingController(text: docName);
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Masukkan Nama Dokumen', style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white,
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: briefing_v1.pdf',
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            docName = controller.text.trim();
                          });
                          Navigator.pop(context);
                        },
                        child: Text('Simpan', style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold)),
                      )
                    ],
                  );
                },
              );
            }

            final safeBottom = MediaQuery.of(context).padding.bottom;
            final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: keyboardBottom + (keyboardBottom > 0 ? 16 : 24 + safeBottom),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull indicator
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Tambah Item Pembelajaran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 23.4,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Item Type Selector (Tugas / Quiz / Materi PDF)
                    Text(
                      'Tipe Item',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => itemType = 'tugas'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: itemType == 'tugas' ? Colors.black : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: itemType == 'tugas' ? Colors.black : const Color(0xFFE2E8F0)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Tugas',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: itemType == 'tugas' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => itemType = 'quiz'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: itemType == 'quiz' ? Colors.black : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: itemType == 'quiz' ? Colors.black : const Color(0xFFE2E8F0)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Quiz',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: itemType == 'quiz' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => itemType = 'pdf'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: itemType == 'pdf' ? Colors.black : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: itemType == 'pdf' ? Colors.black : const Color(0xFFE2E8F0)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Materi PDF',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: itemType == 'pdf' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Task details input style
                    Text(
                      'Judul / Deskripsi Singkat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        maxLines: 2,
                        style: GoogleFonts.dmSans(fontSize: 16.4),
                        onChanged: (val) => taskTitle = val,
                        decoration: InputDecoration(
                          hintText: 'Tulis judul tugas, kuis, atau materi...',
                          hintStyle: GoogleFonts.dmSans(color: Colors.black26),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Start & End dates row
                    if (itemType != 'pdf')
                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal mulai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => selectDate(true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_outlined, color: Colors.black54, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        startDate == null
                                            ? 'DD/MM/YYYY'
                                            : '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15.2,
                                          color: startDate == null ? Colors.black38 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // End Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal selesai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => selectDate(false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_outlined, color: Colors.black54, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        endDate == null
                                            ? 'DD/MM/YYYY'
                                            : '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15.2,
                                          color: endDate == null ? Colors.black38 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Attachment Section
                    Text(
                      'Lampiran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: showAttachmentDialog,
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.description_outlined, color: Colors.black87, size: 24),
                          ),
                          if (docName.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                docName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.2,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (taskTitle.trim().isEmpty) return;
                          
                          // Format date strings
                          final startStr = startDate == null 
                              ? 'DD/MM/YYYY' 
                              : '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}';
                          
                          final endStr = endDate == null 
                              ? 'DD/MM/YYYY' 
                              : '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}';

                          setState(() {
                            (_stages[stageIndex]['materis'][materiIndex]['tasks'] as List).add({
                              'title': taskTitle.trim(),
                              'type': itemType,
                              'start': itemType == 'pdf' ? '' : startStr,
                              'end': itemType == 'pdf' ? '' : endStr,
                              'assignee': '',
                              'assigneeAvatar': '',
                              'doc': docName,
                              'isDone': false,
                            });
                          });
                          
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Tambahkan Item',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _createProject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama classroom wajib diisi.')),
      );
      return;
    }

    if (name.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama classroom maksimal 80 karakter.')),
      );
      return;
    }

    if (widget.editProjectId != null) {
      try {
        await FirebaseFirestore.instance.collection('projects').doc(widget.editProjectId).update({
          'name': name,
          'gradeLevel': _selectedGradeLevel,
          'major': _majorController.text.trim(),
          'cp': _cpController.text.trim(),
          'icon': 'project_${_selectedIconIndex + 1}.png',
          'colorIndex': _selectedColorIndex,
          'stages': _stages,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Classroom berhasil diperbarui!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui classroom: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
      return;
    }

    final deadlineStr = '';

    setState(() {
      // We can disable button during creation or use a simple indicator
    });

    try {
      String ownerUid = widget.registrationData != null 
          ? (widget.registrationData!['uid'] ?? '') 
          : (FirebaseAuth.instance.currentUser?.uid ?? '');

      if (widget.registrationData != null && (ownerUid.isEmpty || ownerUid == 'google_mock_uid')) {
        if (ownerUid != 'google_mock_uid') {
          final email = widget.registrationData!['email']!;
          final password = widget.registrationData!['password']!;
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
          ownerUid = userCredential.user?.uid ?? '';
          if (ownerUid.isEmpty) throw Exception('Gagal mendaftarkan akun baru.');
        } else {
          ownerUid = 'google_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // 1. Save project metadata to Firestore
      final docRef = await FirebaseFirestore.instance.collection('projects').add({
        'name': name,
        'description': '',
        'gradeLevel': _selectedGradeLevel,
        'major': _majorController.text.trim(),
        'cp': _cpController.text.trim(),
        'deadline': deadlineStr,
        'icon': 'project_${_selectedIconIndex + 1}.png',
        'colorIndex': _selectedColorIndex,
        'ownerUid': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'stages': _stages,
      });

      final newProjectId = docRef.id;
      // Add projectId key to the document
      await docRef.update({'projectId': newProjectId});

      NotificationService.addNotification(
        text: 'Classroom baru "$name" berhasil dibuat.',
        type: 'classroom',
        projectId: newProjectId,
      );

      if (widget.registrationData != null) {
        final userName = widget.registrationData!['name']!;
        final email = widget.registrationData!['email']!;
        final userId = widget.registrationData!['userId']!;
        final role = widget.registrationData!['role'] ?? 'Guru';
        final schoolLevel = widget.registrationData!['schoolLevel'] ?? '-';

        // Save User Document to Firestore
        await FirebaseFirestore.instance.collection('users').doc(ownerUid).set({
          'uid': ownerUid,
          'name': userName,
          'email': email,
          'userId': userId,
          'role': role,
          'schoolLevel': schoolLevel,
          'createdAt': FieldValue.serverTimestamp(),
          'projectIds': [newProjectId],
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
      } else {
        // Normal flow: just update user's projectIds array in Firestore
        if (ownerUid.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(ownerUid).update({
            'projectIds': FieldValue.arrayUnion([newProjectId]),
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Classroom berhasil dibuat!'),
              backgroundColor: Colors.black87,
            ),
          );
          Navigator.pop(context);
        }
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
            content: Text('Gagal menyimpan project: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }



  Future<void> _skipClassroomSetup() async {
    if (widget.registrationData == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: ThreeDotsLoader()),
      );

      final userName = widget.registrationData!['name']!;
      final email = widget.registrationData!['email']!;
      final password = widget.registrationData!['password']!;
      final userId = widget.registrationData!['userId']!;
      final role = widget.registrationData!['role'] ?? 'Guru';
      final gender = widget.registrationData!['gender'] ?? 'Laki-laki';
      final defaultAvatar = gender == 'Perempuan'
          ? 'assets/icon_pack/avatar/avatar_1.png'
          : 'assets/icon_pack/avatar/avatar_2.png';

      String ownerUid = widget.registrationData!['uid'] ?? '';
      if (ownerUid.isEmpty || ownerUid == 'google_mock_uid') {
        if (ownerUid != 'google_mock_uid') {
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
          ownerUid = userCredential.user?.uid ?? '';
          if (ownerUid.isEmpty) throw Exception('Gagal mendaftarkan akun baru.');
        } else {
          ownerUid = 'google_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerUid).get();
      if (userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Email ini sudah terdaftar. Silakan Masuk (Login) menggunakan halaman utama.',
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(ownerUid).set({
        'uid': ownerUid,
        'name': userName,
        'email': email,
        'userId': userId,
        'gender': gender,
        'avatar': defaultAvatar,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'projectIds': [],
        'companyProfile': null,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        Navigator.pop(context); // pop loading
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainNavigationPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendaftarkan akun: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _cpController.dispose();
    _majorController.dispose();
    for (var ctrl in _stageNameControllers) { ctrl.dispose(); }
    for (var ctrl in _stageSummaryControllers) { ctrl.dispose(); }
    for (var ctrl in _stageMaterialLinkControllers) { ctrl.dispose(); }
    for (var ctrl in _stageTaskLinkControllers) { ctrl.dispose(); }
    for (var list in _materiTitleControllers) {
      for (var ctrl in list) { ctrl.dispose(); }
    }
    super.dispose();
  }

  void _addStage({
    String? name,
    String? summary,
    String? materialLink,
    String? taskLink,
    List<dynamic>? tasks,
  }) {
    final defaultName = name ?? 'Materi ${_stages.length + 1}';
    final defaultSummary = summary ?? '';
    final defaultMaterialLink = materialLink ?? '';
    final defaultTaskLink = taskLink ?? '';
    final stageId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _stageNameControllers.add(TextEditingController(text: defaultName));
      _stageSummaryControllers.add(TextEditingController(text: defaultSummary));
      _stageMaterialLinkControllers.add(TextEditingController(text: defaultMaterialLink));
      _stageTaskLinkControllers.add(TextEditingController(text: defaultTaskLink));

      final List<TextEditingController> stageMateriCtrls = [
        TextEditingController(text: 'Materi 1'),
        TextEditingController(text: 'Materi 2'),
      ];
      _materiTitleControllers.add(stageMateriCtrls);

      _stages.add({
        'id': stageId,
        'name': defaultName,
        'summary': defaultSummary,
        'materialLink': defaultMaterialLink,
        'taskLink': defaultTaskLink,
        'tasks': tasks ?? [],
        'materis': [
          {
            'title': 'Materi 1',
            'tasks': <Map<String, dynamic>>[],
          },
          {
            'title': 'Materi 2',
            'tasks': <Map<String, dynamic>>[],
          }
        ],
      });
    });
  }

  void _removeStage(int index) {
    setState(() {
      _stageNameControllers[index].dispose();
      _stageNameControllers.removeAt(index);
      _stageSummaryControllers[index].dispose();
      _stageSummaryControllers.removeAt(index);
      _stageMaterialLinkControllers[index].dispose();
      _stageMaterialLinkControllers.removeAt(index);
      _stageTaskLinkControllers[index].dispose();
      _stageTaskLinkControllers.removeAt(index);
      for (var ctrl in _materiTitleControllers[index]) {
        ctrl.dispose();
      }
      _materiTitleControllers.removeAt(index);
      _stages.removeAt(index);
    });
  }

    Widget buildLeftColumn({bool isDesktop = false}) {
    final bool isDark = AppColors.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project Icon Choice List
        Text(
          'Pilih Icon Classroom',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ScrollConfiguration(
          behavior: DesktopScrollBehavior(),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, idx) {
                final isSelected = _selectedIconIndex == idx;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIconIndex = idx;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage(
                        'assets/icon_pack/project/project_${idx + 1}.png',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Card Color Choice List
        Text(
          'Pilih Warna Card Classroom',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            final activeColors = isDark ? _classroomDarkColors : _classroomAccentColors;
            return SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: activeColors.length,
                itemBuilder: (context, idx) {
                  final isSelected = _selectedColorIndex == idx;
                  final Color color = activeColors[idx];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColorIndex = idx;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(isDark ? 0.35 : 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Project Fields (Nama Kelas, Tingkat, Jurusan, CP)
        _buildInputField('Mata Pelajaran', _nameController, maxLength: 80, hint: 'contoh: Pemrograman Web / Bahasa Indonesia'),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tingkat Kelas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        itemHeight: null,
                        value: _selectedGradeLevel,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white60 : Colors.black45, size: 18),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        items: _gradeOptions.map((String grade) {
                          return DropdownMenuItem<String>(
                            value: grade,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(grade, style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGradeLevel = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField('Kelas', _majorController, hint: 'contoh: 10 RPL 1 / Umum'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Capaian Pembelajaran (CP) / Tujuan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        if (isDesktop)
          Expanded(
            child: TextField(
              controller: _cpController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.dmSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tuliskan Capaian Pembelajaran (CP) yang ingin dicapai dalam kelas ini...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black26),
                filled: true,
                fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
                ),
              ),
            ),
          )
        else
          _buildInputField('', _cpController, maxLines: 6, hint: 'Tuliskan Capaian Pembelajaran (CP) yang ingin dicapai dalam kelas ini...'),
      ],
    );
  }

  Widget _buildGeminiCard() {
    final bool isDark = AppColors.isDarkMode;
    if (widget.editProjectId != null) {
      return const SizedBox.shrink();
    }
    if (_isAiGenerating) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AnimatedGeminiLoader(size: 36),
            const SizedBox(height: 12),
            const AnimatedWorkingDotsText(),
            const SizedBox(height: 4),
            Text(
              'Sedang merancang elemen pembelajaran & materi secara otomatis...',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GeminiIcon(size: 18),
              const SizedBox(width: 8),
              Text(
                'Rancang dengan Gemini AI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Buat materi & tugas otomatis secara instan berdasarkan Capaian Pembelajaran (CP) kelas Anda.',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: isDark ? Colors.white60 : Colors.black45,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                final cp = _cpController.text.trim();
                if (cp.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tuliskan Capaian Pembelajaran (CP) / Tujuan terlebih dahulu di atas.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                _runAiGeneration(cp);
              },
              icon: const GeminiIcon(size: 14),
              label: Text(
                'Buat Materi dengan AI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? const Color(0xFF3F3F46) : Colors.black87, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: isDark ? const Color(0xFF27272A).withOpacity(0.4) : Colors.transparent,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRightColumn(bool isDesktop) {
    final bool isDark = AppColors.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Gemini AI Card at the top!
        _buildGeminiCard(),
        const SizedBox(height: 24),

        // 2. Stages Header Row (Without the small "Buat Classroom" button!)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Elemen Pembelajaran & Materi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: _addStage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7C3AED).withOpacity(0.2) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF7C3AED), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, color: Color(0xFF7C3AED), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Elemen',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Stages List (or Skeleton Loader when AI is generating with shimmer & varied lengths)
        if (_isAiGenerating)
          Column(
            children: [
              // Card 1: Long
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        ShimmerSkeletonBox(width: 180, height: 18, borderRadius: 8),
                        ShimmerSkeletonBox(width: 50, height: 14, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const ShimmerSkeletonBox(width: double.infinity, height: 42, borderRadius: 8),
                    const SizedBox(height: 14),
                    const ShimmerSkeletonBox(width: 110, height: 14, borderRadius: 6),
                    const SizedBox(height: 8),
                    const ShimmerSkeletonBox(width: 240, height: 28, borderRadius: 8),
                    const SizedBox(height: 6),
                    const ShimmerSkeletonBox(width: 190, height: 28, borderRadius: 8),
                  ],
                ),
              ),

              // Card 2: Medium / Short
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        ShimmerSkeletonBox(width: 130, height: 18, borderRadius: 8),
                        ShimmerSkeletonBox(width: 40, height: 14, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const ShimmerSkeletonBox(width: double.infinity, height: 26, borderRadius: 8),
                    const SizedBox(height: 14),
                    const ShimmerSkeletonBox(width: 90, height: 14, borderRadius: 6),
                    const SizedBox(height: 8),
                    const ShimmerSkeletonBox(width: 160, height: 28, borderRadius: 8),
                  ],
                ),
              ),

              // Card 3: Varied height
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        ShimmerSkeletonBox(width: 210, height: 18, borderRadius: 8),
                        ShimmerSkeletonBox(width: 60, height: 14, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const ShimmerSkeletonBox(width: double.infinity, height: 34, borderRadius: 8),
                    const SizedBox(height: 14),
                    const ShimmerSkeletonBox(width: 120, height: 14, borderRadius: 6),
                    const SizedBox(height: 8),
                    const ShimmerSkeletonBox(width: 220, height: 28, borderRadius: 8),
                  ],
                ),
              ),
            ],
          )
        else if (_stages.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Text(
                'Belum ada elemen pembelajaran. Tap + Elemen untuk memulai.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stages.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final stage = _stages[index];
              final Color circleColor = _stageColors[index % _stageColors.length];
              final List<dynamic> materis = stage['materis'] ?? [];
              final bool stageIsVisible = stage['isVisible'] ?? true;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : (stageIsVisible ? Colors.white : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _stages[index]['isVisible'] = !stageIsVisible;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Tampilkan ke siswa',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 32,
                                    height: 18,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      color: stageIsVisible ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFCCCCCC)),
                                    ),
                                    alignment: stageIsVisible ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: stageIsVisible ? (isDark ? Colors.black : Colors.white) : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _removeStage(index),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _stageNameControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Nama Elemen (contoh: Proses Bisnis TI)...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white38 : Colors.black26),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onChanged: (val) {
                        _stages[index]['name'] = val;
                      },
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _stageSummaryControllers[index],
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ringkasan / deskripsi elemen...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black38),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      style: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87),
                      onChanged: (val) {
                        _stages[index]['summary'] = val;
                      },
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Daftar Materi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(materis.length, (mIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _materiTitleControllers[index][mIdx],
                                decoration: InputDecoration(
                                  hintText: 'Nama materi...',
                                  hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black26),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                onChanged: (val) {
                                  _stages[index]['materis'][mIdx]['title'] = val;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeMateri(index, mIdx),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _addMateri(index),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 15, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'Tambah Materi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 28),

        // 4. Large "Buat Classroom" Action Button at the bottom
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: isDesktop ? 0.5 : 1.0,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _createProject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.editProjectId != null ? 'Simpan Perubahan' : 'Buat Classroom',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 700 && MediaQuery.of(context).size.shortestSide >= 700;
    final Animation<double>? routeAnimation = ModalRoute.of(context)?.animation;
    final bool isDark = AppColors.isDarkMode;

    Widget buildDesktopPopup() {
      final popupContent = Container(
        width: 1100,
        height: MediaQuery.of(context).size.height * 0.85,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Pop-up Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.editProjectId != null ? 'Edit Classroom' : 'Buat Classroom Baru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.editProjectId == null) ...[
                        GestureDetector(
                          onTap: _showCopyDataBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.content_copy_rounded, size: 15, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 6),
                                Text(
                                  'Salin Data',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9), height: 1),

            // Pop-up Body (2 columns - Column 1 is Sticky/Fixed, Column 2 is Scrollable)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Sticky, expands CP to fill height)
                    Expanded(
                      flex: 11,
                      child: buildLeftColumn(isDesktop: true),
                    ),
                    const SizedBox(width: 36),
                    // Right Column (Scrollable)
                    Expanded(
                      flex: 12,
                      child: SingleChildScrollView(
                        child: buildRightColumn(true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      // Handle custom dialog transition of overlay box
      if (routeAnimation != null) {
        return AnimatedBuilder(
          animation: routeAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.95 + (routeAnimation.value * 0.05),
              child: Opacity(
                opacity: routeAnimation.value,
                child: child,
              ),
            );
          },
          child: popupContent,
        );
      }
      return popupContent;
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: AnimatedBuilder(
                animation: routeAnimation ?? const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withOpacity(0.4 * (routeAnimation?.value ?? 1.0)),
                  );
                },
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: buildDesktopPopup(),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile View
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAF8FF),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                      Text(
                        widget.editProjectId != null ? 'Edit Classroom' : 'Buat Classroom Baru',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (widget.registrationData != null)
                        TextButton(
                          onPressed: _skipClassroomSetup,
                          child: Text(
                            'Atur Nanti',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        )
                      else if (widget.editProjectId == null)
                        GestureDetector(
                          onTap: _showCopyDataBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.content_copy_rounded, size: 14, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Text(
                                  'Salin Data',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 42),
                    ],
                  ),
                ),
                Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9), height: 1),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildLeftColumn(),
                        const SizedBox(height: 24),
                        buildRightColumn(false),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {int maxLines = 1, String? hint, int? maxLength}) {
    final bool isDark = AppColors.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.dmSans(
            fontSize: 14.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black26),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: isDark ? Colors.white : Colors.black,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _sanitizeJsonString(String text) {
    String sanitized = text.trim();
    if (sanitized.startsWith('```')) {
      final lines = sanitized.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      sanitized = lines.join('\n').trim();
    }
    return sanitized;
  }

  Future<Map<String, dynamic>?> _generateProjectWithAI(String projectDesc) async {
    final apiKey = 'AIzaSyAC7KqzJs_v1o8VLNivo0tShRJ8JVMj3wE';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=$apiKey',
    );

    final className = _nameController.text.trim();
    final grade = _selectedGradeLevel;
    final major = _majorController.text.trim();
    final cp = _cpController.text.trim();

    final prompt = '''
Analisis seluruh poin Capaian Pembelajaran (CP) berikut:
"$cp"

Data Kelas:
- Mata Pelajaran: "$className"
- Tingkat Kelas: "$grade"
- Kelas: "$major"
- Catatan Tambahan: "$projectDesc"

Ketentuan Utama:
1. Analisis CP menjadi beberapa Elemen Pembelajaran utama (total elemen/stages harus sesuai dengan jumlah CP yang diupload). Representasikan Elemen ini sebagai item dalam array "stages".
2. Di dalam setiap Elemen ("stages" item):
   - "name": Nama Elemen langsung secara profesional (JANGAN menulis prefiks penomoran seperti "Elemen 1: ...", "Elemen A: ...", atau sejenisnya. Tulis langsung nama elemennya saja).
   - "summary": Ringkasan penjelasan Elemen singkat yang jelas untuk siswa.
   - "materis": Array berisi beberapa Materi Pembelajaran (buat beberapa materi, minimum 2-4 Materi per Elemen).
3. Di dalam setiap Materi (item dalam array "materis"):
   - "title": Judul Materi langsung secara profesional (JANGAN menulis prefiks penomoran seperti "Materi 1.1: ...", "Topik 1: ...", atau sejenisnya. Tulis langsung judul materinya saja).
   - "tasks": Harus berupa array kosong [] secara mutlak. JANGAN mengisi atau membuat tugas, kuis, atau aktivitas apa pun di dalam materi. Biarkan kosong saja agar diisi sendiri oleh guru.
4. Gunakan Bahasa Indonesia.
5. Format output HARUS berupa JSON valid dengan struktur persis seperti berikut:
{
  "stages": [
    {
      "name": "Nama Elemen Langsung Tanpa Prefiks",
      "summary": "Ringkasan penjelasan Elemen sesuai poin CP...",
      "materis": [
        {
          "title": "Judul Materi Pertama Langsung Tanpa Prefiks",
          "tasks": []
        },
        {
          "title": "Judul Materi Kedua Langsung Tanpa Prefiks",
          "tasks": []
        }
      ]
    }
  ]
}
Sertakan HANYA JSON tersebut tanpa penjelasan markdown apa pun di luar JSON.
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = jsonResponse['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null) {
              final cleanJson = _sanitizeJsonString(text);
              final parsed = jsonDecode(cleanJson);
              if (parsed is Map<String, dynamic> && parsed['stages'] != null) {
                return parsed;
              }
            }
          }
        }
      } else {
        throw Exception('ServerException: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Gemini API Error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> _runAiGeneration(String description) async {
    setState(() => _isAiGenerating = true);

    try {
      final aiResult = await _generateProjectWithAI(description);

      if (aiResult == null || aiResult['stages'] == null) {
        throw Exception('Respon AI tidak valid.');
      }

      final stagesList = aiResult['stages'] as List?;
      if (stagesList != null) {
        setState(() {
          for (var ctrl in _stageNameControllers) { ctrl.dispose(); }
          _stageNameControllers.clear();
          for (var ctrl in _stageSummaryControllers) { ctrl.dispose(); }
          _stageSummaryControllers.clear();
          for (var ctrl in _stageMaterialLinkControllers) { ctrl.dispose(); }
          _stageMaterialLinkControllers.clear();
          for (var ctrl in _stageTaskLinkControllers) { ctrl.dispose(); }
          _stageTaskLinkControllers.clear();
          for (var list in _materiTitleControllers) {
            for (var ctrl in list) { ctrl.dispose(); }
          }
          _materiTitleControllers.clear();
          _stages.clear();

          for (final s in stagesList) {
            final stageTitle = s['name'] as String? ?? 'Tahap';
            final stageSummary = s['summary'] as String? ?? '';
            final stageMaterialLink = '';
            final stageTaskLink = '';
            final stageId = '${DateTime.now().millisecondsSinceEpoch}_${_stages.length}';

            final List<Map<String, dynamic>> newMateris = [];
            final List<TextEditingController> stageMateriCtrls = [];
            final materisList = (s['materis'] ?? s['materi'] ?? s['materials'] ?? s['topics']) as List?;
            if (materisList != null) {
              for (final m in materisList) {
                final mTitle = (m['title'] ?? m['name'] ?? m['judul'] ?? 'Materi').toString();
                final List<Map<String, dynamic>> newTasks = [];
                final tasksList = m['tasks'] as List?;
                if (tasksList != null) {
                  for (final t in tasksList) {
                    final taskTitle = t['title'] as String? ?? 'Tugas';
                    final taskType = t['type'] as String? ?? 'tugas';
                    newTasks.add({
                      'title': taskTitle,
                      'type': taskType,
                      'start': '',
                      'end': '',
                      'assignee': '',
                      'assigneeAvatar': '',
                      'doc': '',
                      'isDone': false,
                      'progress': 0,
                    });
                  }
                }
                newMateris.add({
                  'title': mTitle,
                  'tasks': newTasks,
                });
                stageMateriCtrls.add(TextEditingController(text: mTitle));
              }
            }

            if (newMateris.isEmpty) {
              newMateris.addAll([
                {
                  'title': 'Materi 1',
                  'tasks': <Map<String, dynamic>>[],
                },
                {
                  'title': 'Materi 2',
                  'tasks': <Map<String, dynamic>>[],
                }
              ]);
              stageMateriCtrls.add(TextEditingController(text: 'Materi 1'));
              stageMateriCtrls.add(TextEditingController(text: 'Materi 2'));
            }

            _stageNameControllers.add(TextEditingController(text: stageTitle));
            _stageSummaryControllers.add(TextEditingController(text: stageSummary));
            _stageMaterialLinkControllers.add(TextEditingController(text: stageMaterialLink));
            _stageTaskLinkControllers.add(TextEditingController(text: stageTaskLink));
            _materiTitleControllers.add(stageMateriCtrls);

            _stages.add({
              'id': stageId,
              'name': stageTitle,
              'summary': stageSummary,
              'materialLink': stageMaterialLink,
              'taskLink': stageTaskLink,
              'materis': newMateris,
              'tasks': [], // backward compatibility
            });
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const GeminiIcon(size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Materi dan tugas Classroom berhasil dirancang dengan Gemini AI!',
                      style: GoogleFonts.dmSans(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E3A8A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal merancang dengan AI: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAiGenerating = false);
      }
    }
  }

  void _addMateri(int stageIndex) {
    final int nextIndex = _stages[stageIndex]['materis'].length + 1;
    final mTitle = 'Materi $nextIndex';
    setState(() {
      _materiTitleControllers[stageIndex].add(TextEditingController(text: mTitle));
      (_stages[stageIndex]['materis'] as List).add({
        'title': mTitle,
        'tasks': <Map<String, dynamic>>[],
      });
    });
  }

  void _removeMateri(int stageIndex, int materiIndex) {
    setState(() {
      _materiTitleControllers[stageIndex][materiIndex].dispose();
      _materiTitleControllers[stageIndex].removeAt(materiIndex);
      (_stages[stageIndex]['materis'] as List).removeAt(materiIndex);
    });
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  void _showEditStageDialog(int stageIdx) {
    final bool isDark = AppColors.isDarkMode;
    final nameController = TextEditingController(text: _stages[stageIdx]['name']);
    final summaryController = TextEditingController(text: _stages[stageIdx]['summary']);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final List rawMateris = _stages[stageIdx]['materis'] as List? ?? [];
          final List<TextEditingController> materiControllers = rawMateris.map((materi) {
            final String mTitle = (materi['title'] ?? '').toString();
            return TextEditingController(text: mTitle);
          }).toList();

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Edit Elemen / Tahap',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 17.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nama Elemen',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: nameController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Nama Elemen...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Summary / Deskripsi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: summaryController,
                      maxLines: 3,
                      style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Deskripsi elemen...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                  if (materiControllers.isNotEmpty) ...[
                    ...List.generate(materiControllers.length, (mIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Nama Materi ${mIdx + 1}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _removeMateri(stageIdx, mIdx);
                                    setStateDialog(() {});
                                    setState(() {});
                                  },
                                  child: Text(
                                    'Hapus',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.0,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                controller: materiControllers[mIdx],
                                style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Nama materi...',
                                  hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black38),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  for (var ctrl in materiControllers) {
                    ctrl.dispose();
                  }
                  Navigator.pop(ctx);
                },
                child: Text(
                  'Batal',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _stages[stageIdx]['name'] = nameController.text.trim();
                    _stages[stageIdx]['summary'] = summaryController.text.trim();
                    _stageNameControllers[stageIdx].text = nameController.text.trim();
                    _stageSummaryControllers[stageIdx].text = summaryController.text.trim();
                    
                    for (int i = 0; i < rawMateris.length; i++) {
                      if (i < materiControllers.length) {
                        _stages[stageIdx]['materis'][i]['title'] = materiControllers[i].text.trim();
                        _materiTitleControllers[stageIdx][i].text = materiControllers[i].text.trim();
                      }
                    }
                  });
                  for (var ctrl in materiControllers) {
                    ctrl.dispose();
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Simpan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditMateriTitleDialog(int stageIdx, int materiIdx) {
    final bool isDark = AppColors.isDarkMode;
    final titleController = TextEditingController(text: _stages[stageIdx]['materis'][materiIdx]['title']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Nama Materi',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Judul Materi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: titleController,
                style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Judul materi...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _removeMateri(stageIdx, materiIdx);
              });
              Navigator.pop(ctx);
            },
            child: Text('Hapus', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _stages[stageIdx]['materis'][materiIdx]['title'] = titleController.text.trim();
                _materiTitleControllers[stageIdx][materiIdx].text = titleController.text.trim();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Simpan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTaskDetailsDialog({
    required BuildContext context,
    required int stageIdx,
    required int materiIdx,
    required int taskIdx,
    required Map<String, dynamic> task,
  }) {
    final bool isDark = AppColors.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) {
        final titleController = TextEditingController(text: task['title']);
        final docController = TextEditingController(text: task['doc']);
        String selectedType = task['type'] ?? 'tugas';
        String selectedAssignmentType = task['assignmentType'] ?? 'individu';
        DateTime? startDate = task['start'].toString().isNotEmpty ? _parseDateString(task['start']) : null;
        DateTime? endDate = task['end'].toString().isNotEmpty ? _parseDateString(task['end']) : null;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Edit Detail Kegiatan',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 17.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Judul Kegiatan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: titleController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      'Tipe Kegiatan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121215) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        selectedType == 'tugas'
                            ? '📝 Tugas Mandiri/Kelompok'
                            : selectedType == 'quiz'
                                ? '❓ Kuis (Quiz)'
                                : '📄 Materi Pembelajaran (PDF)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (selectedType == 'tugas') ...[
                      Text(
                        'Opsi Pengerjaan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            itemHeight: null,
                            value: selectedAssignmentType,
                            isExpanded: true,
                            style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                            items: const [
                              DropdownMenuItem(
                                value: 'individu',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Text('📝 Individu'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'kelompok',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Text('👥 Kelompok'),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedAssignmentType = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mulai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialEntryMode: DatePickerEntryMode.input,
                                    initialDate: startDate ?? DateTime.now(),
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setModalState(() => startDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    startDate == null ? 'Mulai' : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selesai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialEntryMode: DatePickerEntryMode.input,
                                    initialDate: endDate ?? startDate ?? DateTime.now(),
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setModalState(() => endDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    endDate == null ? 'Selesai' : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Lampiran / Link Modul',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121215) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: docController,
                        style: GoogleFonts.dmSans(fontSize: 14.0, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'modul.pdf atau link gdrive...',
                          hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.black26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _stages[stageIdx]['materis'][materiIdx]['tasks'].removeAt(taskIdx);
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('Hapus', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      final t = _stages[stageIdx]['materis'][materiIdx]['tasks'][taskIdx];
                      t['title'] = titleController.text.trim();
                      t['type'] = selectedType;
                      t['doc'] = docController.text.trim();
                      t['assignmentType'] = selectedAssignmentType;
                      t['start'] = startDate != null ? '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}' : '';
                      t['end'] = endDate != null ? '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}' : '';
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Simpan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class GeminiIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const GeminiIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            width: size * 0.72,
            height: size * 0.72,
            child: CustomPaint(painter: _GeminiStarPainter(color: color)),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: size * 0.42,
            height: size * 0.42,
            child: CustomPaint(painter: _GeminiStarPainter(color: color)),
          ),
        ],
      ),
    );
  }
}

class _GeminiStarPainter extends CustomPainter {
  final Color? color;
  _GeminiStarPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = LinearGradient(
        colors: [
          Color(0xFF4F86F7), // Blue
          Color(0xFF9B72CB), // Purple
          Color(0xFFD96BBA), // Pink
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    path.moveTo(cx, 0);
    path.quadraticBezierTo(cx, cy, w, cy);
    path.quadraticBezierTo(cx, cy, cx, h);
    path.quadraticBezierTo(cx, cy, 0, cy);
    path.quadraticBezierTo(cx, cy, cx, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GeminiStarPainter oldDelegate) =>
      oldDelegate.color != color;
}

class AnimatedGeminiLoader extends StatefulWidget {
  final double size;
  const AnimatedGeminiLoader({super.key, this.size = 48});

  @override
  State<AnimatedGeminiLoader> createState() => _AnimatedGeminiLoaderState();
}

class _AnimatedGeminiLoaderState extends State<AnimatedGeminiLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GeminiIcon(size: widget.size),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double borderRadius;

  DashedBorderPainter({
    this.color = Colors.black26,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashWidth = gap;
    final dashSpace = gap;
    double distance = 0.0;

    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedWorkingDotsText extends StatefulWidget {
  const AnimatedWorkingDotsText({super.key});

  @override
  State<AnimatedWorkingDotsText> createState() => _AnimatedWorkingDotsTextState();
}

class _AnimatedWorkingDotsTextState extends State<AnimatedWorkingDotsText> {
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount % 4) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Text(
      'Gemini AI sedang bekerja$dots',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class ShimmerSkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeletonBox> createState() => _ShimmerSkeletonBoxState();
}

class _ShimmerSkeletonBoxState extends State<ShimmerSkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1).withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}