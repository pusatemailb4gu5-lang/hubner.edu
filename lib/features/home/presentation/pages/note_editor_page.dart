import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar (Clean)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                      Text(
                        widget.noteId == null ? 'Catatan Baru' : 'Edit Catatan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21.1,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      _isSaving
                          ? const SizedBox(
                              width: 44,
                              height: 44,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: _saveNote,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),

                // Editor Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Title Textfield
                        TextField(
                          controller: _titleController,
                          maxLines: 1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 25.7,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Judul Catatan',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 25.7,
                              fontWeight: FontWeight.bold,
                              color: Colors.black26,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Content Textfield
                        TextField(
                          controller: _contentController,
                          maxLines: null,
                          style: GoogleFonts.dmSans(
                            fontSize: 17.6,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Mulai menulis catatan Anda di sini...',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 17.6,
                              color: Colors.black26,
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
