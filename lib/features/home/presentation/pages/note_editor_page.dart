import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
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
  late final ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  String? _currentNoteId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentNoteId = widget.noteId;
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _scrollController = ScrollController()
      ..addListener(() {
        _scrollOffsetNotifier.value = _scrollController.offset;
      });
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
      if (_currentNoteId == null) {
        // Create new note
        final docRef = await FirebaseFirestore.instance.collection('notes').add({
          'title': title.isNotEmpty ? title : 'Tanpa Judul',
          'content': content,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _currentNoteId = docRef.id;
        });
      } else {
        // Update existing note
        await FirebaseFirestore.instance.collection('notes').doc(_currentNoteId).update({
          'title': title.isNotEmpty ? title : 'Tanpa Judul',
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

  void _createNewNote() {
    setState(() {
      _currentNoteId = null;
      _titleController.clear();
      _contentController.clear();
    });
  }

  void _selectNote(String id, String title, String content) {
    setState(() {
      _currentNoteId = id;
      _titleController.text = title == 'Tanpa Judul' ? '' : title;
      _contentController.text = content;
    });
  }

  void _navigateToNotesList() {
    final bool isDark = AppColors.isDarkMode;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, _, _) => NotesListPage(
          isDark: isDark,
          selectedNoteId: _currentNoteId,
          onSelectNote: (id, title, content) {
            _selectNote(id, title, content);
          },
          onCreateNew: () {
            _createNewNote();
          },
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: Stack(
            children: [
              // Scrollable Editor Body
              SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: AppTypography.screenHorizontalMargin,
                  right: AppTypography.screenHorizontalMargin,
                  top: statusBarHeight + 68.0,
                  bottom: 30.0,
                ),
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

              // Sticky Glassmorphic Header Bar with Blur
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffsetNotifier,
                  builder: (context, scrollOffset, _) {
                    final double scrollProgress = (scrollOffset / 20.0).clamp(0.0, 1.0);
                    final double blurSigma = 20.0 * scrollProgress;

                    return ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: blurSigma > 0.1 ? blurSigma : 0.001,
                          sigmaY: blurSigma > 0.1 ? blurSigma : 0.001,
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
                                ? const Color(0xFF09090B).withValues(alpha: 0.65 * scrollProgress)
                                : Colors.white.withValues(alpha: 0.70 * scrollProgress),
                            border: Border(
                              bottom: BorderSide(
                                color: (isDark
                                        ? const Color(0xFF27272A)
                                        : const Color(0xFFF1F5F9))
                                    .withValues(alpha: 0.9 * scrollProgress),
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Tombol Back (<) - Frameless
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
                              Text(
                                'Catatan',
                                style: AppTypography.chatHeaderTitle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Tombol Menu Daftar Catatan - Frameless
                                  BouncyButton(
                                    onTap: _navigateToNotesList,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                      child: Icon(
                                        Icons.menu_rounded,
                                        color: isDark ? Colors.white : Colors.black87,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Tombol Centang (✓) Simpan - Lingkaran Hitam dengan Icon Putih
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
                                          onTap: _saveNote,
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halaman Daftar Catatan (Sticky Header with Blur, Search Bar, List Tanpa Card)
class NotesListPage extends StatefulWidget {
  final bool isDark;
  final String? selectedNoteId;
  final Function(String id, String title, String content) onSelectNote;
  final VoidCallback onCreateNew;

  const NotesListPage({
    super.key,
    required this.isDark,
    required this.selectedNoteId,
    required this.onSelectNote,
    required this.onCreateNew,
  });

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        _scrollOffsetNotifier.value = _scrollController.offset;
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Baru saja';
    DateTime? dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    }
    if (dt == null) return 'Baru saja';

    final now = DateTime.now();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$hour:$minute';
    }
    return '$day/$month $hour:$minute';
  }

  Future<void> _deleteNote(String noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Catatan?',
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus catatan ini?',
          style: TextStyle(
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: widget.isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('notes').doc(noteId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: Stack(
            children: [
              // List of Notes (Scrollable underneath Sticky Header)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notes')
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  final filteredDocs = allDocs.where((doc) {
                    if (_searchQuery.isEmpty) return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    final content = (data['content'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery) || content.contains(_searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: statusBarHeight + 130.0, left: 32, right: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada catatan yang cocok'
                                  : 'Belum ada catatan tersimpan',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      top: statusBarHeight + 124.0,
                      bottom: 24.0,
                    ),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final noteId = doc.id;
                      final title = (data['title'] ?? 'Tanpa Judul').toString();
                      final content = (data['content'] ?? '').toString();
                      final dateStr = _formatDate(data['updatedAt'] ?? data['createdAt']);
                      final bool isSelected = widget.selectedNoteId == noteId;

                      return InkWell(
                        onTap: () {
                          widget.onSelectNote(noteId, title, content);
                          Navigator.pop(context);
                        },
                        child: Container(
                          color: isSelected
                              ? (isDark ? const Color(0xFF1C1917) : const Color(0xFFF8FAFC))
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Baris 1: Judul Catatan & Tombol Hapus
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title.isNotEmpty ? title : 'Tanpa Judul',
                                      style: AppTypography.cardTitle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ).copyWith(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _deleteNote(noteId),
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3.0),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 19,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // Baris 2: Preview Isi (Lurus Sejajar) & Tanggal di Sebelah Kanan
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      content.isNotEmpty
                                          ? content.replaceAll('\n', ' ')
                                          : 'Tidak ada teks tambahan',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        fontSize: 13.0,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Sticky Glassmorphic Header Bar with Blur (Top Bar + Search Bar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffsetNotifier,
                  builder: (context, scrollOffset, _) {
                    final double scrollProgress = (scrollOffset / 20.0).clamp(0.0, 1.0);
                    final double blurSigma = 20.0 * scrollProgress;

                    return ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: blurSigma > 0.1 ? blurSigma : 0.001,
                          sigmaY: blurSigma > 0.1 ? blurSigma : 0.001,
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
                                ? const Color(0xFF09090B).withValues(alpha: 0.65 * scrollProgress)
                                : Colors.white.withValues(alpha: 0.70 * scrollProgress),
                            border: Border(
                              bottom: BorderSide(
                                color: (isDark
                                        ? const Color(0xFF27272A)
                                        : const Color(0xFFF1F5F9))
                                    .withValues(alpha: 0.9 * scrollProgress),
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Tombol Back (<) - Frameless
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
                                  Text(
                                    'Catatan',
                                    style: AppTypography.chatHeaderTitle(
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  // Tombol Buat Catatan Baru (+) - Lingkaran Hitam dengan Icon Putih
                                  BouncyButton(
                                    onTap: () {
                                      widget.onCreateNew();
                                      Navigator.pop(context);
                                    },
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
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Search Bar - Bentuk Round (Pill Shape)
                              Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) {
                                          setState(() {
                                            _searchQuery = val.trim().toLowerCase();
                                          });
                                        },
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Cari catatan...',
                                          hintStyle: TextStyle(
                                            color: isDark ? Colors.white30 : Colors.black26,
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
