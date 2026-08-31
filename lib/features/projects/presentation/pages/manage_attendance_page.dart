import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
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

  Widget _buildPresensiSvgIcon(bool isDark, {double size = 32}) {
    final personColor = isDark ? '#FFFFFF' : '#0F172A';
    const gearColor = '#7BA6EE';

    return SvgPicture.string(
      '''<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="9" cy="6.5" r="3.5" fill="$personColor"/>
        <path d="M9 12C5.69 12 2 13.66 2 17V19H12.3C12.1 18.37 12 17.7 12 17C12 14.86 13.2 13.01 14.95 12.08C13.27 12.03 11.23 12 9 12Z" fill="$personColor"/>
        <path d="M17.5 13.2C17.2 13.2 16.9 13.25 16.6 13.35L16.2 12.35C16.1 12.15 15.9 12 15.65 12.05L14.7 12.35C14.45 12.45 14.3 12.7 14.35 12.95L14.55 13.95C14.25 14.15 14 14.4 13.8 14.7L12.8 14.5C12.55 14.45 12.3 14.6 12.2 14.85L11.9 15.8C11.85 16.05 12 16.25 12.2 16.35L13.2 16.75C13.15 17.05 13.15 17.35 13.2 17.65L12.2 18.05C12 18.15 11.85 18.35 11.9 18.6L12.2 19.55C12.3 19.8 12.55 19.95 12.8 19.9L13.8 19.7C14 20 14.25 20.25 14.55 20.45L14.35 21.45C14.3 21.7 14.45 21.95 14.7 22.05L15.65 22.35C15.9 22.4 16.1 22.25 16.2 22.05L16.6 21.05C16.9 21.15 17.2 21.2 17.5 21.2C17.8 21.2 18.1 21.15 18.4 21.05L18.8 22.05C18.9 22.25 19.1 22.4 19.35 22.35L20.3 22.05C20.55 21.95 20.7 21.7 20.65 21.45L20.45 20.45C20.75 20.25 21 20 21.2 19.7L22.2 19.9C22.45 19.95 22.7 19.8 22.8 19.55L23.1 18.6C23.15 18.35 23 18.15 22.8 18.05L21.8 17.65C21.85 17.35 21.85 17.05 21.8 16.75L22.8 16.35C23 16.25 23.15 16.05 23.1 15.8L22.8 14.85C22.7 14.6 22.45 14.45 22.2 14.5L21.2 14.7C21 14.4 20.75 14.15 20.45 13.95L20.65 12.95C20.7 12.7 20.55 12.45 20.3 12.35L19.35 12.05C19.1 12 18.9 12.15 18.8 12.35L18.4 13.35C18.1 13.25 17.8 13.2 17.5 13.2ZM17.5 15.4C18.5 15.4 19.3 16.2 19.3 17.2C19.3 18.2 18.5 19 17.5 19C16.5 19 15.7 18.2 15.7 17.2C15.7 16.2 16.5 15.4 17.5 15.4Z" fill="$gearColor"/>
      </svg>''',
      width: size,
      height: size,
    );
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
            Theme.of(context).brightness == Brightness.dark ||
            AppColors.isDarkMode;
        final double statusBarHeight = MediaQuery.of(context).padding.top;

        final Widget editorContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPresensiSvgIcon(isDark, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masukan Daftar Nama',
                        style: AppTypography.cardTitle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Satu nama per baris',
                        style: AppTypography.fileSize(
                          color: isDark ? const Color(0xFF71717A) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF7BA6EE).withValues(alpha: isDark ? 0.35 : 0.3),
                    ),
                  ),
                  child: Text(
                    '${_parsedNames.length} Siswa',
                    style: AppTypography.channelTag(
                      color: isDark ? const Color(0xFFA5C9FF) : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tulis atau tempel daftar nama siswa. Sistem akan otomatis mendata dan memproses ke laporan.',
              style: AppTypography.timestamp(
                color: isDark ? const Color(0xFF71717A) : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Divider(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
              height: 1,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _namesController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                cursorColor: isDark ? Colors.white : Colors.black,
                style: AppTypography.chatBody(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Contoh:\nBudi Santoso\nAni Wijaya\nCandra Pratama\nDewi Lestari",
                  hintStyle: AppTypography.chatBody(
                    color: isDark ? Colors.white24 : Colors.black26,
                    height: 1.6,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        );

        if (widget.isEmbedded) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _isSaving
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              ),
                            ),
                          )
                        : BouncyButton(
                            onTap: _saveMasterList,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : Colors.black,
                                shape: BoxShape.circle,
                                border: isDark
                                    ? Border.all(color: const Color(0xFF27272A), width: 1.2)
                                    : null,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: editorContent),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
          body: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width > 600 ? 600 : double.infinity,
              ),
              child: Stack(
                children: [
                  // Scrollable / Expandable Editor Body
                  Padding(
                    padding: EdgeInsets.only(
                      left: AppTypography.screenHorizontalMargin,
                      right: AppTypography.screenHorizontalMargin,
                      top: statusBarHeight + 68.0,
                      bottom: 24.0,
                    ),
                    child: editorContent,
                  ),

                  // Sticky Header Bar with Blur
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: 16.0,
                          sigmaY: 16.0,
                        ),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            AppTypography.screenHorizontalMargin,
                            statusBarHeight + 8.0,
                            AppTypography.screenHorizontalMargin,
                            10.0,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF09090B).withValues(alpha: 0.75)
                                : Colors.white.withValues(alpha: 0.85),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFF1F5F9),
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Tombol Back (<) - Frameless persis seperti di Catatan
                              BouncyButton(
                                onTap: () => Navigator.pop(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: isDark ? Colors.white : Colors.black87,
                                    size: 26,
                                  ),
                                ),
                              ),

                              // Judul Header
                              Text(
                                'Atur Presensi Siswa',
                                style: AppTypography.chatHeaderTitle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),

                              // Tombol Simpan Centang (✓) - Lingkaran Hitam persis di Catatan
                              _isSaving
                                  ? const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.2),
                                        ),
                                      ),
                                    )
                                  : BouncyButton(
                                      onTap: _saveMasterList,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF18181B) : Colors.black,
                                          shape: BoxShape.circle,
                                          border: isDark
                                              ? Border.all(color: const Color(0xFF27272A), width: 1.2)
                                              : null,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 22,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
