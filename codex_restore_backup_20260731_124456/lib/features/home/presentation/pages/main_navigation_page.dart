import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hubner/core/widgets/google_sign_in_button.dart';
import 'home_page.dart';
import 'chat_room_page.dart';
import 'manage_friends_page.dart';
import 'package:hubner/features/todo/presentation/pages/todo_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/features/projects/presentation/pages/laporan_page.dart';
import 'package:hubner/features/projects/presentation/pages/monitoring_page.dart';
import 'package:hubner/features/splash/presentation/pages/splash_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hubner/core/services/google_drive_service.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';
import 'dart:ui' as ui;
class MainNavigationPage extends StatefulWidget {
  final bool taskReminder;
  final bool chatMention;
  final String? uid;
  MainNavigationPage({
    super.key,
    this.taskReminder = true,
    this.chatMention = true,
    this.uid,
  });
  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}
class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  String? _selectedProjectId;
  final Map<String, int> _lastUnreadCounts = {};
  // Persistent page instances to prevent flicker
  String? _lastRole;
  late List<Widget> _pages;
  bool _pagesInitialized = false;
  void _onNavigateTab(int index, {String? projectId}) {
    setState(() {
      _currentIndex = index;
      if (projectId != null) {
        _selectedProjectId = projectId;
        // Only rebuild monitoring page when projectId changes
        if (_lastRole != null && _lastRole!.toLowerCase() != 'guru') {
          _pages[3] = MonitoringPage(
            key: ValueKey(projectId),
            initialProjectId: projectId,
          );
        }
      }
    });
    _saveLastTab(index);
  }
  void _buildPages(bool isGuru) {
    _pages = [
      HomePage(onNavigateTab: _onNavigateTab),
      isGuru ? LaporanPage() : TodoPage(),
      DiscussionTab(),
      isGuru
          ? DocumentsTab()
          : MonitoringPage(
              key: ValueKey(_selectedProjectId ?? 'monitoring_default'),
              initialProjectId: _selectedProjectId,
            ),
      ProfilePage(),
    ];
  }
  @override
  void initState() {
    super.initState();
    _loadLastTab();
  }
  Future<void> _loadLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTab = prefs.getInt('lastTabIndex') ?? 0;