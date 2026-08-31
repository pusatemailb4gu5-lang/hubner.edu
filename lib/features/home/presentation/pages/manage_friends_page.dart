import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_room_page.dart';

class ManageFriendsPage extends StatefulWidget {
  const ManageFriendsPage({super.key});

  @override
  State<ManageFriendsPage> createState() => _ManageFriendsPageState();
}

class _ManageFriendsPageState extends State<ManageFriendsPage> {
  final TextEditingController _friendIdController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _friendIdController.dispose();
    super.dispose();
  }

  void _startPrivateChat(BuildContext context, String friendUid, String friendName, String friendAvatar) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || friendUid.isEmpty || friendUid == currentUid) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomPage(
          discussionId: '',
          channelName: friendName,
          targetUserUid: friendUid,
          targetUserAvatar: friendAvatar,
          isPrivateDraft: true,
        ),
      ),
    );
  }

  Future<void> _addFriend() async {
    final inputId = _friendIdController.text.trim().toLowerCase();
    if (inputId.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _isAdding = true);

    try {
      // 1. Get current user's data to check own userId and existing friends
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      if (!currentUserDoc.exists) return;
      final currentUserId = (currentUserDoc.data()?['userId'] as String?)?.toLowerCase();
      final List<String> currentFriends = List<String>.from(currentUserDoc.data()?['friendUids'] ?? []);

      if (inputId == currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anda tidak bisa menambahkan diri sendiri.'), backgroundColor: Colors.redAccent),
          );
        }
        setState(() => _isAdding = false);
        return;
      }

      // 2. Find target user by userId
      final targetQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: inputId)
          .get();

      if (targetQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID User tidak ditemukan.'), backgroundColor: Colors.redAccent),
          );
        }
        setState(() => _isAdding = false);
        return;
      }

      final targetUserDoc = targetQuery.docs.first;
      final targetUid = targetUserDoc.id;
      final targetName = targetUserDoc.get('name') ?? 'User';

      if (currentFriends.contains(targetUid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengguna tersebut sudah menjadi teman Anda.'), backgroundColor: Colors.redAccent),
          );
        }
        setState(() => _isAdding = false);
        return;
      }

      // 3. Add mutually to friendUids lists
      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
        'friendUids': FieldValue.arrayUnion([targetUid]),
      });
      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'friendUids': FieldValue.arrayUnion([currentUid]),
      });

      _friendIdController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$targetName berhasil ditambahkan sebagai teman!'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan teman: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _removeFriend(String friendUid, String friendName) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        title: Text(
          'Hapus Teman',
          style: AppTypography.buttonLabel(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $friendName dari daftar teman?',
          style: AppTypography.buttonLabel(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: AppTypography.buttonLabel(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Hapus',
              style: AppTypography.buttonLabel(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
          'friendUids': FieldValue.arrayRemove([friendUid]),
        });
        await FirebaseFirestore.instance.collection('users').doc(friendUid).update({
          'friendUids': FieldValue.arrayRemove([currentUid]),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$friendName dihapus dari teman.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus teman: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom AppBar (Sticky Glassmorphic Blur)
                ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.85),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          BouncyButton(
                            scaleDown: 0.85,
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              color: Colors.transparent,
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                'Kelola Teman',
                                style: AppTypography.chatHeaderTitle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Add Friend input field (Disamakan persis dengan Data Anggota Kelas)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101012) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark ? const Color(0xFF222226) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _friendIdController,
                            style: AppTypography.cardTitle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Ketik ID pengguna untuk tambah...',
                              hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black38),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _isAdding ? null : _addFriend,
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            alignment: Alignment.center,
                            child: _isAdding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(),
                                  )
                                : Text(
                                    'Tambah',
                                    style: AppTypography.cardTitle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Friends List Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin),
                  child: Text(
                    'Daftar Teman Anda',
                    style: AppTypography.cardTitle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),

                // Friends List Builder
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Text(
                            'Data tidak ditemukan.',
                            style: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black45),
                          ),
                        );
                      }

                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final List friendUids = List.from(userData?['friendUids'] ?? []);

                      if (friendUids.isEmpty) {
                        return Center(
                          child: Text(
                            'Anda belum memiliki teman.',
                            style: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black45),
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: friendUids)
                            .snapshots(),
                        builder: (context, friendsSnapshot) {
                          if (friendsSnapshot.connectionState == ConnectionState.waiting && !friendsSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final friendDocs = friendsSnapshot.data?.docs ?? [];

                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(AppTypography.screenHorizontalMargin, 4, AppTypography.screenHorizontalMargin, 24),
                            itemCount: friendDocs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final fData = friendDocs[index].data() as Map<String, dynamic>;
                              final fUid = friendDocs[index].id;
                              final fName = fData['name'] ?? 'User';
                              final fUserId = fData['userId'] ?? 'ID';
                              final fAvatar = fData['avatar'] as String? ?? 'assets/icon_pack/avatar/avatar_2.png';

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(36),
                                  onTap: () => _startPrivateChat(context, fUid, fName, fAvatar),
                                  child: Container(
                                    height: 64,
                                    padding: const EdgeInsets.fromLTRB(5, 5, 8, 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF101012) : Colors.white,
                                      borderRadius: BorderRadius.circular(36),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF222226) : const Color(0xFFE2E8F0),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar: Samakan persis dengan Kelola Anggota (Scale 1.45, Frameless)
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                          ),
                                          child: ClipOval(
                                            child: Transform.scale(
                                              scale: 1.45,
                                              child: Image.asset(
                                                fAvatar,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, st) => Container(
                                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                                  child: Icon(
                                                    Icons.person_rounded,
                                                    color: isDark ? Colors.white38 : Colors.black38,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                fName,
                                                style: AppTypography.cardTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: $fUserId',
                                                style: AppTypography.timestamp(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Remove friend button (Ikon Tong Sampah Merah Persis Gambar 2)
                                        IconButton(
                                          tooltip: 'Hapus Teman',
                                          onPressed: () => _removeFriend(fUid, fName),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 22,
                                          ),
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
