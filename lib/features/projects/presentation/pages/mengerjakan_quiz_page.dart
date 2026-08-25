import 'dart:async';
import 'package:hubner/core/widgets/three_dots_loader.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MengerjakanQuizPage extends StatefulWidget {
  final String title;
  final String durationStr;
  final String startTime;
  final String projectId;
  final String studentUid;
  final String taskKey;
  final VoidCallback onCompleted;
  final bool isTeacher;
  final VoidCallback? onEdit;
  final List<dynamic>? questions;
  final Color? cpColor;

  const MengerjakanQuizPage({
    super.key,
    required this.title,
    required this.durationStr,
    required this.startTime,
    required this.projectId,
    required this.studentUid,
    required this.taskKey,
    required this.onCompleted,
    this.isTeacher = false,
    this.onEdit,
    this.questions,
    this.cpColor,
  });

  @override
  State<MengerjakanQuizPage> createState() => _MengerjakanQuizPageState();
}

class _MengerjakanQuizPageState extends State<MengerjakanQuizPage> with TickerProviderStateMixin {
  // Fixed Purple & Yellow Theme
  static const Color kThemePurple = Color(0xFF7B78E5);
  static const Color kThemeYellow = Color(0xFFFDE047);
  static const Color kTextDark = Color(0xFF0F172A);

  int _currentQuestionIdx = 0;
  List<Map<String, dynamic>> _questions = [];
  int _secondsLeft = 15 * 60;
  Timer? _timer;
  bool _isSubmitted = false;
  int _hintsLeft = 3;
  int _finalScore = 0;
  int _correctCount = 0;
  String _predikat = 'Baik';

  // State for result flow: 0 = quiz active, 1 = score burst explosion, 2 = leaderboard
  int _resultStage = 0;
  int _leaderboardCountdown = 10;
  Timer? _autoLeaderboardTimer;
  late AnimationController _explosionController;
  late Animation<double> _scaleAnimation;
  late AnimationController _patternController;

  // Selected tab in leaderboard: 'Kuis Terakhir' or 'Akumulasi Kuis Kelas'
  String _selectedLeaderboardTab = 'Kuis Terakhir';

