import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../edit_class_page.dart';
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

class DesktopTahapanPembelajaranTab extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const DesktopTahapanPembelajaranTab({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<DesktopTahapanPembelajaranTab> createState() =>
      _DesktopTahapanPembelajaranTabState();
}

class _DesktopTahapanPembelajaranTabState
    extends State<DesktopTahapanPembelajaranTab> {
  int _selectedStageIndex = 0;

  int? _editingStageIndex;
  TextEditingController? _stageTitleController;

  int? _editingMateriIndex;
  TextEditingController? _materiTitleController;

  int? _editingDescMateriIndex;
  TextEditingController? _materiDescController;

  int? _editingStageDescIndex;
  TextEditingController? _stageDescController;

  bool _isManagingStages = false;
  final Set<int> _selectedManageIndices = {};

  @override
  void dispose() {
    _stageTitleController?.dispose();
    _materiTitleController?.dispose();
    _materiDescController?.dispose();
    _stageDescController?.dispose();
    super.dispose();
  }

  Future<void> _batchDeleteStages(List stages) async {
    if (_selectedManageIndices.isEmpty) return;

    final sortedIndices = _selectedManageIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in sortedIndices) {
      if (index < stages.length) {
        stages.removeAt(index);
      }
    }

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'stages': stages});

    if (mounted) {
      setState(() {
        _selectedManageIndices.clear();
        _isManagingStages = false;
        if (_selectedStageIndex >= stages.length && stages.isNotEmpty) {
          _selectedStageIndex = 0;
        }
      });
    }
  }

  Future<void> _batchUpdateStageStatus(String status, List stages) async {
    if (_selectedManageIndices.isEmpty) return;

    for (final index in _selectedManageIndices) {
      if (index < stages.length) {
        final stageMap = Map<String, dynamic>.from(stages[index] as Map);
        stageMap['status'] = status;
        stages[index] = stageMap;
      }
    }

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'stages': stages});

    if (mounted) {
      setState(() {
        _selectedManageIndices.clear();
        _isManagingStages = false;
      });
    }
  }

  Future<void> _addNewStage(List stages) async {
    final newStageNumber = stages.length + 1;
    final String stageTitle = 'Elemen $newStageNumber';
    final newStage = {
      'name': stageTitle,
      'summary': '',
      'materis': [
        {
          'title': 'Materi 1',
          'description': 'Penjelasan materi 1',
          'pdfs': [],
          'tasks': [],
        }
      ],
    };
    stages.add(newStage);
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'stages': stages});

    await logClassroomActivity(
      projectId: widget.projectId,
      type: 'elemen',
      actor: 'Guru Pengajar',
      action: 'menambahkan elemen baru',
      target: stageTitle,
    );

    if (mounted) {
      setState(() {
        _selectedStageIndex = stages.length - 1;
      });
    }
  }

  Future<void> _addNewMateri(int sIdx, List stages) async {
    if (sIdx >= stages.length) return;
    final materis = List.from(stages[sIdx]['materis'] as List? ?? []);
    final newMateriNumber = materis.length + 1;
    final String materiTitle = 'Materi $newMateriNumber';
    materis.add({
      'title': materiTitle,
      'pdfs': [],
      'tasks': [],
    });
    stages[sIdx]['materis'] = materis;

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'stages': stages});

    await logClassroomActivity(
      projectId: widget.projectId,
      type: 'materi',
      actor: 'Guru Pengajar',
      action: 'menambahkan materi baru',
      target: materiTitle,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveStageTitle(int idx, List stages) async {
    if (_stageTitleController == null) return;
    final newTitle = _stageTitleController!.text.trim();
    if (newTitle.isEmpty) return;

    stages[idx]['name'] = newTitle;
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'stages': stages});

    await logClassroomActivity(
      projectId: widget.projectId,
      type: 'elemen',
      actor: 'Guru Pengajar',
      action: 'memperbarui nama elemen',
      target: newTitle,
    );

    if (mounted) {
      setState(() {
        _editingStageIndex = null;
        _stageTitleController?.dispose();
        _stageTitleController = null;
      });
    }
  }

  Future<void> _saveMateriTitle(int sIdx, int mIdx, List stages) async {
    if (_materiTitleController == null) return;
    final newTitle = _materiTitleController!.text.trim();
    if (newTitle.isEmpty) return;

    final materis = List.from(stages[sIdx]['materis'] as List? ?? []);
    if (mIdx < materis.length) {
      final updatedM = Map<String, dynamic>.from(materis[mIdx] as Map);
      updatedM['title'] = newTitle;
      materis[mIdx] = updatedM;
      stages[sIdx]['materis'] = materis;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'stages': stages});

      await logClassroomActivity(
        projectId: widget.projectId,
        type: 'materi',
        actor: 'Guru Pengajar',
        action: 'memperbarui nama materi',
        target: newTitle,
      );
    }

    if (mounted) {
      setState(() {
        _editingMateriIndex = null;
      });
    }
  }

  Future<void> _saveMateriDesc(int sIdx, int mIdx, List stages) async {
    if (_materiDescController == null) return;
    final newDesc = _materiDescController!.text.trim();

    final materis = List.from(stages[sIdx]['materis'] as List? ?? []);
    if (mIdx < materis.length) {
      final updatedM = Map<String, dynamic>.from(materis[mIdx] as Map);
      updatedM['description'] =
          newDesc.isEmpty ? 'Belum ada penjelasan materi.' : newDesc;
      materis[mIdx] = updatedM;
      stages[sIdx]['materis'] = materis;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'stages': stages});

      await logClassroomActivity(
        projectId: widget.projectId,
        type: 'materi',
        actor: 'Guru Pengajar',
        action: 'memperbarui deskripsi materi',
        target: updatedM['title'] ?? 'Materi',
      );
    }

    if (mounted) {
      setState(() {
        _editingDescMateriIndex = null;
      });
    }
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

        // Sidebar Icon Color for Tahapan Pembelajaran (Violet / 0xFF7C3AED)
        const Color sidebarHeroColor = Color(0xFF7C3AED);

        final List stages = data['stages'] as List? ?? [];
        final String ownerUid = data['ownerUid'] as String? ?? '';
        final bool isOwner =
            ownerUid == (FirebaseAuth.instance.currentUser?.uid ?? '');

        if (_selectedStageIndex >= stages.length && stages.isNotEmpty) {
          _selectedStageIndex = 0;
        }

        return SingleChildScrollView(
            key: const PageStorageKey('TahapanPembelajaranScroll'),
            padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. TOP STAGE HERO BANNER ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: sidebarHeroColor,
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
                          Icons.account_tree_rounded,
                          color: sidebarHeroColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tahapan Belajar & Kurikulum',
                              style: AppTypography.pageTitle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stages.length} Elemen Tahapan Pembelajaran Terdaftar dalam Kelas',
                              style: AppTypography.timestamp(color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── 2. MULTI-COLUMN MAIN VIEW (Left 40% Rainbow Stage Nav + Right 60% Compact Detail Content) ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN (35-40%): Stage List & Navigation Card (Rainbow Profile Colors)
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.list_alt_rounded,
                                      color: Color(0xFFE11D48), // WARNA MERAH!
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Daftar Elemen Belajar',
                                      style: AppTypography.cardTitle(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (isOwner && !_isManagingStages) ...[
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isManagingStages = true;
                                            _selectedManageIndices.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: Text(
                                            'Kelola',
                                            style: AppTypography.buttonLabel(color: const Color(0xFF334155), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _addNewStage(stages),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFE11D48,
                                            ), // Warna Merah!
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.add_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                'Tambah',
                                                style:
                                                    AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (isOwner && _isManagingStages)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isManagingStages = false;
                                        _selectedManageIndices.clear();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF64748B),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Selesai',
                                        style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (_isManagingStages) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: Checkbox(
                                            value:
                                                _selectedManageIndices.length ==
                                                    stages.length &&
                                                stages.isNotEmpty,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedManageIndices
                                                      .clear();
                                                  _selectedManageIndices.addAll(
                                                    List.generate(
                                                      stages.length,
                                                      (i) => i,
                                                    ),
                                                  );
                                                } else {
                                                  _selectedManageIndices
                                                      .clear();
                                                }
                                              });
                                            },
                                            activeColor: const Color(
                                              0xFF7C3AED,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pilih Semua (${_selectedManageIndices.length}/${stages.length})',
                                          style: AppTypography.buttonLabel(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 5,
                                      children: [
                                        ElevatedButton(
                                          onPressed:
                                              _selectedManageIndices.isEmpty
                                                  ? null
                                                  : () => _batchDeleteStages(
                                                        stages,
                                                      ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFEF4444,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            'Hapus',
                                            style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              _selectedManageIndices.isEmpty
                                                  ? null
                                                  : () =>
                                                      _batchUpdateStageStatus(
                                                        'Akan Datang',
                                                        stages,
                                                      ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0284C7,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            'Akan Datang',
                                            style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              _selectedManageIndices.isEmpty
                                                  ? null
                                                  : () =>
                                                      _batchUpdateStageStatus(
                                                        'Proses Pembelajaran',
                                                        stages,
                                                      ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFD97706,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            'Proses Pembelajaran',
                                            style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              _selectedManageIndices.isEmpty
                                                  ? null
                                                  : () =>
                                                      _batchUpdateStageStatus(
                                                        'Selesai',
                                                        stages,
                                                      ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF059669,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            'Selesai',
                                            style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (stages.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'Belum ada elemen pembelajaran.',
                                    style: AppTypography.subtitle(color: const Color(0xFF000000)),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: stages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 2), // Jarak lebih dekat!
                                itemBuilder: (context, index) {
                                  final stage = stages[index] as Map;
                                  final String stageTitle =
                                      stage['name'] ?? stage['title'] ?? 'Elemen ${index + 1}';
                                  final List materis =
                                      stage['materis'] as List? ?? [];
                                  final bool isSelected =
                                      index == _selectedStageIndex;

                                  final Color elemColor = _classroomAccentColors[
                                      index % _classroomAccentColors.length];

                                  return InkWell(
                                    onTap: () {
                                      if (_isManagingStages) {
                                        setState(() {
                                          if (_selectedManageIndices.contains(index)) {
                                            _selectedManageIndices.remove(index);
                                          } else {
                                            _selectedManageIndices.add(index);
                                          }
                                        });
                                      } else {
                                        setState(() {
                                          _selectedStageIndex = index;
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? elemColor.withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          if (_isManagingStages) ...[
                                            SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: Checkbox(
                                                value: _selectedManageIndices
                                                    .contains(index),
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedManageIndices
                                                          .add(index);
                                                    } else {
                                                      _selectedManageIndices
                                                          .remove(index);
                                                    }
                                                  });
                                                },
                                                activeColor: const Color(
                                                  0xFF7C3AED,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: elemColor, // Warna pelangi tetap aktif walau tidak terpilih!
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style:
                                                    AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  stageTitle,
                                                  style:
                                                      AppTypography.buttonLabel(color: isSelected, fontWeight: isSelected),
                                                ),
                                                Text(
                                                  '${materis.length} Materi',
                                                  style: AppTypography.timestamp(color: const Color()),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: elemColor,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // RIGHT COLUMN (60-65%): Soft Blue Info Banner & Compact Materi List
                    Expanded(
                      flex: 6,
                      child: _buildStageDetailView(
                        context: context,
                        stages: stages,
                        selectedIndex: _selectedStageIndex,
                        isOwner: isOwner,
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

  Widget _buildStageDetailView({
    required BuildContext context,
    required List stages,
    required int selectedIndex,
    required bool isOwner,
  }) {
    if (stages.isEmpty || selectedIndex >= stages.length) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 48, color: Color(0xFF000000)),
              const SizedBox(height: 12),
              Text(
                'Pilih elemen pembelajaran di kolom kiri untuk melihat detail.',
                style: AppTypography.subtitle(color: const Color(0xFF000000)),
              ),
            ],
          ),
        ),
      );
    }

    final selectedStage = stages[selectedIndex] as Map;
    final String stageTitle = selectedStage['name'] ?? selectedStage['title'] ?? 'Elemen Pembelajaran';
    final String stageDesc =
        selectedStage['summary'] ?? selectedStage['description'] ?? 'Belum ada deskripsi elemen.';
    final List materis = selectedStage['materis'] as List? ?? [];
    final Color activeElemColor = _classroomAccentColors[
        selectedIndex % _classroomAccentColors.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── 1. Soft Blue Info Banner for Direct Double-Click Editing Instructions ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF0284C7),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Klik 2x pada Judul, Deskripsi Elemen, atau Materi untuk mengedit langsung. Tekan tombol hijau atau Enter untuk menyimpan.',
                  style: AppTypography.buttonLabel(color: const Color(0xFF0369A1), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── 2. Selected Stage Header (Compact Card with Rainbow Active Element Color) ───
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: activeElemColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Elemen ke-${selectedIndex + 1}',
                          style: AppTypography.buttonLabel(color: activeElemColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Dropdown Status Putih Simple Round dengan PopupMenuButton (Zero-Gap, Rapat & Presisi)
                      PopupMenuButton<String>(
                        tooltip: 'Pilih Status Elemen',
                        offset: const Offset(0, 34),
                        color: Colors.white,
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        onSelected: isOwner
                            ? (String newValue) async {
                                stages[selectedIndex]['status'] = newValue;
                                await FirebaseFirestore.instance
                                    .collection('projects')
                                    .doc(widget.projectId)
                                    .update({'stages': stages});
                                setState(() {});
                              }
                            : null,
                        itemBuilder: (BuildContext context) {
                          final List<Map<String, dynamic>> statusOptions = [
                            {
                              'text': 'Akan Datang',
                              'color': const Color(0xFF0284C7),
                            },
                            {
                              'text': 'Proses Pembelajaran',
                              'color': const Color(0xFFD97706),
                            },
                            {
                              'text': 'Selesai',
                              'color': const Color(0xFF059669),
                            },
                          ];

                          return statusOptions.map((opt) {
                            final String statusText = opt['text'] as String;
                            final Color dotColor = opt['color'] as Color;
                            return PopupMenuItem<String>(
                              value: statusText,
                              height: 32, // Sangat rapat!
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    statusText,
                                    style: AppTypography.buttonLabel(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: selectedStage['status'] == 'Akan Datang'
                                      ? const Color(0xFF0284C7)
                                      : selectedStage['status'] == 'Selesai'
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                [
                                  'Akan Datang',
                                  'Proses Pembelajaran',
                                  'Selesai',
                                ].contains(selectedStage['status'])
                                    ? selectedStage['status']
                                    : 'Proses Pembelajaran',
                                style: AppTypography.buttonLabel(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF94A3B8),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${materis.length} Materi Terlampir',
                    style: AppTypography.timestamp(color: const Color(0xFF000000), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_editingStageIndex == selectedIndex)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stageTitleController,
                        autofocus: true,
                        style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF7C3AED),
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        onSubmitted: (_) =>
                            _saveStageTitle(selectedIndex, stages),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 28,
                      ),
                      onPressed: () => _saveStageTitle(selectedIndex, stages),
                      tooltip: 'Simpan Judul Elemen',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: Color(0xFFEF4444),
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          _editingStageIndex = null;
                        });
                      },
                      tooltip: 'Batal',
                    ),
                  ],
                )
              else
                GestureDetector(
                  onDoubleTap: isOwner
                      ? () {
                          setState(() {
                            _editingStageIndex = selectedIndex;
                            _stageTitleController =
                                TextEditingController(text: stageTitle);
                          });
                        }
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          stageTitle,
                          style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              if (_editingStageDescIndex == selectedIndex)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _stageDescController,
                      autofocus: true,
                      maxLines: null,
                      style: AppTypography.timestamp(color: const Color(0xFF000000)),
                      decoration: InputDecoration(
                        hintText: 'Tulis deskripsi elemen...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF7C3AED),
                            width: 1.8,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final newDesc = _stageDescController!.text.trim();
                            stages[selectedIndex]['summary'] =
                                newDesc.isEmpty ? '' : newDesc;
                            await FirebaseFirestore.instance
                                .collection('projects')
                                .doc(widget.projectId)
                                .update({'stages': stages});
                            if (mounted) {
                              setState(() {
                                _editingStageDescIndex = null;
                                _stageDescController?.dispose();
                                _stageDescController = null;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: const Text('Simpan Deskripsi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            textStyle: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            _stageDescController?.dispose();
                            _stageDescController = null;
                            setState(() => _editingStageDescIndex = null);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            textStyle: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                GestureDetector(
                  onDoubleTap: isOwner
                      ? () {
                          setState(() {
                            _editingStageDescIndex = selectedIndex;
                            _stageDescController =
                                TextEditingController(text: stageDesc);
                          });
                        }
                      : null,
                  child: Text(
                    stageDesc,
                    style: AppTypography.timestamp(color: const Color(0xFF000000)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── 3. Materi Header & Compact View ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Detail Materi & Modul',
              style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
            ),
            if (isOwner)
              GestureDetector(
                onTap: () => _addNewMateri(selectedIndex, stages),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED), // Violet
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Materi Baru',
                        style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (materis.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'Belum ada materi dalam elemen ini.',
                style: AppTypography.subtitle(color: const Color(0xFF000000)),
              ),
            ),
          )
        else
          // Compact Unified Container for All Materis (No individual heavy cards, dense layout)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: materis.length,
              separatorBuilder: (_, __) => const Divider(
                height: 20,
                color: Color(0xFFF1F5F9),
                thickness: 1.0,
              ),
              itemBuilder: (context, mIndex) {
                final m = materis[mIndex] as Map;
                final String mTitle = m['title'] ?? 'Materi ${mIndex + 1}';
                final String mDescRaw = (m['description'] ?? m['summary'] ?? '').toString().trim();
                final String mDesc = mDescRaw.isEmpty ? 'Belum ada penjelasan materi.' : mDescRaw;
                final List pdfs = m['pdfs'] as List? ?? [];
                final List tasks = m['tasks'] as List? ?? [];

                final bool isEditingThisMateri = _editingMateriIndex == mIndex;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditingThisMateri)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: activeElemColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: activeElemColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _materiTitleController,
                                autofocus: true,
                                style: AppTypography.buttonLabel(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7C3AED),
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _saveMateriTitle(
                                    selectedIndex, mIndex, stages),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                              onPressed: () => _saveMateriTitle(
                                  selectedIndex, mIndex, stages),
                              tooltip: 'Simpan Materi',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel_rounded,
                                color: Color(0xFFEF4444),
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _editingMateriIndex = null;
                                });
                              },
                              tooltip: 'Batal',
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onDoubleTap: isOwner
                              ? () {
                                  setState(() {
                                    _editingMateriIndex = mIndex;
                                    _materiTitleController =
                                        TextEditingController(text: mTitle);
                                  });
                                }
                              : null,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: activeElemColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: activeElemColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  mTitle,
                                  style: AppTypography.buttonLabel(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (pdfs.isNotEmpty || tasks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Row(
                              children: [
                                if (pdfs.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          size: 12,
                                          color: Color(0xFF0284C7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${pdfs.length} File PDF',
                                          style: AppTypography.buttonLabel(color: const Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (pdfs.isNotEmpty && tasks.isNotEmpty)
                                  const SizedBox(width: 8),
                                if (tasks.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE11D48)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.assignment_rounded,
                                          size: 12,
                                          color: Color(0xFFE11D48),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${tasks.length} Tugas/Quiz',
                                          style: AppTypography.buttonLabel(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
              },
            ),
          ),
      ],
    );
  }
}
