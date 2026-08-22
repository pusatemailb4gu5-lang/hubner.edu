import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/features/home/presentation/pages/chat_room_page.dart';
import 'package:hubner/features/home/presentation/pages/manage_friends_page.dart';
import 'package:hubner/features/projects/presentation/pages/desktop_classroom_page.dart';

class DesktopDiskusiTab extends StatefulWidget {
  final String currentProjectId;
  final String currentProjectTitle;

  const DesktopDiskusiTab({
    super.key,
    required this.currentProjectId,
    required this.currentProjectTitle,
  });

  @override
  State<DesktopDiskusiTab> createState() => _DesktopDiskusiTabState();
}

class _DesktopDiskusiTabState extends State<DesktopDiskusiTab> {
  String? _selectedDiscussionId;
  String _selectedChannelName = '';
  String _selectedTitle = '';
  String _searchQuery = '';

  Future<List<Map<String, dynamic>>> _loadProjectMembers(String projectId) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('projectIds', arrayContains: projectId)
        .get();

    return query.docs.map((doc) => {
      'uid': doc.id,
      'name': doc.data()['name'] ?? 'User',
      'userId': doc.data()['userId'] ?? '',
      'avatar': doc.data()['avatar'] ?? 'assets/icon_pack/avatar/avatar_2.png',
    }).toList();
  }

  void _showCreateDiscussionDialog(BuildContext context) {
    final channelController = TextEditingController();
    final titleController = TextEditingController();
    List<Map<String, dynamic>> projectMembers = [];
    List<String> selectedMemberUids = [];
    String selectedAvatar = 'assets/icon_pack/chat/chat_1.png';
    bool isLoadingMembers = true;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    selectedMemberUids.add(currentUid);

    _loadProjectMembers(widget.currentProjectId).then((members) {
      projectMembers = members;
      selectedMemberUids = members.map((m) => m['uid'] as String).toList();
      if (!selectedMemberUids.contains(currentUid)) {
        selectedMemberUids.add(currentUid);
      }
      isLoadingMembers = false;
    });

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
                bottom: MediaQuery.of(context).viewInsets.bottom + (MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 16 + MediaQuery.of(context).padding.bottom),
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
                      'Buat Diskusi Baru',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 21.1,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Project indicator card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Grup Kelas',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.7,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.currentProjectTitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.4,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Anggota Diskusi',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingMembers)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: ThreeDotsLoader()))
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
                                    subtitle: Text('ID: ${m['userId']}', style: GoogleFonts.plusJakartaSans(fontSize: 11.7, color: Colors.black38)),
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
                        hintText: 'Contoh: #diskusi-materi',
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
                        hintText: 'Contoh: Diskusi Belajar Kelas',
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

                          final newDocRef = await FirebaseFirestore.instance.collection('discussions').add({
                            'projectId': widget.currentProjectId,
                            'channel': chan.startsWith('#') ? chan : '#$chan',
                            'title': ttl,
                            'avatar': selectedAvatar,
                            'lastMessage': 'Mulai diskusi baru...',
                            'time': 'Sekarang',
                            'memberUids': finalMembers,
                            'creatorUid': currentUid,
                            'createdAt': FieldValue.serverTimestamp(),
                            'colorIndex': Random().nextInt(5),
                            'unreadCounts': {
                              for (var mUid in finalMembers) mUid: 0
                            },
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            setState(() {
                              _selectedDiscussionId = newDocRef.id;
                              _selectedChannelName = chan.startsWith('#') ? chan : '#$chan';
                              _selectedTitle = ttl;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Diskusi baru berhasil dibuat!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Buat Diskusi',
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

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Row(
      children: [
        // ─── 30% Left Panel: List of Discussion Threads for Current Classroom ───
        Expanded(
          flex: 30,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Title, Member Icon, + Create Button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'Diskusi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      // Manage Friends / Members button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageFriendsPage()),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Create New Discussion Thread Button (+)
                      GestureDetector(
                        onTap: () => _showCreateDiscussionDialog(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Cari thread diskusi...',
                      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Stream List of Discussions for this Project
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('discussions')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(24), child: ThreeDotsLoader()));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      
                      // Filter docs by projectId and user membership
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final docProjectId = data['projectId'] as String? ?? '';
                        if (docProjectId != widget.currentProjectId) return false;

                        final memberUids = data['memberUids'] as List?;
                        if (memberUids != null && !memberUids.contains(currentUid)) {
                          return false;
                        }

                        if (_searchQuery.isNotEmpty) {
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final channel = (data['channel'] ?? '').toString().toLowerCase();
                          return title.contains(_searchQuery) || channel.contains(_searchQuery);
                        }
                        return true;
                      }).toList();

                      // Auto-select first thread if nothing selected or selected doc is gone
                      if (filteredDocs.isNotEmpty) {
                        final bool activeExists = filteredDocs.any((d) => d.id == _selectedDiscussionId);
                        if (!activeExists) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              final firstData = filteredDocs[0].data() as Map<String, dynamic>;
                              setState(() {
                                _selectedDiscussionId = filteredDocs[0].id;
                                _selectedChannelName = firstData['channel'] ?? '#general';
                                _selectedTitle = firstData['title'] ?? '';
                              });
                            }
                          });
                        }
                      }

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.forum_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Belum ada thread diskusi untuk kelas ini.'
                                      : 'Thread diskusi tidak ditemukan.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.5,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showCreateDiscussionDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text('Buat Diskusi Baru', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                        itemBuilder: (context, index) {
                          final docId = filteredDocs[index].id;
                          final chat = filteredDocs[index].data() as Map<String, dynamic>;
                          final channelName = chat['channel'] ?? '#general';
                          final title = chat['title'] ?? 'Diskusi';
                          final lastMsg = chat['lastMessage'] ?? '';
                          final avatar = chat['avatar'] as String? ?? 'assets/icon_pack/chat/chat_1.png';
                          final isSelected = docId == _selectedDiscussionId;

                          final Map<String, dynamic>? unreadCounts = chat['unreadCounts'] as Map<String, dynamic>?;
                          final int unreadCount = unreadCounts?[currentUid] as int? ?? 0;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDiscussionId = docId;
                                _selectedChannelName = channelName;
                                _selectedTitle = title;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                border: isSelected
                                    ? const Border(left: BorderSide(color: Color(0xFF2563EB), width: 4))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        avatar,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) => const Icon(Icons.forum_outlined),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          channelName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: const Color(0xFF0F766E),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
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
              ],
            ),
          ),
        ),

        // ─── 70% Right Panel: Embedded Group Chat Room Page ───
        Expanded(
          flex: 70,
          child: Container(
            color: Colors.white,
            child: _selectedDiscussionId != null
                ? ChatRoomPage(
                    key: ValueKey(_selectedDiscussionId),
                    discussionId: _selectedDiscussionId!,
                    channelName: _selectedChannelName,
                    projectId: widget.currentProjectId,
                    isEmbedded: true,
                  )
                : Center(
                    child: Text(
                      'Pilih atau buat thread diskusi untuk memulai obrolan.',
                      style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF94A3B8)),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
