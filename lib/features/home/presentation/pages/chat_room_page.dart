import 'dart:convert';
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
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'dart:io';
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hubner/core/theme/app_colors.dart';
import 'package:hubner/main.dart' show HubnerApp;
import 'home_page.dart' show BouncyButton;
import 'package:hubner/features/projects/presentation/pages/detail_cp_page.dart';

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

  Stream<DocumentSnapshot>? _discussionStream;
  Stream<QuerySnapshot>? _messagesStream;

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
  String? _lastMarkedUnreadMsgId;
  int _lastMessageCount = -1; // Track for smart scroll
  bool _initialScrollDone = false;
  
  // Mention tracking via ValueNotifier to avoid rebuild loops
  final ValueNotifier<List<String>> _mentionNotifier = ValueNotifier<List<String>>([]);
  final Map<String, GlobalKey> _messageKeys = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _replyingToMessage;
  String? _editingMessageId;
  final FocusNode _inputFocusNode = FocusNode();
  bool _showAttachmentPanel = false;
  final ValueNotifier<bool> _showScrollToBottom = ValueNotifier<bool>(false);

  Stream<DocumentSnapshot>? _cachedProjectStream;
  String? _cachedProjectId;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final bool shouldShow = (maxScroll - currentScroll) > 80;
    if (shouldShow != _showScrollToBottom.value) {
      _showScrollToBottom.value = shouldShow;
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

  void _initStreams() {
    final discId = _currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId;
    if (discId.isNotEmpty) {
      _discussionStream = FirebaseFirestore.instance
          .collection('discussions')
          .doc(discId)
          .snapshots();
      _messagesStream = FirebaseFirestore.instance
          .collection('discussions')
          .doc(discId)
          .collection('messages')
          .snapshots();
    } else {
      _discussionStream = null;
      _messagesStream = null;
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
    _isDraft = widget.discussionId.isEmpty;
    _initStreams();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && _showAttachmentPanel) {
        setState(() {
          _showAttachmentPanel = false;
        });
      }
    });
    _loadCurrentUserName();
    _checkExistingPrivateChatInBackground();
  }

  @override
  void didUpdateWidget(covariant ChatRoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.discussionId != oldWidget.discussionId ||
        widget.channelName != oldWidget.channelName) {
      _currentDiscussionId = widget.discussionId;
      _isDraft = widget.discussionId.isEmpty;
      _initialScrollDone = false;
      _lastMessageCount = -1;
      _lastMarkedUnreadMsgId = null;
      _discussionMembers = [];
      _initStreams();
      setState(() {});
    }
  }

  void _checkExistingPrivateChatInBackground() async {
    if (!_isDraft || widget.targetUserUid == null || widget.targetUserUid!.isEmpty) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('discussions')
          .where('isPrivate', isEqualTo: true)
          .where('memberUids', arrayContains: currentUid)
          .get();
      for (var doc in query.docs) {
        final uids = List<String>.from(doc.data()['memberUids'] ?? []);
        if (uids.contains(widget.targetUserUid) && uids.length == 2) {
          if (mounted) {
            setState(() {
              _currentDiscussionId = doc.id;
              _isDraft = false;
              _initStreams();
            });
          }
          break;
        }
      }
    } catch (_) {}
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
          fontSize: 20.0,
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

  Future<void> _showManualDriveLinkDialog(String pId, String discId) async {
    final user = FirebaseAuth.instance.currentUser;
    String userPubDriveUrl = '';
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        userPubDriveUrl = userDoc.data()?['publicDriveFolderUrl'] as String? ?? '';
      } catch (_) {}
    }

    final folderController = TextEditingController(text: userPubDriveUrl);

    if (!mounted) return;
    final String? link = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.isDarkMode ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.folder_shared_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hubungkan Google Drive',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan link folder Google Drive atau nama folder untuk obrolan ini:',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: folderController,
              autofocus: true,
              style: GoogleFonts.dmSans(color: AppColors.isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'https://drive.google.com/drive/folders/...',
                hintStyle: GoogleFonts.dmSans(color: AppColors.isDarkMode ? Colors.white30 : Colors.black26),
                filled: true,
                fillColor: AppColors.isDarkMode ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, folderController.text.trim()),
            child: Text('Simpan & Hubungkan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (link != null && link.isNotEmpty) {
      String folderId = link;
      if (folderId.contains('folders/')) {
        folderId = folderId.split('folders/').last.split('?').first.split('/').first;
      }
      final folderUrl = folderId.startsWith('http') ? folderId : 'https://drive.google.com/drive/folders/$folderId';

      if (pId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('projects').doc(pId).update({
          'driveFolderId': folderId,
          'driveFolderUrl': folderUrl,
        });
      }
      if (discId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('discussions').doc(discId).update({
          'driveFolderId': folderId,
          'driveFolderUrl': folderUrl,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder Google Drive berhasil dihubungkan ke obrolan ini!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showFolderSelectorDialog([String? targetProjectId]) async {
    final String pId = targetProjectId ?? widget.projectId ?? '';
    final String discId = _currentDiscussionId;

    GoogleSignInAccount? account;
    try {
      try {
        await GoogleSignIn.instance.initialize(
          clientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
          serverClientId: '441060738052-j0h3plr6ne53408dh25jdb7akh7fou09.apps.googleusercontent.com',
        );
      } catch (_) {}

      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt != null) {
        account = await attempt;
      }
      if (account == null) {
        account = await GoogleSignIn.instance.authenticate();
      }
    } catch (e) {
      await _showManualDriveLinkDialog(pId, discId);
      return;
    }

    if (account == null) {
      await _showManualDriveLinkDialog(pId, discId);
      return;
    }

    try {
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
                          pId.isNotEmpty ? 'Pilih Folder Google Drive Kelas' : 'Pilih Folder Google Drive Obrolan',
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
                            if (pId.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('projects').doc(pId).update({
                                'driveFolderId': folderId,
                                'driveFolderUrl': 'https://drive.google.com/drive/folders/$folderId',
                                'driveAccessToken': accessToken,
                                'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
                              });
                            }
                            if (discId.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('discussions').doc(discId).update({
                                'driveFolderId': folderId,
                                'driveFolderUrl': 'https://drive.google.com/drive/folders/$folderId',
                                'driveAccessToken': accessToken,
                                'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
                              });
                            }

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
                                      if (pId.isNotEmpty) {
                                        await FirebaseFirestore.instance.collection('projects').doc(pId).update({
                                          'driveFolderId': folder.id,
                                          'driveFolderUrl': 'https://drive.google.com/drive/folders/${folder.id}',
                                          'driveAccessToken': accessToken,
                                          'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
                                        });
                                      }
                                      if (discId.isNotEmpty) {
                                        await FirebaseFirestore.instance.collection('discussions').doc(discId).update({
                                          'driveFolderId': folder.id,
                                          'driveFolderUrl': 'https://drive.google.com/drive/folders/${folder.id}',
                                          'driveAccessToken': accessToken,
                                          'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
                                        });
                                      }

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

  
  Future<String> _generateMicroThumbnail(Uint8List rawBytes) async {
    try {
      final img.Image? decodedNullable = img.decodeImage(rawBytes);
      if (decodedNullable == null) return '';
      // Micro thumbnail around 60-80px width (~2-5 KB)
      final img.Image thumbImg = img.copyResize(
        decodedNullable,
        width: decodedNullable.width > decodedNullable.height ? 80 : null,
        height: decodedNullable.height >= decodedNullable.width ? 80 : null,
      );
      final Uint8List thumbBytes = Uint8List.fromList(img.encodeJpg(thumbImg, quality: 20));
      return 'data:image/jpeg;base64,${base64Encode(thumbBytes)}';
    } catch (e) {
      debugPrint('Error generating micro thumbnail: $e');
      return '';
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

  Future<Map<String, String?>> _getDiscussionDriveInfo() async {
    String? driveFolderId;
    String? driveAccessToken;
    String? driveFolderUrl;
    String? rootFolderId;

    final String activeDiscId = _currentDiscussionId.isNotEmpty
        ? _currentDiscussionId
        : (widget.discussionId.isNotEmpty ? widget.discussionId : 'diskusi_${DateTime.now().millisecondsSinceEpoch}');
    final String pId = widget.projectId ?? '';

    // 1. Cek apakah ini Chat Diskusi Kelas (terikat Project)
    bool isClassDiscussion = false;
    String? teacherUid;

    if (pId.isNotEmpty) {
      isClassDiscussion = true;
      try {
        final projDoc = await FirebaseFirestore.instance.collection('projects').doc(pId).get();
        if (projDoc.exists) {
          final pData = projDoc.data();
          rootFolderId = pData?['driveFolderId'] as String?;
          driveAccessToken = pData?['driveAccessToken'] as String?;
          teacherUid = (pData?['teacherUid'] ?? pData?['guruUid'] ?? pData?['creatorUid']) as String?;
        }
      } catch (_) {}
    }

    if (!isClassDiscussion && _currentDiscussionId.isNotEmpty && !_isDraft) {
      try {
        final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).get();
        if (discDoc.exists) {
          final dData = discDoc.data();
          final String discProjId = dData?['projectId'] as String? ?? '';
          if (discProjId.isNotEmpty) {
            isClassDiscussion = true;
            final projDoc = await FirebaseFirestore.instance.collection('projects').doc(discProjId).get();
            if (projDoc.exists) {
              final pData = projDoc.data();
              rootFolderId = pData?['driveFolderId'] as String?;
              driveAccessToken = pData?['driveAccessToken'] as String?;
              teacherUid = (pData?['teacherUid'] ?? pData?['guruUid'] ?? pData?['creatorUid']) as String?;
            }
          } else {
            // Chat pribadi / teman
            rootFolderId = dData?['driveFolderId'] as String?;
            driveAccessToken = dData?['driveAccessToken'] as String?;
          }
        }
      } catch (_) {}
    }

    // Jika chat kelas dan rootFolderId belum terdeteksi di project, cari di dokumen Guru (publicDriveFolderId guru)
    if (isClassDiscussion && (rootFolderId == null || rootFolderId.isEmpty) && teacherUid != null && teacherUid.isNotEmpty) {
      try {
        final guruDoc = await FirebaseFirestore.instance.collection('users').doc(teacherUid).get();
        if (guruDoc.exists) {
          rootFolderId = guruDoc.data()?['publicDriveFolderId'] as String?;
        }
      } catch (_) {}
    }

    // Jika chat pribadi / teman dan root belum ada, ambil dari Google Drive user saat ini (menu Dokumen)
    if (!isClassDiscussion && (rootFolderId == null || rootFolderId.isEmpty)) {
      final curUser = FirebaseAuth.instance.currentUser;
      if (curUser != null) {
        try {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(curUser.uid).get();
          rootFolderId = uDoc.data()?['publicDriveFolderId'] as String?;
        } catch (_) {}
      }
    }

    // Coba dapatkan access token aktif secara silent (TIDAK membuka prompt interaktif agar tidak kedip-kedip)
    if (driveAccessToken == null || driveAccessToken.isEmpty) {
      try {
        final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (account != null) {
          final auth = await account.authorizationClient.authorizeScopes([drive.DriveApi.driveFileScope]);
          driveAccessToken = auth.accessToken;
        }
      } catch (_) {}
    }

    // Jika rootFolderId dan driveAccessToken tersedia, pastikan struktur subfolder Data/diskusi/{Id diskusi} dibuat
    if (rootFolderId != null && rootFolderId.isNotEmpty && driveAccessToken != null && driveAccessToken.isNotEmpty) {
      try {
        final subFolderId = await GoogleDriveService.getOrCreateNestedPath(
          accessToken: driveAccessToken,
          rootFolderId: rootFolderId,
          pathSegments: ['Data', 'diskusi', activeDiscId],
        );
        driveFolderId = subFolderId;
        driveFolderUrl = 'https://drive.google.com/drive/folders/$subFolderId';

        // Simpan ke dokumen diskusi jika sudah ada
        if (_currentDiscussionId.isNotEmpty && !_isDraft) {
          await FirebaseFirestore.instance.collection('discussions').doc(_currentDiscussionId).update({
            'driveFolderId': driveFolderId,
            'driveFolderUrl': driveFolderUrl,
            'discussionSubFolderId': driveFolderId,
            'discussionSubFolderUrl': driveFolderUrl,
          });
        }
      } catch (_) {
        driveFolderId = rootFolderId;
        driveFolderUrl = 'https://drive.google.com/drive/folders/$rootFolderId';
      }
    } else {
      driveFolderId = rootFolderId;
      driveFolderUrl = rootFolderId != null ? 'https://drive.google.com/drive/folders/$rootFolderId' : null;
    }

    return {
      'folderId': driveFolderId,
      'accessToken': driveAccessToken,
      'folderUrl': driveFolderUrl,
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _toggleAttachmentPanel() {
    if (_showAttachmentPanel) {
      setState(() {
        _showAttachmentPanel = false;
      });
      _inputFocusNode.requestFocus();
    } else {
      _inputFocusNode.unfocus();
      setState(() {
        _showAttachmentPanel = true;
      });
    }
  }

  Widget _buildAttachmentBottomPanel(bool isDark, bool showCpFeatures, String projectId) {
    final List<Map<String, dynamic>> items = [
      {
        'id': 'camera',
        'label': 'Kamera',
        'icon': Icons.camera_alt_rounded,
        'color': const Color(0xFF7C3AED),
        'onTap': () {
          setState(() => _showAttachmentPanel = false);
          _pickAndSendMedia(isImage: true);
        },
      },
      {
        'id': 'gallery',
        'label': 'Galeri',
        'icon': Icons.photo_library_rounded,
        'color': const Color(0xFFEC4899),
        'onTap': () {
          setState(() => _showAttachmentPanel = false);
          _pickAndSendMedia(isImage: true);
        },
      },
      {
        'id': 'document',
        'label': 'Dokumen',
        'icon': Icons.insert_drive_file_rounded,
        'color': const Color(0xFF2563EB),
        'onTap': () {
          setState(() => _showAttachmentPanel = false);
          _pickAndSendMedia(isImage: false);
        },
      },
      if (showCpFeatures) ...[
        {
          'id': 'tugas',
          'label': 'Link Tugas',
          'icon': Icons.assignment_rounded,
          'color': const Color(0xFFD97706),
          'onTap': () {
            setState(() => _showAttachmentPanel = false);
            _showSelectCpItemDialog(type: 'tugas', projectId: projectId, isDark: isDark);
          },
        },
        {
          'id': 'materi',
          'label': 'Link Materi',
          'icon': Icons.menu_book_rounded,
          'color': const Color(0xFF059669),
          'onTap': () {
            setState(() => _showAttachmentPanel = false);
            _showSelectCpItemDialog(type: 'materi', projectId: projectId, isDark: isDark);
          },
        },
        {
          'id': 'quiz',
          'label': 'Link Quiz',
          'icon': Icons.extension_rounded,
          'color': const Color(0xFF6366F1),
          'onTap': () {
            setState(() => _showAttachmentPanel = false);
            _showSelectCpItemDialog(type: 'quiz', projectId: projectId, isDark: isDark);
          },
        },
      ],
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: showCpFeatures ? 175 : 90,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      color: Colors.transparent,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final color = item['color'] as Color;
          final icon = item['icon'] as IconData;
          final label = item['label'] as String;
          final onTap = item['onTap'] as VoidCallback;

          return GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSelectCpItemDialog({
    required String type, // 'tugas' | 'materi' | 'quiz'
    required String projectId,
    required bool isDark,
  }) async {
    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tautan hanya tersedia untuk ruang diskusi kelas.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: ThreeDotsLoader()),
    );

    List<Map<String, dynamic>> stages = [];
    String projectTitle = 'Kelas';
    try {
      final doc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        projectTitle = data['title'] ?? 'Kelas';
        final rawStages = data['stages'] ?? data['learningStages'] ?? [];
        if (rawStages is List) {
          stages = rawStages.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching stages: $e');
    }

    if (mounted) {
      Navigator.pop(context); // close loader
    }

    if (stages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belum ada Capaian Pembelajaran (CP) di kelas ini.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    int selectedCpIdx = 0;
    int selectedItemIdx = 0;

    String typeTitle = 'Tugas';
    IconData typeIcon = Icons.assignment_rounded;
    Color typeColor = const Color(0xFFF59E0B);
    if (type == 'materi') {
      typeTitle = 'Materi';
      typeIcon = Icons.menu_book_rounded;
      typeColor = const Color(0xFF10B981);
    } else if (type == 'quiz') {
      typeTitle = 'Quiz';
      typeIcon = Icons.extension_rounded;
      typeColor = const Color(0xFF6366F1);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentStage = stages[selectedCpIdx];
            final cpTitle = currentStage['title'] ?? currentStage['name'] ?? 'CP ${selectedCpIdx + 1}';

            List<Map<String, dynamic>> itemsForType = [];
            if (type == 'tugas') {
              final raw = currentStage['tasks'] ?? currentStage['tugas'] ?? [];
              if (raw is List) {
                itemsForType = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              }
            } else if (type == 'materi') {
              final raw = currentStage['materials'] ?? currentStage['materi'] ?? [];
              if (raw is List) {
                itemsForType = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              }
            } else if (type == 'quiz') {
              final raw = currentStage['quizzes'] ?? currentStage['quiz'] ?? [];
              if (raw is List) {
                itemsForType = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              }
            }

            if (selectedItemIdx >= itemsForType.length) {
              selectedItemIdx = 0;
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Link $typeTitle dari CP',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Tautan interaktif akan dikirim ke obrolan',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dropdown 1: Pilih Capaian Pembelajaran (CP)
                  Text(
                    '1. Pilih Capaian Pembelajaran (CP):',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedCpIdx,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        items: List.generate(stages.length, (idx) {
                          final st = stages[idx];
                          final name = st['title'] ?? st['name'] ?? 'CP ${idx + 1}';
                          return DropdownMenuItem<int>(
                            value: idx,
                            child: Text(
                              'CP ${idx + 1}: $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedCpIdx = val;
                              selectedItemIdx = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dropdown 2: Pilih Item (Tugas / Materi / Quiz)
                  Text(
                    '2. Pilih $typeTitle:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (itemsForType.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Belum ada $typeTitle di CP ini.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedItemIdx,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                          items: List.generate(itemsForType.length, (i) {
                            final it = itemsForType[i];
                            final itemTitle = it['title'] ?? it['name'] ?? '$typeTitle ${i + 1}';
                            return DropdownMenuItem<int>(
                              value: i,
                              child: Text(
                                itemTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedItemIdx = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            side: BorderSide(
                              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: itemsForType.isEmpty
                              ? null
                              : () async {
                                  final chosenItem = itemsForType[selectedItemIdx];
                                  final chosenTitle = chosenItem['title'] ?? chosenItem['name'] ?? '$typeTitle ${selectedItemIdx + 1}';
                                  Navigator.pop(sheetCtx);

                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) return;
                                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                  final senderName = userDoc.data()?['name'] ?? 'User';
                                  final senderAvatar = userDoc.data()?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';
                                  final targetDocId = _currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId;

                                  final String msgText = type == 'tugas'
                                      ? '📝 Tautan Tugas: $chosenTitle'
                                      : (type == 'materi'
                                          ? '📚 Tautan Materi: $chosenTitle'
                                          : '🧩 Tautan Quiz: $chosenTitle');

                                  await FirebaseFirestore.instance
                                      .collection('discussions')
                                      .doc(targetDocId)
                                      .collection('messages')
                                      .add({
                                    'sender': senderName,
                                    'senderUid': user.uid,
                                    'avatar': senderAvatar,
                                    'message': msgText,
                                    'cpLinkType': type,
                                    'cpLinkData': {
                                      'type': type,
                                      'projectId': projectId,
                                      'projectTitle': projectTitle,
                                      'cpIndex': selectedCpIdx,
                                      'cpTitle': cpTitle,
                                      'itemTitle': chosenTitle,
                                      'itemData': chosenItem,
                                    },
                                    'time': FieldValue.serverTimestamp(),
                                  });

                                  final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(targetDocId).get();
                                  final memberUids = List<String>.from(discDoc.data()?['memberUids'] ?? []);

                                  final Map<String, dynamic> updates = {
                                    'lastMessage': '$senderName membagikan $typeTitle: $chosenTitle',
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
                                  await FirebaseFirestore.instance.collection('discussions').doc(targetDocId).update(updates);
                                  _scrollToBottom();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: typeColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Kirim Tautan',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildCpLinkCard({
    required Map<String, dynamic> cpLinkData,
    required bool isMe,
    required bool isDark,
    required String timeText,
  }) {
    final type = cpLinkData['type'] as String? ?? 'tugas';
    final projectId = cpLinkData['projectId'] as String? ?? '';
    final projectTitle = cpLinkData['projectTitle'] as String? ?? 'Kelas';
    final cpIndex = cpLinkData['cpIndex'] as int? ?? 0;
    final cpTitle = cpLinkData['cpTitle'] as String? ?? '';
    final itemTitle = cpLinkData['itemTitle'] as String? ?? '';
    final itemData = cpLinkData['itemData'] as Map<String, dynamic>? ?? {};

    IconData typeIcon = Icons.assignment_rounded;
    String badgeText = 'TUGAS CP';
    Color badgeColor = const Color(0xFFF59E0B);
    String buttonText = 'Buka Tugas';

    if (type == 'materi') {
      typeIcon = Icons.menu_book_rounded;
      badgeText = 'MATERI CP';
      badgeColor = const Color(0xFF10B981);
      buttonText = 'Buka Materi';
    } else if (type == 'quiz') {
      typeIcon = Icons.extension_rounded;
      badgeText = 'KUIS CP';
      badgeColor = const Color(0xFF6366F1);
      buttonText = 'Mulai Kuis';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.18))
            : (isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(typeIcon, color: badgeColor, size: 15),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  timeText,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: isMe ? Colors.white60 : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ],
            ),
          ),

          // Body: CP & Title
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cpTitle.isNotEmpty) ...[
                  Text(
                    cpTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: isMe ? Colors.white70 : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  itemTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 10),

                // Interactive Button
                GestureDetector(
                  onTap: () async {
                    if (type == 'materi') {
                      final driveLink = itemData['driveLink'] ?? itemData['fileUrl'] ?? itemData['link'] ?? '';
                      if (driveLink.toString().isNotEmpty) {
                        final uri = Uri.parse(driveLink.toString());
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return;
                        }
                      }
                    }
                    if (context.mounted && projectId.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetailCpPage(
                            projectId: projectId,
                            projectTitle: projectTitle,
                            stageIdx: cpIndex,
                            isOwner: _userRole == 'guru',
                            accentColor: const Color(0xFF7C3AED),
                            cardColor: const Color(0xFFD6A5F8),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendMedia({required bool isImage}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: isImage ? FileType.image : FileType.any,
      );
      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      Uint8List rawBytes;
      if (kIsWeb) {
        rawBytes = pickedFile.bytes!;
      } else {
        rawBytes = await File(pickedFile.path!).readAsBytes();
      }

      bool isHd = false;
      String caption = '';

      if (isImage) {
        if (!mounted) return;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final previewResult = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (dialogCtx) => ImagePreviewSendDialog(
              imageBytes: rawBytes,
              fileName: pickedFile.name,
              isDark: isDark,
            ),
            fullscreenDialog: true,
          ),
        );

        if (previewResult == null) {
          // User cancelled sending
          return;
        }

        isHd = previewResult['isHd'] as bool? ?? false;
        caption = previewResult['caption'] as String? ?? '';
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
            ),
          ),
        ),
      );

      Uint8List uploadBytes = rawBytes;
      String uploadFileName = pickedFile.name;
      String thumbnailLink = '';

      if (isImage) {
        // 1. Generate micro thumbnail (~2-5 KB) for instant progressive blur rendering
        thumbnailLink = await _generateMicroThumbnail(rawBytes);

        // 2. Compress or keep HD based on user choice
        if (!isHd) {
          uploadBytes = await _compressImageToMax200Kb(rawBytes);
        }

        if (!uploadFileName.toLowerCase().endsWith('.jpg') && !uploadFileName.toLowerCase().endsWith('.jpeg')) {
          uploadFileName = '${uploadFileName.split('.').first}.jpg';
        }
      }

      String imageLink = '';
      String fileLink = '';

      if (isImage) {
        imageLink = 'data:image/jpeg;base64,${base64Encode(uploadBytes)}';
      }

      // Check Drive info silently without triggering interactive OAuth prompts
      String? driveFolderId;
      String? driveAccessToken;
      String driveFolderUrl = '';

      try {
        final driveInfo = await _getDiscussionDriveInfo();
        driveFolderId = driveInfo['folderId'];
        driveAccessToken = driveInfo['accessToken'];
        driveFolderUrl = driveInfo['folderUrl'] ?? '';

        // If it's a non-image file and drive token is already ready, upload to drive
        if (!isImage && driveFolderId != null && driveFolderId.isNotEmpty && driveAccessToken != null && driveAccessToken.isNotEmpty) {
          final uploadResult = await GoogleDriveService.uploadFile(
            accessToken: driveAccessToken,
            folderId: driveFolderId,
            fileName: uploadFileName,
            bytes: uploadBytes,
          );
          fileLink = uploadResult['directLink'] ?? uploadResult['viewLink'] ?? driveFolderUrl;
        }
      } catch (e) {
        debugPrint('Silent drive check error: $e');
      }

      if (!isImage && fileLink.isEmpty) {
        fileLink = driveFolderUrl;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'User';
      final senderAvatar = userDoc.data()?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

      String targetDocId = _currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId;

      // If draft private chat, create discussion doc in Firestore
      if (_isDraft || targetDocId.isEmpty) {
        final newDoc = await FirebaseFirestore.instance.collection('discussions').add({
          'channel': '@${widget.channelName.toLowerCase().replaceAll(' ', '')}',
          'title': widget.channelName,
          'avatar': widget.targetUserAvatar ?? 'assets/icon_pack/avatar/sma_1.png',
          'isPrivate': true,
          'memberUids': [user.uid, widget.targetUserUid ?? ''],
          'lastMessage': isImage
              ? '$senderName: 📷 Foto${caption.isNotEmpty ? ' $caption' : ''}'
              : '$senderName mengirim berkas',
          'time': 'Sekarang',
          if (driveFolderId != null && driveFolderId.isNotEmpty) 'driveFolderId': driveFolderId,
          if (driveFolderUrl.isNotEmpty) 'driveFolderUrl': driveFolderUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'colorIndex': Random().nextInt(5),
        });
        targetDocId = newDoc.id;
        _currentDiscussionId = newDoc.id;
        _isDraft = false;
        _initStreams();
        if (mounted) setState(() {});
      }

      final String fileExt = pickedFile.name.contains('.') ? pickedFile.name.split('.').last.toLowerCase() : '';
      final String formattedSize = _formatFileSize(pickedFile.size);

      // Send message with media info
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(targetDocId)
          .collection('messages')
          .add({
        'sender': senderName,
        'senderUid': user.uid,
        'avatar': senderAvatar,
        'message': isImage ? caption : '[Berkas: $uploadFileName]',
        if (isImage) ...{
          'imageUrl': imageLink,
          'thumbnailUrl': thumbnailLink,
          'isHd': isHd,
        },
        if (!isImage) ...{
          'fileUrl': fileLink,
          'fileName': uploadFileName,
          'fileSize': formattedSize,
          'fileExtension': fileExt,
        },
        'time': FieldValue.serverTimestamp(),
        if (_replyingToMessage != null) ...{
          'replyToSender': _replyingToMessage!['sender'],
          'replyToText': _replyingToMessage!['message'],
          'replyToImageUrl': _replyingToMessage!['imageUrl'] ?? '',
        },
      });

      // Auto-save to Dokumen -> Berkas Diskusi in Firestore
      try {
        final diskFolderQuery = await FirebaseFirestore.instance
            .collection('driveDocuments')
            .where('name', isEqualTo: 'Berkas Diskusi')
            .where('isFolder', isEqualTo: true)
            .limit(1)
            .get();

        String diskFolderId;
        if (diskFolderQuery.docs.isNotEmpty) {
          diskFolderId = diskFolderQuery.docs.first.id;
        } else {
          final newFolder = await FirebaseFirestore.instance.collection('driveDocuments').add({
            'name': 'Berkas Diskusi',
            'mimeType': 'application/vnd.google-apps.folder',
            'isFolder': true,
            'parentFolderId': '',
            'driveFileId': '',
            'driveLink': '',
            'uploaderUid': user.uid,
            'uploaderName': 'Sistem',
            'fileSize': 0,
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          diskFolderId = newFolder.id;
        }

        final String channelFolderName = widget.channelName.isNotEmpty ? widget.channelName : 'Umum';
        final subFolderQuery = await FirebaseFirestore.instance
            .collection('driveDocuments')
            .where('name', isEqualTo: channelFolderName)
            .where('parentFolderId', isEqualTo: diskFolderId)
            .where('isFolder', isEqualTo: true)
            .limit(1)
            .get();

        String channelFolderDocId;
        if (subFolderQuery.docs.isNotEmpty) {
          channelFolderDocId = subFolderQuery.docs.first.id;
        } else {
          final newSub = await FirebaseFirestore.instance.collection('driveDocuments').add({
            'name': channelFolderName,
            'mimeType': 'application/vnd.google-apps.folder',
            'isFolder': true,
            'parentFolderId': diskFolderId,
            'driveFileId': '',
            'driveLink': '',
            'uploaderUid': user.uid,
            'uploaderName': 'Sistem',
            'fileSize': 0,
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          channelFolderDocId = newSub.id;
        }

        await FirebaseFirestore.instance.collection('driveDocuments').add({
          'name': uploadFileName,
          'mimeType': isImage ? 'image/jpeg' : (fileExt.isNotEmpty ? 'application/$fileExt' : 'application/octet-stream'),
          'isFolder': false,
          'parentFolderId': channelFolderDocId,
          'driveFileId': '',
          'driveLink': isImage ? imageLink : fileLink,
          'uploaderUid': user.uid,
          'uploaderName': senderName,
          'uploaderAvatar': senderAvatar,
          'discussionId': targetDocId,
          'fileSize': pickedFile.size,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error syncing chat file to driveDocuments: $e');
      }

      if (_replyingToMessage != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      // Update last message in discussion
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(targetDocId).get();
      final memberUids = List<String>.from(discDoc.data()?['memberUids'] ?? []);

      final Map<String, dynamic> updates = {
        'lastMessage': isImage ? '$senderName mengirim gambar' : '$senderName mengirim berkas: $uploadFileName',
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
      await FirebaseFirestore.instance.collection('discussions').doc(targetDocId).update(updates);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim lampiran: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String targetDocId = _currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId;

    if (_editingMessageId != null) {
      final editId = _editingMessageId!;
      _messageController.clear();
      setState(() {
        _editingMessageId = null;
      });

      try {
        await FirebaseFirestore.instance
            .collection('discussions')
            .doc(targetDocId)
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
      if (_isDraft || targetDocId.isEmpty) {
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
        targetDocId = newDoc.id;
        _currentDiscussionId = newDoc.id;
        _isDraft = false;
        _initStreams();
        if (mounted) setState(() {});
      }

      // 1. Add message to discussions subcollection
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(targetDocId)
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
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(targetDocId).get();
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
          .doc(targetDocId)
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
    _showScrollToBottom.dispose();
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
      final dId = _currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId;
      if (dId.isNotEmpty) {
        final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(dId).get();
        if (discDoc.exists) {
          final discMemberUids = List<String>.from(discDoc.data()?['memberUids'] ?? []);
          allMemberUidSet.addAll(discMemberUids);
        }
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
    if (projectId.isEmpty) {
      _showEditDiscussionDialog(context, discData, []);
      return;
    }

    final members = await _loadProjectMembers(projectId);
    if (context.mounted) {
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
    bool isManagingMembers = false;

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
            final activeSelectedMembers = projectMembers
                .where((m) => selectedMemberUids.contains(m['uid']))
                .toList();
            final availableToAdd = projectMembers
                .where((m) => !selectedMemberUids.contains(m['uid']))
                .toList();

            // Helper to build stacked avatars (clickable, no Kelola button)
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

            void showAddMemberSheet() {
              showModalBottomSheet(
                context: context,
                backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (addCtx) {
                  final currentAvailable = projectMembers
                      .where((m) => !selectedMemberUids.contains(m['uid']))
                      .toList();
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
                        if (currentAvailable.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Semua anggota kelas sudah tergabung.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: currentAvailable.length,
                              separatorBuilder: (_, __) => Divider(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (aCtx, aIdx) {
                                final cand = currentAvailable[aIdx];
                                final candUid = cand['uid'] as String;
                                final candName = cand['name'] ?? 'User';
                                final candAvatar = cand['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                    ),
                                    child: ClipOval(
                                      child: Transform.scale(
                                        scale: 1.35,
                                        child: Image.asset(candAvatar, fit: BoxFit.cover),
                                      ),
                                    ),
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
                                      setModalState(() {
                                        selectedMemberUids.add(candUid);
                                      });
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
            }

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
                              onTap: () {
                                if (isManagingMembers) {
                                  setModalState(() {
                                    isManagingMembers = false;
                                  });
                                } else {
                                  Navigator.pop(modalCtx);
                                }
                              },
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
                                  Icons.arrow_back_rounded,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                            Text(
                              isManagingMembers ? 'Kelola Anggota' : 'Edit Diskusi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        if (isManagingMembers) ...[
                          if ((isUserAdmin || canAllMembersInvite) && availableToAdd.isNotEmpty)
                            GestureDetector(
                              onTap: showAddMemberSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
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
                        ] else ...[
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BODY (Switches between Kelola Anggota and Edit Diskusi)
                  if (isManagingMembers)
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                        ),
                        itemCount: activeSelectedMembers.length,
                        separatorBuilder: (_, __) => Divider(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                          height: 1,
                          indent: 56,
                        ),
                        itemBuilder: (ctx, i) {
                          final m = activeSelectedMembers[i];
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
                                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
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
                                      setModalState(() {
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
                                      setModalState(() {
                                        selectedMemberUids.remove(mUid);
                                        adminUids.remove(mUid);
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else
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
                            // 1. Channel Name & Icon Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar circle
                                GestureDetector(
                                  onTap: canEditGroupInfo
                                      ? () {
                                          setModalState(() {
                                            showAvatarSlider = !showAvatarSlider;
                                          });
                                        }
                                      : null,
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                        width: 2,
                                      ),
                                    ),
                                    child: isDefaultGroupIcon
                                        ? const Center(
                                            child: Icon(
                                              Icons.groups_rounded,
                                              color: Color(0xFF0F766E),
                                              size: 32,
                                            ),
                                          )
                                        : ClipOval(
                                            child: Transform.scale(
                                              scale: 1.35,
                                              child: Image.asset(selectedAvatar, fit: BoxFit.cover),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Channel Name input
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: channelController,
                                        enabled: canEditGroupInfo,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Nama Channel (cth: diskusi-ipa)',
                                          hintStyle: GoogleFonts.dmSans(
                                            color: isDark ? Colors.white38 : Colors.black38,
                                            fontSize: 13.5,
                                          ),
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.only(left: 14, right: 8),
                                            child: Text(
                                              '#',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 18.0,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(24),
                                            borderSide: BorderSide(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(24),
                                            borderSide: BorderSide(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
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

                            const SizedBox(height: 16),

                            // 2. Title / Deskripsi
                            Text(
                              'Nama Lengkap / Topik Diskusi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: titleController,
                              enabled: canEditGroupInfo,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Masukkan topik diskusi...',
                                hintStyle: GoogleFonts.dmSans(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 13.5,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // 3. Classroom Info & Anggota Stack (Clickable to switch view, NO Kelola button)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                  // Clickable member stack to open member management in same modal
                                  InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        isManagingMembers = true;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          buildStackedAvatars(activeSelectedMembers),
                                        ],
                                      ),
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
                                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.admin_panel_settings_rounded,
                                        size: 18,
                                        color: Color(0xFF0F766E),
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
        Text.rich(
          TextSpan(
            children: _buildMessageSpans(text, _currentUserName, context, isMe),
            style: GoogleFonts.dmSans(
              fontSize: 20.0,
              color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
              height: 1.3,
            ),
          ),
        ),
        if (timeText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              timeText,
              style: GoogleFonts.dmSans(
                fontSize: 15.0,
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

  Widget _buildSafeAvatar(String? avatar) {
    final String raw = (avatar ?? '').trim();
    if (raw.isEmpty) {
      return Image.asset('assets/icon_pack/avatar/avatar_2.png', fit: BoxFit.cover);
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(
        raw,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset('assets/icon_pack/avatar/avatar_2.png', fit: BoxFit.cover),
      );
    }
    String assetPath = raw;
    if (!assetPath.startsWith('assets/')) {
      if (assetPath.startsWith('icon_pack/')) {
        assetPath = 'assets/$assetPath';
      } else {
        assetPath = 'assets/icon_pack/avatar/$assetPath';
      }
    }
    if (!assetPath.toLowerCase().endsWith('.png') &&
        !assetPath.toLowerCase().endsWith('.jpg') &&
        !assetPath.toLowerCase().endsWith('.jpeg') &&
        !assetPath.toLowerCase().endsWith('.webp')) {
      assetPath = '$assetPath.png';
    }
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset('assets/icon_pack/avatar/avatar_2.png', fit: BoxFit.cover),
    );
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
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141416) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                            width: 1.0,
                          ),
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
                                  child: _buildSafeAvatar(avatar),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            padding: EdgeInsets.fromLTRB(12, replyData != null ? 6 : 8, 12, 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? (isDark ? const Color(0xFF141416).withValues(alpha: 0.85) : Colors.black)
                                  : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: isMe
                                    ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.transparent)
                                    : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                                width: 1.0,
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
                                          : (isDark ? Colors.black.withValues(alpha: 0.35) : Colors.white),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMe
                                            ? Colors.transparent
                                            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          replyData['sender'] ?? 'User',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.bold,
                                            color: isMe ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                          ),
                                        ),
                                        Text(
                                          replyData['message'] == '[Gambar Lampiran]'
                                              ? '📷 Foto'
                                              : (replyData['message'] ?? ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 16.5,
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
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : senderColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (imageUrl.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 240),
                                      child: Builder(
                                        builder: (context) {
                                          if (imageUrl.startsWith('data:image') && imageUrl.contains(',')) {
                                            try {
                                              final b64 = imageUrl.split(',').last;
                                              final bytes = base64Decode(b64);
                                              return Image.memory(bytes, fit: BoxFit.cover);
                                            } catch (_) {}
                                          }
                                          return Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                          );
                                        },
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
                                  child: _buildSafeAvatar(avatar),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 135,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141416) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
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
                              Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
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
                                Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                              ],
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == 'Gelap' || themeMode == 'Hitam';

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
            stream: _discussionStream ??
                ((_currentDiscussionId.isNotEmpty || widget.discussionId.isNotEmpty)
                    ? FirebaseFirestore.instance
                        .collection('discussions')
                        .doc(_currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId)
                        .snapshots()
                    : null),
            builder: (context, discSnapshot) {
              final discData = discSnapshot.data?.data() as Map<String, dynamic>?;
              final channelTitle = discData?['channel'] ?? widget.channelName;
              final channelDesc = discData?['title'] ?? '';
              final isPrivate = _isDraft ? true : (discData?['isPrivate'] ?? false);
              final memberUids = List<String>.from(discData?['memberUids'] ?? []);
              final memberCount = memberUids.isNotEmpty ? memberUids.length : 1;
              final subtitle = isPrivate ? 'Obrolan Pribadi' : '$channelDesc • $memberCount anggota';
              final projectId = discData?['projectId'] as String? ?? widget.projectId ?? '';
              final bool showCpFeatures = !isPrivate && projectId.isNotEmpty;
              final isOwner = discData?['creatorUid'] == currentUid || _userRole == 'guru';

              if (memberUids.isNotEmpty && _discussionMembers.isEmpty) {
                _loadDiscussionMembersOnce(memberUids);
              }

              final double fullScreenHeight = MediaQuery.of(context).size.height;
              final double fullScreenWidth = MediaQuery.of(context).size.width;

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarColor: isDark ? const Color(0xFF000000) : Colors.white,
                  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: Scaffold(
                  backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF3EDFD),
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Sticky Wallpaper background (Does not move or squish when keyboard appears)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedPurpleMicroPatternBackground(
                            isDark: isDark,
                            child: const SizedBox.shrink(),
                          ),
                        ),
                      ),

                      // 2. Main Column: Solid White Header + Full Viewport Messages Stack + Solid White Input Bar
                      Positioned.fill(
                        child: Column(
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
                                      ? const Color(0xFF000000).withValues(alpha: 0.75)
                                      : Colors.white.withValues(alpha: 0.70),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF27272A)
                                          : const Color(0xFFF1F5F9),
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
                            PopupMenuButton<String>(
                              tooltip: '',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                  width: 1.0,
                                ),
                              ),
                              elevation: 6,
                              color: isDark ? const Color(0xFF141416) : Colors.white,
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
                        child: Stack(
                            children: [
                              // 1. Full Screen Messages ListView with 94px bottom padding (completely unobstructed)
                              Positioned.fill(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: (_currentDiscussionId.isNotEmpty || widget.discussionId.isNotEmpty)
                                      ? FirebaseFirestore.instance
                                          .collection('discussions')
                                          .doc(_currentDiscussionId.isNotEmpty ? _currentDiscussionId : widget.discussionId)
                                          .collection('messages')
                                          .snapshots()
                                      : null,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                      return Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isDark ? const Color(0xFF7C3AED) : const Color(0xFF9333EA),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Text(
                                            'Gagal memuat pesan: ${snapshot.error}',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.dmSans(color: Colors.redAccent, fontSize: 13),
                                          ),
                                        ),
                                      );
                                    }
                                    final rawDocs = snapshot.data?.docs ?? [];
                                    final messageDocs = List<QueryDocumentSnapshot>.from(rawDocs);
                                    messageDocs.sort((a, b) {
                                      final aData = a.data() as Map<String, dynamic>;
                                      final bData = b.data() as Map<String, dynamic>;
                                      final aTime = aData['time'] ?? aData['createdAt'] ?? aData['timestamp'];
                                      final bTime = bData['time'] ?? bData['createdAt'] ?? bData['timestamp'];
                                      if (aTime is Timestamp && bTime is Timestamp) {
                                        return aTime.compareTo(bTime);
                                      }
                                      return a.id.compareTo(b.id);
                                    });

                                    // Track mention messages (no setState!)
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
                                      if (!listEquals(_mentionNotifier.value, mentionIds)) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) {
                                            _mentionNotifier.value = mentionIds;
                                          }
                                        });
                                      }
                                    }

                                    // Smart scroll & unread count
                                    final currentCount = messageDocs.length;
                                    if (!_initialScrollDone) {
                                      _initialScrollDone = true;
                                      _lastMessageCount = currentCount;
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _scrollToBottom();
                                        if (!_isDraft && _currentDiscussionId.isNotEmpty && messageDocs.isNotEmpty) {
                                          _lastMarkedUnreadMsgId = messageDocs.last.id;
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

                                        if (!_isDraft && _currentDiscussionId.isNotEmpty && _lastMarkedUnreadMsgId != lastMsgId) {
                                          _lastMarkedUnreadMsgId = lastMsgId;
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            _scrollToBottom();
                                            FirebaseFirestore.instance
                                                .collection('discussions')
                                                .doc(_currentDiscussionId)
                                                .update({
                                              'unreadCounts.$currentUid': 0,
                                            }).catchError((_) {});
                                          });
                                        }
                                      }
                                    }

                                    if (messageDocs.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chat_bubble_outline_rounded,
                                              size: 48,
                                              color: isDark ? Colors.white24 : Colors.black26,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Belum ada pesan di sini.\nMulai obrolan sekarang!',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 15,
                                                color: isDark ? Colors.white60 : Colors.black45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      controller: _scrollController,
                                      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                                      cacheExtent: 500,
                                      padding: const EdgeInsets.only(
                                        left: 14,
                                        right: 14,
                                        top: 16,
                                        bottom: 16,
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
                                        final fileUrl = msgData['fileUrl'] as String? ?? '';
                                        final fileName = msgData['fileName'] as String? ?? '';
                                        final fileSize = msgData['fileSize'] as String? ?? '';
                                        final fileExtension = msgData['fileExtension'] as String? ?? '';
                                        final timeVal = msgData['time'] ?? msgData['createdAt'] ?? msgData['timestamp'];
                                        String timeText = '';
                                        if (timeVal is Timestamp) {
                                          final dt = timeVal.toDate();
                                          final hour = dt.hour.toString().padLeft(2, '0');
                                          final min = dt.minute.toString().padLeft(2, '0');
                                          timeText = '$hour:$min';
                                        } else if (timeVal is String) {
                                          timeText = timeVal;
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
                                        final String thumbnailUrl = msgData['thumbnailUrl'] as String? ?? msgData['thumbnailBase64'] as String? ?? '';
                                        final bool isHdImage = msgData['isHd'] as bool? ?? false;
                                        final cpLinkData = msgData['cpLinkData'] as Map<String, dynamic>?;
                                        final bool isCpLink = cpLinkData != null;
                                        final String rawMsg = message.trim();
                                        String resolvedFileName = fileName;
                                        if (resolvedFileName.isEmpty && rawMsg.startsWith('[Berkas:')) {
                                          resolvedFileName = rawMsg.replaceFirst('[Berkas:', '').replaceAll(']', '').trim();
                                        }
                                        final bool isOnlyImage = imageUrl.isNotEmpty && !isCpLink && (rawMsg.isEmpty || rawMsg == '[Gambar Lampiran]');
                                        final bool isOnlyFile = (fileUrl.isNotEmpty || resolvedFileName.isNotEmpty || rawMsg.startsWith('[Berkas:')) && !isCpLink && (rawMsg.isEmpty || rawMsg.startsWith('[Berkas:'));

                                        return Dismissible(
                                          key: Key('msg_$msgId'),
                                          direction: DismissDirection.startToEnd,
                                          confirmDismiss: (direction) async {
                                            setState(() {
                                              _replyingToMessage = {
                                                'id': msgId,
                                                'sender': senderName,
                                                'message': message.isNotEmpty ? message : (imageUrl.isNotEmpty ? '📷 Foto' : '[Berkas]'),
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
                                                color: isDark ? const Color(0xFF18181B) : Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                                  width: 1.0,
                                                ),
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
                                                          child: _buildSafeAvatar(avatar),
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
                                                          padding: isOnlyImage
                                                              ? const EdgeInsets.all(3)
                                                              : EdgeInsets.fromLTRB(
                                                                  12,
                                                                  replyData != null ? 6 : 8,
                                                                  12,
                                                                  8,
                                                                ),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? (isDark ? const Color(0xFF3B185F) : const Color(0xFF7C3AED))
                                                                : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                                            borderRadius: BorderRadius.only(
                                                              topLeft: const Radius.circular(18),
                                                              topRight: const Radius.circular(18),
                                                              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                                            ),
                                                            border: Border.all(
                                                              color: isMe
                                                                  ? (isDark ? const Color(0xFF6B21A8).withValues(alpha: 0.35) : Colors.transparent)
                                                                  : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                                              width: 1.0,
                                                            ),
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
                                                                          alignment: 0.2,
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
                                                                          : (isDark ? Colors.black.withValues(alpha: 0.35) : Colors.white),
                                                                      borderRadius: BorderRadius.circular(10),
                                                                      border: Border.all(
                                                                        color: isMe
                                                                            ? Colors.transparent
                                                                            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                                                                        width: 0.8,
                                                                      ),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          replyData['sender'] ?? 'User',
                                                                          style: GoogleFonts.plusJakartaSans(
                                                                            fontSize: 16.5,
                                                                            fontWeight: FontWeight.bold,
                                                                            color: isMe ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          replyData['message'] == '[Gambar Lampiran]'
                                                                              ? '📷 Foto'
                                                                              : (replyData['message'] ?? ''),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          style: GoogleFonts.dmSans(
                                                                            fontSize: 16.5,
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
                                                                    fontSize: 18.0,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: isDark ? Colors.white70 : senderColor,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                              ],
                                                              if (imageUrl.isNotEmpty) ...[
                                                                if (isOnlyImage) ...[
                                                                  Stack(
                                                                    children: [
                                                                      BlurImageProgressive(
                                                                        imageUrl: imageUrl,
                                                                        thumbnailUrl: thumbnailUrl,
                                                                        isMe: isMe,
                                                                        isDark: isDark,
                                                                        onTap: () {
                                                                          Navigator.of(context).push(
                                                                            MaterialPageRoute(
                                                                              builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
                                                                            ),
                                                                          );
                                                                        },
                                                                      ),
                                                                      Positioned(
                                                                        bottom: 6,
                                                                        right: 6,
                                                                        child: Container(
                                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                                          decoration: BoxDecoration(
                                                                            color: Colors.black.withValues(alpha: 0.55),
                                                                            borderRadius: BorderRadius.circular(10),
                                                                          ),
                                                                          child: Row(
                                                                            mainAxisSize: MainAxisSize.min,
                                                                            children: [
                                                                              if (isHdImage) ...[
                                                                                Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                                                  margin: const EdgeInsets.only(right: 4),
                                                                                  decoration: BoxDecoration(
                                                                                    color: const Color(0xFF7C3AED),
                                                                                    borderRadius: BorderRadius.circular(4),
                                                                                  ),
                                                                                  child: Text(
                                                                                    'HD',
                                                                                    style: GoogleFonts.plusJakartaSans(
                                                                                      fontSize: 8.5,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      color: Colors.white,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                              Text(
                                                                                timeText,
                                                                                style: GoogleFonts.dmSans(
                                                                                  fontSize: 11.0,
                                                                                  fontWeight: FontWeight.w500,
                                                                                  color: Colors.white.withValues(alpha: 0.95),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ] else ...[
                                                                  BlurImageProgressive(
                                                                    imageUrl: imageUrl,
                                                                    thumbnailUrl: thumbnailUrl,
                                                                    isMe: isMe,
                                                                    isDark: isDark,
                                                                    onTap: () {
                                                                      Navigator.of(context).push(
                                                                        MaterialPageRoute(
                                                                          builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                  const SizedBox(height: 6),
                                                                ],
                                                              ],
                                                              if (fileUrl.isNotEmpty || resolvedFileName.isNotEmpty) ...[
                                                                GestureDetector(
                                                                  onTap: () async {
                                                                    if (fileUrl.isNotEmpty) {
                                                                      final uri = Uri.tryParse(fileUrl);
                                                                      if (uri != null && await canLaunchUrl(uri)) {
                                                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                                        return;
                                                                      }
                                                                    }
                                                                    if (context.mounted) {
                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text('Membuka informasi berkas: $resolvedFileName'),
                                                                          behavior: SnackBarBehavior.floating,
                                                                          duration: const Duration(seconds: 2),
                                                                        ),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: Container(
                                                                    constraints: const BoxConstraints(maxWidth: 240),
                                                                    padding: const EdgeInsets.all(10),
                                                                    decoration: BoxDecoration(
                                                                      color: isMe
                                                                          ? (isDark ? const Color(0xFF581C87).withValues(alpha: 0.5) : const Color(0xFF6D28D9).withValues(alpha: 0.25))
                                                                          : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                                                                      borderRadius: BorderRadius.circular(12),
                                                                      border: Border.all(
                                                                        color: isMe
                                                                            ? const Color(0xFFD6A5F8).withValues(alpha: 0.3)
                                                                            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        (() {
                                                                          final ext = resolvedFileName.contains('.') ? resolvedFileName.split('.').last.toLowerCase() : '';
                                                                          Color badgeBg = const Color(0xFF2563EB);
                                                                          IconData badgeIcon = Icons.insert_drive_file;
                                                                          if (ext == 'pdf') {
                                                                            badgeBg = const Color(0xFFEF4444);
                                                                            badgeIcon = Icons.picture_as_pdf;
                                                                          } else if (ext == 'doc' || ext == 'docx') {
                                                                            badgeBg = const Color(0xFF2563EB);
                                                                            badgeIcon = Icons.description;
                                                                          } else if (ext == 'xls' || ext == 'xlsx') {
                                                                            badgeBg = const Color(0xFF059669);
                                                                            badgeIcon = Icons.table_chart;
                                                                          } else if (ext == 'zip' || ext == 'rar') {
                                                                            badgeBg = const Color(0xFFD97706);
                                                                            badgeIcon = Icons.folder_zip;
                                                                          } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
                                                                            badgeBg = const Color(0xFF8B5CF6);
                                                                            badgeIcon = Icons.image;
                                                                          }
                                                                          return Container(
                                                                            width: 36,
                                                                            height: 36,
                                                                            decoration: BoxDecoration(
                                                                              color: badgeBg.withValues(alpha: 0.2),
                                                                              shape: BoxShape.circle,
                                                                            ),
                                                                            child: Icon(badgeIcon, color: badgeBg, size: 20),
                                                                          );
                                                                        })(),
                                                                        const SizedBox(width: 10),
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            mainAxisSize: MainAxisSize.min,
                                                                            children: [
                                                                              Text(
                                                                                resolvedFileName.isNotEmpty ? resolvedFileName : 'Dokumen',
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                                style: GoogleFonts.plusJakartaSans(
                                                                                  fontSize: 14.5,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                                                ),
                                                                              ),
                                                                              if (fileSize.isNotEmpty) ...[
                                                                                const SizedBox(height: 2),
                                                                                Text(
                                                                                  fileSize,
                                                                                  style: GoogleFonts.dmSans(
                                                                                    fontSize: 12.0,
                                                                                    color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        const SizedBox(width: 6),
                                                                        Icon(
                                                                          Icons.file_download,
                                                                          size: 18,
                                                                          color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black45),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (message.isNotEmpty && !message.startsWith('[Berkas:')) const SizedBox(height: 4),
                                                              ],
                                                              if (isCpLink) ...[
                                                                _buildCpLinkCard(
                                                                  cpLinkData: cpLinkData,
                                                                  isMe: isMe,
                                                                  isDark: isDark,
                                                                  timeText: timeText,
                                                                ),
                                                              ],
                                                              if (message.isNotEmpty && !isOnlyImage && !isOnlyFile && !isCpLink) ...[
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
                                                                        fontSize: 18.0,
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
                                                                      color: isDark ? const Color(0xFF18181B) : Colors.white,
                                                                      borderRadius: BorderRadius.circular(10),
                                                                      border: Border.all(
                                                                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                                                        width: 1.2,
                                                                      ),
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
                              if (!isPrivate)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: ValueListenableBuilder<List<String>>(
                                    valueListenable: _mentionNotifier,
                                    builder: (context, mentionIds, _) {
                                      if (mentionIds.isEmpty) return const SizedBox.shrink();
                                      return GestureDetector(
                                        onTap: () {
                                          final lastMentionId = mentionIds.last;
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
                                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF3EEFF),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFD8B4FE).withValues(alpha: 0.4),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF9333EA)),
                                              const SizedBox(width: 6),
                                              Text(
                                                '@mention (${mentionIds.length})',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF9333EA),
                                                ),
                                              ),
                                              const Spacer(),
                                              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9333EA)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              // 3. Floating Scroll-To-Bottom Button (Kanan di luar card textbox, circular button dengan shadow)
                              Positioned(
                                right: 18,
                                bottom: 16,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _showScrollToBottom,
                                  builder: (context, show, _) {
                                    if (!show) return const SizedBox.shrink();
                                    return BouncyButton(
                                      scaleDown: 0.85,
                                      onTap: () => _scrollToBottom(animate: true),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                            width: 1.0,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Glassmorphic Flat Input Bar (Full width flush to bottom acting as backdrop for Android buttons)
                        ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF000000).withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.85),
                                border: Border(
                                  top: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF27272A)
                                        : const Color(0xFFF1F5F9),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.fromLTRB(
                                14.0,
                                10.0,
                                14.0,
                                MediaQuery.of(context).viewInsets.bottom > 0
                                    ? 10.0
                                    : (MediaQuery.of(context).padding.bottom > 0
                                        ? MediaQuery.of(context).padding.bottom + 4.0
                                        : 12.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Replying Banner
                                  if (_replyingToMessage != null) ...[
                                    Container(
                                      height: 44,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                                    fontSize: 16.5,
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
                                                    fontSize: 15.0,
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
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                      height: 44,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF7C3AED),
                                                  ),
                                                ),
                                                Text(
                                                  'Perbarui teks di kolom lalu kirim',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 15.0,
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
                                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                      // Tombol Lampiran Berkas / Gambar (Toggle Mode Lampiran & Keyboard)
                                      BouncyButton(
                                        onTap: _toggleAttachmentPanel,
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Icon(
                                            _showAttachmentPanel ? Icons.keyboard_rounded : Icons.attach_file_rounded,
                                            color: _showAttachmentPanel
                                                ? const Color(0xFF10B981)
                                                : (isDark ? Colors.white70 : const Color(0xFFEF4444)),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      // Text Field (1 Baris lurus sejajar)
                                      Expanded(
                                        child: Container(
                                          constraints: const BoxConstraints(minHeight: 46),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(23),
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
                                              onTap: () {
                                                if (_showAttachmentPanel) {
                                                  setState(() => _showAttachmentPanel = false);
                                                }
                                              },
                                              style: GoogleFonts.dmSans(
                                                fontSize: 20.0,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: _editingMessageId != null ? 'Edit pesan...' : 'Tulis pesan...',
                                                hintStyle: GoogleFonts.dmSans(
                                                  color: isDark ? Colors.white38 : Colors.black26,
                                                  fontSize: 20.0,
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Tombol Kirim: Lingkaran background ungu ikon kirim putih
                                      BouncyButton(
                                        scaleDown: 0.85,
                                        duration: const Duration(milliseconds: 100),
                                        onTap: _sendMessage,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF7C3AED),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            _editingMessageId != null ? Icons.check_rounded : Icons.send_rounded,
                                            color: Colors.white,
                                            size: 19,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Drawer Lampiran Berkas / Mode File Pengganti Keyboard
                                  if (_showAttachmentPanel)
                                    _buildAttachmentBottomPanel(isDark, showCpFeatures, projectId),
                                ],
                              ),
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
          },
        ),
      );
    },
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

class ImagePreviewSendDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;
  final bool isDark;

  const ImagePreviewSendDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
    required this.isDark,
  });

  @override
  State<ImagePreviewSendDialog> createState() => _ImagePreviewSendDialogState();
}

class _ImagePreviewSendDialogState extends State<ImagePreviewSendDialog> {
  bool _isHd = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Interactive Image Canvas
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 2. Top Bar: Close Button (X) on left, HD Toggle button on right
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tombol Batal / Close (X)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, null),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Tombol HD (Interactive with Haptic & Reliable Icons)
                    BouncyButton(
                      scaleDown: 0.9,
                      onTap: () {
                        setState(() {
                          _isHd = !_isHd;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isHd
                              ? const Color(0xFF7C3AED)
                              : Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isHd ? const Color(0xFFA78BFA) : Colors.white38,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isHd ? Icons.check_circle_rounded : Icons.high_quality_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'HD',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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

          // 3. Bottom Bar: Caption input text box & Send button
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset > 0 ? bottomInset : (MediaQuery.of(context).padding.bottom + 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  // Text box keterangan
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _captionController,
                        style: GoogleFonts.dmSans(
                          fontSize: 15.0,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tambah keterangan...',
                          hintStyle: GoogleFonts.dmSans(
                            fontSize: 15.0,
                            color: Colors.white60,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Kirim: Lingkaran background ungu ikon kirim putih
                  BouncyButton(
                    scaleDown: 0.85,
                    duration: const Duration(milliseconds: 100),
                    onTap: () {
                      Navigator.pop(context, {
                        'isHd': _isHd,
                        'caption': _captionController.text.trim(),
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BlurImageProgressive extends StatefulWidget {
  final String imageUrl;
  final String? thumbnailUrl;
  final bool isMe;
  final bool isDark;
  final VoidCallback? onTap;

  const BlurImageProgressive({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.isMe,
    required this.isDark,
    this.onTap,
  });

  @override
  State<BlurImageProgressive> createState() => _BlurImageProgressiveState();
}

class _BlurImageProgressiveState extends State<BlurImageProgressive> {
  Uint8List? _fullImageBytes;
  Uint8List? _thumbBytes;

  @override
  void initState() {
    super.initState();
    _decodeThumb();
    _decodeFullIfBase64();
  }

  void _decodeThumb() {
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.startsWith('data:image') && thumb.contains(',')) {
      try {
        _thumbBytes = base64Decode(thumb.split(',').last);
      } catch (_) {}
    }
  }

  void _decodeFullIfBase64() {
    if (widget.imageUrl.startsWith('data:image') && widget.imageUrl.contains(',')) {
      try {
        _fullImageBytes = base64Decode(widget.imageUrl.split(',').last);
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant BlurImageProgressive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl || widget.thumbnailUrl != oldWidget.thumbnailUrl) {
      _fullImageBytes = null;
      _decodeThumb();
      _decodeFullIfBase64();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 260),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Low-res blurred background thumbnail (instant load)
              if (_thumbBytes != null)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Image.memory(
                      _thumbBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),

              // 2. Full resolution image (memory or network)
              if (_fullImageBytes != null)
                Image.memory(
                  _fullImageBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
              else
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_thumbBytes == null)
                          Container(
                            height: 180,
                            width: 240,
                            color: widget.isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                          ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    width: 180,
                    color: Colors.red.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.redAccent),
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

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
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
          child: Builder(
            builder: (context) {
              if (imageUrl.startsWith('data:image') && imageUrl.contains(',')) {
                try {
                  final b64 = imageUrl.split(',').last;
                  final bytes = base64Decode(b64);
                  return Image.memory(bytes, fit: BoxFit.contain);
                } catch (_) {}
              }
              return Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
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
      duration: const Duration(seconds: 16),
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

class _AbstractSquiggleData {
  final double xFrac;
  final double yFrac;
  final double driftX;
  final double driftY;
  final double speedX;
  final double speedY;
  final double baseAngle;
  final double rotSpeed;
  final double scale;
  final int style;

  const _AbstractSquiggleData(
    this.xFrac,
    this.yFrac,
    this.driftX,
    this.driftY,
    this.speedX,
    this.speedY,
    this.baseAngle,
    this.rotSpeed,
    this.scale,
    this.style,
  );
}

class _PurpleMicroPatternPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  _PurpleMicroPatternPainter({
    required this.animationValue,
    required this.isDark,
  });

  static const List<_AbstractSquiggleData> _squiggles = [
    _AbstractSquiggleData(0.12, 0.08, 16.0, 22.0, 1.0, 1.2, 0.4, 0.8, 1.1, 0),
    _AbstractSquiggleData(0.48, 0.05, 22.0, 14.0, -1.1, 0.9, -0.6, -1.0, 0.95, 1),
    _AbstractSquiggleData(0.84, 0.12, 18.0, 24.0, 0.8, -1.3, 1.1, 0.7, 1.2, 2),
    _AbstractSquiggleData(0.26, 0.22, 25.0, 16.0, -1.3, 1.0, -1.4, -0.9, 0.9, 3),
    _AbstractSquiggleData(0.68, 0.26, 17.0, 26.0, 1.2, -0.8, 0.8, 1.1, 1.15, 4),
    _AbstractSquiggleData(0.08, 0.38, 22.0, 18.0, 0.9, 1.4, -0.3, -0.8, 1.2, 5),
    _AbstractSquiggleData(0.92, 0.35, 16.0, 28.0, -1.0, -1.1, 1.5, 0.6, 0.95, 6),
    _AbstractSquiggleData(0.42, 0.44, 26.0, 20.0, 1.4, 0.7, -0.9, -1.2, 1.05, 0),
    _AbstractSquiggleData(0.72, 0.52, 18.0, 22.0, -0.7, -1.4, 0.5, 1.0, 1.25, 1),
    _AbstractSquiggleData(0.18, 0.58, 24.0, 17.0, 1.1, 1.1, -1.2, -0.7, 0.88, 2),
    _AbstractSquiggleData(0.54, 0.64, 21.0, 24.0, -1.2, 0.8, 1.3, 0.9, 1.1, 3),
    _AbstractSquiggleData(0.88, 0.68, 19.0, 21.0, 0.8, -1.0, -0.4, -1.1, 1.0, 4),
    _AbstractSquiggleData(0.14, 0.76, 23.0, 18.0, -1.0, 1.3, 0.9, 0.8, 1.2, 5),
    _AbstractSquiggleData(0.46, 0.82, 17.0, 28.0, 1.3, -0.9, -1.1, -1.0, 1.05, 6),
    _AbstractSquiggleData(0.80, 0.88, 22.0, 19.0, -0.9, 1.2, 1.4, 0.7, 0.92, 0),
    _AbstractSquiggleData(0.30, 0.94, 20.0, 23.0, 1.0, -1.1, -0.7, -0.8, 1.2, 1),
    _AbstractSquiggleData(0.95, 0.92, 18.0, 20.0, -1.2, 0.9, 0.6, 1.1, 1.05, 2),
    _AbstractSquiggleData(0.06, 0.90, 25.0, 16.0, 0.7, 1.4, -1.5, -0.6, 0.88, 3),
    _AbstractSquiggleData(0.62, 0.16, 21.0, 22.0, -1.4, -0.8, 0.2, 1.2, 1.1, 4),
    _AbstractSquiggleData(0.36, 0.34, 19.0, 25.0, 1.1, 1.0, -0.8, -0.9, 0.95, 5),
    _AbstractSquiggleData(0.86, 0.48, 23.0, 17.0, -0.8, -1.2, 1.0, 0.8, 1.3, 6),
    _AbstractSquiggleData(0.10, 0.62, 18.0, 24.0, 1.3, 0.9, -0.5, -1.1, 1.05, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid Flat Background (20% Ungu lembut pada mode light)
    final Color solidBg = isDark ? const Color(0xFF000000) : const Color(0xFFF3EDFD);
    canvas.drawColor(solidBg, BlendMode.src);

    // 2. Abstract Squiggle & Brush Paint (Ungu soft elegan)
    final strokePaint = Paint()
      ..color = (isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED))
          .withValues(alpha: isDark ? 0.14 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = (isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED))
          .withValues(alpha: isDark ? 0.18 : 0.12)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _squiggles.length; i++) {
      final sq = _squiggles[i];

      // Gerak mengambang dinamis ke sana ke mari secara organik
      final double progressX = (animationValue * sq.speedX) % 1.0;
      final double progressY = (animationValue * sq.speedY) % 1.0;

      final double floatX = sin(progressX * 2 * pi) * sq.driftX;
      final double floatY = cos(progressY * 2 * pi) * sq.driftY;

      final double cx = (sq.xFrac * size.width + floatX);
      final double cy = (sq.yFrac * size.height + floatY);

      // Rotasi dan goyangan halus tak beraturan
      final double angle = sq.baseAngle + sin(animationValue * 2 * pi * sq.rotSpeed + i) * 0.30;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.scale(sq.scale);

      switch (sq.style) {
        case 0:
          // 1. S-curve squiggle ("oletan lengkung S")
          final p = Path()
            ..moveTo(-16, -8)
            ..cubicTo(-8, -18, -2, 6, 8, -4)
            ..cubicTo(14, -10, 18, 10, 12, 16);
          canvas.drawPath(p, strokePaint);
          break;

        case 1:
          // 2. Fluid loop squiggle ("oletan melingkar halus")
          final p = Path()
            ..moveTo(-14, 6)
            ..cubicTo(-18, -12, -2, -16, 4, -4)
            ..cubicTo(10, 8, 16, -10, 12, 12);
          canvas.drawPath(p, strokePaint);
          break;

        case 2:
          // 3. Organic wave ribbon ("lekukan gelombang mengalir")
          final p = Path()
            ..moveTo(-18, -4)
            ..cubicTo(-8, -14, 2, 8, 12, -6)
            ..cubicTo(16, -12, 20, 2, 14, 8);
          canvas.drawPath(p, strokePaint);
          break;

        case 3:
          // 4. Freeform curl squiggle ("oletan spiral bebas")
          final p = Path()
            ..moveTo(-12, 10)
            ..cubicTo(-16, -6, 2, -14, 10, -2)
            ..cubicTo(16, 8, 0, 14, -4, 4)
            ..cubicTo(-6, -2, 2, -4, 4, 0);
          canvas.drawPath(p, strokePaint);
          break;

        case 4:
          // 5. Floating double arcs ("dua goresan kurva lepas")
          final p1 = Path()
            ..moveTo(-14, -10)
            ..quadraticBezierTo(0, 12, 14, -6);
          canvas.drawPath(p1, strokePaint);
          final p2 = Path()
            ..moveTo(-8, 6)
            ..quadraticBezierTo(4, -10, 16, 8);
          canvas.drawPath(p2, strokePaint);
          break;

        case 5:
          // 6. Wandering fluid squiggle dengan aksen titik
          final p = Path()
            ..moveTo(-15, 8)
            ..cubicTo(-5, 16, -2, -12, 10, -8)
            ..cubicTo(16, -6, 12, 10, 6, 12);
          canvas.drawPath(p, strokePaint);
          canvas.drawCircle(const Offset(16, -12), 1.5, dotPaint);
          break;

        case 6:
        default:
          // 7. Crescent wave squiggle
          final p = Path()
            ..moveTo(-14, -10)
            ..cubicTo(-4, -4, 4, 6, 14, 10)
            ..cubicTo(8, 6, -4, -4, -14, -10);
          canvas.drawPath(p, strokePaint);
          break;
      }

      // Aksen titik mikro mengambang di sekitar oletan
      canvas.drawCircle(
        Offset(
          sin(animationValue * 2 * pi * 0.8 + i) * 16.0,
          cos(animationValue * 2 * pi * 0.6 + i) * 16.0,
        ),
        1.4,
        dotPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PurpleMicroPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isDark != isDark;
  }
}
