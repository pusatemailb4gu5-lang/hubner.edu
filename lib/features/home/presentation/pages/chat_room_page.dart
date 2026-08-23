import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/services.dart';
// Animated Purple Micro Pattern Background
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'home_page.dart' show BouncyButton;

class ChatRoomPage extends StatefulWidget {
  final String discussionId;
  final String channelName;
  final String? projectId;
  final bool isEmbedded;
  final String? targetUserUid;
  final String? targetUserAvatar;
  final bool isPrivateDraft;

  const ChatRoomPage({
    super.key,
    required this.discussionId,
    required this.channelName,
    this.projectId,
    this.isEmbedded = false,
    this.targetUserUid,
    this.targetUserAvatar,
    this.isPrivateDraft = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late String _currentDiscussionId;
  late bool _isDraft;

  final Set<String> _expandedMessageIds = {};
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _discussionMembers = [];
  List<Map<String, dynamic>> _filteredMentionMembers = [];
  bool _isLoadingMembers = false;
  bool _showMentionPopup = false;
  String _currentUserName = '';
  String _userRole = 'siswa';
  String _currentUserUid = '';
  String? _lastPlayedMessageId;
  int _lastMessageCount = -1; // Track for smart scroll
  bool _initialScrollDone = false;
  
  // Mention tracking: list of message doc IDs where current user is mentioned
  List<String> _mentionMessageIds = [];
  int _unreadMentionCount = 0;
  final Map<String, GlobalKey> _messageKeys = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _replyingToMessage;
  String? _editingMessageId;
  final FocusNode _inputFocusNode = FocusNode();
  bool _showScrollToBottom = false;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final bool shouldShow = (maxScroll - currentScroll) > 80;
    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDiscussionId = widget.discussionId;
    _isDraft = widget.isPrivateDraft || widget.discussionId.isEmpty;
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _loadCurrentUserName();
  }

  void _loadCurrentUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      if (mounted) {
        setState(() {
          _currentUserName = doc.data()?['name'] ?? '';
          _currentUserUid = uid;
          _userRole = (doc.data()?['role'] as String? ?? 'siswa').toLowerCase();
        });
      }
    }
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.baseOffset < 0) return;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final words = textBeforeCursor.split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last : '';

    if (lastWord.startsWith('@')) {
      final query = lastWord.substring(1).toLowerCase();
      setState(() {
        // Filter out self from mention list
        final List<Map<String, dynamic>> matches = _discussionMembers.where((m) {
          if (m['uid'] == _currentUserUid) return false; // Cannot mention yourself
          final name = (m['name'] as String).toLowerCase();
          final username = (m['userId'] as String).toLowerCase();
          return name.contains(query) || username.contains(query);
        }).toList();

        if (query.isEmpty || 'all'.contains(query)) {
          matches.insert(0, {
            'uid': 'all',
            'name': 'Semua Orang',
            'userId': 'all',
            'avatar': 'assets/icon_pack/chat/chat_1.png',
          });
        }

        _filteredMentionMembers = matches;
        _showMentionPopup = matches.isNotEmpty;
      });
    } else {
      if (_showMentionPopup) {
        setState(() {
          _showMentionPopup = false;
        });
      }
    }
  }

  void _selectMention(Map<String, dynamic> member) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.baseOffset < 0) return;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);
    
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    if (lastAtIndex < 0) return;

    final mentionText = member['uid'] == 'all' ? '@all ' : '@${member['name']} ';
    final newText = text.substring(0, lastAtIndex) + mentionText + textAfterCursor;
    
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lastAtIndex + mentionText.length),
    );

    setState(() {
      _showMentionPopup = false;
    });
  }

  void _loadDiscussionMembersOnce(List<String> memberUids) async {
    if (_discussionMembers.isNotEmpty || _isLoadingMembers || memberUids.isEmpty) return;
    _isLoadingMembers = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberUids)
          .get();
      if (mounted) {
        setState(() {
          _discussionMembers = snap.docs.map((d) => {
            'uid': d.id,
            'name': d.data()['name'] ?? 'User',
            'userId': d.data()['userId'] ?? '',
            'avatar': d.data()['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
          }).toList();
        });
      }
    } catch (e) {
      // ignore
    } finally {
      _isLoadingMembers = false;
    }
  }

  List<InlineSpan> _buildMessageSpans(String text, String currentUserName, BuildContext context, bool isMe) {
    final List<InlineSpan> spans = [];
    // Match @name (allowing letters, digits, spaces, underscores)
    final RegExp mentionRegex = RegExp(r'@(?:all|[A-Za-z0-9_]+(?: [A-Za-z0-9_]+)*)');
    
    int lastIndex = 0;
    final matches = mentionRegex.allMatches(text);
    for (final match in matches) {
      if (match.start > lastIndex) {
        // Regular text before mention
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
        ));
      }
      
      final mention = match.group(0)!;
      final bool isMentionAll = mention.toLowerCase() == '@all';
      final bool isMeMentioned = isMentionAll || 
          (currentUserName.isNotEmpty && 
           mention.substring(1).trim().toLowerCase() == currentUserName.toLowerCase());
      
      // Only highlight the @name part — no background block, just colored text
      spans.add(TextSpan(
        text: mention,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          // Pastel purple for mentions that include you; subtle purple for others
          color: isMeMentioned
              ? const Color(0xFFB57BEE) // vibrant pastel purple for self-mention
              : const Color(0xFFAF8FD4), // soft muted purple for other mentions
        ),
      ));
      
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
      ));
    }
    
    return spans;
  }

  Future<void> _showFolderSelectorDialog(String projectId) async {
    try {
      try {
        await GoogleSignIn.instance.initialize(
          clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
          serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
        );
      } catch (_) {
        // Safe to ignore if already initialized
      }

      GoogleSignInAccount? account;

      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt != null) {
        account = await attempt;
      }
      if (account == null) {
        account = await GoogleSignIn.instance.authenticate();
      }
      if (account == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: ThreeDotsLoader()),
      );

      final auth = await account.authorizationClient.authorizeScopes([drive.DriveApi.driveFileScope]);
      final accessToken = auth.accessToken;

      final api = GoogleDriveService.getDriveApi(accessToken);
      final list = await api.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      final List<drive.File> folders = list.files ?? [];

      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Folder Google Drive Kelas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final folderNameController = TextEditingController();
                        final newFolderName = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text('Buat Folder Baru', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                            content: TextField(
                              controller: folderNameController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Nama Folder',
                                hintStyle: GoogleFonts.dmSans(color: Colors.black26),
                              ),
                              style: GoogleFonts.dmSans(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, folderNameController.text.trim()),
                                child: Text('Buat', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );

                        if (newFolderName != null && newFolderName.isNotEmpty) {
                          Navigator.pop(context); // Close bottom sheet
                          
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: ThreeDotsLoader()),
                          );

                          try {
                            final folderId = await GoogleDriveService.createClassroomFolder(accessToken, newFolderName);
                            
                            // Save to Firestore
                            await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
                              'driveFolderId': folderId,
                              'driveFolderUrl': 'https://drive.google.com/drive/folders/$folderId',
                              'driveAccessToken': accessToken,
                              'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
                            });

                            if (!mounted) return;
                            Navigator.pop(context); // Close loader

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Berhasil menghubungkan folder baru: $newFolderName!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context); // Close loader
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal membuat folder: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: Text('Buat Folder Baru', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: folders.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada folder ditemukan di Google Drive.',
                                style: GoogleFonts.dmSans(color: Colors.black38, fontSize: 13.5),
                              ),
                            )
                          : ListView.separated(
                              itemCount: folders.length,
                              separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                return ListTile(
                                  leading: const Icon(Icons.folder, color: Color(0xFFF59E0B)),
                                  title: Text(
                                    folder.name ?? 'Folder Tanpa Nama',
                                    style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w500),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, size: 18),
                                  onTap: () async {
                                    Navigator.pop(context); // Close bottom sheet
                                    
                                    if (!mounted) return;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(child: ThreeDotsLoader()),
                                    );

                                    try {
                                      await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
                                        'driveFolderId': folder.id,
                                        'driveFolderUrl': 'https://drive.google.com/drive/folders/${folder.id}',
                                        'driveAccessToken': accessToken,
                                        'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
                                      });

                                      if (!mounted) return;
                                      Navigator.pop(context); // Close loader

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Berhasil menghubungkan ke folder: ${folder.name}!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      Navigator.pop(context); // Close loader
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal menghubungkan folder: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  
  Future<Uint8List> _compressImageToMax200Kb(Uint8List rawBytes) async {
    const int maxSizeBytes = 200 * 1024; // 200 KB
    if (rawBytes.lengthInBytes <= maxSizeBytes) {
      return rawBytes;
    }

    try {
      final img.Image? decodedNullable = img.decodeImage(rawBytes);
      if (decodedNullable == null) return rawBytes;
      img.Image currentImg = decodedNullable;

      // Resize if very large
      if (currentImg.width > 1280 || currentImg.height > 1280) {
        currentImg = img.copyResize(
          currentImg,
          width: currentImg.width > currentImg.height ? 1280 : null,
          height: currentImg.height >= currentImg.width ? 1280 : null,
        );
      }

      int quality = 85;
      Uint8List compressed = Uint8List.fromList(img.encodeJpg(currentImg, quality: quality));

      while (compressed.lengthInBytes > maxSizeBytes && quality > 15) {
        quality -= 15;
        if (quality <= 40 && (currentImg.width > 800 || currentImg.height > 800)) {
          currentImg = img.copyResize(
            currentImg,
            width: (currentImg.width * 0.75).round(),
            height: (currentImg.height * 0.75).round(),
          );
        }
        compressed = Uint8List.fromList(img.encodeJpg(currentImg, quality: quality));
      }

      return compressed;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return rawBytes;
    }
  }

  void _showDriveUploadErrorDialog(BuildContext context, String folderUrl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Google Drive Belum Tersambung',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Fitur kirim gambar memerlukan Google Drive Classroom yang aktif.',
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Tutup', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
          ),
          if (folderUrl.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final uri = Uri.parse(folderUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('Buka Folder', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    String pId = widget.projectId ?? '';
    if (pId.isEmpty && !_isDraft && _currentDiscussionId.isNotEmpty) {
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).get();
      if (discDoc.exists) {
        pId = discDoc.data()?['projectId'] as String? ?? '';
      }
    }

    if (pId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitur kirim gambar tidak tersedia pada obrolan yang tidak terhubung ke kelas.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('projects').doc(pId).get();
    final driveFolderId = doc.data()?['driveFolderId'] as String?;
    final driveAccessToken = doc.data()?['driveAccessToken'] as String?;
    final driveFolderUrl = doc.data()?['driveFolderUrl'] as String? ?? (driveFolderId != null ? 'https://drive.google.com/drive/folders/$driveFolderId' : '');

    // Jika akun belum terhubung ke folder google drive maka fitur kirim gambar tidak berfungsi
    if (driveFolderId == null || driveFolderId.isEmpty || driveAccessToken == null || driveAccessToken.isEmpty) {
      if (mounted) {
        if (driveFolderUrl.isNotEmpty) {
          _showDriveUploadErrorDialog(context, driveFolderUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fitur kirim gambar tidak berfungsi karena classroom ini belum terhubung ke folder Google Drive.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      return;
    }

    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: ThreeDotsLoader()),
      );

      Uint8List rawBytes;
      if (kIsWeb) {
        rawBytes = pickedFile.bytes!;
      } else {
        rawBytes = await File(pickedFile.path!).readAsBytes();
      }

      // Kompresi data gambar hingga maksimal 200KB
      final Uint8List compressedBytes = await _compressImageToMax200Kb(rawBytes);

      final uploadResult = await GoogleDriveService.uploadFile(
        accessToken: driveAccessToken,
        folderId: driveFolderId,
        fileName: pickedFile.name.endsWith('.jpg') || pickedFile.name.endsWith('.jpeg')
            ? pickedFile.name
            : '${pickedFile.name.split('.').first}.jpg',
        bytes: compressedBytes,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'User';
      final senderAvatar = userDoc.data()?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

      // If draft private chat, create discussion doc in Firestore now!
      if (_isDraft || _currentDiscussionId.isEmpty) {
        final newDoc = await FirebaseFirestore.instance.collection('discussions').add({
          'channel': '@${widget.channelName.toLowerCase().replaceAll(' ', '')}',
          'title': widget.channelName,
          'avatar': widget.targetUserAvatar ?? 'assets/icon_pack/avatar/sma_1.png',
          'isPrivate': true,
          'memberUids': [user.uid, widget.targetUserUid ?? ''],
          'lastMessage': '$senderName mengirim gambar',
          'time': 'Sekarang',
          'createdAt': FieldValue.serverTimestamp(),
          'colorIndex': Random().nextInt(5),
        });
        _currentDiscussionId = newDoc.id;
        _isDraft = false;
        if (mounted) setState(() {});
      }

      // Send message with image URL
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(_currentDiscussionId)
          .collection('messages')
          .add({
        'sender': senderName,
        'senderUid': user.uid,
        'avatar': senderAvatar,
        'message': '[Gambar Lampiran]',
        'imageUrl': uploadResult['directLink']!,
        'time': FieldValue.serverTimestamp(),
        if (_replyingToMessage != null) ...{
          'replyToSender': _replyingToMessage!['sender'],
          'replyToText': _replyingToMessage!['message'],
          'replyToImageUrl': _replyingToMessage!['imageUrl'] ?? '',
        },
      });

      if (_replyingToMessage != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      // Update last message in discussion
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).get();
      final memberUids = List<String>.from(discDoc.data()?['memberUids'] ?? []);

      final Map<String, dynamic> updates = {
        'lastMessage': '$senderName mengirim gambar',
        'time': _formatCurrentTime(),
        'hasMessages': true,
        'hiddenForUids': [],
        'clearedByUids': [],
      };
      for (var mUid in memberUids) {
        if (mUid != user.uid) {
          updates['unreadCounts.$mUid'] = FieldValue.increment(1);
        }
      }
      await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).update(updates);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim gambar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_editingMessageId != null) {
      final editId = _editingMessageId!;
      _messageController.clear();
      setState(() {
        _editingMessageId = null;
      });

      try {
        await FirebaseFirestore.instance
            .collection('discussions')
            .doc(_currentDiscussionId)
            .collection('messages')
            .doc(editId)
            .update({
          'message': text,
          'isEdited': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesan berhasil diperbarui!'), duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui pesan: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
      return;
    }

    _messageController.clear();

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'User';
      final senderAvatar = userDoc.data()?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

      // If draft private chat, create discussion doc in Firestore now!
      if (_isDraft || _currentDiscussionId.isEmpty) {
        final newDoc = await FirebaseFirestore.instance.collection('discussions').add({
          'channel': '@${widget.channelName.toLowerCase().replaceAll(' ', '')}',
          'title': widget.channelName,
          'avatar': widget.targetUserAvatar ?? 'assets/icon_pack/avatar/sma_1.png',
          'isPrivate': true,
          'memberUids': [user.uid, widget.targetUserUid ?? ''],
          'lastMessage': '$senderName: $text',
          'time': 'Sekarang',
          'createdAt': FieldValue.serverTimestamp(),
          'colorIndex': Random().nextInt(5),
        });
        _currentDiscussionId = newDoc.id;
        _isDraft = false;
        if (mounted) setState(() {});
      }

      // 1. Add message to discussions subcollection
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(_currentDiscussionId)
          .collection('messages')
          .add({
        'sender': senderName,
        'senderUid': user.uid,
        'avatar': senderAvatar,
        'message': text,
        'time': FieldValue.serverTimestamp(),
        if (_replyingToMessage != null) ...{
          'replyToSender': _replyingToMessage!['sender'],
          'replyToText': _replyingToMessage!['message'],
          'replyToImageUrl': _replyingToMessage!['imageUrl'] ?? '',
        },
      });

      if (_replyingToMessage != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      // 2. Update discussion document's last message info and increment unread counts
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).get();
      final memberUids = List<String>.from(discDoc.data()?['memberUids'] ?? []);
      
      final Map<String, dynamic> updates = {
        'lastMessage': '$senderName: $text',
        'time': _formatCurrentTime(),
        'hasMessages': true,
        'hiddenForUids': [],
        'clearedByUids': [],
      };
      
      for (var mUid in memberUids) {
        if (mUid != user.uid) {
          updates['unreadCounts.$mUid'] = FieldValue.increment(1);
        }
      }

      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(_currentDiscussionId)
          .update(updates);

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pesan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }



  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _inputFocusNode.dispose();
    _audioPlayer.dispose();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProjectMembers(String projectId) async {
    try {
      final Set<String> allMemberUidSet = {};

      // 1. Get users belonging to this project
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('projectIds', arrayContains: projectId)
          .get();
      for (var doc in usersQuery.docs) {
        allMemberUidSet.add(doc.id);
      }

      // 2. Also get discussion's own members
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).get();
      if (discDoc.exists) {
        final discMemberUids = List<String>.from(discDoc.data()?['memberUids'] ?? []);
        allMemberUidSet.addAll(discMemberUids);
      }

      if (allMemberUidSet.isEmpty) return [];

      final List<String> allMemberUids = allMemberUidSet.toList();
      final List<Map<String, dynamic>> members = [];
      const int chunkLimit = 10;
      for (var i = 0; i < allMemberUids.length; i += chunkLimit) {
        final chunk = allMemberUids.sublist(
          i,
          i + chunkLimit > allMemberUids.length ? allMemberUids.length : i + chunkLimit,
        );
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var d in usersSnap.docs) {
          members.add({
            'uid': d.id,
            'name': d.data()['name'] ?? 'User',
            'userId': d.data()['userId'] ?? '',
            'avatar': d.data()['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
          });
        }
      }
      return members;
    } catch (e) {
      debugPrint('Error loading project members: $e');
      return [];
    }
  }

  void _openEditDiscussionSettings(BuildContext context, Map<String, dynamic> discData) async {
    final projectId = discData['projectId'] as String? ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: ThreeDotsLoader(),
      ),
    );

    final members = await _loadProjectMembers(projectId);
    
    if (context.mounted) {
      Navigator.pop(context); // close loading indicator
      _showEditDiscussionDialog(context, discData, members);
    }
  }

  void _showEditDiscussionDialog(BuildContext context, Map<String, dynamic> discData, List<Map<String, dynamic>> projectMembers) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDark = AppColors.isDarkMode;
    final screenHeight = MediaQuery.of(context).size.height;

    final channelController = TextEditingController(text: (discData['channel'] ?? '').toString().replaceAll('#', ''));
    final titleController = TextEditingController(text: discData['title'] ?? '');
    
    // Accurate avatar synchronization
    final String currentAvatarInDoc = (discData['avatar'] ?? '').toString();
    bool isDefaultGroupIcon = currentAvatarInDoc.isEmpty || currentAvatarInDoc == 'default_group';
    String selectedAvatar = isDefaultGroupIcon ? 'assets/icon_pack/chat/chat_1.png' : currentAvatarInDoc;
    bool showAvatarSlider = false;

    List<String> selectedMemberUids = List<String>.from(discData['memberUids'] ?? []);
    List<String> adminUids = List<String>.from(discData['adminUids'] ?? []);
    final String creatorUid = discData['creatorUid'] ?? '';
    if (creatorUid.isNotEmpty && !adminUids.contains(creatorUid)) {
      adminUids.add(creatorUid);
    }

    bool canAllMembersEditInfo = discData['canAllMembersEditInfo'] ?? true;
    bool canAllMembersInvite = discData['canAllMembersInvite'] ?? true;

    final String projectId = discData['projectId'] as String? ?? '';
    final projectGuru = projectMembers.firstWhere(
      (m) => m['role'] == 'guru',
      orElse: () => <String, dynamic>{},
    );
    final String projectGuruUid = projectGuru['uid'] as String? ?? '';
    final bool isUserAdmin = adminUids.contains(currentUid) || _userRole == 'guru' || (currentUid == projectGuruUid);
    final bool canEditGroupInfo = isUserAdmin || canAllMembersEditInfo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            // Helper to build stacked avatars
            Widget buildStackedAvatars(List<Map<String, dynamic>> members) {
              if (members.isEmpty) return const SizedBox.shrink();
              final int maxDisplay = 4;
              final int displayCount = members.length > maxDisplay ? maxDisplay : members.length;
              final int remaining = members.length - displayCount;
              const double avatarSize = 38.0;
              const double overlap = 26.0;

              return SizedBox(
                height: avatarSize,
                width: (displayCount + (remaining > 0 ? 1 : 0)) * overlap + 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < displayCount; i++)
                      Positioned(
                        left: i * overlap,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                          ),
                          child: ClipOval(
                            child: Transform.scale(
                              scale: 1.35,
                              child: Image.asset(
                                members[i]['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (remaining > 0)
                      Positioned(
                        left: displayCount * overlap,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF181E2C),
                          ),
                          child: Center(
                            child: Text(
                              '+$remaining',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }

            // Manage Members Modal
            void openManageMembersModal() {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (mCtx) {
                  return StatefulBuilder(
                    builder: (mCtx, setInnerState) {
                      final activeMembers = projectMembers
                          .where((m) => selectedMemberUids.contains(m['uid']))
                          .toList();
                      final availableToAdd = projectMembers
                          .where((m) => !selectedMemberUids.contains(m['uid']))
                          .toList();

                      return Container(
                        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
                        padding: EdgeInsets.only(
                          top: 16,
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 44,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kelola Anggota (${activeMembers.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                // Tambah Anggota (if admin or canAllMembersInvite)
                                if (isUserAdmin || canAllMembersInvite)
                                  if (availableToAdd.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                          ),
                                          builder: (addCtx) {
                                            return Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Tambah Anggota dari Kelas',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Flexible(
                                                    child: ListView.separated(
                                                      shrinkWrap: true,
                                                      itemCount: availableToAdd.length,
                                                      separatorBuilder: (_, __) => Divider(
                                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                      ),
                                                      itemBuilder: (aCtx, aIdx) {
                                                        final cand = availableToAdd[aIdx];
                                                        final candUid = cand['uid'] as String;
                                                        final candName = cand['name'] ?? 'User';
                                                        final candAvatar = cand['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

                                                        return ListTile(
                                                          contentPadding: EdgeInsets.zero,
                                                          leading: ClipOval(
                                                            child: Image.asset(candAvatar, width: 38, height: 38, fit: BoxFit.cover),
                                                          ),
                                                          title: Text(
                                                            candName,
                                                            style: GoogleFonts.plusJakartaSans(
                                                              fontSize: 13.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: isDark ? Colors.white : Colors.black87,
                                                            ),
                                                          ),
                                                          trailing: ElevatedButton(
                                                            onPressed: () {
                                                              Navigator.pop(addCtx);
                                                              setInnerState(() {
                                                                selectedMemberUids.add(candUid);
                                                              });
                                                              setModalState(() {});
                                                            },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: const Color(0xFF0F766E),
                                                              foregroundColor: Colors.white,
                                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                            ),
                                                            child: const Text('Tambah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.person_add_rounded, size: 15, color: Color(0xFF0F766E)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '+ Tambah',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F766E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ListView.separated(
                                itemCount: activeMembers.length,
                                separatorBuilder: (_, __) => Divider(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                  height: 1,
                                  indent: 56,
                                ),
                                itemBuilder: (ctx, i) {
                                  final m = activeMembers[i];
                                  final mUid = m['uid'] as String;
                                  final name = m['name'] ?? 'User';
                                  final avatarPath = m['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';
                                  final bool isGuru = (m['role'] == 'guru') || (mUid == projectGuruUid);
                                  final bool isCreator = mUid == creatorUid;
                                  final bool isAdmin = isGuru || isCreator || adminUids.contains(mUid);

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      ),
                                      child: ClipOval(
                                        child: Transform.scale(
                                          scale: 1.35,
                                          child: Image.asset(avatarPath, fit: BoxFit.cover),
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isGuru) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Guru',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F766E),
                                              ),
                                            ),
                                          ),
                                        ] else if (isAdmin) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Admin',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      isGuru
                                          ? 'Admin Utama (Guru)'
                                          : (isAdmin ? 'Admin Grup' : 'Anggota'),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Admin management options (only by Admin)
                                        if (isUserAdmin && !isGuru && !isCreator) ...[
                                          TextButton(
                                            onPressed: () {
                                              setInnerState(() {
                                                if (adminUids.contains(mUid)) {
                                                  if (adminUids.length > 1) {
                                                    adminUids.remove(mUid);
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Minimal 1 admin di dalam grup.')),
                                                    );
                                                  }
                                                } else {
                                                  adminUids.add(mUid);
                                                }
                                              });
                                              setModalState(() {});
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              adminUids.contains(mUid) ? 'Lepas Admin' : 'Jadikan Admin',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: adminUids.contains(mUid)
                                                    ? const Color(0xFFE11D48)
                                                    : const Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              setInnerState(() {
                                                selectedMemberUids.remove(mUid);
                                                adminUids.remove(mUid);
                                              });
                                              setModalState(() {});
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            }

            final activeSelectedMembers = projectMembers
                .where((m) => selectedMemberUids.contains(m['uid']))
                .toList();

            return Container(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            BouncyButton(
                              onTap: () => Navigator.pop(modalCtx),
                              child: Container(
                                width: 42,
                                height: 42,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                            Text(
                              'Edit Diskusi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        // Simpan Perubahan button
                        GestureDetector(
                          onTap: () async {
                            final chan = channelController.text.trim();
                            final ttl = titleController.text.trim();
                            if (ttl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nama diskusi wajib diisi.')),
                              );
                              return;
                            }

                            final List<String> finalMembers = List<String>.from(selectedMemberUids);
                            if (!finalMembers.contains(currentUid)) {
                              finalMembers.add(currentUid);
                            }

                            final List<String> finalAdminUids = List<String>.from(adminUids);
                            if (!finalAdminUids.contains(currentUid) && isUserAdmin) {
                              finalAdminUids.add(currentUid);
                            }
                            if (projectGuruUid.isNotEmpty && !finalAdminUids.contains(projectGuruUid)) {
                              finalAdminUids.add(projectGuruUid);
                            }

                            final cleanTitle = ttl.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
                            final channelName = chan.isNotEmpty
                                ? (chan.startsWith('#') ? chan : '#$chan')
                                : '#${cleanTitle.isNotEmpty ? cleanTitle : 'diskusi'}';

                            await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).update({
                              'channel': channelName,
                              'title': ttl,
                              'avatar': isDefaultGroupIcon ? '' : selectedAvatar,
                              'memberUids': finalMembers,
                              'adminUids': finalAdminUids,
                              'canAllMembersEditInfo': canAllMembersEditInfo,
                              'canAllMembersInvite': canAllMembersInvite,
                            });

                            if (context.mounted) {
                              Navigator.pop(modalCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pengaturan diskusi berhasil diperbarui!')),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Simpan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BODY (Same as Step 2 of WhatsApp-Style Creation)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Layout 35% - 65% (Avatar + Title)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Kiri: Avatar (Tap to toggle slider)
                              GestureDetector(
                                onTap: canEditGroupInfo
                                    ? () {
                                        setModalState(() {
                                          showAvatarSlider = !showAvatarSlider;
                                        });
                                      }
                                    : null,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: isDefaultGroupIcon
                                          ? const Center(
                                              child: Icon(
                                                Icons.groups_rounded,
                                                color: Color(0xFF0F766E),
                                                size: 38,
                                              ),
                                            )
                                          : ClipOval(
                                              child: Transform.scale(
                                                scale: 1.35,
                                                child: Image.asset(selectedAvatar, fit: BoxFit.cover),
                                              ),
                                            ),
                                    ),
                                    if (canEditGroupInfo)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white : Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            showAvatarSlider ? Icons.check_rounded : Icons.camera_alt_rounded,
                                            size: 12,
                                            color: isDark ? Colors.black : Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Kanan: Nama Diskusi
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nama Diskusi',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: titleController,
                                      enabled: canEditGroupInfo,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Nama Diskusi (Wajib)',
                                        hintStyle: GoogleFonts.dmSans(
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontSize: 13.5,
                                        ),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: BorderSide(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: BorderSide(
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Frameless 50% Translucent Avatar Slider
                          if (showAvatarSlider && canEditGroupInfo) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.50)
                                        : Colors.white.withValues(alpha: 0.50),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.08),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    itemCount: 11,
                                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                                    itemBuilder: (ctx, i) {
                                      final isDef = i == 0;
                                      final avatarP = isDef ? '' : 'assets/icon_pack/chat/chat_$i.png';
                                      final isSel = isDef
                                          ? isDefaultGroupIcon
                                          : (!isDefaultGroupIcon && selectedAvatar == avatarP);

                                      return GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            if (isDef) {
                                              isDefaultGroupIcon = true;
                                              selectedAvatar = 'assets/icon_pack/chat/chat_1.png';
                                            } else {
                                              isDefaultGroupIcon = false;
                                              selectedAvatar = avatarP;
                                            }
                                            showAvatarSlider = false;
                                          });
                                        },
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: isSel
                                                ? Border.all(color: const Color(0xFF0F766E), width: 2.2)
                                                : Border.all(color: Colors.transparent, width: 2.2),
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          ),
                                          child: isDef
                                              ? const Center(
                                                  child: Icon(
                                                    Icons.groups_rounded,
                                                    color: Color(0xFF0F766E),
                                                    size: 26,
                                                  ),
                                                )
                                              : ClipOval(
                                                  child: Transform.scale(
                                                    scale: 1.35,
                                                    child: Image.asset(avatarP, fit: BoxFit.cover),
                                                  ),
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Saluran / Channel
                          Text(
                            'Saluran (Channel)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: channelController,
                            enabled: canEditGroupInfo,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Saluran (Opsional, contoh: #diskusi)',
                              hintStyle: GoogleFonts.dmSans(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13.5,
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Detail Classroom Card & Anggota Terpilih (Clickable -> Kelola Anggota)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Color(0xFF0F766E),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Classroom ID: $projectId',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${activeSelectedMembers.length} Anggota',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 12.0,
                                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Anggota',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: openManageMembersModal,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      buildStackedAvatars(activeSelectedMembers),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.people_alt_rounded,
                                              size: 14,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Kelola',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Pengaturan Hak Akses / Role Admin
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 18,
                                      color: const Color(0xFF0F766E),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hak Akses Anggota',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Checkbox 1: Edit info grup (Only editable by admin)
                                InkWell(
                                  onTap: isUserAdmin
                                      ? () {
                                          setModalState(() {
                                            canAllMembersEditInfo = !canAllMembersEditInfo;
                                          });
                                        }
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: canAllMembersEditInfo
                                                ? (isDark ? Colors.white : Colors.black)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: canAllMembersEditInfo
                                                  ? (isDark ? Colors.white : Colors.black)
                                                  : (isDark ? Colors.white38 : Colors.black26),
                                              width: 2,
                                            ),
                                          ),
                                          child: canAllMembersEditInfo
                                              ? Icon(
                                                  Icons.check_rounded,
                                                  color: isDark ? Colors.black : Colors.white,
                                                  size: 13,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Seluruh anggota dapat mengubah info grup',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 12.5,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Checkbox 2: Undang teman (Only editable by admin)
                                InkWell(
                                  onTap: isUserAdmin
                                      ? () {
                                          setModalState(() {
                                            canAllMembersInvite = !canAllMembersInvite;
                                          });
                                        }
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: canAllMembersInvite
                                                ? (isDark ? Colors.white : Colors.black)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: canAllMembersInvite
                                                  ? (isDark ? Colors.white : Colors.black)
                                                  : (isDark ? Colors.white38 : Colors.black26),
                                              width: 2,
                                            ),
                                          ),
                                          child: canAllMembersInvite
                                              ? Icon(
                                                  Icons.check_rounded,
                                                  color: isDark ? Colors.black : Colors.white,
                                                  size: 13,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Seluruh anggota dapat mengundang teman',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 12.5,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Pembuat grup dan Guru otomatis menjadi Admin.\n• Minimal 1 admin di dalam grup. Guru tidak dapat dilepas.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.0,
                                    color: isDark ? Colors.white38 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<bool> _checkIsOwner(String projectId, String creatorUid) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return false;
    if (creatorUid == currentUid) return true;

    if (projectId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
      if (doc.exists) {
        final projectOwner = doc.data()?['ownerUid'] ?? doc.data()?['owner'] ?? '';
        if (projectOwner == currentUid) return true;
      }
    }
    return false;
  }

  Widget _buildMessageTextWithTime({
    required String text,
    required String timeText,
    required bool isMe,
    required bool isDark,
  }) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
            height: 1.3,
          ),
        ),
        if (timeText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              timeText,
              style: GoogleFonts.dmSans(
                fontSize: 10.0,
                color: isMe ? Colors.white60 : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _startPrivateChat(
    BuildContext context,
    String targetUid,
    String targetName,
    String targetAvatar,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || targetUid.isEmpty || targetUid == currentUid) return;

    String? existingChatId;
    try {
      final query = await FirebaseFirestore.instance
          .collection('discussions')
          .where('isPrivate', isEqualTo: true)
          .where('memberUids', arrayContains: currentUid)
          .get();

      for (var doc in query.docs) {
        final uids = List<String>.from(doc.data()['memberUids'] ?? []);
        if (uids.contains(targetUid) && uids.length == 2) {
          existingChatId = doc.id;
          break;
        }
      }
    } catch (_) {}

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomPage(
            discussionId: existingChatId ?? '',
            channelName: targetName,
            targetUserUid: targetUid,
            targetUserAvatar: targetAvatar,
            isPrivateDraft: existingChatId == null,
          ),
        ),
      );
    }
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatsAppStyleMessageOverlay({
    required BuildContext context,
    required String msgId,
    required String message,
    required String imageUrl,
    required String senderName,
    required String senderUid,
    required String timeText,
    required bool isMe,
    required Map<String, dynamic>? replyData,
    required Color senderColor,
    required String avatar,
    List<String> reactions = const [],
    bool showAvatar = true,
  }) {
    HapticFeedback.mediumImpact();
    final isDark = AppColors.isDarkMode;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool canEdit = isMe && message.isNotEmpty && imageUrl.isEmpty;
    final bool canDelete = isMe || _userRole == 'guru';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            // 1. Blur surrounding
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(dialogContext),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // 2. Focused Message & Menu aligned left/right with avatar
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Emoji reactions bar (Frameless press & mepet ke card)
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '🙏'])
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(dialogContext);
                                      FirebaseFirestore.instance
                                          .collection('discussions')
                                          .doc(_currentDiscussionId)
                                          .collection('messages')
                                          .doc(msgId)
                                          .update({
                                        'reactions.$currentUid': emoji,
                                      }).catchError((_) {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // The Message Bubble itself with avatar beside it
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe && showAvatar) ...[
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: ClipOval(
                                child: Transform.scale(
                                  scale: 1.45,
                                  child: Image.asset(avatar, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            padding: EdgeInsets.fromLTRB(
                              12,
                              replyData != null ? 6 : 8,
                              12,
                              8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (replyData != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : (isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          replyData['sender'] ?? 'User',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.bold,
                                            color: isMe ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                          ),
                                        ),
                                        Text(
                                          replyData['message'] == '[Gambar Lampiran]'
                                              ? '📷 Foto'
                                              : (replyData['message'] ?? ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11.0,
                                            color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!isMe) ...[
                                  Text(
                                    senderName.trim().isEmpty ? 'User' : senderName.trim().split(' ')[0],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: senderColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (imageUrl.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 240),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (message.isNotEmpty) const SizedBox(height: 4),
                                ],
                                if (message.isNotEmpty)
                                  _buildMessageTextWithTime(
                                    text: message,
                                    timeText: timeText,
                                    isMe: isMe,
                                    isDark: isDark,
                                  ),
                              ],
                            ),
                          ),
                          if (isMe && showAvatar) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: ClipOval(
                                child: Transform.scale(
                                  scale: 1.45,
                                  child: Image.asset(avatar, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Context Menu Card (Sleek compact dropdown card)
                      Container(
                        width: 135,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Balas
                              _buildContextMenuItem(
                                icon: Icons.reply_rounded,
                                iconColor: const Color(0xFF3B82F6),
                                title: 'Balas',
                                isDark: isDark,
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  setState(() {
                                    _replyingToMessage = {
                                      'id': msgId,
                                      'sender': senderName,
                                      'message': message.isNotEmpty ? message : '[Gambar Lampiran]',
                                      'senderUid': senderUid,
                                    };
                                  });
                                },
                              ),
                              Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                              // 2. Edit (Tulis ulang di text box bawah)
                              if (canEdit) ...[
                                _buildContextMenuItem(
                                  icon: Icons.edit_rounded,
                                  iconColor: const Color(0xFF7C3AED),
                                  title: 'Edit',
                                  isDark: isDark,
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    setState(() {
                                      _editingMessageId = msgId;
                                      _replyingToMessage = null;
                                      _messageController.text = message;
                                      _messageController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _messageController.text.length),
                                      );
                                    });
                                    _inputFocusNode.requestFocus();
                                  },
                                ),
                                Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              ],

                              // 3. Salin (Jika ada teks)
                              if (message.isNotEmpty) ...[
                                _buildContextMenuItem(
                                  icon: Icons.copy_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  title: 'Salin',
                                  isDark: isDark,
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    Clipboard.setData(ClipboardData(text: message));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Pesan disalin ke papan klip'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                if (canDelete)
                                  Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              ],

                              // 4. Hapus (Jika pengirim sendiri atau guru)
                              if (canDelete) ...[
                                _buildContextMenuItem(
                                  icon: Icons.delete_outline_rounded,
                                  iconColor: const Color(0xFFEF4444),
                                  title: 'Hapus',
                                  textColor: const Color(0xFFEF4444),
                                  isDark: isDark,
                                  onTap: () async {
                                    Navigator.pop(dialogContext);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: Text('Hapus Pesan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                        content: Text('Apakah Anda yakin ingin menghapus pesan ini?', style: GoogleFonts.plusJakartaSans()),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text('Hapus', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance
                                          .collection('discussions')
                                          .doc(_currentDiscussionId)
                                          .collection('messages')
                                          .doc(msgId)
                                          .delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Pesan dihapus.')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // If discussion was created but has 0 messages, auto-delete it on exit
          if (!_isDraft && _currentDiscussionId.isNotEmpty) {
            try {
              final msgsSnap = await FirebaseFirestore.instance
                  .collection('discussions')
                  .doc(_currentDiscussionId)
                  .collection('messages')
                  .limit(1)
                  .get();
              if (msgsSnap.docs.isEmpty) {
                final discDoc = await FirebaseFirestore.instance
                    .collection('discussions')
                    .doc(_currentDiscussionId)
                    .get();
                if (discDoc.exists && discDoc.data()?['isPrivate'] == true) {
                  await FirebaseFirestore.instance
                      .collection('discussions')
                      .doc(_currentDiscussionId)
                      .delete();
                }
              }
            } catch (_) {}
          }
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: (!_isDraft && _currentDiscussionId.isNotEmpty)
            ? FirebaseFirestore.instance
                .collection('discussions')
                .doc(_currentDiscussionId)
                .snapshots()
            : null,
        builder: (context, discSnapshot) {
          final discData = discSnapshot.data?.data() as Map<String, dynamic>?;
          final channelTitle = discData?['channel'] ?? widget.channelName;
          final channelDesc = discData?['title'] ?? '';
          final isPrivate = _isDraft ? true : (discData?['isPrivate'] ?? false);
          final memberUids = List<String>.from(discData?['memberUids'] ?? []);
          final memberCount = memberUids.isNotEmpty ? memberUids.length : 1;
          final subtitle = isPrivate ? 'Obrolan Pribadi' : '$channelDesc • $memberCount anggota';
          final projectId = discData?['projectId'] as String? ?? '';
          final isOwner = discData?['creatorUid'] == currentUid || _userRole == 'guru';

          return StreamBuilder<DocumentSnapshot>(
            stream: projectId.isNotEmpty
                ? FirebaseFirestore.instance.collection('projects').doc(projectId).snapshots()
                : null,
            builder: (context, projSnapshot) {
              final projData = projSnapshot.data?.data() as Map<String, dynamic>?;

              final double fullScreenHeight = MediaQuery.of(context).size.height;
              final double fullScreenWidth = MediaQuery.of(context).size.width;

              return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0A0910) : const Color(0xFFFAF8FF),
              body: Stack(
                children: [
                  // 1. Sticky Wallpaper background (Does not move or squish when keyboard appears)
                  Positioned(
                    top: 0,
                    left: 0,
                    width: fullScreenWidth,
                    height: fullScreenHeight,
                    child: AnimatedPurpleMicroPatternBackground(
                      isDark: isDark,
                      child: const SizedBox.shrink(),
                    ),
                  ),

                  // 2. Main Column: Solid White Header + Full Viewport Messages Stack + Solid White Input Bar
                  Column(
                    children: [
                      // Header Bar (Transparan 50% + Blur Glassmorphic dengan Border Bawah)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              14.0,
                              MediaQuery.of(context).padding.top + 10.0,
                              14.0,
                              12.0,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F0B1E).withValues(alpha: 0.70)
                                  : Colors.white.withValues(alpha: 0.70),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.50),
                                  width: 1.0,
                                ),
                              ),
                            ),
                        child: Row(
                          children: [
                            if (!widget.isEmbedded) ...[
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: isDark ? Colors.white : Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    channelTitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (projectId.isNotEmpty) ...[
                              // Open Drive folder button (Visible to everyone if connected)
                              if (projData?['driveFolderId'] != null && projData!['driveFolderId'].toString().isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: BouncyButton(
                                    onTap: () async {
                                      final String folderId = projData['driveFolderId'].toString();
                                      final String folderUrl = projData['driveFolderUrl']?.toString() ?? 'https://drive.google.com/drive/folders/$folderId';
                                      final Uri uri = Uri.parse(folderUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Tidak dapat membuka Google Drive.')),
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.folder_shared_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              // Connect/Change folder button (Only visible to guru)
                              if (_userRole == 'guru')
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: BouncyButton(
                                    onTap: () => _showFolderSelectorDialog(projectId),
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.add_to_drive_rounded,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                            PopupMenuButton<String>(
                              tooltip: '',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  width: 1.0,
                                ),
                              ),
                              elevation: 6,
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              icon: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 20,
                                ),
                              ),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  if (discData != null) {
                                    _openEditDiscussionSettings(context, discData);
                                  }
                                } else if (val == 'clear') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: const Text('Bersihkan Obrolan', style: TextStyle(fontWeight: FontWeight.bold)),
                                      content: Text(
                                        isPrivate
                                            ? 'Apakah Anda yakin ingin menghapus semua pesan di obrolan pribadi ini?'
                                            : 'Apakah Anda yakin ingin membersihkan semua pesan di grup diskusi ini?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('Bersihkan', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && !_isDraft && _currentDiscussionId.isNotEmpty) {
                                    final msgs = await FirebaseFirestore.instance
                                        .collection('discussions')
                                        .doc(_currentDiscussionId)
                                        .collection('messages')
                                        .get();
                                    for (var doc in msgs.docs) {
                                      await doc.reference.delete();
                                    }
                                    await FirebaseFirestore.instance
                                        .collection('discussions')
                                        .doc(_currentDiscussionId)
                                        .update({
                                      'lastMessage': isPrivate ? 'Mulai obrolan privat...' : 'Obrolan telah dibersihkan...',
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Obrolan berhasil dibersihkan!')),
                                      );
                                    }
                                  }
                                } else if (val == 'leave') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: Text('Keluar dari Grup', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                      content: Text('Apakah Anda yakin ingin keluar dari grup diskusi ini?', style: GoogleFonts.plusJakartaSans()),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('Keluar', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && !_isDraft && _currentDiscussionId.isNotEmpty) {
                                    await FirebaseFirestore.instance
                                        .collection('discussions')
                                        .doc(_currentDiscussionId)
                                        .update({
                                      'memberUids': FieldValue.arrayRemove([currentUid]),
                                    });
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Anda telah keluar dari grup diskusi.')),
                                      );
                                    }
                                  }
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: Text(
                                        isPrivate ? 'Hapus Obrolan' : 'Hapus Diskusi',
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                      ),
                                      content: Text(
                                        isPrivate
                                            ? 'Apakah Anda yakin ingin menghapus obrolan ini secara permanen?'
                                            : 'Apakah Anda yakin ingin menghapus grup diskusi ini? Semua pesan di dalamnya akan terhapus secara permanen.',
                                        style: GoogleFonts.plusJakartaSans(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('Hapus', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    if (!_isDraft && _currentDiscussionId.isNotEmpty) {
                                      final msgs = await FirebaseFirestore.instance
                                          .collection('discussions')
                                          .doc(_currentDiscussionId)
                                          .collection('messages')
                                          .get();
                                      for (var doc in msgs.docs) {
                                        await doc.reference.delete();
                                      }
                                      await FirebaseFirestore.instance
                                          .collection('discussions')
                                          .doc(_currentDiscussionId)
                                          .delete();
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(isPrivate ? 'Obrolan berhasil dihapus!' : 'Diskusi berhasil dihapus!')),
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) {
                                if (isPrivate) {
                                  return [
                                    PopupMenuItem(
                                      value: 'clear',
                                      height: 36,
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.cleaning_services_rounded, size: 18, color: Color(0xFF06B6D4)),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Bersihkan Obrolan',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      height: 36,
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Hapus Obrolan',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ];
                                }

                                return [
                                  if (isOwner) ...[
                                    PopupMenuItem(
                                      value: 'edit',
                                      height: 36,
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF7C3AED)),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Pengaturan',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  PopupMenuItem(
                                    value: 'leave',
                                    height: 36,
                                    padding: EdgeInsets.zero,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFF59E0B)),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Keluar Diskusi',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'clear',
                                    height: 36,
                                    padding: EdgeInsets.zero,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.cleaning_services_rounded, size: 18, color: Color(0xFF06B6D4)),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Bersihkan Obrolan',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isOwner) ...[
                                    PopupMenuItem(
                                      value: 'delete',
                                      height: 36,
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Hapus Diskusi',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ];
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                      // Messages and Floating Controls Viewport
                      Expanded(
                        child: SafeArea(
                          top: false,
                          child: Stack(
                            children: [
                              // 1. Full Screen Messages ListView with 94px bottom padding (completely unobstructed)
                              Positioned.fill(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: (!_isDraft && _currentDiscussionId.isNotEmpty)
                                      ? FirebaseFirestore.instance
                                          .collection('discussions')
                                          .doc(_currentDiscussionId)
                                          .collection('messages')
                                          .orderBy('time', descending: false)
                                          .snapshots()
                                      : null,
                                  builder: (context, snapshot) {
                                    if (snapshot.data == null && snapshot.connectionState == ConnectionState.waiting) {
                                      return const SizedBox.shrink();
                                    }
                                    final messageDocs = snapshot.data?.docs ?? [];

                                    // Track mention messages
                                    if (messageDocs.isNotEmpty && _currentUserName.isNotEmpty) {
                                      final mentionIds = <String>[];
                                      for (final doc in messageDocs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final msg = (data['message'] ?? '') as String;
                                        final senderUid = data['senderUid'] ?? '';
                                        if (senderUid == currentUid) continue;
                                        if (msg.toLowerCase().contains('@all') ||
                                            msg.toLowerCase().contains('@${_currentUserName.toLowerCase()}')) {
                                          mentionIds.add(doc.id);
                                          if (!_messageKeys.containsKey(doc.id)) {
                                            _messageKeys[doc.id] = GlobalKey();
                                          }
                                        }
                                      }
                                      if (_mentionMessageIds.length != mentionIds.length) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) setState(() { _mentionMessageIds = mentionIds; _unreadMentionCount = mentionIds.length; });
                                        });
                                      }
                                    }

                                    // Smart scroll
                                    final currentCount = messageDocs.length;
                                    if (!_initialScrollDone) {
                                      _initialScrollDone = true;
                                      _lastMessageCount = currentCount;
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _scrollToBottom();
                                        if (!_isDraft && _currentDiscussionId.isNotEmpty) {
                                          FirebaseFirestore.instance
                                              .collection('discussions')
                                              .doc(_currentDiscussionId)
                                              .update({
                                            'unreadCounts.$currentUid': 0,
                                          }).catchError((_) {});
                                        }
                                      });
                                    } else if (currentCount > _lastMessageCount) {
                                      _lastMessageCount = currentCount;
                                      if (messageDocs.isNotEmpty) {
                                        final lastDoc = messageDocs.last;
                                        final lastMsgData = lastDoc.data() as Map<String, dynamic>;
                                        final lastSenderUid = lastMsgData['senderUid'] ?? '';
                                        final lastMsgId = lastDoc.id;
                                        if (lastSenderUid != currentUid && _lastPlayedMessageId != lastMsgId) {
                                          _lastPlayedMessageId = lastMsgId;
                                          _playNotificationSound();
                                        }
                                      }

                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _scrollToBottom();
                                        if (!_isDraft && _currentDiscussionId.isNotEmpty) {
                                          FirebaseFirestore.instance
                                              .collection('discussions')
                                              .doc(_currentDiscussionId)
                                              .update({
                                            'unreadCounts.$currentUid': 0,
                                          }).catchError((_) {});
                                        }
                                      });
                                    }

                                    if (messageDocs.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'Belum ada pesan di sini. Mulai obrolan!',
                                          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black38),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      controller: _scrollController,
                                      padding: EdgeInsets.only(
                                        left: 14,
                                        right: 14,
                                        top: 16,
                                        bottom: 94 + (_replyingToMessage != null ? 50.0 : 0.0),
                                      ),
                                      itemCount: messageDocs.length,
                                      itemBuilder: (context, index) {
                                        final msgDoc = messageDocs[index];
                                        final msgData = msgDoc.data() as Map<String, dynamic>;
                                        final msgId = msgDoc.id;
                                        if (!_messageKeys.containsKey(msgId)) {
                                          _messageKeys[msgId] = GlobalKey();
                                        }
                                        final msgKey = _messageKeys[msgId];
                                        final sender = msgData['sender'] ?? 'User';
                                        final senderUid = msgData['senderUid'] ?? '';

                                        final member = _discussionMembers.firstWhere(
                                          (m) => m['uid'] == senderUid,
                                          orElse: () => <String, dynamic>{},
                                        );
                                        final avatar = member['avatar'] as String? ?? msgData['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';
                                        final senderName = member['name'] as String? ?? sender;

                                        final message = msgData['message'] ?? '';
                                        final imageUrl = msgData['imageUrl'] as String? ?? '';
                                        final timeVal = msgData['time'];
                                        String timeText = '';
                                        if (timeVal is Timestamp) {
                                          final dt = timeVal.toDate();
                                          final hour = dt.hour.toString().padLeft(2, '0');
                                          final min = dt.minute.toString().padLeft(2, '0');
                                          timeText = '$hour:$min';
                                        }
                                        final isMe = senderUid == currentUid;
                                        final String displayName = senderName.trim().isEmpty ? 'User' : senderName.trim().split(' ')[0];

                                        final lines = message.split('\n');
                                        final bool isLongMessage = lines.length > 15;
                                        final bool isExpanded = _expandedMessageIds.contains(msgId);
                                        final String displayMessage = (isLongMessage && !isExpanded)
                                            ? lines.take(15).join('\n')
                                            : message;

                                        final List<Color> nameColors = [
                                          const Color(0xFFE11D48),
                                          const Color(0xFF2563EB),
                                          const Color(0xFF059669),
                                          const Color(0xFFD97706),
                                          const Color(0xFF7C3AED),
                                          const Color(0xFF0891B2),
                                          const Color(0xFFDB2777),
                                          const Color(0xFF4F46E5),
                                        ];
                                        final int colorHash = senderUid.hashCode.abs() % nameColors.length;
                                        final Color senderColor = nameColors[colorHash];

                                        final replyData = msgData['replyTo'] as Map<String, dynamic>?;
                                        final reactionsMap = (msgData['reactions'] as Map<String, dynamic>?) ?? {};
                                        final List<String> reactionList = reactionsMap.values
                                            .map((e) => e.toString())
                                            .where((e) => e.isNotEmpty)
                                            .toList();

                                        return Dismissible(
                                          key: Key('msg_$msgId'),
                                          direction: DismissDirection.startToEnd,
                                          confirmDismiss: (direction) async {
                                            setState(() {
                                              _replyingToMessage = {
                                                'id': msgId,
                                                'sender': senderName,
                                                'message': message.isNotEmpty ? message : '[Gambar Lampiran]',
                                                'senderUid': senderUid,
                                              };
                                            });
                                            HapticFeedback.lightImpact();
                                            return false;
                                          },
                                          background: Container(
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.only(left: 16),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.reply_rounded,
                                                size: 18,
                                                color: isDark ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                          ),
                                          child: Container(
                                            key: msgKey,
                                            margin: EdgeInsets.only(bottom: reactionList.isNotEmpty ? 16 : 6),
                                            child: Row(
                                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                if (!isMe && !isPrivate) ...[
                                                  GestureDetector(
                                                    onTap: () {
                                                      _startPrivateChat(
                                                        context,
                                                        senderUid,
                                                        senderName,
                                                        avatar,
                                                      );
                                                    },
                                                    child: SizedBox(
                                                      width: 32,
                                                      height: 32,
                                                      child: ClipOval(
                                                        child: Transform.scale(
                                                          scale: 1.45,
                                                          child: Image.asset(avatar, fit: BoxFit.cover),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Flexible(
                                                  child: GestureDetector(
                                                    onLongPress: () {
                                                      _showWhatsAppStyleMessageOverlay(
                                                        context: context,
                                                        msgId: msgId,
                                                        message: message,
                                                        imageUrl: imageUrl,
                                                        senderName: senderName,
                                                        senderUid: senderUid,
                                                        timeText: timeText,
                                                        isMe: isMe,
                                                        replyData: replyData,
                                                        senderColor: senderColor,
                                                        avatar: avatar,
                                                        reactions: reactionList,
                                                        showAvatar: !isPrivate,
                                                      );
                                                    },
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        Container(
                                                          padding: EdgeInsets.fromLTRB(
                                                            12,
                                                            replyData != null ? 6 : 8,
                                                            12,
                                                            8,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? Colors.black
                                                                : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                                            borderRadius: BorderRadius.only(
                                                              topLeft: const Radius.circular(16),
                                                              topRight: const Radius.circular(16),
                                                              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                                                blurRadius: 4,
                                                                offset: const Offset(0, 1),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              if (replyData != null) ...[
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    final targetId = replyData['id'] as String?;
                                                                    if (targetId != null && _messageKeys.containsKey(targetId)) {
                                                                      final targetKey = _messageKeys[targetId];
                                                                      if (targetKey?.currentContext != null) {
                                                                        Scrollable.ensureVisible(
                                                                          targetKey!.currentContext!,
                                                                          duration: const Duration(milliseconds: 400),
                                                                          curve: Curves.easeOut,
                                                                          alignment: 0.3,
                                                                        );
                                                                      }
                                                                    }
                                                                  },
                                                                  child: Container(
                                                                    margin: const EdgeInsets.only(bottom: 6),
                                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                                    decoration: BoxDecoration(
                                                                      color: isMe
                                                                          ? Colors.white.withValues(alpha: 0.12)
                                                                          : (isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9)),
                                                                      borderRadius: BorderRadius.circular(10),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          replyData['sender'] ?? 'User',
                                                                          style: GoogleFonts.plusJakartaSans(
                                                                            fontSize: 11.0,
                                                                            fontWeight: FontWeight.bold,
                                                                            color: isMe ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          replyData['message'] == '[Gambar Lampiran]'
                                                                              ? '📷 Foto'
                                                                              : (replyData['message'] ?? ''),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          style: GoogleFonts.dmSans(
                                                                            fontSize: 11.0,
                                                                            color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                              if (!isMe) ...[
                                                                Text(
                                                                  displayName,
                                                                  style: GoogleFonts.plusJakartaSans(
                                                                    fontSize: 12.0,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: senderColor,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                              ],
                                                              if (imageUrl.isNotEmpty) ...[
                                                                GestureDetector(
                                                                  onTap: () async {
                                                                    final isDriveConnected = await GoogleDriveService.isConnected();
                                                                    if (!isDriveConnected) {
                                                                      if (context.mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                          const SnackBar(
                                                                            content: Text('Sambungkan akun Google Drive terlebih dahulu untuk melihat gambar.'),
                                                                            backgroundColor: Colors.redAccent,
                                                                            duration: Duration(seconds: 2),
                                                                          ),
                                                                        );
                                                                      }
                                                                      return;
                                                                    }
                                                                    if (context.mounted) {
                                                                      Navigator.of(context).push(
                                                                        MaterialPageRoute(
                                                                          builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
                                                                        ),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: ClipRRect(
                                                                    borderRadius: BorderRadius.circular(10),
                                                                    child: Container(
                                                                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 240),
                                                                      child: Image.network(
                                                                        imageUrl,
                                                                        fit: BoxFit.cover,
                                                                        loadingBuilder: (context, child, progress) {
                                                                          if (progress == null) return child;
                                                                          return Container(
                                                                            height: 120,
                                                                            width: 200,
                                                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                                            child: const Center(
                                                                              child: SizedBox(
                                                                                width: 20,
                                                                                height: 20,
                                                                                child: CircularProgressIndicator(strokeWidth: 2),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                        errorBuilder: (_, __, ___) => Container(
                                                                          height: 80,
                                                                          width: 140,
                                                                          color: Colors.red.withValues(alpha: 0.1),
                                                                          child: const Center(
                                                                            child: Icon(Icons.broken_image_rounded, color: Colors.redAccent),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (message.isNotEmpty) const SizedBox(height: 4),
                                                              ],
                                                              if (message.isNotEmpty) ...[
                                                                _buildMessageTextWithTime(
                                                                  text: displayMessage,
                                                                  timeText: timeText,
                                                                  isMe: isMe,
                                                                  isDark: isDark,
                                                                ),
                                                                if (isLongMessage) ...[
                                                                  const SizedBox(height: 2),
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      setState(() {
                                                                        if (isExpanded) {
                                                                          _expandedMessageIds.remove(msgId);
                                                                        } else {
                                                                          _expandedMessageIds.add(msgId);
                                                                        }
                                                                      });
                                                                    },
                                                                    child: Text(
                                                                      isExpanded ? 'Lebih sedikit' : 'Selengkapnya...',
                                                                      style: GoogleFonts.plusJakartaSans(
                                                                        fontSize: 12.0,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: isMe
                                                                            ? const Color(0xFF60A5FA)
                                                                            : const Color(0xFF2563EB),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ],
                                                          ),
                                                        ),

                                                        // Reaction Floating under the chat bubble: emot tanpa background, background angka saja jika > 1
                                                        if (reactionList.isNotEmpty)
                                                          Positioned(
                                                            bottom: -12,
                                                            right: isMe ? 4 : null,
                                                            left: isMe ? null : 4,
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.center,
                                                              children: [
                                                                for (final emoji in reactionList.toSet().take(3))
                                                                  Padding(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                                                    child: Text(
                                                                      emoji,
                                                                      style: const TextStyle(fontSize: 20),
                                                                    ),
                                                                  ),
                                                                if (reactionList.length > 1) ...[
                                                                  const SizedBox(width: 3),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                                      borderRadius: BorderRadius.circular(10),
                                                                      border: Border.all(
                                                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                                        width: 1.2,
                                                                      ),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                                                                          blurRadius: 3,
                                                                          offset: const Offset(0, 1),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Text(
                                                                      '${reactionList.length}',
                                                                      style: GoogleFonts.plusJakartaSans(
                                                                        fontSize: 11,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (isMe && !isPrivate) ...[
                                                  const SizedBox(width: 4),
                                                  SizedBox(
                                                    width: 32,
                                                    height: 32,
                                                    child: ClipOval(
                                                      child: Transform.scale(
                                                        scale: 1.45,
                                                        child: Image.asset(avatar, fit: BoxFit.cover),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              // 2. Mention Banner
                              if (!isPrivate && _mentionMessageIds.isNotEmpty)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      final lastMentionId = _mentionMessageIds.last;
                                      final key = _messageKeys[lastMentionId];
                                      if (key?.currentContext != null) {
                                        Scrollable.ensureVisible(
                                          key!.currentContext!,
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeOut,
                                          alignment: 0.2,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3EEFF),
                                        border: Border(
                                          bottom: BorderSide(color: const Color(0xFFD8B4FE).withValues(alpha: 0.4), width: 1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF9333EA)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '@mention ($_unreadMentionCount)',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF9333EA),
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9333EA)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                              // 3. Floating Scroll-To-Bottom Button (Kanan di luar card textbox, circular button dengan shadow)
                              if (_showScrollToBottom)
                                Positioned(
                                  right: 18,
                                  bottom: 84 + ((_replyingToMessage != null || _editingMessageId != null) ? 48.0 : 0.0),
                                  child: BouncyButton(
                                    scaleDown: 0.85,
                                    onTap: () => _scrollToBottom(animate: true),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),

                              // 4. Glassmorphic Flat Input Bar (Non-Round, Transparan 60% + Blur)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F0B1E).withValues(alpha: 0.60)
                                            : Colors.white.withValues(alpha: 0.60),
                                        border: Border(
                                          top: BorderSide(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.12)
                                                : Colors.white.withValues(alpha: 0.50),
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      padding: EdgeInsets.fromLTRB(
                                        14.0,
                                        10.0,
                                        14.0,
                                        MediaQuery.of(context).padding.bottom > 0
                                            ? MediaQuery.of(context).padding.bottom + 6.0
                                            : 12.0,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Replying Banner
                                          if (_replyingToMessage != null) ...[
                                            Container(
                                              height: 38,
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(19),
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.reply_rounded, color: Color(0xFF2563EB), size: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          _replyingToMessage!['sender'] ?? 'User',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 12.0,
                                                            fontWeight: FontWeight.bold,
                                                            color: const Color(0xFF2563EB),
                                                          ),
                                                        ),
                                                        Text(
                                                          _replyingToMessage!['message'] == '[Gambar Lampiran]'
                                                              ? '📷 Foto'
                                                              : (_replyingToMessage!['message'] ?? ''),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.dmSans(
                                                            fontSize: 11.0,
                                                            color: isDark ? Colors.white70 : Colors.black54,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _replyingToMessage = null;
                                                      });
                                                    },
                                                    child: Container(
                                                      margin: const EdgeInsets.only(right: 8),
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.close_rounded,
                                                        size: 13,
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],

                                          // Editing Banner
                                          if (_editingMessageId != null) ...[
                                            Container(
                                              height: 38,
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(19),
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.edit_rounded, color: Color(0xFF7C3AED), size: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          'Edit Pesan',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 12.0,
                                                            fontWeight: FontWeight.bold,
                                                            color: const Color(0xFF7C3AED),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Perbarui teks di kolom lalu kirim',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.dmSans(
                                                            fontSize: 11.0,
                                                            color: isDark ? Colors.white70 : Colors.black54,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _editingMessageId = null;
                                                        _messageController.clear();
                                                      });
                                                    },
                                                    child: Container(
                                                      margin: const EdgeInsets.only(right: 8),
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.close_rounded,
                                                        size: 13,
                                                        color: isDark ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],

                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Tombol Gambar (36x36 terpusat)
                                              BouncyButton(
                                                onTap: _pickAndSendImage,
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  margin: const EdgeInsets.only(right: 6),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.image_rounded,
                                                    color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                              // Text Field (1 Baris lurus sejajar)
                                              Expanded(
                                                child: Container(
                                                  constraints: const BoxConstraints(minHeight: 38),
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                                    borderRadius: BorderRadius.circular(19),
                                                    border: Border.all(
                                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                  child: KeyboardListener(
                                                    focusNode: _inputFocusNode,
                                                    onKeyEvent: (event) {
                                                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                                                        if (!HardwareKeyboard.instance.isShiftPressed) {
                                                          _sendMessage();
                                                        }
                                                      }
                                                    },
                                                    child: TextField(
                                                      controller: _messageController,
                                                      minLines: 1,
                                                      maxLines: 4,
                                                      keyboardType: TextInputType.multiline,
                                                      textInputAction: TextInputAction.send,
                                                      onSubmitted: (_) => _sendMessage(),
                                                      style: GoogleFonts.dmSans(
                                                        fontSize: 13.5,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: _editingMessageId != null ? 'Edit pesan...' : 'Tulis pesan...',
                                                        hintStyle: GoogleFonts.dmSans(
                                                          color: isDark ? Colors.white38 : Colors.black26,
                                                          fontSize: 13.5,
                                                        ),
                                                        border: InputBorder.none,
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 9,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // Tombol Kirim: Ikon saja warna hitam lurus sejajar dengan animasi bounce responsif
                                              BouncyButton(
                                                scaleDown: 0.75,
                                                duration: const Duration(milliseconds: 100),
                                                onTap: _sendMessage,
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    _editingMessageId != null ? Icons.check_rounded : Icons.send_rounded,
                                                    color: _editingMessageId != null
                                                        ? const Color(0xFF7C3AED)
                                                        : (isDark ? Colors.white : Colors.black),
                                                    size: 21,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
}

class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool isDark = AppColors.isDarkMode;
    final Color primaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.20);
    final Color secondaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.30);
    final Color strokePatternColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);
    final Color ringPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.16)
        : accentColor.withValues(alpha: 0.07);
    final Color dotPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : accentColor.withValues(alpha: 0.10);

    switch (patternIndex % 5) {
      case 0:
        // Pattern 1: Wave & Smooth Ribbon (Curved waves flowing down right side)
        final paint = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final path = Path();
        path.moveTo(size.width * 0.45, 0);
        path.cubicTo(
          size.width * 0.65, size.height * 0.35,
          size.width * 0.35, size.height * 0.75,
          size.width * 0.85, size.height,
        );
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
        path.close();
        canvas.drawPath(path, paint);

        final paintSecondary = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathSecondary = Path();
        pathSecondary.moveTo(size.width * 0.6, 0);
        pathSecondary.cubicTo(
          size.width * 0.8, size.height * 0.4,
          size.width * 0.5, size.height * 0.8,
          size.width, size.height * 0.7,
        );
        pathSecondary.lineTo(size.width, 0);
        pathSecondary.close();
        canvas.drawPath(pathSecondary, paintSecondary);
        break;

      case 1:
        // Pattern 2: Concentric Swirls & Rings (Arcs centered top-right)
        final paintRing = Paint()
          ..color = ringPatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        final center = Offset(size.width * 0.85, size.height * 0.3);
        canvas.drawCircle(center, 30, paintRing);
        canvas.drawCircle(center, 55, paintRing);

        final paintWave = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRing = Path();
        pathRing.moveTo(size.width * 0.55, 0);
        pathRing.quadraticBezierTo(
          size.width * 0.8, size.height * 0.5,
          size.width, size.height,
        );
        pathRing.lineTo(size.width, 0);
        pathRing.close();
        canvas.drawPath(pathRing, paintWave);
        break;

      case 2:
        // Pattern 3: Floating Soft Circles / Bubbles
        final paintBubble1 = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 45, paintBubble1);

        final paintBubble2 = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.75), 35, paintBubble2);
        break;

      case 3:
        // Pattern 4: Modern Geometric Mesh / Node Grid
        final paintDot = Paint()
          ..color = dotPatternColor
          ..style = PaintingStyle.fill;
        for (double x = size.width * 0.5; x < size.width; x += 18) {
          for (double y = 10; y < size.height; y += 18) {
            canvas.drawCircle(Offset(x, y), 3, paintDot);
          }
        }
        break;

      case 4:
      default:
        // Pattern 5: Organic Diagonal Rays / Leaf Curves
        final paintRay = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRay = Path();
        pathRay.moveTo(size.width * 0.5, 0);
        pathRay.quadraticBezierTo(
          size.width * 0.7, size.height * 0.5,
          size.width * 0.8, size.height,
        );
        pathRay.lineTo(size.width, size.height);
        pathRay.lineTo(size.width, 0);
        pathRay.close();
        canvas.drawPath(pathRay, paintRay);

        final paintStroke = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
        final pathStroke = Path();
        pathStroke.moveTo(size.width * 0.65, 0);
        pathStroke.quadraticBezierTo(
          size.width * 0.8, size.height * 0.4,
          size.width * 0.85, size.height,
        );
        canvas.drawPath(pathStroke, paintStroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ClassroomCardPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex || oldDelegate.accentColor != accentColor;
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4F46E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: ThreeDotsLoader());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Gagal memuat gambar',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    required this.isMe,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      if (widget.isMe) {
        // Drag to left: offset should be negative
        if (_dragOffset > 0) _dragOffset = 0;
        if (_dragOffset < -80) _dragOffset = -80;
      } else {
        // Drag to right: offset should be positive
        if (_dragOffset < 0) _dragOffset = 0;
        if (_dragOffset > 80) _dragOffset = 80;
      }

      final absOffset = _dragOffset.abs();
      if (absOffset >= 50 && !_triggered) {
        _triggered = true;
        HapticFeedback.lightImpact();
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_triggered) {
      widget.onReply();
    }
    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ))..addListener(() {
      setState(() {
        _dragOffset = _animation.value;
      });
    });

    _triggered = false;
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Opacity(
                  opacity: (_dragOffset.abs() / 80.0).clamp(0.0, 1.0),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// ANIMATED PURPLE MICRO PATTERN BACKGROUND (SUBTLE GENTLE MOTION)
// ============================================================================
class AnimatedPurpleMicroPatternBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const AnimatedPurpleMicroPatternBackground({
    super.key,
    required this.child,
    this.isDark = false,
  });

  @override
  State<AnimatedPurpleMicroPatternBackground> createState() => _AnimatedPurpleMicroPatternBackgroundState();
}

class _AnimatedPurpleMicroPatternBackgroundState extends State<AnimatedPurpleMicroPatternBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PurpleMicroPatternPainter(
            animationValue: _controller.value,
            isDark: widget.isDark,
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _PurpleMicroPatternPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  _PurpleMicroPatternPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 1. Hero Purple Gradient (Persis warna hero Laporan: #7F52FC / #6D28D9)
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF140D2B),
              Color(0xFF1F1242),
              Color(0xFF120A24),
            ]
          : const [
              Color(0xFF7F52FC),
              Color(0xFF6D28D9),
              Color(0xFF8B5CF6),
            ],
    );
    canvas.drawRect(rect, Paint()..shader = bgGradient.createShader(rect));

    // 2. Animated Abstract Flowing Shapes & Curves (Card Classroom & Hero Laporan Style)
    final double anim1 = sin(animationValue * 2 * pi);
    final double anim2 = cos(animationValue * 2 * pi);

    // Large Soft Abstract Wave 1 (Top-Right to Center)
    final wavePaint1 = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.06 : 0.10)
      ..style = PaintingStyle.fill;
    final wavePath1 = Path();
    wavePath1.moveTo(size.width * 0.3 + anim1 * 12, 0);
    wavePath1.quadraticBezierTo(
      size.width * 0.7 + anim2 * 15,
      size.height * 0.25 + anim1 * 10,
      size.width,
      size.height * 0.35 + anim2 * 12,
    );
    wavePath1.lineTo(size.width, 0);
    wavePath1.close();
    canvas.drawPath(wavePath1, wavePaint1);

    // Large Soft Abstract Wave 2 (Bottom-Left to Right)
    final wavePaint2 = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.05 : 0.08)
      ..style = PaintingStyle.fill;
    final wavePath2 = Path();
    wavePath2.moveTo(0, size.height * 0.65 + anim2 * 14);
    wavePath2.quadraticBezierTo(
      size.width * 0.4 + anim1 * 18,
      size.height * 0.8 + anim2 * 12,
      size.width * 0.85 + anim1 * 10,
      size.height,
    );
    wavePath2.lineTo(0, size.height);
    wavePath2.close();
    canvas.drawPath(wavePath2, wavePaint2);

    // Abstract Floating Rings (Like Laporan Hero & Classroom Card Pattern)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.14 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final ringPaintThin = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.08 : 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(
      Offset(size.width * 0.15 + anim1 * 10, size.height * 0.22 + anim2 * 8),
      36,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88 - anim2 * 12, size.height * 0.45 + anim1 * 14),
      48,
      ringPaintThin,
    );
    canvas.drawCircle(
      Offset(size.width * 0.32 + anim2 * 14, size.height * 0.78 - anim1 * 10),
      28,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75 + anim1 * 8, size.height * 0.88 + anim2 * 12),
      56,
      ringPaintThin,
    );

    // Dynamic Abstract Curves & Strokes
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.10 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final arcPath = Path();
    arcPath.moveTo(size.width * 0.05, size.height * 0.48 + anim1 * 10);
    arcPath.quadraticBezierTo(
      size.width * 0.25 + anim2 * 12,
      size.height * 0.55 + anim1 * 15,
      size.width * 0.45,
      size.height * 0.42 + anim2 * 8,
    );
    canvas.drawPath(arcPath, strokePaint);

    // 3. Scattered Abstract Dots & Micro Shapes (Bentuk Abstrak Tidak Teratur)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.22 : 0.28)
      ..style = PaintingStyle.fill;

    final softDotPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.12 : 0.16)
      ..style = PaintingStyle.fill;

    final List<Offset> dots = [
      Offset(size.width * 0.12, size.height * 0.10),
      Offset(size.width * 0.45, size.height * 0.14),
      Offset(size.width * 0.78, size.height * 0.08),
      Offset(size.width * 0.25, size.height * 0.34),
      Offset(size.width * 0.62, size.height * 0.28),
      Offset(size.width * 0.92, size.height * 0.24),
      Offset(size.width * 0.18, size.height * 0.60),
      Offset(size.width * 0.50, size.height * 0.52),
      Offset(size.width * 0.82, size.height * 0.64),
      Offset(size.width * 0.08, size.height * 0.82),
      Offset(size.width * 0.40, size.height * 0.90),
      Offset(size.width * 0.70, size.height * 0.76),
      Offset(size.width * 0.90, size.height * 0.92),
    ];

    for (int i = 0; i < dots.length; i++) {
      final double wave = sin((i * 0.8) + (animationValue * 2 * pi));
      final double dx = dots[i].dx + (sin(animationValue * 2 * pi + i) * 6.0);
      final double dy = dots[i].dy + (cos(animationValue * 2 * pi + i) * 6.0);
      final double radius = 1.8 + (wave * 0.8);

      if (i % 3 == 0) {
        canvas.drawCircle(Offset(dx, dy), radius, dotPaint);
      } else if (i % 3 == 1) {
        canvas.drawCircle(Offset(dx, dy), radius * 0.7, softDotPaint);
      } else {
        // Small 4-point sparkle
        final double s = radius * 1.5;
        final spPaint = Paint()
          ..color = Colors.white.withValues(alpha: isDark ? 0.25 : 0.30)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(dx - s, dy), Offset(dx + s, dy), spPaint);
        canvas.drawLine(Offset(dx, dy - s), Offset(dx, dy + s), spPaint);
      }
    }

    // 4. Tint Overlay (50% Putih untuk Light mode, 50% Hitam untuk Dark mode)
    final overlayPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.50)
          : Colors.white.withValues(alpha: 0.50)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _PurpleMicroPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isDark != isDark;
  }
}
