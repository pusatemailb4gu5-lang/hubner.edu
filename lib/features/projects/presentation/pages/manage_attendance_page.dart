import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';

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

  Color _getAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> avatarColors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
    ];
    return avatarColors[hash % avatarColors.length];
  }

  String _getInitials(String name) {
    final List<String> parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length > 1 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
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
    final Widget mainBody = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: const Color(0xFF1D4ED8), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Masukan Daftar Nama',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tulis atau tempel daftar nama siswa (satu nama per baris). Sistem akan memproses nama-nama tersebut.',
                      style: GoogleFonts.dmSans(fontSize: 12.3, color: Colors.black45, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: TextField(
                          controller: _namesController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: GoogleFonts.dmSans(fontSize: 14.7),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Contoh:\nBudi Santoso\nAni Wijaya\nCandra Pratama",
                            hintStyle: GoogleFonts.dmSans(fontSize: 14, color: Colors.black26),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!widget.isEmbedded) ...[
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    side: const BorderSide(color: const Color(0xFFCBD5E1), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(
                    'Kembali',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 15.2),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                onPressed: _isSaving ? null : _saveMasterList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Simpan Perubahan',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15.2),
                      ),
              ),
            ],
          ),
        ],
      ),
    );


    if (widget.isEmbedded) {
      return Container(
        color: Colors.transparent,
        child: mainBody,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Pengaturan Presensi Siswa',
          style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18.7),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedRainbowBackground(
        child: SafeArea(
          child: mainBody,
        ),
      ),
    );
  }
}
