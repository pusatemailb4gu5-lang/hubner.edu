import 'package:flutter/material.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
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

  Future<void> _startPrivateChat(BuildContext context, String friendUid, String friendName, String friendAvatar) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: const ThreeDotsLoader(),
      ),
    );

    try {
      final query = await FirebaseFirestore.instance
          .collection('discussions')
          .where('isPrivate', isEqualTo: true)
          .where('memberUids', arrayContains: currentUid)
          .get();

      String? existingChatId;
      for (var doc in query.docs) {
        final uids = List<String>.from(doc.data()['memberUids'] ?? []);
        if (uids.contains(friendUid) && uids.length == 2) {
          existingChatId = doc.id;
          break;
        }
      }

      if (existingChatId == null) {
        final newDocRef = await FirebaseFirestore.instance.collection('discussions').add({
          'channel': '@${friendName.toLowerCase().replaceAll(' ', '')}',
          'title': friendName,
          'avatar': friendAvatar,
          'isPrivate': true,
          'memberUids': [currentUid, friendUid],
          'lastMessage': 'Mulai obrolan privat...',
          'time': 'Sekarang',
          'createdAt': FieldValue.serverTimestamp(),
          'colorIndex': Random().nextInt(5),
        });
        existingChatId = newDocRef.id;
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(
              discussionId: existingChatId!,
              channelName: friendName,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai chat privat: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width > 500 ? double.infinity : 500),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Kelola Teman',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21.1,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Add Friend input field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Teman Baru',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _friendIdController,
                              style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Masukkan ID User teman...',
                                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.black26, fontWeight: FontWeight.normal, fontSize: 15.2),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _isAdding ? null : _addFriend,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: _isAdding
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: const ThreeDotsLoader(),
                                    )
                                  : Text(
                                      'Tambah',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15.2,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Friends List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Daftar Teman Anda',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15.2, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 10),

                // Friends List Builder
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: ThreeDotsLoader());
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Text('Data tidak ditemukan.', style: GoogleFonts.dmSans(color: Colors.black45)),
                        );
                      }

                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final List<String> friendUids = List<String>.from(userData?['friendUids'] ?? []);

                      if (friendUids.isEmpty) {
                        return Center(
                          child: Text(
                            'Anda belum memiliki teman.',
                            style: GoogleFonts.dmSans(fontSize: 15.2, color: Colors.black45),
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: friendUids)
                            .snapshots(),
                        builder: (context, friendsSnapshot) {
                          if (friendsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: ThreeDotsLoader());
                          }

                          final friendDocs = friendsSnapshot.data?.docs ?? [];

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                            itemCount: friendDocs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final fData = friendDocs[index].data() as Map<String, dynamic>;
                              final fUid = friendDocs[index].id;
                              final fName = fData['name'] ?? 'User';
                              final fUserId = fData['userId'] ?? 'ID';
                              final fAvatar = fData['avatar'] as String? ?? 'assets/icon_pack/avatar/avatar_2.png';

                              return GestureDetector(
                                onDoubleTap: () => _startPrivateChat(context, fUid, fName, fAvatar),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black, width: 1.5),
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            fAvatar,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, st) => Container(
                                              color: const Color(0xFFF1F5F9),
                                              child: const Icon(Icons.person_rounded, color: Colors.black38),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fName,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 16.4, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                            Text(
                                              'ID User: $fUserId',
                                              style: GoogleFonts.dmSans(fontSize: 14.0, color: Colors.black45),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _removeFriend(fUid, fName),
                                        icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
                                      ),
                                    ],
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
