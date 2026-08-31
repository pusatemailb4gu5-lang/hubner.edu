import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:hubner/main.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hubner/core/services/google_drive_service.dart';

class InAppFileViewerDialog extends StatefulWidget {
  final String fileName;
  final String? mimeType;
  final String fileUrl;
  final String? fileId;
  final String? uploaderName;
  final String? dateFormatted;
  final int fileSize;

  const InAppFileViewerDialog({
    super.key,
    required this.fileName,
    this.mimeType,
    required this.fileUrl,
    this.fileId,
    this.uploaderName,
    this.dateFormatted,
    this.fileSize = 0,
  });

  static void show(
    BuildContext context, {
    required String fileName,
    String? mimeType,
    required String fileUrl,
    String? fileId,
    String? uploaderName,
    String? dateFormatted,
    int fileSize = 0,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (ctx) => InAppFileViewerDialog(
        fileName: fileName,
        mimeType: mimeType,
        fileUrl: fileUrl,
        fileId: fileId,
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

  File? _localFile;
  Uint8List? _fileBytes;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isImage {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    final u = widget.fileUrl.toLowerCase();
    return m.contains('image') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        n.endsWith('.bmp') ||
        n.endsWith('.heic') ||
        n.endsWith('.svg') ||
        u.startsWith('data:image') ||
        u.startsWith('data:') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.webp') ||
        (u.contains('firebasestorage') && !u.contains('.pdf'));
  }

  bool get _isAudio {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    return m.contains('audio') ||
        n.endsWith('.mp3') ||
        n.endsWith('.wav') ||
        n.endsWith('.m4a') ||
        n.endsWith('.aac') ||
        n.endsWith('.ogg');
  }

  bool get _isText {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    return m.contains('text') ||
        n.endsWith('.txt') ||
        n.endsWith('.md') ||
        n.endsWith('.json') ||
        n.endsWith('.csv') ||
        n.endsWith('.log');
  }

  bool get _isPdf {
    final m = widget.mimeType?.toLowerCase() ?? '';
    final n = widget.fileName.toLowerCase();
    final u = widget.fileUrl.toLowerCase();
    return m.contains('pdf') ||
        n.endsWith('.pdf') ||
        u.contains('.pdf') ||
        u.startsWith('data:application/pdf');
  }

  @override
  void initState() {
    super.initState();
    _loadFile();
    if (_isAudio) {
      _initAudio();
    }
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawUrl = widget.fileUrl;

      // 0. Base64 Data URI (e.g. chat images or embedded documents)
      if (rawUrl.startsWith('data:') && rawUrl.contains(',')) {
        try {
          final b64 = rawUrl.split(',').last;
          final bytes = base64Decode(b64);
          if (bytes.isNotEmpty) {
            final docDir = await getApplicationDocumentsDirectory();
            final hubnerDir = Directory('${docDir.path}/Hubner_Documents');
            if (!hubnerDir.existsSync()) {
              await hubnerDir.create(recursive: true);
            }
            final safeName = widget.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
            final cachedFile = File('${hubnerDir.path}/$safeName');
            try {
              await cachedFile.writeAsBytes(bytes);
            } catch (_) {}

            if (mounted) {
              setState(() {
                _localFile = cachedFile;
                _fileBytes = bytes;
                _isLoading = false;
                if (_isText) _textContent = utf8.decode(bytes, allowMalformed: true);
              });
            }
            return;
          }
        } catch (e) {
          debugPrint('Base64 decode error: $e');
        }
      }

      // 1. Check if rawUrl is already a direct local file
      if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
        final f = File(rawUrl);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          if (mounted) {
            setState(() {
              _localFile = f;
              _fileBytes = bytes;
              _isLoading = false;
              if (_isText) _textContent = utf8.decode(bytes, allowMalformed: true);
            });
          }
          return;
        }
      }

      // 2. Determine effective Google Drive File ID
      final effectiveFileId = (widget.fileId != null && widget.fileId!.isNotEmpty)
          ? widget.fileId!
          : _extractFileId(rawUrl);

      // 3. Prepare local cache file path in Hubner_Documents folder
      final docDir = await getApplicationDocumentsDirectory();
      final hubnerDir = Directory('${docDir.path}/Hubner_Documents');
      if (!hubnerDir.existsSync()) {
        await hubnerDir.create(recursive: true);
      }
      final safeName = widget.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cacheFileName = effectiveFileId.isNotEmpty ? '${effectiveFileId}_$safeName' : safeName;
      final cachedFile = File('${hubnerDir.path}/$cacheFileName');

      if (await cachedFile.exists() && (await cachedFile.length()) > 0) {
        final bytes = await cachedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _localFile = cachedFile;
            _fileBytes = bytes;
            _isLoading = false;
            if (_isText) _textContent = utf8.decode(bytes, allowMalformed: true);
          });
        }
        return;
      }

      // 4. Download file bytes from Google Drive API or HTTP candidates
      final downloadedBytes = await _downloadFileBytes(effectiveFileId, rawUrl);

      if (downloadedBytes != null && downloadedBytes.isNotEmpty) {
        // Save local copy to file manager
        try {
          await cachedFile.writeAsBytes(downloadedBytes);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _localFile = cachedFile;
            _fileBytes = downloadedBytes;
            _isLoading = false;
            if (_isText) _textContent = utf8.decode(downloadedBytes, allowMalformed: true);
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mengunduh atau memuat pratinjau berkas.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<Uint8List?> _downloadFileBytes(String fileId, String rawUrl) async {
    // A. Attempt Google Drive API authenticated download
    if (fileId.isNotEmpty) {
      try {
        final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (account != null) {
          final auth = await account.authorizationClient.authorizeScopes([
            drive.DriveApi.driveFileScope,
            drive.DriveApi.driveReadonlyScope,
          ]);
          final api = GoogleDriveService.getDriveApi(auth.accessToken);
          final dynamic media = await api.files.get(
            fileId,
            downloadOptions: drive.DownloadOptions.fullMedia,
          );
          if (media is drive.Media) {
            final List<int> data = [];
            await for (final chunk in media.stream) {
              data.addAll(chunk);
            }
            if (data.isNotEmpty) {
              return Uint8List.fromList(data);
            }
          }
        }
      } catch (e) {
        debugPrint('Google Drive API download exception: $e');
      }
    }

    // B. Build HTTP Candidate URLs
    final List<String> candidates = [];
    if (fileId.isNotEmpty) {
      candidates.add('https://drive.usercontent.google.com/download?id=$fileId&export=download&authuser=0&confirm=t');
      candidates.add('https://drive.google.com/uc?export=download&id=$fileId&confirm=t');
      candidates.add('https://docs.google.com/uc?export=download&id=$fileId&confirm=t');
      candidates.add('https://lh3.googleusercontent.com/d/$fileId');
      candidates.add('https://drive.google.com/uc?export=download&id=$fileId');
      candidates.add('https://docs.google.com/uc?export=download&id=$fileId');
    }
    if (rawUrl.isNotEmpty && !candidates.contains(rawUrl)) {
      candidates.add(_resolveDownloadUrl(rawUrl));
      candidates.add(rawUrl);
    }

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };

    for (final url in candidates) {
      try {
        final uri = Uri.parse(url);
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 18));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final bytes = res.bodyBytes;
          final headStr = String.fromCharCodes(bytes.take(250)).toLowerCase();

          // Check if response is an HTML redirect/warning page instead of the actual file
          if (headStr.contains('<html') || headStr.contains('<!doctype')) {
            final htmlBody = utf8.decode(bytes, allowMalformed: true);

            // 1. Direct usercontent link inside html
            final userContentMatch = RegExp(r'https://drive\.usercontent\.google\.com/download\?[^"\s>]+').firstMatch(htmlBody);
            if (userContentMatch != null) {
              final directUrl = userContentMatch.group(0)!.replaceAll('&amp;', '&');
              final dRes = await http.get(Uri.parse(directUrl), headers: headers).timeout(const Duration(seconds: 20));
              if (dRes.statusCode == 200 && dRes.bodyBytes.isNotEmpty) {
                final dHead = String.fromCharCodes(dRes.bodyBytes.take(50)).toLowerCase();
                if (!dHead.contains('<html') && !dHead.contains('<!doctype')) {
                  return dRes.bodyBytes;
                }
              }
            }

            // 2. Form action with confirm token
            final formActionMatch = RegExp(r'action="([^"]+)"').firstMatch(htmlBody);
            final confirmMatch = RegExp(r'confirm=([0-9a-zA-Z_-]+)').firstMatch(htmlBody);
            final confirmToken = confirmMatch?.group(1);

            if (formActionMatch != null) {
              var actionUrl = formActionMatch.group(1)!.replaceAll('&amp;', '&');
              if (confirmToken != null && !actionUrl.contains('confirm=')) {
                actionUrl += '&confirm=$confirmToken';
              }
              final dRes = await http.get(Uri.parse(actionUrl), headers: headers).timeout(const Duration(seconds: 20));
              if (dRes.statusCode == 200 && dRes.bodyBytes.isNotEmpty) {
                final dHead = String.fromCharCodes(dRes.bodyBytes.take(50)).toLowerCase();
                if (!dHead.contains('<html') && !dHead.contains('<!doctype')) {
                  return dRes.bodyBytes;
                }
              }
            }

            // 3. Fallback confirm on drive.google.com
            if (confirmToken != null && fileId.isNotEmpty) {
              final confirmUrl = 'https://drive.google.com/uc?export=download&id=$fileId&confirm=$confirmToken';
              final dRes = await http.get(Uri.parse(confirmUrl), headers: headers).timeout(const Duration(seconds: 20));
              if (dRes.statusCode == 200 && dRes.bodyBytes.isNotEmpty) {
                final dHead = String.fromCharCodes(dRes.bodyBytes.take(50)).toLowerCase();
                if (!dHead.contains('<html') && !dHead.contains('<!doctype')) {
                  return dRes.bodyBytes;
                }
              }
            }
            continue;
          }

          // Valid file bytes
          return bytes;
        }
      } catch (e) {
        debugPrint('Candidate fetch error for $url: $e');
      }
    }

    return null;
  }

  String _extractFileId(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    final regFile = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
    final regId = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
    final regDoc = RegExp(r'/d/([a-zA-Z0-9_-]+)');

    final matchFile = regFile.firstMatch(rawUrl);
    final matchId = regId.firstMatch(rawUrl);
    final matchDoc = regDoc.firstMatch(rawUrl);

    if (matchFile != null) return matchFile.group(1)!;
    if (matchId != null) return matchId.group(1)!;
    if (matchDoc != null) return matchDoc.group(1)!;
    if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(rawUrl)) return rawUrl;
    return '';
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
        if (_localFile != null && await _localFile!.exists()) {
          await _audioPlayer!.play(DeviceFileSource(_localFile!.path));
        } else {
          await _audioPlayer!.play(UrlSource(_resolveDownloadUrl(widget.fileUrl)));
        }
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

  String _resolveDownloadUrl(String url) {
    if (url.isEmpty) return url;
    if (url.contains('drive.google.com') || url.contains('docs.google.com')) {
      final regFileD = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
      final matchFileD = regFileD.firstMatch(url);
      if (matchFileD != null) {
        final id = matchFileD.group(1);
        return 'https://drive.google.com/uc?export=download&id=$id';
      }
      final regIdParam = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      final matchId = regIdParam.firstMatch(url);
      if (matchId != null) {
        final id = matchId.group(1);
        return 'https://drive.google.com/uc?export=download&id=$id';
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = HubnerApp.themeNotifier.value == 'Gelap' || HubnerApp.themeNotifier.value == 'Hitam';

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
                          style: AppTypography.documentTitle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildMainContent(isDark),
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
                        style: AppTypography.buttonLabel(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final downloadUri = Uri.parse(widget.fileUrl);
                        if (await canLaunchUrl(downloadUri)) {
                          await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
                        } else {
                          final downloadUrl = _resolveDownloadUrl(widget.fileUrl);
                          final uri = Uri.parse(downloadUrl);
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Unduh',
                        style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981), // Hijau
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
    if (_isLoading) {
      return Container(
        height: 400,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2.8,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F52FC)),
            ),
            const SizedBox(height: 16),
            Text(
              _isPdf
                  ? 'Menyiapkan & memuat dokumen PDF...'
                  : (_isImage ? 'Memuat gambar...' : 'Mengunduh berkas ke File Manager...'),
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Menyalin ke penyimpanan lokal...',
              style: AppTypography.fileSize(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _fileBytes == null && _localFile == null) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat pratinjau berkas',
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'File dapat diunduh langsung menggunakan tombol di bawah.',
              textAlign: TextAlign.center,
              style: AppTypography.fileSize(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFile,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F52FC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      );
    }

    if (_isImage) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 460),
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
              child: _localFile != null
                  ? Image.file(
                      _localFile!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => _fileBytes != null
                          ? Image.memory(_fileBytes!, fit: BoxFit.contain)
                          : const SizedBox.shrink(),
                    )
                  : (_fileBytes != null
                      ? Image.memory(_fileBytes!, fit: BoxFit.contain)
                      : const SizedBox.shrink()),
            ),
          ),
        ),
      );
    }

    if (_isPdf) {
      return Container(
        height: 480,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _localFile != null
              ? SfPdfViewer.file(
                  _localFile!,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  canShowPaginationDialog: true,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    debugPrint('PDF file load failed: ${details.description}');
                  },
                )
              : (_fileBytes != null
                  ? SfPdfViewer.memory(
                      _fileBytes!,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      canShowPaginationDialog: true,
                      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                        debugPrint('PDF memory load failed: ${details.description}');
                      },
                    )
                  : const Center(child: Text('PDF tidak dapat dimuat'))),
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
                Icon(Icons.check_circle_outline_rounded, size: 16, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  _localFile != null ? 'Tersalin di File Manager lokal' : 'Akses publik aman & terenkripsi',
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
