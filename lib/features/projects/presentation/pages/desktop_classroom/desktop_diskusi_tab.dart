import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:hubner/main.dart' show HubnerApp;
import 'package:hubner/features/home/presentation/pages/chat_room_page.dart';
import 'package:hubner/features/home/presentation/pages/manage_friends_page.dart';

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
  String _searchQuery = '';

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

  void _showCreateDiscussionDialog(BuildContext context, {required bool isDark}) {
    final channelController = TextEditingController();
    final titleController = TextEditingController();
    List<Map<String, dynamic>> projectMembers = [];
    List<String> selectedMemberUids = [];
    String selectedAvatar = 'assets/icon_pack/chat/chat_1.png';
    bool isLoadingMembers = true;
    bool createDriveFolder = false;

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
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
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
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Buat Diskusi Baru',
                      style: AppTypography.chatHeaderTitle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),

                    // Project indicator card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF147D75) : const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(16),
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
                                  style: AppTypography.fileSize(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.currentProjectTitle,
                                  style: AppTypography.cardTitle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingMembers)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: ThreeDotsLoader()))
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: Text(
                                'Pilih Semua',
                                style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                              trailing: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (selectedMemberUids.length - 1 >= projectMembers.where((m) => m['uid'] != currentUid).length)
                                      ? const Color(0xFF7C3AED)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: (selectedMemberUids.length - 1 >= projectMembers.where((m) => m['uid'] != currentUid).length)
                                        ? const Color(0xFF7C3AED)
                                        : (isDark ? Colors.white38 : Colors.black26),
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
                            Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9), height: 1),
                            Expanded(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                itemCount: projectMembers.length,
                                separatorBuilder: (context, index) => Divider(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9), height: 1),
                                itemBuilder: (context, idx) {
                                  final m = projectMembers[idx];
                                  final mUid = m['uid'] as String;
                                  if (mUid == currentUid) return const SizedBox();
                                  final isChecked = selectedMemberUids.contains(mUid);

                                  return ListTile(
                                    title: Text(
                                      m['name'],
                                      style: AppTypography.buttonLabel(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      'ID: ${m['userId']}',
                                      style: AppTypography.channelTag(color: isDark ? Colors.white38 : Colors.black38),
                                    ),
                                    leading: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isDark ? const Color(0xFF27272A) : Colors.black, width: 1),
                                      ),
                                      child: ClipOval(
                                        child: _buildSafeAvatar(m['avatar'] as String?),
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    trailing: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isChecked ? const Color(0xFF7C3AED) : Colors.transparent,
                                        border: Border.all(
                                          color: isChecked ? const Color(0xFF7C3AED) : (isDark ? Colors.white38 : Colors.black26),
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
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: channelController,
                      style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Contoh: #diskusi-materi',
                        hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Judul Diskusi',
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      style: AppTypography.subtitle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Diskusi Belajar Kelas',
                        hintStyle: AppTypography.subtitle(color: isDark ? Colors.white38 : Colors.black26),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pilih Avatar Diskusi',
                      style: AppTypography.buttonLabel(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600),
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
                                    color: isSelected
                                        ? const Color(0xFF7C3AED)
                                        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _buildSafeAvatar(avatarPath),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Opsi Buat Folder Penyimpanan Data
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
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
                            child: const Icon(
                              Icons.folder_shared_rounded,
                              color: Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Folder Penyimpanan Data',
                                  style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Buat folder arsip berkas grup otomatis',
                                  style: AppTypography.fileSize(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: createDriveFolder,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF7C3AED),
                            onChanged: (val) {
                              setModalState(() {
                                createDriveFolder = val;
                              });
                            },
                          ),
                        ],
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
                            'createDriveFolder': createDriveFolder,
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
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Diskusi baru berhasil dibuat!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Buat Diskusi',
                          style: AppTypography.cardTitle(fontWeight: FontWeight.bold),
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

    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.themeNotifier,
      builder: (context, themeMode, _) {
        final bool isDark = themeMode == 'Gelap' ||
            themeMode == 'Hitam' ||
            Theme.of(context).brightness == Brightness.dark;

        return Row(
          children: [
            // ─── 30% Left Panel: List of Discussion Threads for Current Classroom ───
            Expanded(
              flex: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
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
                            style: AppTypography.pageTitle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
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
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                Icons.people_outline_rounded,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Create New Discussion Thread Button (+)
                          GestureDetector(
                            onTap: () => _showCreateDiscussionDialog(context, isDark: isDark),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
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
                        style: AppTypography.timestamp(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Cari thread diskusi...',
                          hintStyle: AppTypography.timestamp(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          fillColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                    ),

                    // Stream List of Discussions for this Project
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('discussions')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const SizedBox.shrink();
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
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 48,
                                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'Belum ada thread diskusi untuk kelas ini.'
                                          : 'Thread diskusi tidak ditemukan.',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.timestamp(color: isDark ? Colors.white60 : const Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => _showCreateDiscussionDialog(context, isDark: isDark),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C3AED),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: Text(
                                        'Buat Diskusi Baru',
                                        style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: filteredDocs.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                            ),
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
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF2E1065) : const Color(0xFFEFF6FF))
                                        : (isDark ? const Color(0xFF18181B) : Colors.white),
                                    border: isSelected
                                        ? Border(
                                            left: BorderSide(
                                              color: isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED),
                                              width: 4,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: _buildSafeAvatar(avatar),
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
                                              style: AppTypography.channelTag(color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF475569), fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.buttonLabel(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              lastMsg,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.timestamp(color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF475569)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (unreadCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF14B8A6) : const Color(0xFF7C3AED),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            unreadCount > 99 ? '99+' : '$unreadCount',
                                            style: AppTypography.channelTag(color: Colors.white, fontWeight: FontWeight.bold),
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
                color: isDark ? const Color(0xFF000000) : Colors.white,
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
                          style: AppTypography.timestamp(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
