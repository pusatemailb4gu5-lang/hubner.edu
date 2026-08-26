import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hubner/core/widgets/bouncy_button.dart';
import 'student_home_page.dart';
import 'teacher_home_page.dart';

export 'student_home_page.dart';
export 'teacher_home_page.dart';
export 'package:hubner/core/widgets/bouncy_button.dart';

class HomePage extends StatefulWidget {
  final Function(int index, {String? projectId})? onNavigateTab;
  const HomePage({super.key, this.onNavigateTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return StudentHomePage(onNavigateTab: widget.onNavigateTab);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final Map<String, dynamic>? userData = snapshot.data?.data() as Map<String, dynamic>?;
        final String role = (userData?['role'] ?? 'Siswa').toString();
        final bool isTeacher = role.toLowerCase() == 'guru';

        if (isTeacher) {
          return TeacherHomePage(onNavigateTab: widget.onNavigateTab);
        } else {
          return StudentHomePage(onNavigateTab: widget.onNavigateTab);
        }
      },
    );
  }
}
