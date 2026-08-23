import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Hapus Teman', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus $friendName dari daftar teman?', style: GoogleFonts.plusJakartaSans()),
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
      backgroundColor: isDark ? const Color(0xFF0F0F10) : Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom AppBar (Disamakan persis dengan Data Anggota Kelas)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
                  child: Row(
                    children: [
                      BouncyButton(
                        scaleDown: 0.85,
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
                            color: isDark ? Colors.white : Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Kelola Teman',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                ),

                const SizedBox(height: 16),

                // Add Friend input field (Disamakan persis dengan Data Anggota Kelas)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _friendIdController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ketik ID pengguna untuk tambah...',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 15.0,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
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
                                    child: ThreeDotsLoader(),
                                  )
                                : Text(
                                    'Tambah',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15.5,
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

                const SizedBox(height: 16),

                // Friends List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Daftar Teman Anda',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                    ),
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
                            style: GoogleFonts.dmSans(color: isDark ? Colors.white38 : Colors.black45),
                          ),
                        );
                      }

                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final List<String> friendUids = List<String>.from(userData?['friendUids'] ?? []);

                      if (friendUids.isEmpty) {
                        return Center(
                          child: Text(
                            'Anda belum memiliki teman.',
                            style: GoogleFonts.dmSans(
                              fontSize: 15.2,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                                      color: isDark ? const Color(0xFF18181B) : Colors.white,
                                      borderRadius: BorderRadius.circular(36),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                                    child: Row(
                                      children: [
                                        // Avatar: Samakan persis dengan Kelola Anggota (Scale 1.45, Frameless)
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.12),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
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
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: $fUserId',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14.0,
                                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
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
