import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/services.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
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

class ChatRoomPage extends StatefulWidget {
  final String discussionId;
  final String channelName;
  final String? projectId;
  final bool isEmbedded;

  const ChatRoomPage({
    super.key,
    required this.discussionId,
    required this.channelName,
    this.projectId,
    this.isEmbedded = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
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
    _messageController.addListener(_onTextChanged);
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
          fontSize: 15.2,
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
                            fontSize: 18.7,
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
                      label: Text('Buat Folder Baru', style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: folders.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada folder ditemukan di Google Drive.',
                                style: GoogleFonts.dmSans(color: Colors.black38, fontSize: 15.2),
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
                                    style: GoogleFonts.dmSans(fontSize: 15.2, fontWeight: FontWeight.w500),
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

  Future<void> _pickAndSendImage() async {
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

      String pId = widget.projectId ?? '';
      if (pId.isEmpty) {
        final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).get();
        if (discDoc.exists) {
          pId = discDoc.data()?['projectId'] as String? ?? '';
        }
      }
      if (pId.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Chat ini tidak terhubung dengan Google Drive Kelas.')),
          );
        }
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('projects').doc(pId).get();
      final driveFolderId = doc.data()?['driveFolderId'] as String?;
      final driveFolderUrl = doc.data()?['driveFolderUrl'] as String? ?? (driveFolderId != null ? 'https://drive.google.com/drive/folders/$driveFolderId' : '');
      final driveAccessToken = doc.data()?['driveAccessToken'] as String?;

      if (driveFolderId == null || driveFolderId.isEmpty || driveAccessToken == null || driveAccessToken.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          if (driveFolderUrl.isNotEmpty) {
            _showDriveUploadErrorDialog(context, driveFolderUrl);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal: Google Drive Guru belum tersinkronisasi. Pastikan Guru telah masuk kelas untuk mengaktifkan Google Drive.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
        return;
      }

      List<int> fileBytes;
      if (kIsWeb) {
        fileBytes = pickedFile.bytes!;
      } else {
        fileBytes = await File(pickedFile.path!).readAsBytes();
      }

      final uploadResult = await GoogleDriveService.uploadFile(
        accessToken: driveAccessToken,
        folderId: driveFolderId,
        fileName: pickedFile.name,
        bytes: fileBytes,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'User';
      final senderAvatar = userDoc.data()?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

      // Send message with image URL
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(widget.discussionId)
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
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).get();
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
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(widget.discussionId)
          .update(updates);

      if (mounted) {
        Navigator.pop(context); // Dismiss loader
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loader
        String pId = widget.projectId ?? '';
        if (pId.isEmpty) {
          final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).get();
          if (discDoc.exists) {
            pId = discDoc.data()?['projectId'] as String? ?? '';
          }
        }
        if (pId.isNotEmpty) {
          final doc = await FirebaseFirestore.instance.collection('projects').doc(pId).get();
          final driveFolderId = doc.data()?['driveFolderId'] as String?;
          final driveFolderUrl = doc.data()?['driveFolderUrl'] as String? ?? (driveFolderId != null ? 'https://drive.google.com/drive/folders/$driveFolderId' : '');
          if (driveFolderUrl.isNotEmpty) {
            _showDriveUploadErrorDialog(context, driveFolderUrl);
            return;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim gambar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showDriveUploadErrorDialog(BuildContext context, String folderUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Gagal Mengunggah Otomatis',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koneksi Google Drive Guru kedaluwarsa atau belum disinkronisasi.',
              style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              'Anda dapat mengunggah berkas secara manual ke folder kelas (Akses Bebas) berikut, lalu menyalin dan menempelkan tautan berkas Anda di kolom input pesan.',
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.dmSans(color: Colors.black54)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(folderUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text('Buka Folder Google Drive', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _messageController.clear();

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'User';
      final senderAvatar = userDoc.data()?['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png';

      // 1. Add message to discussions subcollection
      await FirebaseFirestore.instance
          .collection('discussions')
          .doc(widget.discussionId)
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
      final discDoc = await FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).get();
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
          .doc(widget.discussionId)
          .update(updates);

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      // ignore
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent,
    );
  }

  @override
  void dispose() {
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
        child: const ThreeDotsLoader(),
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
    
    final channelController = TextEditingController(text: discData['channel'] ?? '');
    final titleController = TextEditingController(text: discData['title'] ?? '');
    String selectedAvatar = discData['avatar'] ?? 'assets/icon_pack/chat/chat_1.png';
    List<String> selectedMemberUids = List<String>.from(discData['memberUids'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24 + MediaQuery.of(context).padding.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pengaturan Diskusi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 21.1,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Project info card
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).get(),
                      builder: (context, discSnapshot) {
                        if (discSnapshot.hasData) {
                          final projectId = (discSnapshot.data!.data() as Map<String, dynamic>)['projectId'] as String? ?? '';
                          if (projectId.isNotEmpty) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('projects').doc(projectId).get(),
                              builder: (context, projectSnapshot) {
                                if (projectSnapshot.hasData && projectSnapshot.data!.exists) {
                                  final projectName = (projectSnapshot.data!.data() as Map<String, dynamic>)['name'] as String? ?? '';
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.folder_open_rounded, color: Colors.black54, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Kelas',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black38,
                                                ),
                                              ),
                                              Text(
                                                projectName,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16.4,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Anggota',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    if (projectMembers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Tidak ada anggota kelas.',
                            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: Text('Pilih Semua', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                              trailing: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (selectedMemberUids.length - 1 >= projectMembers.where((m) => m['uid'] != currentUid).length) ? Colors.black : Colors.transparent,
                                  border: Border.all(
                                    color: (selectedMemberUids.length - 1 >= projectMembers.where((m) => m['uid'] != currentUid).length) ? Colors.black : Colors.black26,
                                    width: 2,
                                  ),
                                ),
                                child: (selectedMemberUids.length - 1 >= projectMembers.where((m) => m['uid'] != currentUid).length)
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                              onTap: () {
                                setModalState(() {
                                  final bool isAll = selectedMemberUids.length - 1 >= projectMembers.where((m) => m['uid'] != currentUid).length;
                                  if (!isAll) {
                                    selectedMemberUids = projectMembers.map((m) => m['uid'] as String).toList();
                                    if (!selectedMemberUids.contains(currentUid)) {
                                      selectedMemberUids.add(currentUid);
                                    }
                                  } else {
                                    selectedMemberUids = [currentUid];
                                  }
                                });
                              },
                            ),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            Expanded(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                itemCount: projectMembers.length,
                                separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                                itemBuilder: (context, idx) {
                                  final m = projectMembers[idx];
                                  final mUid = m['uid'] as String;
                                  if (mUid == currentUid) return const SizedBox();
                                  final isChecked = selectedMemberUids.contains(mUid);

                                  return ListTile(
                                    title: Text(m['name'], style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                                    subtitle: Text('ID: ${m['userId']}', style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: Colors.black38)),
                                    leading: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 1),
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(m['avatar']),
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    trailing: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isChecked ? Colors.black : Colors.transparent,
                                        border: Border.all(
                                          color: isChecked ? Colors.black : Colors.black26,
                                          width: 2,
                                        ),
                                      ),
                                      child: isChecked
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                    onTap: () {
                                      setModalState(() {
                                        if (!isChecked) {
                                          selectedMemberUids.add(mUid);
                                        } else {
                                          selectedMemberUids.remove(mUid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    Text(
                      'Nama Saluran (Channel)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: channelController,
                      style: GoogleFonts.dmSans(fontSize: 15.2),
                      decoration: InputDecoration(
                        hintText: 'Contoh: #ui-design',
                        hintStyle: GoogleFonts.dmSans(color: Colors.black26, fontSize: 15.2),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Judul Diskusi',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.dmSans(fontSize: 15.2),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Saluran Masukan Desain UI',
                        hintStyle: GoogleFonts.dmSans(color: Colors.black26, fontSize: 15.2),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pilih Avatar Diskusi',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 10,
                        itemBuilder: (context, i) {
                          final avatarPath = 'assets/icon_pack/chat/chat_${i + 1}.png';
                          final isSelected = selectedAvatar == avatarPath;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedAvatar = avatarPath;
                              });
                            },
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(avatarPath, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final chan = channelController.text.trim();
                          final ttl = titleController.text.trim();
                          if (chan.isEmpty || ttl.isEmpty) return;

                          final List<String> finalMembers = selectedMemberUids;
                          if (!finalMembers.contains(currentUid)) {
                            finalMembers.add(currentUid);
                          }

                          await FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).update({
                            'channel': chan.startsWith('#') ? chan : '#$chan',
                            'title': ttl,
                            'avatar': selectedAvatar,
                            'memberUids': finalMembers,
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pengaturan diskusi berhasil diperbarui!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Simpan Perubahan',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('discussions').doc(widget.discussionId).snapshots(),
      builder: (context, discSnapshot) {
        final discData = discSnapshot.data?.data() as Map<String, dynamic>?;
        if (discData != null) {
          final memberUids = List<String>.from(discData['memberUids'] ?? []);
          _loadDiscussionMembersOnce(memberUids);
        }
        final bool isPrivate = discData?['isPrivate'] ?? false;
        final String channelTitle = discData?['title'] ?? widget.channelName;
        final String subtitle = isPrivate ? 'Obrolan Pribadi' : 'Grup Chat Diskusi';
        final String projectId = discData?['projectId'] ?? '';
        final String creatorUid = discData?['creatorUid'] ?? '';

        return FutureBuilder<bool>(
          future: _checkIsOwner(projectId, creatorUid),
          builder: (context, ownerSnapshot) {
            final bool isOwner = ownerSnapshot.data ?? false;

            return StreamBuilder<DocumentSnapshot>(
              stream: projectId.isNotEmpty
                  ? FirebaseFirestore.instance.collection('projects').doc(projectId).snapshots()
                  : const Stream.empty(),
              builder: (context, projSnapshot) {
                final projData = projSnapshot.data?.data() as Map<String, dynamic>?;
                final int colorIdx = projData?['colorIndex'] ?? 0;

                final List<Color> stageColorsList = [
                  const Color(0xFFEFF6FF), // Blue
                  const Color(0xFFECFDF5), // Emerald/Green
                  const Color(0xFFFFF7ED), // Amber/Orange
                  const Color(0xFFFDF2F8), // Pink
                  const Color(0xFFFAF5FF), // Purple
                ];
                final List<Color> stageAccentColorsList = [
                  const Color(0xFF3B82F6),
                  const Color(0xFF10B981),
                  const Color(0xFFF59E0B),
                  const Color(0xFFEC4899),
                  const Color(0xFF8B5CF6),
                ];

                final Color softBgColor = stageColorsList[colorIdx % stageColorsList.length];
                final Color accentColor = stageAccentColorsList[colorIdx % stageAccentColorsList.length];

                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: AnimatedRainbowBackground(
                              child: SizedBox.shrink(),
                            ),
                          ),
                          Column(
                            children: [
                              // Custom Chat AppBar (Solid White Header, blends with status bar)
                              Container(
                                color: Colors.white,
                                width: double.infinity,
                                padding: EdgeInsets.fromLTRB(
                                  20.0,
                                  MediaQuery.of(context).padding.top + 10.0,
                                  20.0,
                                  10.0,
                                ),
                      child: Row(
                        children: [
                          if (!widget.isEmbedded) ...[
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
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  channelTitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18.7,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  subtitle,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
                                    color: Colors.black38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (projectId.isNotEmpty) ...[
                            // Open Drive folder button (Visible to everyone if connected)
                            if (projData?['driveFolderId'] != null && projData!['driveFolderId'].toString().isNotEmpty)
                              GestureDetector(
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
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF), // soft blue background
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.folder_shared_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                ),
                              ),
                            // Connect/Change folder button (Only visible to guru)
                            if (_userRole == 'guru')
                              GestureDetector(
                                onTap: () => _showFolderSelectorDialog(projectId),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_to_drive_rounded,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                          PopupMenuButton<String>(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.15),
                            color: Colors.white,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.black,
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
                                    title: const Text('Bersihkan Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: const Text('Apakah Anda yakin ingin menghapus semua pesan di obrolan pribadi ini?'),
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
                                if (confirm == true) {
                                  final msgs = await FirebaseFirestore.instance
                                      .collection('discussions')
                                      .doc(widget.discussionId)
                                      .collection('messages')
                                      .get();
                                  for (var doc in msgs.docs) {
                                    await doc.reference.delete();
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('discussions')
                                      .doc(widget.discussionId)
                                      .update({
                                    'lastMessage': 'Mulai obrolan privat...',
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Chat berhasil dibersihkan!')),
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
                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('discussions')
                                      .doc(widget.discussionId)
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
                                          : 'Apakah Anda yakin ingin menghapus grup diskusi ini beserta seluruh isinya?',
                                      style: GoogleFonts.dmSans(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text(
                                          'Hapus',
                                          style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final msgs = await FirebaseFirestore.instance
                                      .collection('discussions')
                                      .doc(widget.discussionId)
                                      .collection('messages')
                                      .get();
                                  for (var doc in msgs.docs) {
                                    await doc.reference.delete();
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('discussions')
                                      .doc(widget.discussionId)
                                      .delete();
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
                                    child: Row(
                                      children: [
                                        const Icon(Icons.clear_all_rounded, color: Colors.black87, size: 18),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Bersihkan Chat',
                                          style: GoogleFonts.dmSans(fontSize: 15.2, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Hapus Obrolan',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 15.2, color: Colors.redAccent, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ];
                              }

                              return [
                                if (isOwner) ...[
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.settings_outlined, color: Colors.black87, size: 18),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Pengaturan Diskusi',
                                          style: GoogleFonts.dmSans(fontSize: 15.2, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                PopupMenuItem(
                                  value: 'leave',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.logout_rounded, color: Colors.orangeAccent, size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Keluar dari Grup',
                                        style: GoogleFonts.dmSans(fontSize: 15.2, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOwner) ...[
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Hapus Diskusi',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 15.2, color: Colors.redAccent, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [

                    // Mention banner (only for group chats where user has been mentioned)
                    if (!isPrivate && _mentionMessageIds.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Scroll to the latest mention message
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
                              bottom: BorderSide(color: const Color(0xFFD8B4FE).withOpacity(0.4), width: 1),
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
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('discussions')
                                  .doc(widget.discussionId)
                                  .collection('messages')
                                  .orderBy('time', descending: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                // Only show spinner if no data at all (first load)
                                if (snapshot.data == null && snapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox.shrink();
                                }
                                final messageDocs = snapshot.data?.docs ?? [];

                                // Track all messages mentioning current user (from others)
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

                                // Smart scroll: only scroll on new messages or first load
                                final currentCount = messageDocs.length;
                                if (!_initialScrollDone) {
                                  // First load: jump instantly to bottom (no animation)
                                  _initialScrollDone = true;
                                  _lastMessageCount = currentCount;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _scrollToBottom();
                                    // Clear unread count for current user
                                    FirebaseFirestore.instance
                                        .collection('discussions')
                                        .doc(widget.discussionId)
                                        .update({
                                      'unreadCounts.$currentUid': 0,
                                    }).catchError((_) {});
                                  });
                                } else if (currentCount > _lastMessageCount) {
                                  // New message arrived: smooth scroll
                                  _lastMessageCount = currentCount;
                                  
                                  // Play notification sound if the sender is not current user
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
                                    // Clear unread count for current user
                                    FirebaseFirestore.instance
                                        .collection('discussions')
                                        .doc(widget.discussionId)
                                        .update({
                                      'unreadCounts.$currentUid': 0,
                                    }).catchError((_) {});
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
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  itemCount: messageDocs.length,
                                  itemBuilder: (context, index) {
                                    final msgDoc = messageDocs[index];
                                    final msgData = msgDoc.data() as Map<String, dynamic>;
                                    final msgId = msgDoc.id;
                                    // Ensure a GlobalKey exists for each message
                                    if (!_messageKeys.containsKey(msgId)) {
                                      _messageKeys[msgId] = GlobalKey();
                                    }
                                    final msgKey = _messageKeys[msgId];
                                    final sender = msgData['sender'] ?? 'User';
                                    final senderUid = msgData['senderUid'] ?? '';
                                    
                                    // Dynamically lookup current avatar & name of the sender
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

                                     return SwipeToReply(
                                       isMe: isMe,
                                       onReply: () {
                                         setState(() {
                                           _replyingToMessage = {
                                             'sender': senderName,
                                             'message': message,
                                             'imageUrl': imageUrl,
                                           };
                                         });
                                       },
                                       child: Container(
                                         key: msgKey,
                                         margin: const EdgeInsets.only(bottom: 12),
                                         child: Row(
                                           mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             if (!isMe) ...[
                                               Container(
                                                 width: 32,
                                                 height: 32,
                                                 decoration: BoxDecoration(
                                                   shape: BoxShape.circle,
                                                   border: Border.all(color: Colors.black54, width: 1),
                                                 ),
                                                 child: ClipOval(
                                                   child: Image.asset(avatar, fit: BoxFit.cover),
                                                 ),
                                               ),
                                               const SizedBox(width: 8),
                                             ],
                                             Flexible(
                                               child: GestureDetector(
                                               onLongPress: () {
                                                 setState(() {
                                                   _replyingToMessage = {
                                                     'sender': senderName,
                                                     'message': message,
                                                     'imageUrl': imageUrl,
                                                   };
                                                 });
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(
                                                     content: Text('Membalas pesan dari $senderName'),
                                                     duration: const Duration(milliseconds: 1000),
                                                     behavior: SnackBarBehavior.floating,
                                                     shape: RoundedRectangleBorder(
                                                       borderRadius: BorderRadius.circular(12),
                                                     ),
                                                   ),
                                                 );
                                               },
                                               child: Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                 decoration: BoxDecoration(
                                                   color: isMe ? Colors.black : const Color(0xFFF1F5F9),
                                                   borderRadius: BorderRadius.only(
                                                     topLeft: const Radius.circular(16),
                                                     topRight: const Radius.circular(16),
                                                       bottomLeft: Radius.circular(isMe ? 16 : 4),
                                                       bottomRight: Radius.circular(isMe ? 4 : 16),
                                                     ),
                                                   ),
                                                   child: Column(
                                                     crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                     children: [
                                                       if (msgData['replyToSender'] != null) ...[
                                                         Container(
                                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                           margin: const EdgeInsets.only(bottom: 6),
                                                           decoration: BoxDecoration(
                                                             color: isMe ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05),
                                                             borderRadius: BorderRadius.circular(8),
                                                             border: Border(
                                                               left: BorderSide(
                                                                 color: isMe ? Colors.white70 : const Color(0xFF2563EB),
                                                                 width: 3,
                                                               ),
                                                             ),
                                                           ),
                                                           child: Column(
                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                             mainAxisSize: MainAxisSize.min,
                                                             children: [
                                                               Text(
                                                                 msgData['replyToSender'] as String,
                                                                 style: GoogleFonts.plusJakartaSans(
                                                                   fontSize: 14.0,
                                                                   fontWeight: FontWeight.bold,
                                                                   color: isMe ? Colors.white : const Color(0xFF2563EB),
                                                                 ),
                                                               ),
                                                               const SizedBox(height: 2),
                                                               Text(
                                                                 msgData['replyToText'] == '[Gambar Lampiran]'
                                                                     ? '📷 Foto'
                                                                     : (msgData['replyToText'] as String? ?? ''),
                                                                 maxLines: 1,
                                                                 overflow: TextOverflow.ellipsis,
                                                                 style: GoogleFonts.dmSans(
                                                                   fontSize: 14.0,
                                                                   color: isMe ? Colors.white70 : Colors.black54,
                                                                 ),
                                                               ),
                                                             ],
                                                           ),
                                                         ),
                                                       ],
                                                       if (!isMe)
                                                         Text(
                                                           displayName,
                                                           style: GoogleFonts.plusJakartaSans(
                                                             fontSize: 14.0,
                                                             fontWeight: FontWeight.bold,
                                                             color: Colors.black54,
                                                           ),
                                                         ),
                                                       const SizedBox(height: 2),
                                                       if (imageUrl.isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          GestureDetector(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (context) => FullScreenImagePage(imageUrl: imageUrl),
                                                                ),
                                                              );
                                                            },
                                                            child: Container(
                                                             constraints: const BoxConstraints(
                                                               maxWidth: 180,
                                                               maxHeight: 180,
                                                             ),
                                                             child: ClipRRect(
                                                               borderRadius: BorderRadius.circular(12),
                                                               child: Image.network(
                                                                 imageUrl,
                                                                 width: 180,
                                                                 height: 180,
                                                                 fit: BoxFit.cover,
                                                                 errorBuilder: (context, error, stackTrace) {
                                                                   return Container(
                                                                     padding: const EdgeInsets.all(12),
                                                                     color: Colors.red[50],
                                                                     child: Row(
                                                                       mainAxisSize: MainAxisSize.min,
                                                                       children: [
                                                                         const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                                                         const SizedBox(width: 6),
                                                                         Text(
                                                                           'Gagal memuat gambar',
                                                                           style: GoogleFonts.dmSans(fontSize: 14.0, color: Colors.redAccent),
                                                                         ),
                                                                       ],
                                                                     ),
                                                                   );
                                                                 },
                                                               ),
                                                             ),
                                                           ),
                                                         ),
                                                         const SizedBox(height: 4),
                                                       ],
                                                       RichText(
                                                         text: TextSpan(
                                                           style: GoogleFonts.dmSans(
                                                             fontSize: 15.2,
                                                             color: isMe ? Colors.white : Colors.black87,
                                                             fontWeight: FontWeight.w500,
                                                           ),
                                                           children: _buildMessageSpans(message, _currentUserName, context, isMe),
                                                         ),
                                                       ),
                                                       const SizedBox(height: 2),
                                                       Text(
                                                         timeText,
                                                         style: GoogleFonts.dmSans(
                                                           fontSize: 14.0,
                                                           color: isMe ? Colors.white60 : Colors.black38,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ),
                                             ),
                                             if (isMe) ...[
                                               const SizedBox(width: 8),
                                               Container(
                                                 width: 32,
                                                 height: 32,
                                                 decoration: BoxDecoration(
                                                   shape: BoxShape.circle,
                                                   border: Border.all(color: Colors.black54, width: 1),
                                                 ),
                                                 child: ClipOval(
                                                   child: Image.asset(avatar, fit: BoxFit.cover),
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
                          if (_filteredMentionMembers.isNotEmpty)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 8,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, -4),
                                    ),
                                  ],
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  itemCount: _filteredMentionMembers.length,
                                  itemBuilder: (context, idx) {
                                    final m = _filteredMentionMembers[idx];
                                    return GestureDetector(
                                      onTap: () => _selectMention(m),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.black, width: 0.5),
                                              ),
                                              child: ClipOval(
                                                child: Image.asset(m['avatar'], fit: BoxFit.cover),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              m['uid'] == 'all' ? '@all' : '@${m['name']}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Chat Input Field
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_replyingToMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: const Border(
                                  left: BorderSide(color: Color(0xFF2563EB), width: 4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _replyingToMessage!['sender'] ?? 'User',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _replyingToMessage!['message'] == '[Gambar Lampiran]'
                                              ? '📷 Foto'
                                              : (_replyingToMessage!['message'] ?? ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14.0,
                                            color: Colors.black54,
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
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _pickAndSendImage,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.image_rounded,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: 'Tulis pesan...',
                                    hintStyle: GoogleFonts.dmSans(color: Colors.black26, fontSize: 15.2),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(color: Colors.black87),
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _sendMessage,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
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
        ],
      ),
    ),
  ),
);
  },
);
  },
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
