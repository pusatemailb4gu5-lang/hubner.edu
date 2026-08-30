import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
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
  String? _currentNoteId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentNoteId = widget.noteId;
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
      MaterialPageRoute(
        builder: (ctx) => NotesListPage(
          isDark: isDark,
          selectedNoteId: _currentNoteId,
          onSelectNote: (id, title, content) {
            _selectNote(id, title, content);
          },
          onCreateNew: () {
            _createNewNote();
          },
        ),
      ),
    );
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTypography.screenHorizontalMargin,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Back (<) - 52x52px Standar Login
                      BouncyButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                        ),
                      ),
                      Text(
                        _currentNoteId == null ? 'Catatan Baru' : 'Edit Catatan',
                        style: AppTypography.chatHeaderTitle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tombol 3 Garis Horisontal (Buka Halaman Daftar Catatan) - 52x52px
                          BouncyButton(
                            onTap: _navigateToNotesList,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.menu_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tombol Centang (✓) Simpan - 52x52px
                          _isSaving
                              ? const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.2),
                                    ),
                                  ),
                                )
                              : BouncyButton(
                                  onTap: _saveNote,
                                  child: Container(
                                    width: 52,
                                    height: 52,
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
                                      size: 24,
                                    ),
                                  ),
                                ),
                        ],
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

/// Halaman Baru Daftar Catatan (Full Page, Tanpa Card, Dipisahkan Garis Divider, Ada Tombol Back)
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

  @override
  void dispose() {
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
      return 'Hari ini, $hour:$minute';
    }
    return '$day/$month/${dt.year} $hour:$minute';
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top AppBar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTypography.screenHorizontalMargin,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Back (<) untuk kembali ke buat catatan / editor
                      BouncyButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                        ),
                      ),
                      Text(
                        'Daftar Catatan',
                        style: AppTypography.chatHeaderTitle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      // Tombol Buat Catatan Baru (+)
                      BouncyButton(
                        onTap: () {
                          widget.onCreateNew();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : Colors.black,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 26,
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

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
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
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                ),

                // List of Notes (Tanpa Card, Hanya Dipisahkan dengan Garis Divider)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
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
                            padding: const EdgeInsets.all(32.0),
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, __) => Divider(
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
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title.isNotEmpty ? title : 'Tanpa Judul',
                                          style: AppTypography.cardTitle(
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ).copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (content.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            content,
                                            style: TextStyle(
                                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                              fontSize: 13.5,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                color: isDark ? Colors.white38 : Colors.black38,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Delete button
                                  GestureDetector(
                                    onTap: () => _deleteNote(noteId),
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 22,
                                        color: isDark ? Colors.white38 : Colors.black38,
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
