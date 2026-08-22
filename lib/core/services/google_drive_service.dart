import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleDriveService {
  static const String _prefKeyConnected = 'is_google_drive_connected';
  static const String _prefKeyEmail = 'google_drive_account_email';

  /// Dapatkan DriveApi terotentikasi dari token akses
  static drive.DriveApi getDriveApi(String accessToken) {
    final authClient = _GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    return drive.DriveApi(authClient);
  }

  /// Cek apakah akun Google Drive sudah terhubung
  static Future<bool> isConnected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isSaved = prefs.getBool(_prefKeyConnected) ?? false;
      if (isSaved) return true;

      // Cek apakah ada session aktif
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) {
        await prefs.setBool(_prefKeyConnected, true);
        await prefs.setString(_prefKeyEmail, account.email);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mendapatkan info email akun Google Drive yang terhubung
  static Future<String?> getConnectedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyEmail);
    } catch (_) {
      return null;
    }
  }

  /// Hubungkan akun Google Drive secara interaktif (hanya 1x diminta)
  static Future<bool> connectGoogleDrive() async {
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyConnected, true);
      await prefs.setString(_prefKeyEmail, account.email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Putuskan koneksi akun Google Drive
  static Future<void> disconnectGoogleDrive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyConnected);
      await prefs.remove(_prefKeyEmail);
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  /// Buat folder classroom di Google Drive
  static Future<String> createClassroomFolder(String accessToken, String folderName) async {
    try {
      final api = getDriveApi(accessToken);
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      return created.id ?? '';
    } catch (e) {
      throw Exception('Gagal membuat folder Google Drive: $e');
    }
  }

  /// Sinkronisasi folder classroom
  static Future<void> syncClassroomFolder({
    required String projectId,
    required String className,
    required dynamic googleAccount,
  }) async {
    try {
      final auth = await googleAccount.authorizationClient.authorizeScopes([drive.DriveApi.driveFileScope]);
      final accessToken = auth.accessToken;
      final docSnap = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
      if (!docSnap.exists) return;
      final data = docSnap.data() as Map<String, dynamic>;
      String? folderId = data['driveFolderId'];
      if (folderId == null || folderId.isEmpty) {
        folderId = await createClassroomFolder(accessToken, 'Hubner - $className');
      }
      await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
        'driveFolderId': folderId,
        'driveFolderUrl': 'https://drive.google.com/drive/folders/$folderId',
        'driveAccessToken': accessToken,
        'driveTokenExpiry': DateTime.now().add(const Duration(minutes: 55)).toIso8601String(),
      });
    } catch (_) {}
  }

  /// Mencari atau membuat folder "Hubner_Backups" di Google Drive
  static Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    try {
      final searchResult = await driveApi.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = 'Hubner_Backups' and trashed = false",
        spaces: 'drive',
      );

      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        return searchResult.files!.first.id;
      }

      final folderMetadata = drive.File()
        ..name = 'Hubner_Backups'
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folderMetadata);
      return createdFolder.id;
    } catch (_) {
      return null;
    }
  }

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

  /// Mencadangkan data Classroom ke Google Drive
  static Future<String?> backupClassroomToDrive(Map<String, dynamic> projectData) async {
    try {
      var account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      account ??= await GoogleSignIn.instance.authenticate();

      final auth = await account.authorizationClient.authorizeScopes([drive.DriveApi.driveFileScope]);
      final driveApi = getDriveApi(auth.accessToken);

      final folderId = await _getOrCreateBackupFolder(driveApi);

      final String rawName = (projectData['name'] ?? 'Classroom').toString();
      final String safeName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final String fileName = '${safeName}_backup_$timestamp.json';

      final sanitizedData = _sanitizeForJson(projectData) as Map<String, dynamic>;
      final jsonString = const JsonEncoder.withIndent('  ').convert(sanitizedData);
      final bytes = utf8.encode(jsonString);

      final fileMetadata = drive.File()
        ..name = fileName
        ..mimeType = 'application/json'
        ..description = 'Hubner Edu Classroom Backup - ${DateTime.now()}';

      if (folderId != null) {
        fileMetadata.parents = [folderId];
      }

      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );

      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyConnected, true);
      await prefs.setString(_prefKeyEmail, account.email);

      return uploadedFile.name ?? fileName;
    } catch (_) {
      return null;
    }
  }

  /// Mengunggah berkas umum ke Google Drive (digunakan untuk pengumpulan tugas, dsb.)
  static Future<Map<String, String>> uploadFile({
    required String accessToken,
    required String folderId,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final driveApi = getDriveApi(accessToken);

      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = folderId.isNotEmpty ? [folderId] : null;

      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'id, webViewLink, webContentLink',
      );

      final fileId = uploadedFile.id ?? '';
      final link = uploadedFile.webViewLink ?? 'https://drive.google.com/file/d/$fileId/view';

      return {
        'fileId': fileId,
        'directLink': link,
      };
    } catch (e) {
      throw Exception('Gagal mengunggah berkas ke Google Drive: $e');
    }
  }
}
