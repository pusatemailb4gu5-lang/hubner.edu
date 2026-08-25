import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:hubner/core/theme/app_typography.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  final String initialTitle;
  final String initialContent;

  const NoteEditorPage({
    super.key,
    required this.noteId,
    required this.initialTitle,
    required this.initialContent,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan kosong tidak dapat disimpan.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.noteId == null) {
        // Create new note
        await FirebaseFirestore.instance.collection('notes').add({
          'title': title,
          'content': content,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing note
        await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).update({
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan berhasil disimpan!'),
            backgroundColor: Colors.black87,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan catatan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Back (<): Dark sama seperti lonceng, Light putih border halus
                      BouncyButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                      Text(
                        widget.noteId == null ? 'Catatan Baru' : 'Edit Catatan',
                        style: AppTypography.chatHeaderTitle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      // Tombol Centang (✓): Dark sama seperti lonceng, Light warna hitam text/icon putih
                      _isSaving
                          ? SizedBox(
                              width: 42,
                              height: 42,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: const ThreeDotsLoader(),
                                ),
                              ),
                            )
                          : BouncyButton(
                              onTap: _saveNote,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : Colors.black,
                                    width: 1.2,
                                  ),
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
                Divider(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                  height: 1,
                ),

                // Editor Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppTypography.pagePadding(top: 20.0, bottom: 20.0),
                    child: Column(
                      children: [
                        // Title Textfield
                        TextField(
                          controller: _titleController,
                          maxLines: 1,
                          cursorColor: isDark ? Colors.white : Colors.black,
                          style: AppTypography.pageTitle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Judul Catatan',
                            hintStyle: AppTypography.pageTitle(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Content Textfield
                        TextField(
                          controller: _contentController,
                          maxLines: null,
                          cursorColor: isDark ? Colors.white : Colors.black,
                          style: AppTypography.chatBody(
                            color: isDark ? const Color(0xFFE2E8F0) : Colors.black87,
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Mulai menulis catatan Anda di sini...',
                            hintStyle: AppTypography.chatBody(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
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
        ),
      ),
    );
  }
}

class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool enableSquash;

  const BouncyButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.88,
    this.duration = const Duration(milliseconds: 130),
    this.enableSquash = true,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _squashX;
  late Animation<double> _squashY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.enableSquash
          ? const Duration(milliseconds: 380)
          : const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
        reverseCurve: widget.enableSquash ? Curves.elasticOut : Curves.easeOutCubic,
      ),
    );
    _squashX = Tween<double>(begin: 1.0, end: widget.enableSquash ? 1.05 : 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
        reverseCurve: widget.enableSquash ? Curves.elasticOut : Curves.easeOutCubic,
      ),
    );
    _squashY = Tween<double>(begin: 1.0, end: widget.enableSquash ? 0.92 : 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
        reverseCurve: widget.enableSquash ? Curves.elasticOut : Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _controller.forward();
      },
      onTapUp: (_) async {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: widget.enableSquash
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(_squashX.value, _squashY.value, 1.0),
                    child: child,
                  )
                : child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
