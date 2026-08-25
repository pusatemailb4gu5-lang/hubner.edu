import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/main.dart';

class ManageAttendancePage extends StatefulWidget {
  final String projectId;
  final List currentMasterList;
  final bool isEmbedded;

  const ManageAttendancePage({
    super.key,
    required this.projectId,
    required this.currentMasterList,
    this.isEmbedded = false,
  });

  @override
  State<ManageAttendancePage> createState() => _ManageAttendancePageState();
}

class _ManageAttendancePageState extends State<ManageAttendancePage> {
  late TextEditingController _namesController;
  List<String> _parsedNames = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existingNames = widget.currentMasterList
        .map((e) => (e is Map ? e['name']?.toString() : '') ?? '')
        .where((name) => name.isNotEmpty)
        .join('\n');
    _namesController = TextEditingController(text: existingNames);
    _namesController.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    _namesController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _namesController.text;
    setState(() {
      _parsedNames = text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    });
  }

  Future<void> _saveMasterList() async {
    setState(() => _isSaving = true);
    final List<Map<String, dynamic>> updatedMasterList = [];

    for (var name in _parsedNames) {
      final existingEntry = widget.currentMasterList.firstWhere(
        (e) => e is Map && e['name']?.toString().toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );

      if (existingEntry != null) {
        updatedMasterList.add({
          'name': existingEntry['name'],
          'uid': existingEntry['uid'] ?? '',
          'joined': existingEntry['joined'] ?? false,
          'avatar': existingEntry['avatar'] ?? '',
        });
      } else {
        updatedMasterList.add({
          'name': name,
          'uid': '',
          'joined': false,
          'avatar': '',
        });
      }
    }

    try {
      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'studentsMasterList': updatedMasterList,
      });
      if (mounted) {
        if (!widget.isEmbedded) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Daftar presensi siswa berhasil diperbarui!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Gagal menyimpan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' ||
            themeMode == 'Hitam' ||
            Theme.of(context).brightness == Brightness.dark;

        final Widget editorContent = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_alt_rounded,
                          color: isDark ? const Color(0xFFD6A5F8) : const Color(0xFF7C3AED),
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masukan Daftar Nama',
                              style: AppTypography.cardTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Satu nama per baris',
                              style: AppTypography.fileSize(color: isDark ? const Color(0xFF71717A)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                                : const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${_parsedNames.length} Siswa',
                          style: AppTypography.channelTag(color: isDark ? const Color(0xFFD6A5F8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tulis atau tempel daftar nama siswa. Sistem akan otomatis mendata dan memproses ke laporan.',
                    style: AppTypography.timestamp(color: isDark ? const Color(0xFF71717A, height: 1.4)),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: TextField(
                          controller: _namesController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          cursorColor: const Color(0xFF7C3AED),
                          style: AppTypography.subtitle(color: isDark ? Colors.white : const Color(0xFF0F172A, height: 1.5)),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Contoh:\nBudi Santoso\nAni Wijaya\nCandra Pratama\nDewi Lestari",
                            hintStyle: AppTypography.subtitle(color: isDark ? const Color(0xFF52525B, height: 1.5)),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (widget.isEmbedded) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _isSaving
                        ? const SizedBox(
                            width: 38,
                            height: 38,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: ThreeDotsLoader(),
                              ),
                            ),
                          )
                        : _BouncyIconButton(
                            onTap: _saveMasterList,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              Expanded(child: editorContent),
            ],
          );
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF6F6F6),
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar (AppBar acuan Note Editor Page)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Kembali (<) di atas
                      _BouncyIconButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            size: 18,
                          ),
                        ),
                      ),

                      // Judul Header
                      Text(
                        'Atur Presensi Siswa',
                        style: AppTypography.chatHeaderTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      ),

                      // Tombol Simpan Centang (✓) di atas
                      _isSaving
                          ? const SizedBox(
                              width: 42,
                              height: 42,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: ThreeDotsLoader(),
                                ),
                              ),
                            )
                          : _BouncyIconButton(
                              onTap: _saveMasterList,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C3AED),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                Divider(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  height: 1,
                ),

                // Main Editor
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width > 600 ? 600 : double.infinity,
                      ),
                      child: editorContent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BouncyIconButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncyIconButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_BouncyIconButton> createState() => _BouncyIconButtonState();
}

class _BouncyIconButtonState extends State<_BouncyIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _anim.forward(),
      onTapUp: (_) {
        _anim.reverse();
        widget.onTap();
      },
      onTapCancel: () => _anim.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
