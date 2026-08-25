import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DesktopGudangMateriTab extends StatelessWidget {
  final String projectId;

  const DesktopGudangMateriTab({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final List stages = data['stages'] as List? ?? [];
        final List<Map<String, dynamic>> materis = [];

        for (var stage in stages) {
          final stageName = stage['name'] ?? 'Elemen';
          final rawMateris = stage['materis'] as List? ?? [];
          for (var m in rawMateris) {
            final mMap = Map<String, dynamic>.from(m as Map);
            mMap['stageName'] = stageName;
            materis.add(mMap);
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gudang Materi Pembelajaran',
                style: AppTypography.chatHeaderTitle(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: materis.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada materi pembelajaran.',
                          style: AppTypography.timestamp(color: const Color(0xFF000000)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: materis.length,
                        itemBuilder: (context, index) {
                          final m = materis[index];
                          final mTitle = m['title'] ?? 'Materi Pembelajaran';
                          final stageName = m['stageName'] ?? '';
                          final List tasks = m['tasks'] as List? ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.folder_open_rounded,
                                    color: Color(0xFF10B981),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mTitle,
                                        style: AppTypography.cardTitle(color: const Color(0xFF000000), fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '$stageName • ${tasks.length} Aktivitas',
                                        style: AppTypography.timestamp(color: const Color(0xFF000000)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
}
