import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageMembersPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String ownerUid;
  final bool isEmbedded;
  final VoidCallback? onCloseInline;

  const ManageMembersPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.ownerUid,
    this.isEmbedded = false,
    this.onCloseInline,
  });

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  final TextEditingController _inviteController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember() async {
    final inputId = _inviteController.text.trim();
    if (inputId.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu untuk mengelola anggota.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _isInviting = true;
    });

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: inputId)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID User tidak ditemukan. Periksa kembali ID!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final targetUserDoc = userQuery.docs.first;
      final targetUid = targetUserDoc.id;
      final targetName = targetUserDoc.get('name') ?? 'User';

      // Check if user is already a member
      final projectIds = List<String>.from(targetUserDoc.data()['projectIds'] ?? []);
      if (projectIds.contains(widget.projectId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengguna tersebut sudah terdaftar di kelas ini.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Check if invitation is already pending
      final pendingQuery = await FirebaseFirestore.instance
          .collection('projectInvitations')
          .where('projectId', isEqualTo: widget.projectId)
          .where('invitedUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Undangan untuk pengguna ini masih tertunda (Pending).'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Fetch sender details
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final senderName = senderDoc.exists ? (senderDoc.get('name') ?? 'Guru') : 'Guru';

      String projectIcon = 'project_1.png';
      try {
        final projDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
        if (projDoc.exists) {
          projectIcon = (projDoc.data()?['icon'] as String?) ?? 'project_1.png';
        }
      } catch (_) {}

      await FirebaseFirestore.instance.collection('projectInvitations').add({
        'projectId': widget.projectId,
        'projectName': widget.projectName,
        'projectIcon': projectIcon,
        'invitedUid': targetUid,
        'invitedUserId': inputId,
        'invitedName': targetName,
        'senderUid': currentUid,
        'senderName': senderName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _inviteController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undangan berhasil dikirim ke $targetName! Status: Pending.'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim undangan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Future<void> _cancelInvitation(String invitationId, String targetName) async {
    try {
      await FirebaseFirestore.instance.collection('projectInvitations').doc(invitationId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undangan untuk $targetName dibatalkan.'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan undangan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(String memberUid, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Hapus Anggota',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $memberName dari kelas ini?',
          style: GoogleFonts.dmSans(fontSize: 15.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
        if (doc.exists) {
          final List masterList = doc.data()?['studentsMasterList'] as List? ?? [];
          final List<Map<String, dynamic>> updatedMasterList = [];
          for (var item in masterList) {
            if (item is Map) {
              final String itemUid = item['uid'] ?? '';
              if (itemUid == memberUid) {
                updatedMasterList.add({
                  'name': item['name'] ?? '',
                  'uid': '',
                  'joined': false,
                });
              } else {
                updatedMasterList.add({
                  'name': item['name'] ?? '',
                  'uid': itemUid,
                  'joined': item['joined'] ?? false,
                });
              }
            }
          }
          await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
            'studentsMasterList': updatedMasterList,
          });
        }

        await FirebaseFirestore.instance.collection('users').doc(memberUid).update({
          'projectIds': FieldValue.arrayRemove([widget.projectId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$memberName berhasil dihapus dari kelas.'),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus anggota: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleJoinRequest(String requestId, String requesterUid, bool accept) async {
    try {
      if (accept) {
        final requestSnap = await FirebaseFirestore.instance.collection('projectJoinRequests').doc(requestId).get();
        final requestData = requestSnap.data();
        final String selectedMasterName = requestData?['selectedMasterName'] ?? '';

        if (selectedMasterName.isNotEmpty) {
          final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
          final List masterList = projectDoc.data()?['studentsMasterList'] as List? ?? [];
          final List<Map<String, dynamic>> updatedMasterList = [];
          for (var item in masterList) {
            if (item is Map) {
              final String name = item['name'] ?? '';
              if (name.toLowerCase() == selectedMasterName.toLowerCase()) {
                updatedMasterList.add({
                  'name': name,
                  'uid': requesterUid,
                  'joined': true,
                });
              } else {
                updatedMasterList.add({
                  'name': name,
                  'uid': item['uid'] ?? '',
                  'joined': item['joined'] ?? false,
                });
              }
            }
          }
          await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
            'studentsMasterList': updatedMasterList,
          });
        }

        await FirebaseFirestore.instance.collection('users').doc(requesterUid).update({
          'projectIds': FieldValue.arrayUnion([widget.projectId]),
        });
        await FirebaseFirestore.instance.collection('projectJoinRequests').doc(requestId).update({
          'status': 'accepted',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permintaan diterima. Anggota berhasil bergabung.'),
              backgroundColor: Color(0xFF0F172A),
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('projectJoinRequests').doc(requestId).update({
          'status': 'rejected',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permintaan bergabung ditolak.'),
              backgroundColor: Color(0xFF0F172A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildAvatarImage(Map<String, dynamic> userData, int index) {
    final photo = (userData['profileImageUrl'] ??
            userData['photoUrl'] ??
            userData['avatarUrl'] ??
            userData['avatar'] ??
            '')
        .toString()
        .trim();
    final name = (userData['name'] ?? 'U').toString().trim();

    if (photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return Image.network(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, index),
        );
      } else {
        return Image.asset(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, index),
        );
      }
    }
    return _buildFallbackAvatar(name, index);
  }

  Widget _buildFallbackAvatar(String name, int index) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    const colors = [
      Color(0xFFFEF08A), // Light Yellow
      Color(0xFFBBF7D0), // Light Green
      Color(0xFFFBCFE8), // Light Pink
      Color(0xFFBAE6FD), // Light Blue
      Color(0xFFDDD6FE), // Light Purple
    ];
    final Color bgColor = colors[index % colors.length];

    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final contentWidget = StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, projectSnap) {
        final projectData = projectSnap.data?.data() as Map<String, dynamic>? ?? {};
        final List masterList = projectData['studentsMasterList'] as List? ?? [];

        // Build a map of uid -> attendance full name
        final Map<String, String> uidToAttendanceName = {};
        for (var item in masterList) {
          if (item is Map) {
            final String u = (item['uid'] ?? '').toString();
            final String n = (item['name'] ?? '').toString();
            if (u.isNotEmpty && n.isNotEmpty) {
              uidToAttendanceName[u] = n;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Top App Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isEmbedded ? 12.0 : 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!widget.isEmbedded)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 22,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Data Anggota Kelas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.isEmbedded)
                    const SizedBox(width: 46),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
            ),

            const SizedBox(height: 16),

            // Invite Member Section (Only project owner can invite)
            if (currentUid == widget.ownerUid)
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
                          controller: _inviteController,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ketik ID pengguna untuk undang...',
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
                        onTap: _isInviting ? null : _inviteMember,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.center,
                          child: _isInviting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Undang',
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

            // Pending Join Requests & Pending Invitations (Owner View)
            if (currentUid == widget.ownerUid) ...[
              // 1. Permintaan Bergabung (Siswa Minta Gabung)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projectJoinRequests')
                    .where('projectId', isEqualTo: widget.projectId)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const SizedBox();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permintaan Bergabung (${docs.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final reqId = docs[index].id;
                            final requesterUid = data['requesterUid'] ?? '';
                            final requesterName = data['requesterName'] ?? 'User';
                            final requesterUserId = data['requesterUserId'] ?? 'ID';

                            return Container(
                              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
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
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFFFF7ED),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        requesterName.isNotEmpty ? requesterName.substring(0, 1).toUpperCase() : 'U',
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA580C), fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          requesterName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'ID: $requesterUserId',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14.5,
                                            color: isDark ? Colors.white54 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _handleJoinRequest(reqId, requesterUid, true),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _handleJoinRequest(reqId, requesterUid, false),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),

              // 2. Menunggu Persetujuan Siswa (Undangan yang Dikirim Guru)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projectInvitations')
                    .where('projectId', isEqualTo: widget.projectId)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, invSnapshot) {
                  final invDocs = invSnapshot.data?.docs ?? [];
                  if (invDocs.isEmpty) return const SizedBox();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menunggu Persetujuan Siswa (${invDocs.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: invDocs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = invDocs[index].data() as Map<String, dynamic>;
                            final invId = invDocs[index].id;
                            final invitedName = data['invitedName'] ?? 'Siswa';
                            final invitedUserId = data['invitedUserId'] ?? 'ID';

                            return Container(
                              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
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
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFEFF6FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.outgoing_mail, color: Color(0xFF2563EB), size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          invitedName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'ID: $invitedUserId • Status: Pending',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14.5,
                                            color: const Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _cancelInvitation(invId, invitedName),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Icon(
                                        Icons.cancel_outlined,
                                        color: Colors.redAccent.withValues(alpha: 0.85),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Active Members Heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Data Anggota Kelas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Active Members List (Guru selalu di urutan paling atas, diikuti siswa)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('projectIds', arrayContains: widget.projectId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rawDocs = snapshot.data?.docs ?? [];

                  if (rawDocs.isEmpty) {
                    return Center(
                      child: Text(
                        'Tidak ada anggota terdaftar.',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    );
                  }

                  // Sort members: Guru/Owner selalu di urutan PALING ATAS!
                  final memberDocs = List<QueryDocumentSnapshot>.from(rawDocs);
                  memberDocs.sort((a, b) {
                    final aId = a.id;
                    final bId = b.id;
                    final aData = a.data() as Map<String, dynamic>? ?? {};
                    final bData = b.data() as Map<String, dynamic>? ?? {};
                    final aRole = (aData['role'] ?? '').toString().toLowerCase();
                    final bRole = (bData['role'] ?? '').toString().toLowerCase();

                    final aIsGuru = aId == widget.ownerUid || aRole == 'guru' || aRole == 'teacher' || aRole == 'pengajar' || aRole == 'admin';
                    final bIsGuru = bId == widget.ownerUid || bRole == 'guru' || bRole == 'teacher' || bRole == 'pengajar' || bRole == 'admin';

                    if (aIsGuru && !bIsGuru) return -1;
                    if (!aIsGuru && bIsGuru) return 1;

                    final aName = (aData['name'] ?? '').toString().toLowerCase();
                    final bName = (bData['name'] ?? '').toString().toLowerCase();
                    return aName.compareTo(bName);
                  });

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                    builder: (context, currentUserSnapshot) {
                      final currentUserData = currentUserSnapshot.data?.data() as Map<String, dynamic>?;
                      final List<String> friendUids = List<String>.from(currentUserData?['friendUids'] ?? []);

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: memberDocs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final memberData = memberDocs[index].data() as Map<String, dynamic>;
                          final memberUid = memberDocs[index].id;
                          final rawName = (memberData['name'] ?? 'User').toString();
                          final memberUserId = (memberData['userId'] ?? 'ID').toString();
                          final isOwner = memberUid == widget.ownerUid;
                          final role = (memberData['role'] ?? '').toString().toLowerCase();

                          final bool isGuru = isOwner || role == 'guru' || role == 'teacher' || role == 'pengajar' || role == 'admin';

                          // Nama Lengkap sesuai absensi (jika ada master list), atau fallback ke nama akun
                          final String attendanceName = uidToAttendanceName[memberUid] ?? '';
                          final String displayName = attendanceName.isNotEmpty ? attendanceName : rawName;

                          return Container(
                            height: 64,
                            padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
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
                                // Model Avatar: Samakan persis dengan Avatar di Tumpukan (Besar, Frameless, Scale 1.45)
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
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
                                      child: _buildAvatarImage(memberData, index),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Nama Lengkap
                                      Text(
                                        displayName + (memberUid == currentUid ? ' (Anda)' : ''),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      // ID Siswa / Status Guru
                                      Text(
                                        isGuru ? 'Guru (Pengajar)' : 'ID: $memberUserId',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14.0,
                                          color: isGuru
                                              ? const Color(0xFF0D9488)
                                              : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                          fontWeight: isGuru ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (memberUid != currentUid) ...[
                                      friendUids.contains(memberUid)
                                          ? const Padding(
                                              padding: EdgeInsets.all(6.0),
                                              child: Icon(
                                                Icons.people_rounded,
                                                size: 22,
                                                color: Color(0xFF10B981),
                                              ),
                                            )
                                          : GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () async {
                                                await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                                                  'friendUids': FieldValue.arrayUnion([memberUid]),
                                                });
                                                await FirebaseFirestore.instance.collection('users').doc(memberUid).update({
                                                  'friendUids': FieldValue.arrayUnion([currentUid]),
                                                });
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('$displayName sekarang adalah teman Anda!'),
                                                      backgroundColor: const Color(0xFF0F172A),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.all(6.0),
                                                child: Icon(
                                                  Icons.person_add_alt_1_rounded,
                                                  size: 22,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                      const SizedBox(width: 4),
                                    ],
                                    // Project Owner can remove other members
                                    if (currentUid == widget.ownerUid && !isOwner)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _removeMember(memberUid, displayName),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6.0),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent.withValues(alpha: 0.85),
                                            size: 22,
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
                },
              ),
            ),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return Container(
        color: Colors.transparent,
        child: contentWidget,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: contentWidget,
      ),
    );
  }
}
