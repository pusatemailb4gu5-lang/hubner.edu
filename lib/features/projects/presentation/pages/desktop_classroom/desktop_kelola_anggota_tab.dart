import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hubner/features/projects/domain/activity_logger.dart';

final List<Color> _classroomAccentColors = const [
  Color(0xFF009688), // 0: Teal
  Color(0xFF448AFF), // 1: Blue
  Color(0xFFE040FB), // 2: Purple/Magenta
  Color(0xFFFF4081), // 3: Pink/Rose
  Color(0xFFFFAB40), // 4: Orange/Amber
  Color(0xFF536DFE), // 5: Indigo
  Color(0xFF607D8B), // 6: Blue Grey
];

class DesktopKelolaAnggotaTab extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const DesktopKelolaAnggotaTab({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<DesktopKelolaAnggotaTab> createState() =>
      _DesktopKelolaAnggotaTabState();
}

class _DesktopKelolaAnggotaTabState extends State<DesktopKelolaAnggotaTab> {
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _searchMemberController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _searchMemberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: ThreeDotsLoader());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String ownerUid = data['ownerUid'] as String? ?? '';
        final bool isOwner =
            ownerUid == (FirebaseAuth.instance.currentUser?.uid ?? '');
        final int? rawColorIndex = data['colorIndex'] as int?;

        // 40/60 Color Concept Accent Sync
        final Color accentColor = rawColorIndex != null
            ? _classroomAccentColors[rawColorIndex % _classroomAccentColors.length]
            : const Color(0xFF7C3AED);

        final List membersArray = data['members'] as List? ?? [];

        return SingleChildScrollView(
            key: const PageStorageKey('KelolaAnggotaScroll'),
            padding: const EdgeInsets.only(left: 24, right: 24, top: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. TOP HERO BANNER (Indigo Style) ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Color(0xFF4F46E5),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kelola Anggota & Komunitas Kelas',
                              style: AppTypography.pageTitle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Undang Siswa, Konfirmasi Permintaan Bergabung, dan Kelola Anggota Kelas',
                              style: AppTypography.timestamp(color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ─── 2. 3-COLUMN DESKTOP MAIN VIEW ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COLUMN 1 (Width ~30% / flex: 3): Undang Siswa & Kode Kelas
                    Expanded(
                      flex: 3,
                      child: _buildColumn1InviteCard(
                        accentColor: accentColor,
                        projectId: widget.projectId,
                      ),
                    ),
                    const SizedBox(width: 18),

                    // COLUMN 2 (Width ~32% / flex: 3): Permintaan Bergabung
                    Expanded(
                      flex: 3,
                      child: _buildColumn2JoinRequestsCard(
                        accentColor: accentColor,
                        projectId: widget.projectId,
                        isOwner: isOwner,
                      ),
                    ),
                    const SizedBox(width: 18),

                    // COLUMN 3 (Width ~38% / flex: 4): Daftar Anggota Kelas
                    Expanded(
                      flex: 4,
                      child: _buildColumn3MemberListCard(
                        accentColor: accentColor,
                        projectId: widget.projectId,
                        ownerUid: ownerUid,
                        isOwner: isOwner,
                        membersArray: membersArray,
                        studentsMasterList: data['studentsMasterList'] as List? ?? [],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        );
      },
    );
  }

  // ─── COLUMN 1: UNDANG SISWA & KODE KELAS ───
  Widget _buildColumn1InviteCard({
    required Color accentColor,
    required String projectId,
  }) {
    const Color magentaColor = Color(0xFFC026D3);
    const Color purpleColor = Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_add_rounded,
                color: magentaColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Undang Anggota',
                style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kode Kelas Container with Copy Action
          Text(
            'Kode Akses Kelas',
            style: AppTypography.buttonLabel(color: const Color(0xFF000000, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.key_rounded,
                    size: 16, color: magentaColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    projectId,
                    style: AppTypography.buttonLabel(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: projectId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kode kelas berhasil disalin: $projectId'),
                        backgroundColor: magentaColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: magentaColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Salin',
                          style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Invite Email Field
          Text(
            'Undang via Email Siswa',
            style: AppTypography.buttonLabel(color: const Color(0xFF000000, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _inviteEmailController,
            decoration: InputDecoration(
              hintText: 'Masukkan email siswa...',
              hintStyle: AppTypography.timestamp(color: Colors.grey),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: purpleColor, width: 1.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sendEmailInvitation,
              icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              label: Text(
                'Kirim Undangan',
                style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // QR Code Display
          Center(
            child: Column(
              children: [
                QrImageView(
                  data: projectId,
                  version: QrVersions.auto,
                  size: 110,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan QR Code untuk Gabung Kelas',
                  style: AppTypography.timestamp(color: const Color(0xFF000000),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── COLUMN 2: PERMINTAAN BERGABUNG ───
  Widget _buildColumn2JoinRequestsCard({
    required Color accentColor,
    required String projectId,
    required bool isOwner,
  }) {
    final collectionRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('join_requests');

    return StreamBuilder<QuerySnapshot>(
      stream: collectionRef.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.how_to_reg_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Permintaan Bergabung',
                    style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${docs.length}',
                      style: AppTypography.buttonLabel(color: const Color(0xFF10B981, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 36, color: const Color(0xFF000000)),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada permintaan bergabung saat ini.',
                          textAlign: TextAlign.center,
                          style: AppTypography.timestamp(color: const Color(0xFF000000),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final reqDoc = docs[index];
                    final reqData = reqDoc.data() as Map<String, dynamic>;
                    final String userUid = reqData['uid'] ?? reqDoc.id;
                    final String userName = reqData['name'] ?? 'Siswa Baru';
                    final String email = reqData['email'] ?? 'siswa@hubner.edu';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.15),
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'S',
                                  style: AppTypography.buttonLabel(color: accentColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: AppTypography.buttonLabel(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      email,
                                      style: AppTypography.timestamp(color: const Color(0xFF000000),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isOwner)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _approveRequest(
                                        projectId, reqDoc.id, userUid),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Setujui',
                                      style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _rejectRequest(
                                        projectId, reqDoc.id),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(
                                          color: Color(0xFFEF4444)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Tolak',
                                      style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
          ],
        ),
      );
    },
  );
}

  // ─── COLUMN 3: DAFTAR ANGGOTA KELAS ───
  Widget _buildColumn3MemberListCard({
    required Color accentColor,
    required String projectId,
    required String ownerUid,
    required bool isOwner,
    required List membersArray,
    List studentsMasterList = const [],
  }) {
    final membersCollection = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('members');

    return StreamBuilder<QuerySnapshot>(
      stream: membersCollection.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final List<Map<String, dynamic>> memberItems = [];

        if (studentsMasterList.isNotEmpty) {
          for (int i = 0; i < studentsMasterList.length; i++) {
            final m = studentsMasterList[i];
            if (m is Map) {
              final bool isJoined = m['joined'] == true;
              final String sUid = (m['uid'] ?? '').toString();
              // Only include students who have joined (joined == true) and have a valid ID
              if (isJoined && sUid.isNotEmpty) {
                memberItems.add({
                  'docId': sUid,
                  'uid': sUid,
                  'name': m['name'] ?? 'Siswa ${i + 1}',
                  'email': m['email'] ?? 'siswa@hubner.edu',
                  'photoUrl': m['photoUrl'] ?? m['avatar'] ?? m['avatarUrl'],
                  'role': 'Siswa',
                  'joined': true,
                });
              }
            }
          }
        } else if (docs.isNotEmpty) {
          for (var doc in docs) {
            final m = doc.data() as Map<String, dynamic>;
            memberItems.add({
              'docId': doc.id,
              'uid': m['uid'] ?? doc.id,
              'name': m['name'] ?? 'Anggota Kelas',
              'email': m['email'] ?? 'anggota@hubner.edu',
              'photoUrl': m['photoUrl'] ?? m['avatar'] ?? m['avatarUrl'],
              'role': m['role'] ?? (doc.id == ownerUid ? 'Guru' : 'Siswa'),
              'joined': m['joined'] ?? true,
            });
          }
        } else {
          for (int i = 0; i < membersArray.length; i++) {
            final m = membersArray[i];
            if (m is Map) {
              memberItems.add({
                'docId': m['uid'] ?? 'm_$i',
                'uid': m['uid'] ?? 'm_$i',
                'name': m['name'] ?? 'Anggota ${i + 1}',
                'email': m['email'] ?? 'anggota@hubner.edu',
                'photoUrl': m['photoUrl'] ?? m['avatar'] ?? m['avatarUrl'],
                'role': m['role'] ?? 'Siswa',
                'joined': true,
              });
            } else if (m is String) {
              memberItems.add({
                'docId': m,
                'uid': m,
                'name': m == ownerUid ? 'Guru Pengajar' : 'Siswa Kelas',
                'email': 'anggota@hubner.edu',
                'role': m == ownerUid ? 'Guru' : 'Siswa',
                'joined': true,
              });
            }
          }
        }

        final filteredMembers = memberItems.where((m) {
          final String name = (m['name'] ?? '').toString().toLowerCase();
          final String email = (m['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase()) ||
              email.contains(_searchQuery.toLowerCase());
        }).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF0284C7),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daftar Anggota Kelas',
                    style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredMembers.length} Anggota',
                      style: AppTypography.buttonLabel(color: const Color(0xFF0284C7, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Field
              TextField(
                controller: _searchMemberController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 18, color: Color(0xFF7C3AED)),
                  hintText: 'Cari nama atau email anggota...',
                  hintStyle:
                      AppTypography.timestamp(color: Colors.grey),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (filteredMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Tidak ada anggota yang cocok.',
                      style: AppTypography.timestamp(color: const Color(0xFF000000),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredMembers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final m = filteredMembers[index];
                    final String name = m['name'] ?? 'Anggota';
                    final String uid = m['uid'] ?? '';
                    final String role = m['role'] ?? 'Siswa';
                    final String? photoUrl = m['photoUrl'] as String?;
                    final bool isTeacher = role.toLowerCase() == 'guru';
                    final bool hasValidPhoto = photoUrl != null && photoUrl.startsWith('http');

                    final Color avatarColor = _getMemberAvatarColor(name);

                    // Fetch real avatar from users collection if not available
                    return FutureBuilder<DocumentSnapshot>(
                      future: uid.isNotEmpty
                          ? FirebaseFirestore.instance.collection('users').doc(uid).get()
                          : null,
                      builder: (context, userSnap) {
                        String? realPhotoUrl = photoUrl;
                        String displayName = name;
                        String displayUserId = '';
                        if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                          final userPhoto = userData['profileImageUrl'] ?? userData['photoUrl'] ?? userData['avatar'] ?? userData['avatarUrl'];
                          if (userPhoto != null && userPhoto.toString().isNotEmpty) {
                            realPhotoUrl = userPhoto.toString();
                          }
                          if (isTeacher && (userData['name'] ?? '').toString().isNotEmpty) {
                            displayName = userData['name'];
                          }
                          displayUserId = (userData['userId'] ?? '').toString();
                        }
                        final String finalUserId = displayUserId.isNotEmpty ? displayUserId : uid;
                        final String avatarPath = realPhotoUrl ?? '';
                        final bool isAsset = avatarPath.startsWith('assets/');
                        final bool isNetwork = avatarPath.startsWith('http');

                        Widget avatarChild;
                        if (isNetwork) {
                          avatarChild = ClipOval(
                            child: Transform.scale(
                              scale: 1.35,
                              child: Image.network(
                                avatarPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInitialAvatar(displayName, isTeacher, avatarColor),
                              ),
                            ),
                          );
                        } else if (isAsset) {
                          avatarChild = ClipOval(
                            child: Transform.scale(
                              scale: 1.35,
                              child: Image.asset(
                                avatarPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInitialAvatar(displayName, isTeacher, avatarColor),
                              ),
                            ),
                          );
                        } else {
                          avatarChild = _buildInitialAvatar(displayName, isTeacher, avatarColor);
                        }

                        return Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isTeacher
                                    ? accentColor.withValues(alpha: 0.15)
                                    : avatarColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: avatarChild,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: AppTypography.buttonLabel(color: const Color(0xFF000000, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: $finalUserId',
                                    style: GoogleFonts.dmMono(
                                      fontSize: 14.0,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isTeacher
                                    ? accentColor.withValues(alpha: 0.12)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                role,
                                style: AppTypography.buttonLabel(color: isTeacher, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
          ],
        ),
      );
    },
  );
}

  void _sendEmailInvitation() {
    final email = _inviteEmailController.text.trim();
    if (email.isNotEmpty) {
      _inviteEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Undangan telah dikirim ke $email'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  void _approveRequest(String projectId, String reqDocId, String userUid) async {
    final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(projectId);

    await projectRef.collection('join_requests').doc(reqDocId).delete();
    await projectRef.collection('members').doc(userUid).set({
      'uid': userUid,
      'role': 'Siswa',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await projectRef.update({
      'members': FieldValue.arrayUnion([userUid]),
      'students': FieldValue.arrayUnion([userUid]),
    });

    await logClassroomActivity(
      projectId: projectId,
      type: 'siswa',
      actor: 'Siswa',
      action: 'telah bergabung ke',
      target: widget.projectTitle,
    );
  }

  void _rejectRequest(String projectId, String reqDocId) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('join_requests')
        .doc(reqDocId)
        .delete();
  }

  Widget _buildInitialAvatar(String name, bool isTeacher, Color avatarColor) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    return Center(
      child: Text(
        initial,
        style: AppTypography.cardTitle(color: isTeacher ? Colors.white : avatarColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getMemberAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> avatarColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];
    return avatarColors[hash % avatarColors.length];
  }
}
