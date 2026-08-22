import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class BacaMateriPage extends StatefulWidget {
  final String title;
  final String docName;
  final VoidCallback onCompleted;

  const BacaMateriPage({
    super.key,
    required this.title,
    required this.docName,
    required this.onCompleted,
  });

  @override
  State<BacaMateriPage> createState() => _BacaMateriPageState();
}

class _BacaMateriPageState extends State<BacaMateriPage> {
  bool _isMarkedAsRead = false;

  void _markAsRead() {
    setState(() {
      _isMarkedAsRead = true;
    });
    widget.onCompleted();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Materi berhasil ditandai selesai!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
          ),
        ),
        title: Text(
          'Materi Pembelajaran',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18.7,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 14, color: Color(0xFF0D9488)),
                          const SizedBox(width: 6),
                          Text(
                            'Modul Materi PDF',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.3,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 21.1,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 14, color: Colors.black45),
                        const SizedBox(width: 6),
                        Text(
                          widget.docName.startsWith('http') ? '📄 Berkas Materi (Google Drive)' : (widget.docName.isNotEmpty ? widget.docName : 'Berkas_Materi.pdf'),
                          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Document Reader Placeholder Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCCFBF1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0D9488), size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.docName.startsWith('http') ? 'Materi Pembelajaran (Google Drive)' : (widget.docName.isNotEmpty ? widget.docName : 'Modul Pembelajaran Elemen.pdf'),
                      style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan pelajari dokumen modul di atas hingga tuntas. Setelah selesai membaca, tekan tombol di bawah untuk menyelesaikan materi.',
                      style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(widget.docName);
                        if (uri != null && (widget.docName.startsWith('http://') || widget.docName.startsWith('https://'))) {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.inAppWebView);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tidak dapat membuka link tersebut.')),
                              );
                            }
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Nama Berkas: ${widget.docName}'),
                              backgroundColor: const Color(0xFF0D9488),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('Buka Dokumen Fullscreen', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Complete Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isMarkedAsRead ? null : _markAsRead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Tandai Sudah Dibaca & Selesai',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
