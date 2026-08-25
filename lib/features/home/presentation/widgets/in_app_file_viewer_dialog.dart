import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class InAppFileViewerDialog extends StatefulWidget {
  final String fileName;
  final String? mimeType;
  final String fileUrl;
  final String? uploaderName;
  final String? dateFormatted;
  final int fileSize;

  const InAppFileViewerDialog({
    super.key,
    required this.fileName,
    this.mimeType,
    required this.fileUrl,
    this.uploaderName,
    this.dateFormatted,
    this.fileSize = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String fileName,
    String? mimeType,
    required String fileUrl,
    String? uploaderName,
    String? dateFormatted,
    int fileSize = 0,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => InAppFileViewerDialog(
        fileName: fileName,
        mimeType: mimeType,
        fileUrl: fileUrl,
        uploaderName: uploaderName,
        dateFormatted: dateFormatted,
        fileSize: fileSize,
      ),
    );
  }

  @override
  State<InAppFileViewerDialog> createState() => _InAppFileViewerDialogState();
}

class _InAppFileViewerDialogState extends State<InAppFileViewerDialog> {
  AudioPlayer? _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoadingAudio = false;

  String? _textContent;
  bool _isLoadingText = false;

  bool get _isImage {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    return m.contains('image') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.webp') || n.endsWith('.gif');
  }

  bool get _isAudio {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    return m.contains('audio') || n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a') || n.endsWith('.aac') || n.endsWith('.ogg');
  }

  bool get _isText {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    return m.contains('text') || n.endsWith('.txt') || n.endsWith('.md') || n.endsWith('.json') || n.endsWith('.csv') || n.endsWith('.log');
  }

  bool get _isPdf {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    return m.contains('pdf') || n.endsWith('.pdf');
  }

  @override
  void initState() {
    super.initState();
    if (_isAudio) {
      _initAudio();
    } else if (_isText) {
      _loadTextContent();
    }
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _audioPlayer!.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer!.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _togglePlayAudio() async {
    if (_audioPlayer == null) return;
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer!.pause();
      } else {
        setState(() => _isLoadingAudio = true);
        await _audioPlayer!.play(UrlSource(widget.fileUrl));
        setState(() => _isLoadingAudio = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memutar file audio.')),
        );
      }
    }
  }

  Future<void> _loadTextContent() async {
    setState(() => _isLoadingText = true);
    try {
      final res = await http.get(Uri.parse(widget.fileUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _textContent = res.body;
            _isLoadingText = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingText = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingText = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isImage
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                          : _isPdf
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : _isAudio
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isImage
                          ? Icons.image_rounded
                          : _isPdf
                              ? Icons.picture_as_pdf_rounded
                              : _isAudio
                                  ? Icons.audiotrack_rounded
                                  : Icons.insert_drive_file_rounded,
                      color: _isImage
                          ? const Color(0xFF8B5CF6)
                          : _isPdf
                              ? const Color(0xFFEF4444)
                              : _isAudio
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.documentTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (widget.uploaderName != null && widget.uploaderName!.isNotEmpty) ...[
                              Text(
                                widget.uploaderName!,
                                style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black45),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white38 : Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.fileSize > 0) ...[
                              Text(
                                _formatBytes(widget.fileSize),
                                style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black45),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.dateFormatted != null && widget.dateFormatted!.isNotEmpty) ...[
                              Text(
                                widget.dateFormatted!,
                                style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black45),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Content Area
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildMainContent(isDark),
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.fileUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tautan berkas berhasil disalin!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'Salin Tautan',
                        style: AppTypography.channelTag(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(widget.fileUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Buka Berkas',
                        style: AppTypography.channelTag(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    if (_isImage) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.fileUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_rounded, size: 48, color: Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat pratinjau gambar',
                        style: AppTypography.timestamp(color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_isAudio) {
      final isPlaying = _playerState == PlayerState.playing;
      final maxDuration = _duration.inMilliseconds.toDouble();
      final currentPos = _position.inMilliseconds.toDouble().clamp(0.0, maxDuration > 0 ? maxDuration : 1.0);

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note_rounded, size: 36, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
                activeTrackColor: const Color(0xFF10B981),
                inactiveTrackColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                thumbColor: const Color(0xFF10B981),
              ),
              child: Slider(
                value: currentPos,
                max: maxDuration > 0 ? maxDuration : 1.0,
                onChanged: (val) {
                  _audioPlayer?.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: AppTypography.fileSize(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isLoadingAudio ? null : _togglePlayAudio,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isLoadingAudio
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isText) {
      if (_isLoadingText) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (_textContent != null && _textContent!.isNotEmpty) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 380),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              _textContent!,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                color: isDark ? const Color(0xFFC9D1D9) : const Color(0xFF24292F),
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    // Default File Preview Card
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _isPdf
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : const Color(0xFF3B82F6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              size: 34,
              color: _isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.fileName,
            textAlign: TextAlign.center,
            style: AppTypography.cardTitle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isPdf ? 'Dokumen Format PDF' : 'Berkas Repositori Hubner Edu',
            style: AppTypography.timestamp(color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Text(
                  'Akses publik aman & terenkripsi',
                  style: AppTypography.fileSize(color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
