import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
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
        backgroundColor: Color(0xFF16A34A),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top AppBar with 52x52px Circular Buttons (Matching Login Google Button standard)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTypography.screenHorizontalMargin,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button (<) - 52x52px
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
                        'Materi Pembelajaran',
                        style: AppTypography.chatHeaderTitle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      // Action Done Button (✓) - 52x52px
                      BouncyButton(
                        onTap: _isMarkedAsRead ? null : _markAsRead,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _isMarkedAsRead
                                ? const Color(0xFF16A34A)
                                : (isDark ? const Color(0xFF18181B) : Colors.black),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isMarkedAsRead
                                  ? const Color(0xFF16A34A)
                                  : (isDark ? const Color(0xFF27272A) : Colors.black),
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
                ),
                Divider(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                  height: 1,
                ),

                // Main Content Body (Typography matching NoteEditorPage)
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppTypography.pagePadding(top: 20.0, bottom: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0369A1).withValues(alpha: 0.3)
                                : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 14,
                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Modul Materi Pembelajaran',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title Text (Matching NoteEditorPage sizePageTitle: 28px bold)
                        Text(
                          widget.title,
                          style: AppTypography.pageTitle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Document metadata
                        Row(
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 15,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.docName.startsWith('http')
                                    ? 'Dokumen Google Drive'
                                    : (widget.docName.isNotEmpty ? widget.docName : 'Berkas_Materi.pdf'),
                                style: AppTypography.timestamp(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Document Reader Card Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0369A1).withValues(alpha: 0.25)
                                      : const Color(0xFFE0F2FE),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.docName.startsWith('http')
                                    ? 'Dokumen Modul (Google Drive)'
                                    : (widget.docName.isNotEmpty ? widget.docName : 'Modul Pembelajaran Elemen.pdf'),
                                style: AppTypography.cardTitle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Silakan pelajari dokumen modul di atas hingga tuntas. Setelah selesai membaca materi, tekan tombol simpan di kanan atas atau tombol di bawah untuk menyelesaikan tugas membaca ini.',
                                style: AppTypography.chatBody(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              // Open Document Button (Height 52px)
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.tryParse(widget.docName);
                                    if (uri != null && (widget.docName.startsWith('http://') || widget.docName.startsWith('https://'))) {
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.inAppWebView);
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Tidak dapat membuka tautan tersebut.')),
                                          );
                                        }
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Nama Berkas: ${widget.docName}'),
                                          backgroundColor: const Color(0xFF0284C7),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: Text(
                                    'Buka Dokumen Fullscreen',
                                    style: AppTypography.buttonLabel(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF0284C7) : const Color(0xFF0284C7),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Bottom Complete Button (Height 52px, Radius 32)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isMarkedAsRead ? null : _markAsRead,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF18181B) : Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF27272A) : Colors.black,
                                  width: 1.2,
                                ),
                              ),
                            ),
                            child: Text(
                              _isMarkedAsRead ? 'Selesai Dibaca ✓' : 'Tandai Sudah Dibaca & Selesai',
                              style: AppTypography.buttonLabel(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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
