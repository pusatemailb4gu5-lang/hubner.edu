import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassroomExportService {
  /// Mengubah objek Firestore (seperti Timestamp) menjadi tipe data yang kompatibel dengan JSON
  static dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    } else if (value is List) {
      return value.map((v) => _sanitizeForJson(v)).toList();
    }
    return value;
  }

  /// Ekspor data classroom ke format JSON yang dapat disimpan pengguna
  static Future<bool> exportClassroom({
    required BuildContext context,
    required Map<String, dynamic> projectData,
  }) async {
    try {
      final String rawName = (projectData['name'] ?? 'Classroom').toString();
      final String safeName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final String fileName = '${safeName}_export.json';

      // Bersihkan dan amankan data untuk serialisasi JSON (Timestamp -> ISO string)
      final sanitizedData = _sanitizeForJson(projectData) as Map<String, dynamic>;
      final jsonString = const JsonEncoder.withIndent('  ').convert(sanitizedData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: 'Pilih Lokasi Simpan Backup Classroom',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (selectedPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom "$rawName" berhasil diekspor!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Impor data classroom dari file JSON ke Firestore
  static Future<String?> importClassroom({
    required BuildContext context,
    required String currentTeacherUid,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        throw Exception('File kosong atau tidak dapat dibaca');
      }

      final jsonString = utf8.decode(fileBytes);
      final dynamic rawData = jsonDecode(jsonString);

      if (rawData is! Map<String, dynamic>) {
        throw Exception('Format file JSON tidak valid');
      }

      final Map<String, dynamic> projectData = Map<String, dynamic>.from(rawData);

      // Buat ID baru agar tidak menimpa data yang sudah ada
      final newDocRef = FirebaseFirestore.instance.collection('projects').doc();
      final String newProjectId = newDocRef.id;

      projectData['projectId'] = newProjectId;
      projectData['ownerUid'] = currentTeacherUid;
      projectData['createdAt'] = FieldValue.serverTimestamp();
      projectData['importedAt'] = FieldValue.serverTimestamp();

      // Reset progress siswa jika ada
      projectData['members'] = [currentTeacherUid];

      await newDocRef.set(projectData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom "${projectData['name'] ?? 'Baru'}" berhasil diimpor!'),
            backgroundColor: const Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return newProjectId;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengimpor file: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }
}
