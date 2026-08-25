import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditCpPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String initialCp;
  final Color accentColor;

  const EditCpPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.initialCp,
    this.accentColor = const Color(0xFFD6A5F8),
  });

  @override
  State<EditCpPage> createState() => _EditCpPageState();
}

class _EditCpPageState extends State<EditCpPage> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCp);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCp() async {
    final text = _controller.text.trim();
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'cpDescription': text});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capaian Pembelajaran berhasil disimpan!'),
            backgroundColor: Color(0xFF0F172A),
          ),
        );
        Navigator.pop(context, text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan CP: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Clean Note Editor Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (Circle 44x44)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),

                  // Title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Capaian Pembelajaran',
                            style: AppTypography.cardTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (widget.projectName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.projectName,
                              style: AppTypography.timestamp(color: isDark ? Colors.white54 : Colors.black45),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Save Button (Icon Centang Hijau Tanpa Background & Tanpa Text)
                  _isSaving
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: ThreeDotsLoader(size: 5, bounceHeight: 3),
                          ),
                        )
                      : GestureDetector(
                          onTap: _saveCp,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF10B981),
                              size: 28,
                            ),
                          ),
                        ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
            ),

            // Note Editor Body Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Header Card with white circle icon & black icon like slider
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF6B3BA3) : const Color(0xFFD6A5F8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Target & Tujuan Kompetensi',
                                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tuliskan kompetensi pembelajaran dan materi inti fase kelas ini.',
                                  style: AppTypography.timestamp(color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Multi-line Text Editor
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      autofocus: true,
                      style: AppTypography.subtitle(color: isDark ? Colors.white : const Color(0xFF0F172A), height: 1.7),
                      decoration: InputDecoration(
                        hintText: 'Mulai menuliskan Capaian Pembelajaran (CP) di sini...\n\nContoh:\nPada akhir fase ini, peserta didik mampu memahami konsep dasar, menganalisis permasalahan, dan mempresentasikan hasil proyek secara mandiri maupun berkelompok.',
                        hintStyle: AppTypography.subtitle(color: isDark ? Colors.white30 : Colors.black38, height: 1.7),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