  // 100% Real leaderboard data from Firestore
  List<Map<String, dynamic>> _lastQuizLeaderboard = [];
  List<Map<String, dynamic>> _accumulatedLeaderboard = [];
  bool _isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _explosionController,
      curve: Curves.elasticOut,
    );

    // Continuous smooth animation for floating patterns in leaderboard
    _patternController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _initQuestions();
    _initTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoLeaderboardTimer?.cancel();
    _explosionController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  void _initQuestions() {
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      _questions = widget.questions!.map((q) {
        final map = Map<String, dynamic>.from(q as Map);
        int correctIdx = 0;
        final rawCorrect = map['correct'];
        if (rawCorrect is int) {
          correctIdx = rawCorrect;
        } else if (rawCorrect is String) {
          final up = rawCorrect.toUpperCase();
          if (up == 'A') {
            correctIdx = 0;
          } else if (up == 'B') {
            correctIdx = 1;
          } else if (up == 'C') {
            correctIdx = 2;
          } else if (up == 'D') {
            correctIdx = 3;
          }
        }

        return {
          'question': (map['question'] ?? map['title'] ?? '').toString(),
          'a': (map['a'] ?? map['optionA'] ?? '').toString(),
          'b': (map['b'] ?? map['optionB'] ?? '').toString(),
          'c': (map['c'] ?? map['optionC'] ?? '').toString(),
          'd': (map['d'] ?? map['optionD'] ?? '').toString(),
          'image': (map['image'] ?? '').toString(),
          'hint': (map['hint'] ?? 'Perhatikan kata kunci soal dengan seksama.').toString(),
          'correctIndex': correctIdx,
          'selected': map['selected'] as int? ?? -1,
        };
      }).toList();
    } else {
      _questions = [
        {
          'question': 'Apa hewan darat terbesar di dunia saat ini?',
          'a': 'Gajah',
          'b': 'Badak',
          'c': 'Jerapah',
          'd': 'Harimau',
          'image': '',
          'hint': 'Hewan ini memiliki belalai panjang dan telinga yang lebar.',
          'correctIndex': 0,
          'selected': -1,
        },
        {
          'question': 'Hewan manakah yang dikenal sebagai raja hutan?',
          'a': 'Serigala',
          'b': 'Singa',
          'c': 'Beruang',
          'd': 'Macan Tutul',
          'image': '',
          'hint': 'Hewan ini hidup berkelompok dan jantan memiliki surai lebat.',
          'correctIndex': 1,
          'selected': -1,
        },
      ];
    }
  }

  void _initTimer() {
    int durationMinutes = int.tryParse(widget.durationStr) ?? 15;
    if (durationMinutes <= 0) durationMinutes = 15;
    _secondsLeft = durationMinutes * 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _submitQuiz(isAuto: true);
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _selectOption(int optionIdx) {
    if (_isSubmitted) return;
    setState(() {
      _questions[_currentQuestionIdx]['selected'] = optionIdx;
    });
  }

  int get _answeredCount {
    return _questions.where((q) => (q['selected'] as int? ?? -1) != -1).length;
  }

  void _showHintDialog() {
    if (_hintsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bantuan petunjuk telah habis!',
            style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final currentQ = _questions[_currentQuestionIdx];
    final String hintText = currentQ['hint']?.toString() ?? 'Perhatikan kata kunci pada pertanyaan.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF08A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Petunjuk Soal',
                style: AppTypography.cardTitle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          hintText,
          style: AppTypography.timestamp(color: const Color(0xFF334155), height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hintsLeft--;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTextDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Mengerti', style: AppTypography.buttonLabel(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // POPUP NOMOR SOAL: DIALOG TENGAH DENGAN TOMBOL X & NOMOR LINGKARAN
  // ═══════════════════════════════════════════════════════════════════════
  void _showQuestionSheetModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Nomor Soal',
                            style: AppTypography.chatHeaderTitle(color: kTextDark, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_answeredCount/${_questions.length} Soal Dijawab',
                            style: AppTypography.buttonLabel(color: kThemePurple, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF1F5F9),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: kTextDark,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_questions.length, (idx) {
                    final bool isCurrent = idx == _currentQuestionIdx;
                    final bool isAnswered = (_questions[idx]['selected'] as int? ?? -1) != -1;

                    Color circleColor;
                    Color textColor;

                    if (isCurrent) {
                      circleColor = kTextDark;
                      textColor = Colors.white;
                    } else if (isAnswered) {
                      circleColor = kThemeYellow;
                      textColor = kTextDark;
                    } else {
                      circleColor = const Color(0xFFF1F5F9);
                      textColor = const Color(0xFF475569);
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentQuestionIdx = idx;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: AppTypography.buttonLabel(color: textColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSubmitConfirmation() {
    final int unAnswered = _questions.length - _answeredCount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Selesaikan Kuis?',
          style: AppTypography.chatHeaderTitle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          unAnswered > 0
              ? 'Masih ada $unAnswered soal yang belum dijawab. Apakah Anda yakin ingin menyelesaikan kuis sekarang?'
              : 'Anda telah menjawab semua soal. Kirim lembar kuis sekarang?',
          style: AppTypography.timestamp(color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: AppTypography.timestamp(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitQuiz();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTextDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              'Ya, Selesai',
              style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuiz({bool isAuto = false}) async {
    _timer?.cancel();

    int correctCount = 0;
    for (var q in _questions) {
      final int sel = q['selected'] as int? ?? -1;
      final int correctIdx = q['correctIndex'] as int? ?? 0;
      if (sel != -1 && sel == correctIdx) {
        correctCount++;
      }
    }

    int score = _questions.isNotEmpty
        ? ((correctCount / _questions.length) * 100).round()
        : 100;

    String predikatName = 'Baik';
    if (score >= 90) {
      predikatName = 'Sangat Memuaskan';
    } else if (score >= 75) {
      predikatName = 'Baik';
    } else if (score >= 60) {
      predikatName = 'Cukup';
    } else {
      predikatName = 'Perlu Belajar Lagi';
    }

    setState(() {
      _isSubmitted = true;
      _finalScore = score;
      _correctCount = correctCount;
      _predikat = predikatName;
      _resultStage = 1;
      _leaderboardCountdown = 10;
    });

    _explosionController.forward(from: 0.0);

    // Auto transition to Leaderboard after 10 seconds
    _autoLeaderboardTimer?.cancel();
    _autoLeaderboardTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resultStage != 1) {
        t.cancel();
        return;
      }
      if (_leaderboardCountdown <= 1) {
        t.cancel();
        setState(() {
          _resultStage = 2;
        });
      } else {
        setState(() {
          _leaderboardCountdown--;
        });
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    final String uid = widget.studentUid.isNotEmpty ? widget.studentUid : (user?.uid ?? '');
    String sName = user?.displayName ?? 'Siswa';
    String sPhoto = user?.photoURL ?? '';

    // Fetch user details from Firestore users collection
    if (uid.isNotEmpty) {
      try {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (uDoc.exists) {
          final uData = uDoc.data() ?? {};
          sName = uData['name']?.toString() ?? sName;
          sPhoto = uData['avatar']?.toString() ?? uData['photoUrl']?.toString() ?? sPhoto;
        }
      } catch (_) {}
    }

    if (!widget.isTeacher && widget.projectId.isNotEmpty && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('studentSubmissions')
            .doc('${uid}_${widget.taskKey}')
            .set({
          'score': score,
          'correctCount': correctCount,
          'totalQuestions': _questions.length,
          'predikat': predikatName,
          'completedAt': FieldValue.serverTimestamp(),
          'studentUid': uid,
          'studentName': sName,
          'photoUrl': sPhoto,
          'avatar': sPhoto,
          'taskKey': widget.taskKey,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    _loadRealLeaderboardData(currentScore: score, currentUid: uid, currentName: sName, currentPhoto: sPhoto);

    widget.onCompleted();
  }

  Future<void> _loadRealLeaderboardData({
    required int currentScore,
    required String currentUid,
    required String currentName,
    required String currentPhoto,
  }) async {
    setState(() {
      _isLoadingLeaderboard = true;
    });

    try {
      final List<Map<String, dynamic>> lastQuizList = [];
      final Map<String, Map<String, dynamic>> accumulatedMap = {};

      String myAvatar = currentPhoto;
      String myName = currentName;
      if (currentUid.isNotEmpty) {
        try {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
          if (uDoc.exists) {
            final uData = uDoc.data() ?? {};
            myAvatar = uData['avatar']?.toString() ?? uData['photoUrl']?.toString() ?? myAvatar;
            myName = uData['name']?.toString() ?? myName;
          }
        } catch (_) {}
      }

      if (widget.projectId.isNotEmpty) {
        final querySnap = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('studentSubmissions')
            .get();

        // Query user documents to get real names and real avatar assets/URLs
        final Set<String> studentUids = {};
        for (var doc in querySnap.docs) {
          final data = doc.data();
          final String sUid = data['studentUid']?.toString() ?? doc.id.split('_').first;
          if (sUid.isNotEmpty) studentUids.add(sUid);
        }
        if (currentUid.isNotEmpty) studentUids.add(currentUid);

        final Map<String, Map<String, String>> userProfiles = {};
        for (var sUid in studentUids) {
          try {
            final uDoc = await FirebaseFirestore.instance.collection('users').doc(sUid).get();
            if (uDoc.exists) {
              final uData = uDoc.data() ?? {};
              userProfiles[sUid] = {
                'name': uData['name']?.toString() ?? 'Siswa',
                'userId': uData['userId']?.toString() ?? '',
                'avatar': uData['avatar']?.toString() ?? uData['photoUrl']?.toString() ?? '',
              };
            }
          } catch (_) {}
        }

        for (var doc in querySnap.docs) {
          final data = doc.data();
          final String sUid = data['studentUid']?.toString() ?? doc.id.split('_').first;
          final String sName = userProfiles[sUid]?['name'] ?? (data['studentName']?.toString() ?? 'Siswa');
          final String photo = userProfiles[sUid]?['avatar'] ?? (data['photoUrl']?.toString() ?? (data['avatar']?.toString() ?? ''));
          final String uIdTag = userProfiles[sUid]?['userId'] ?? (data['userId']?.toString() ?? '');
          final int scoreVal = int.tryParse(data['score']?.toString() ?? '0') ?? 0;
          final int correctVal = int.tryParse(data['correctCount']?.toString() ?? '0') ?? 0;
          final String tKey = data['taskKey']?.toString() ?? '';

          if (tKey == widget.taskKey) {
            lastQuizList.add({
              'uid': sUid,
              'name': sName,
              'userId': uIdTag,
              'photoUrl': photo,
              'points': scoreVal,
              'streaks': correctVal,
              'isMe': sUid == currentUid,
            });
          }

          if (!accumulatedMap.containsKey(sUid)) {
            accumulatedMap[sUid] = {
              'uid': sUid,
              'name': sName,
              'userId': uIdTag,
              'photoUrl': photo,
              'points': scoreVal,
              'streaks': correctVal,
              'isMe': sUid == currentUid,
            };
          } else {
            accumulatedMap[sUid]!['points'] = (accumulatedMap[sUid]!['points'] as int) + scoreVal;
            accumulatedMap[sUid]!['streaks'] = (accumulatedMap[sUid]!['streaks'] as int) + correctVal;
          }
        }
      }

      // Ensure current user is present
      final displayName = myName.isNotEmpty ? myName : 'Kamu';
      if (!lastQuizList.any((e) => e['uid'] == currentUid)) {
        lastQuizList.add({
          'uid': currentUid,
          'name': displayName,
          'userId': '',
          'photoUrl': myAvatar,
          'points': currentScore,
          'streaks': _correctCount,
          'isMe': true,
        });
      }

      if (!accumulatedMap.containsKey(currentUid)) {
        accumulatedMap[currentUid] = {
          'uid': currentUid,
          'name': displayName,
          'userId': '',
          'photoUrl': myAvatar,
          'points': currentScore,
          'streaks': _correctCount,
          'isMe': true,
        };
      }

      // 100% REAL DATA ONLY - Sort descending by points
      lastQuizList.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
      final List<Map<String, dynamic>> accumulatedList = accumulatedMap.values.toList();
      accumulatedList.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

      if (mounted) {
        setState(() {
          _lastQuizLeaderboard = lastQuizList;
          _accumulatedLeaderboard = accumulatedList;
          _isLoadingLeaderboard = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLeaderboard = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      if (_resultStage == 1) {
        return _buildScoreExplosionScreen();
      } else {
        return _buildLeaderboardScreen();
      }
    }

    final currentQ = _questions[_currentQuestionIdx];
    final String currentQuestionText = currentQ['question']?.toString() ?? '';
    final String currentImage = currentQ['image']?.toString() ?? '';
    final int selectedOptionIdx = currentQ['selected'] as int? ?? -1;

    final List<Map<String, String>> options = [
      {'label': 'A', 'text': currentQ['a']?.toString() ?? ''},
      {'label': 'B', 'text': currentQ['b']?.toString() ?? ''},
      {'label': 'C', 'text': currentQ['c']?.toString() ?? ''},
      {'label': 'D', 'text': currentQ['d']?.toString() ?? ''},
    ];

    return Scaffold(
      backgroundColor: kThemePurple,
      body: Stack(
        children: [
          // ─── 0. DISTINCT STATIC EDUCATIONAL PATTERN FOR QUESTION SCREEN ───
          Positioned.fill(
            child: CustomPaint(
              painter: QuizQuestionPatternPainter(),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 1. TOP APP BAR ───────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!_isSubmitted) {
                            _showExitConfirmation();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      GestureDetector(
                        onTap: _showQuestionSheetModal,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ─── 2. QUESTION PROGRESS BAR & COUNT ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(_currentQuestionIdx + 1).toString().padLeft(2, '0')} Pertanyaan',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_currentQuestionIdx + 1} dari ${_questions.length}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: List.generate(_questions.length, (idx) {
                      final bool isPassed = idx <= _currentQuestionIdx;
                      final bool isAnswered = (_questions[idx]['selected'] as int? ?? -1) != -1;
                      return Expanded(
                        child: Container(
                          height: 8,
                          margin: EdgeInsets.only(right: idx == _questions.length - 1 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: isPassed || isAnswered
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // ─── 3. ILLUSTRATION / IMAGE & TIMER BADGE ─────────────────
                  Row(
                    mainAxisAlignment: currentImage.isNotEmpty
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (currentImage.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            currentImage,
                            height: 90,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                          ),
                        ),

                      // Timer Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: kThemeYellow,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: kTextDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(_secondsLeft),
                              style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ─── 4. QUESTION TEXT & ADAPTIVE ANSWER CHOICES (1-COL OR 2-COL) ──
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Text (Extra Bold & Prominent)
                          Text(
                            currentQuestionText,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              height: 1.32,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Subtitle
                          Text(
                            'Pilih jawaban Anda',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Adaptive Option Layout (Auto 1-Col for long text, 2-Col for short text)
                          _buildAdaptiveOptionLayout(options, selectedOptionIdx),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // ─── 5. BOTTOM NAVIGATION BAR ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _currentQuestionIdx > 0
                            ? () => setState(() => _currentQuestionIdx--)
                            : null,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: _currentQuestionIdx > 0 ? kTextDark : Colors.black26,
                        ),
                        label: Text(
                          'Sebelumnya',
                          style: AppTypography.buttonLabel(color: _currentQuestionIdx > 0 ? kTextDark : Colors.black26, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentQuestionIdx > 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          foregroundColor: kTextDark,
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
                          disabledForegroundColor: Colors.black26,
                          elevation: _currentQuestionIdx > 0 ? 3 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),

                      GestureDetector(
                        onTap: _showHintDialog,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: Color(0xFF93C5FD),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.lightbulb_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: kTextDark,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_hintsLeft',
                                  style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          if (_currentQuestionIdx < _questions.length - 1) {
                            setState(() => _currentQuestionIdx++);
                          } else {
                            _showSubmitConfirmation();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kTextDark,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentQuestionIdx < _questions.length - 1 ? 'Selanjutnya' : 'Selesai',
                              style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _currentQuestionIdx < _questions.length - 1
                                  ? Icons.chevron_right_rounded
                                  : Icons.check_circle_rounded,
                              size: 18,
                              color: kTextDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADAPTIVE OPTION LAYOUT: 1-COLUMN FOR LONG TEXT, 2-COLUMN (2x2) FOR SHORT TEXT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildAdaptiveOptionLayout(List<Map<String, String>> options, int selectedOptionIdx) {
    final bool isLongText = options.any((opt) => (opt['text']?.trim().length ?? 0) > 16);

    if (isLongText) {
      return Column(
        children: List.generate(options.length, (optIdx) {
          final opt = options[optIdx];
          final bool isSelected = selectedOptionIdx == optIdx;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _selectOption(optIdx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  color: isSelected ? kThemeYellow : Colors.white,
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Row(
                  children: [
                    Text(
                      '${opt['label']}. ',
                      style: AppTypography.cardTitle(color: kTextDark, fontWeight: FontWeight.w900),
                    ),
                    Expanded(
                      child: Text(
                        opt['text']!,
                        style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      );
    } else {
      return LayoutBuilder(
        builder: (ctx, constraints) {
          final double itemWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(options.length, (optIdx) {
              final opt = options[optIdx];
              final bool isSelected = selectedOptionIdx == optIdx;

              return GestureDetector(
                onTap: () => _selectOption(optIdx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: itemWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? kThemeYellow : Colors.white,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${opt['label']}. ',
                        style: AppTypography.cardTitle(color: kTextDark, fontWeight: FontWeight.w900),
                      ),
                      Expanded(
                        child: Text(
                          opt['text']!,
                          style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      );
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Keluar dari Kuis?',
          style: AppTypography.chatHeaderTitle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Progres kuis saat ini tidak akan tersimpan jika Anda keluar sebelum menyelesaikan.',
          style: AppTypography.timestamp(color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Lanjutkan Kuis',
              style: AppTypography.timestamp(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Keluar',
              style: AppTypography.buttonLabel(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STAGE 1: LETUSAN NILAI (DISTINCT SCORE CELEBRATION STARBURST PATTERN)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildScoreExplosionScreen() {
    return Scaffold(
      backgroundColor: kThemePurple,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Distinct Celebration Starburst Ray Pattern
          Positioned.fill(
            child: CustomPaint(
              painter: ScoreCelebrationPatternPainter(progress: _explosionController.value),
            ),
          ),

          // Confetti particles
          Positioned.fill(
            child: CustomPaint(
              painter: ConfettiExplosionPainter(progress: _explosionController.value),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kThemeYellow,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFB45309), size: 32),
                              Text(
                                '$_finalScore',
                                style: AppTypography.pageTitle(color: kTextDark, fontWeight: FontWeight.w900, height: 1.0),
                              ),
                              Text(
                                'POIN',
                                style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.w900, letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      _finalScore >= 90
                          ? 'LUAR BIASA! 🌟'
                          : _finalScore >= 75
                              ? 'HEBAT SEKALI! 👏'
                              : 'KUIS SELESAI! 👍',
                      style: AppTypography.pageTitle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Predikat: $_predikat',
                        style: AppTypography.buttonLabel(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kamu berhasil menjawab $_correctCount dari ${_questions.length} soal dengan benar.',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                    ),

                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          _autoLeaderboardTimer?.cancel();
                          setState(() {
                            _resultStage = 2;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kTextDark,
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              'Lihat Papan Peringkat (${_leaderboardCountdown}s)',
                              style: AppTypography.cardTitle(color: kTextDark, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, color: kTextDark, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Kembali ke Kelas',
                        style: AppTypography.buttonLabel(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STAGE 2: PAPAN PERINGKAT (ANIMATED SOFT PASTEL PATTERN FROM DETAIL KELAS MOBILE)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLeaderboardScreen() {
    final activeList = _selectedLeaderboardTab == 'Kuis Terakhir'
        ? _lastQuizLeaderboard
        : _accumulatedLeaderboard;

    final top1 = activeList.isNotEmpty ? activeList[0] : null;
    final top2 = activeList.length > 1 ? activeList[1] : null;
    final top3 = activeList.length > 2 ? activeList[2] : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ─── ANIMATED FLOATING SOFT PASTEL PATTERN (FROM MOBILE CLASS SLIDER COLORS) ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _patternController,
              builder: (ctx, child) {
                return CustomPaint(
                  painter: AnimatedLeaderboardPatternPainter(
                    progress: _patternController.value,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ─── TOP BAR: Title & Close Button ────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(AppTypography.screenHorizontalMargin, 16, AppTypography.screenHorizontalMargin, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 38),
                      Text(
                        'Papan Peringkat',
                        style: AppTypography.chatHeaderTitle(color: kTextDark, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF1F5F9),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: kTextDark,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── TABS FILTER: [Kuis Terakhir] [Akumulasi Kuis Kelas] ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTypography.screenHorizontalMargin, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        _buildLeaderboardTabItem('Kuis Terakhir'),
                        _buildLeaderboardTabItem('Akumulasi Kuis Kelas'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ─── SCROLLABLE CONTENT (PODIUM + RANKINGS LIST) ──────────
                Expanded(
                  child: _isLoadingLeaderboard
                      ? const Center(child: ThreeDotsLoader())
                      : activeList.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada data pengerjaan kuis.',
                                style: AppTypography.timestamp(color: const Color(0xFF64748B)),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(AppTypography.screenHorizontalMargin, 8, AppTypography.screenHorizontalMargin, 24),
                              child: Column(
                                children: [
                                  // Top 3 Podium (Proportional height based on score, 0 = 18px base)
                                  _buildPodiumSection(top1: top1, top2: top2, top3: top3),

                                  const SizedBox(height: 20),

                                  // ALL REAL STUDENTS IN LIST (Rank 1, 2, 3, 4...)
                                  ...List.generate(activeList.length, (idx) {
                                    final item = activeList[idx];
                                    final int rankNum = idx + 1;

                                    // Badge colors: 1 Emas, 2 Abu, 3 Coklat, 4+ Putih
                                    Color badgeBgColor;
                                    Color badgeTextColor;
                                    Color badgeBorderColor;

                                    if (rankNum == 1) {
                                      badgeBgColor = const Color(0xFFF59E0B); // Emas (Gold)
                                      badgeTextColor = Colors.white;
                                      badgeBorderColor = Colors.white;
                                    } else if (rankNum == 2) {
                                      badgeBgColor = const Color(0xFF94A3B8); // Abu (Silver)
                                      badgeTextColor = Colors.white;
                                      badgeBorderColor = Colors.white;
                                    } else if (rankNum == 3) {
                                      badgeBgColor = const Color(0xFFB45309); // Coklat (Bronze)
                                      badgeTextColor = Colors.white;
                                      badgeBorderColor = Colors.white;
                                    } else {
                                      badgeBgColor = Colors.white; // Putih
                                      badgeTextColor = const Color(0xFF475569);
                                      badgeBorderColor = const Color(0xFFCBD5E1);
                                    }

                                    final String subText = (item['userId'] != null && item['userId'].toString().isNotEmpty)
                                        ? 'ID: ${item['userId']}'
                                        : '${item['streaks'] ?? 0} Soal Benar';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4), // Margin avatar & card sangat tipis!
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(40), // Round Stadium / Capsule CSS
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0), // Frameless soft border tipis
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar + Badge (Margin tipis menempel rapi ke sisi kiri card)
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              _buildMemberAvatar(
                                                name: item['name'] ?? 'Siswa',
                                                photoUrl: item['photoUrl'],
                                                radius: 25,
                                                accentColor: kThemePurple,
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: badgeBgColor,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: badgeBorderColor, width: 1.2),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$rankNum',
                                                      style: AppTypography.buttonLabel(color: badgeTextColor, fontWeight: FontWeight.w900),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(width: 12),

                                          // Student Name & ID / Streaks Subtitle
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ?? 'Siswa',
                                                  style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  subText,
                                                  style: AppTypography.timestamp(color: const Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Points Badge Pill with Golden Star
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFFEF3C7)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.stars_rounded,
                                                  color: Color(0xFFF59E0B),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item['points']} Poin',
                                                  style: AppTypography.buttonLabel(color: const Color(0xFFB45309), fontWeight: FontWeight.w900),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTabItem(String tabName) {
    final bool isSelected = _selectedLeaderboardTab == tabName;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLeaderboardTab = tabName),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? kThemePurple : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              tabName,
              style: AppTypography.buttonLabel(color: isSelected ? Colors.white : const Color(0xFF475569), fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PODIUM SECTION: REAL PROPORTIONAL HEIGHT (0 = 18px Base, 100 = 145px Full)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildPodiumSection({
    required Map<String, dynamic>? top1,
    required Map<String, dynamic>? top2,
    required Map<String, dynamic>? top3,
  }) {
    final int p1 = top1 != null ? (top1['points'] as int? ?? 0) : 0;
    final int p2 = top2 != null ? (top2['points'] as int? ?? 0) : 0;
    final int p3 = top3 != null ? (top3['points'] as int? ?? 0) : 0;

    double calcHeight(int pts, bool has) {
      if (!has || pts <= 0) return 18.0;
      return (18.0 + (pts / 100.0) * (145.0 - 18.0)).clamp(18.0, 145.0);
    }

    final double h1 = calcHeight(p1, top1 != null);
    final double h2 = calcHeight(p2, top2 != null);
    final double h3 = calcHeight(p3, top3 != null);

    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2nd Place (Left - Blue Block #2)
          Expanded(
            child: _buildPodiumColumn(
              student: top2,
              rank: 2,
              blockHeight: h2,
              blockColor: const Color(0xFF93C5FD),
              stripeColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
              accentColor: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 8),

          // 1st Place (Center - Highest Yellow Block #1)
          Expanded(
            child: _buildPodiumColumn(
              student: top1,
              rank: 1,
              blockHeight: h1,
              blockColor: const Color(0xFFFDE047),
              stripeColor: const Color(0xFFD97706).withValues(alpha: 0.35),
              accentColor: kThemePurple,
            ),
          ),
          const SizedBox(width: 8),

          // 3rd Place (Right - Purple Block #3)
          Expanded(
            child: _buildPodiumColumn(
              student: top3,
              rank: 3,
              blockHeight: h3,
              blockColor: const Color(0xFFC4B5FD),
              stripeColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              accentColor: const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required Map<String, dynamic>? student,
    required int rank,
    required double blockHeight,
    required Color blockColor,
    required Color stripeColor,
    required Color accentColor,
  }) {
    final bool hasStudent = student != null;
    final int points = hasStudent ? (student['points'] as int? ?? 0) : 0;
    final String sName = hasStudent ? (student['name'] ?? 'Siswa') : '';
    final String sPhoto = hasStudent ? (student['photoUrl']?.toString() ?? '') : '';
    final bool hasScore = hasStudent && points > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasScore)
          _buildMemberAvatar(
            name: sName,
            photoUrl: sPhoto,
            radius: 24,
            accentColor: accentColor,
          )
        else
          const SizedBox(height: 48), // Kosong tanpa avatar jika 0 poin / belum ada
        const SizedBox(height: 5),

        // Name
        Text(
          hasScore ? sName : '',
          style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Points
        Text(
          hasScore ? '$points Poin' : '0 Poin',
          style: AppTypography.buttonLabel(color: hasScore ? const Color(0xFFD97706) : Colors.black54, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),

        // Striped Podium Block with Circular Number Badge
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: blockHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(double.infinity, blockHeight),
                  painter: DiagonalStripesPainter(stripeColor: stripeColor),
                ),
                if (blockHeight >= 36)
                  Positioned(
                    top: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  )
                else
                  // Flat base circle badge
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: AppTypography.buttonLabel(color: kTextDark, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AVATAR COMPONENT: SUPPORTS REAL USER AVATARS (ASSET ICON PACK & URLs)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildMemberAvatar({
    required String name,
    String? photoUrl,
    required double radius,
    required Color accentColor,
  }) {
    final String avatarStr = (photoUrl != null && photoUrl.trim().isNotEmpty)
        ? photoUrl.trim()
        : '';

    if (avatarStr.isNotEmpty) {
      if (avatarStr.startsWith('http://') || avatarStr.startsWith('https://')) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12, width: 1.2),
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.35,
              child: Image.network(
                avatarStr,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => _buildFallbackAvatar(name, radius, accentColor),
              ),
            ),
          ),
        );
      } else {
        // Asset image path (e.g. assets/icon_pack/avatar/guru_1.png or avatar_1.png)
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12, width: 1.2),
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.35,
              child: Image.asset(
                avatarStr,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => _buildFallbackAvatar(name, radius, accentColor),
              ),
            ),
          ),
        );
      }
    }

    return _buildFallbackAvatar(name, radius, accentColor);
  }

  Widget _buildFallbackAvatar(String name, double radius, Color accentColor) {
    final int avatarNum = (name.hashCode.abs() % 10) + 1;
    final String assetPath = 'assets/icon_pack/avatar/guru_$avatarNum.png';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 1.2),
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: 1.35,
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) {
              final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
              return Container(
                color: accentColor.withValues(alpha: 0.15),
                child: Center(
                  child: Text(
                    initial,
                    style: AppTypography.buttonLabel(color: accentColor, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. DISTINCT PATTERN: QUIZ QUESTION PAGE (SUBTLE EDUCATIONAL & MATH DOODLES)
// ═══════════════════════════════════════════════════════════════════════════
class QuizQuestionPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    final random = Random(12345);
    const int count = 38;

    for (int i = 0; i < count; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final int type = i % 5;

      if (type == 0) {
        // Soft ring
        canvas.drawCircle(Offset(x, y), 8 + random.nextDouble() * 12, paint);
      } else if (type == 1) {
        // Cross (+)
        const double s = 7;
        canvas.drawLine(Offset(x - s, y), Offset(x + s, y), paint);
        canvas.drawLine(Offset(x, y - s), Offset(x, y + s), paint);
      } else if (type == 2) {
        // Triangle (△)
        final path = Path()
          ..moveTo(x, y - 9)
          ..lineTo(x + 8, y + 7)
          ..lineTo(x - 8, y + 7)
          ..close();
        canvas.drawPath(path, paint);
      } else if (type == 3) {
        // Rounded diamond / dot
        canvas.drawCircle(Offset(x, y), 3.5, fillPaint);
      } else {
        // Soft wavy squiggly
        final path = Path()
          ..moveTo(x - 8, y)
          ..quadraticBezierTo(x - 4, y - 6, x, y)
          ..quadraticBezierTo(x + 4, y + 6, x + 8, y);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. DISTINCT PATTERN: SCORE EXPLOSION SCREEN (RADIANT CELEBRATION STARBURST)
// ═══════════════════════════════════════════════════════════════════════════
class ScoreCelebrationPatternPainter extends CustomPainter {
  final double progress;

  ScoreCelebrationPatternPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);

    // Glowing radiating starburst rays
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.12 * progress).clamp(0.0, 0.12))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const int rayCount = 16;
    final double maxRayLength = size.width * 0.65;

    for (int i = 0; i < rayCount; i++) {
      final double angle = (i / rayCount) * 2 * pi + (progress * 0.4);
      final double startDist = 90;
      final double endDist = startDist + (maxRayLength - startDist) * progress;

      final startX = center.dx + cos(angle) * startDist;
      final startY = center.dy + sin(angle) * startDist;
      final endX = center.dx + cos(angle) * endDist;
      final endY = center.dy + sin(angle) * endDist;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), rayPaint);
    }

    // Expanding celebration ripples
    final ripplePaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: (0.25 * (1.0 - progress)).clamp(0.0, 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, 90 + progress * 80, ripplePaint);
    canvas.drawCircle(center, 90 + progress * 140, ripplePaint);
  }

  @override
  bool shouldRepaint(covariant ScoreCelebrationPatternPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. DISTINCT PATTERN: ANIMATED FLOATING SOFT PASTEL PATTERN FOR LEADERBOARD
// Uses exact colors from Mobile Class Detail Slider:
// [Indigo 0xFF6366F1, Blue 0xFF3B82F6, Emerald 0xFF10B981, Amber 0xFFF59E0B, Pink 0xFFEC4899, Cyan 0xFF06B6D4, Violet 0xFF8B5CF6]
// ═══════════════════════════════════════════════════════════════════════════
class AnimatedLeaderboardPatternPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 continuously looping

  AnimatedLeaderboardPatternPainter({required this.progress});

  // 7 Distinct Colors from Mobile Detail Kelas Slider Menu
  static const List<Color> kSliderPalette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(777);
    const int numShapes = 24;

    for (int i = 0; i < numShapes; i++) {
      final Color baseColor = kSliderPalette[i % kSliderPalette.length];

      // Base anchor position across the screen
      final double baseX = (random.nextDouble() * 0.9 + 0.05) * size.width;
      final double baseY = (random.nextDouble() * 0.9 + 0.05) * size.height;

      // Smooth floating sinusoidal wave displacement
      final double phase = (i * 0.45) + (progress * 2 * pi);
      final double driftX = sin(phase) * 18.0;
      final double driftY = cos(phase * 0.8) * 22.0;

      final double x = (baseX + driftX).clamp(0.0, size.width);
      final double y = (baseY + driftY).clamp(0.0, size.height);

      // Very soft pastel opacity (0.06 to 0.12) to stay clean & premium on white background
      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.09)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = baseColor.withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final int shapeType = i % 4;

      if (shapeType == 0) {
        // Floating Soft Circle Orb
        final double radius = 10.0 + (i % 3) * 6.0;
        canvas.drawCircle(Offset(x, y), radius, fillPaint);
      } else if (shapeType == 1) {
        // Floating Soft Rounded Cross / Plus
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * 2 * pi + i);
        const double arm = 9.0;
        canvas.drawLine(const Offset(-arm, 0), const Offset(arm, 0), strokePaint);
        canvas.drawLine(const Offset(0, -arm), const Offset(0, arm), strokePaint);
        canvas.restore();
      } else if (shapeType == 2) {
        // Floating Soft Rounded Ring
        final double ringRadius = 8.0 + (i % 4) * 4.0;
        canvas.drawCircle(Offset(x, y), ringRadius, strokePaint);
      } else {
        // Floating Soft Sparkle / Diamond
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-(progress * 2 * pi * 0.7 + i));
        final path = Path()
          ..moveTo(0, -9)
          ..quadraticBezierTo(1.5, -1.5, 9, 0)
          ..quadraticBezierTo(1.5, 1.5, 0, 9)
          ..quadraticBezierTo(-1.5, 1.5, -9, 0)
          ..quadraticBezierTo(-1.5, -1.5, 0, -9)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedLeaderboardPatternPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER: DIAGONAL STRIPES FOR PODIUM BLOCKS
// ═══════════════════════════════════════════════════════════════════════════
class DiagonalStripesPainter extends CustomPainter {
  final Color stripeColor;
  final double stripeWidth;
  final double gap;

  DiagonalStripesPainter({
    required this.stripeColor,
    this.stripeWidth = 2.5,
    this.gap = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final double total = size.width + size.height;
    for (double i = -size.height; i < total; i += gap) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER: CONFETTI & PARTICLES EXPLOSION BURST
// ═══════════════════════════════════════════════════════════════════════════
class ConfettiExplosionPainter extends CustomPainter {
  final double progress;

  ConfettiExplosionPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.38);
    final random = Random(42);
    const particleCount = 45;

    final colors = [
      const Color(0xFFFDE047),
      const Color(0xFFF472B6),
      const Color(0xFF60A5FA),
      const Color(0xFF34D399),
      const Color(0xFFA78BFA),
      Colors.white,
    ];

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi + (random.nextDouble() * 0.4);
      final speed = 80 + random.nextDouble() * 160;
      final distance = speed * progress;

      final x = center.dx + cos(angle) * distance;
      final y = center.dy + sin(angle) * distance;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: (1.0 - progress * 0.3).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      if (i % 3 == 0) {
        canvas.drawCircle(Offset(x, y), (4 + random.nextDouble() * 4) * (1.0 - progress * 0.2), paint);
      } else if (i % 3 == 1) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * pi * 2 + i);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 8, height: 5), paint);
        canvas.restore();
      } else {
        final path = Path()
          ..moveTo(x, y - 5)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 5)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiExplosionPainter oldDelegate) => true;
}
