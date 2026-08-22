import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hubner/features/projects/presentation/pages/class_page.dart'
    show ClassroomCardPatternPainter;
import 'package:hubner/features/auth/presentation/pages/login_page.dart';
import 'package:hubner/features/home/presentation/widgets/animated_rainbow_background.dart';
import 'package:hubner/main.dart' show HubnerApp;

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // Active Showcase Tab (0: Card Kelas, 1: Monitoring Kelas, 2: Mengerjakan Quiz)
  int _activeTab = 0;
  Timer? _tabAutoSwitchTimer; // Set to 10 Seconds as requested!

  // Card Kelas Animation (Materi checkmark transition: unchecked -> checked)
  bool _materi3Checked = false;
  Timer? _materiCheckTimer;

  // Interactive Quiz State (Autoplay simulation & live score 70 -> 80 -> 100)
  int _selectedQuizOption = -1;
  bool _quizSubmitted = false;
  int _liveScore = 70;
  int _quizStep = 0;
  Timer? _quizAutoPlayTimer;

  // Chat Room Real-Time Animation Loop (Simulating new messages popping up)
  int _chatCount = 3;
  Timer? _chatAnimationTimer;

  // AI Demo State (Interactive Prompt & Stage Generation Animation Loop)
  bool _isGeneratingAI = false;
  int _aiStageCount = 3;
  Timer? _aiAnimationTimer;
  final TextEditingController _aiPromptController = TextEditingController(text: 'Fisika Modern Kelas 11 SMA');

  // App Palette from class_page.dart & home_page.dart
  final List<Color> _classroomCardColors = const [
    Color(0xFFFFF0F5),
    Color(0xFFECFEFF),
    Color(0xFFEFF6FF),
    Color(0xFFF5F3FF),
    Color(0xFFFFFBEB),
  ];

  final List<Color> _classroomAccentColors = const [
    Color(0xFFF43F5E),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
  ];

  // Translation Maps (100% Complete, Pure Icons, NO Emojis)
  final Map<String, Map<String, String>> _translations = {
    'Bahasa Indonesia': {
      'star_badge': 'Platform Edukasi Terintegrasi Modern',
      'hero_title': 'Sistem Pembelajaran Cerdas\nuntuk Masa Depan Kelas Anda',
      'hero_desc': 'Hubner Edu menggabungkan manajemen classroom interaktif, generator tahapan belajar AI, monitoring presensi instan, ujian kuis, dan chat diskusi dinamis.',
      'hero_cta': 'Coba Sekarang',
      'ai_section_title': 'Kecerdasan Buatan Terintegrasi',
      'ai_section_subtitle': 'Buat Kurikulum & Tahapan Belajar Instan dengan AI',
      'ai_section_desc': 'Cukup ketik topik atau mata pelajaran, AI Hubner Edu akan merancang struktur elemen, materi (3-5 topik per elemen), dan kuis otomatis.',
      'ai_prompt_hint': 'Ketik topik mata pelajaran...',
      'ai_btn_generate': 'Generate AI',
      'ai_result_title': 'Hasil Generasi Otomatis Kurikulum AI',
      'showcase_title_0': 'Struktur Kelas & Tahapan Pembelajaran',
      'showcase_desc_0': 'Tampilan identitas kelas dan rincian elemen materi interaktif dari aplikasi.',
      'showcase_title_1': 'Pusat Monitoring & Analitis Keaktifan',
      'showcase_desc_1': 'Pantau aktivitas diskusi kelas real-time dan rekap capaian siswa.',
      'showcase_title_2': 'Simulasi Kuis Interaktif & Live Score Card',
      'showcase_desc_2': 'Ujian kuis interaktif dengan penilai otomatis dan update skor langsung.',
      'feature_grid_title': 'Lebih Dari Sekadar LMS Biasa',
      'feature_grid_desc': 'Dirancang khusus untuk menghadirkan pengalaman mengajar yang manusiawi, menyenangkan, dan efisien.',
      'feature_card_0_tag': 'Respon Instan',
      'feature_card_0_title': 'Swipe-to-Reply Diskusi Kelas',
      'feature_card_0_desc': 'Balas pertanyaan siswa secepat kilat dengan fitur geser pesan interaktif di ruang diskusi.',
      'feature_card_1_tag': 'Sinkronisasi Real-Time',
      'feature_card_1_title': 'Kalender & Jadwal Interaktif',
      'feature_card_1_desc': 'Kelola agenda mengajar mingguan dan tenggat waktu tugas penting dalam satu tampilan terpadu.',
      'feature_card_2_tag': 'Analisis Cerdas',
      'feature_card_2_title': 'Laporan Capaian Siswa',
      'feature_card_2_desc': 'Pantau grafik kehadiran, rekap nilai kuis, dan keaktifan kelas secara transparan dan terukur.',
      'cta_title': 'Siap Meningkatkan Kualitas Belajar?',
      'cta_desc': 'Bergabunglah bersama ribuan guru dan siswa dalam sistem belajar Hubner Edu.',
      'cta_btn': 'Masuk Hubner Edu',
      'navbar_masuk': 'Masuk',
      'quiz_soal_header': 'Soal 1 dari 10 • Fisika Modern',
      'quiz_sisa_waktu': 'Sisa Waktu: 08:45',
      'quiz_soal_text': 'Berikut ini yang merupakan contoh perangkat keras input utama adalah...',
      'quiz_btn_kirim': 'Kirim Jawaban',
      'quiz_btn_sent': 'Jawaban Terkirim!',
      'quiz_feedback_great': 'Sangat Baik',
      'quiz_score_subtitle': 'Hasil evaluasi kuis kinerjamu melampaui rata-rata kelas.',
      'monitoring_kelas_title': 'Fisika Modern • Progress Pembelajaran',
      'monitoring_kelas_selesai': '84% Selesai',
      'monitoring_kelas_aktivitas': 'Aktivitas Diskusi Real-Time',
      'elemen_status_1': 'Selesai',
      'elemen_status_2': 'Proses Pembelajaran',
      'elemen_status_3': 'Akan Datang',
      'btn_kerjakan_quiz': 'Kerjakan Kuis Elemen 2',
    },
    'English': {
      'star_badge': 'Modern Integrated Educational Platform',
      'hero_title': 'Smart Learning System\nfor Your Classroom\'s Future',
      'hero_desc': 'Hubner Edu combines interactive classroom management, AI learning stage generator, instant attendance tracking, quiz testing, and dynamic discussion chat.',
      'hero_cta': 'Try Now',
      'ai_section_title': 'Integrated Artificial Intelligence',
      'ai_section_subtitle': 'Create Instant Curriculum & Learning Stages with AI',
      'ai_section_desc': 'Simply type a topic or subject, and Hubner Edu AI will generate element structures, topics (3-5 materials per stage), and quizzes.',
      'ai_prompt_hint': 'Type a subject topic...',
      'ai_btn_generate': 'Generate AI',
      'ai_result_title': 'Automated AI Curriculum Generation Result',
      'showcase_title_0': 'Classroom Structure & Study Stages',
      'showcase_desc_0': 'Class identity display along with interactive material elements from the app.',
      'showcase_title_1': 'Monitoring & Activity Analytics Center',
      'showcase_desc_1': 'Track real-time class discussion activity and student achievement summaries.',
      'showcase_title_2': 'Interactive Quiz & Live Score Card',
      'showcase_desc_2': 'Interactive quiz exam experience with automatic grading and live score updates.',
      'feature_grid_title': 'More Than Just an LMS',
      'feature_grid_desc': 'Specially designed to deliver a humanized, engaging, and efficient teaching experience.',
      'feature_card_0_tag': 'Instant Response',
      'feature_card_0_title': 'Swipe-to-Reply Class Chat',
      'feature_card_0_desc': 'Reply to student questions in a flash with interactive message swiping in chat rooms.',
      'feature_card_1_tag': 'Real-Time Sync',
      'feature_card_1_title': 'Interactive Calendar & Schedule',
      'feature_card_1_desc': 'Manage weekly teaching agendas and assignment deadlines in one unified view.',
      'feature_card_2_tag': 'Smart Analytics',
      'feature_card_2_title': 'Student Achievement Report',
      'feature_card_2_desc': 'Monitor attendance graphs, quiz score recaps, and class engagement transparently.',
      'cta_title': 'Ready to Enhance Learning Quality?',
      'cta_desc': 'Join thousands of teachers and students in the Hubner Edu learning system.',
      'cta_btn': 'Enter Hubner Edu',
      'navbar_masuk': 'Login',
      'quiz_soal_header': 'Question 1 of 10 • Modern Physics',
      'quiz_sisa_waktu': 'Time Left: 08:45',
      'quiz_soal_text': 'Which of the following is a primary input hardware device...',
      'quiz_btn_kirim': 'Submit Answer',
      'quiz_btn_sent': 'Answer Submitted!',
      'quiz_feedback_great': 'Great Job',
      'quiz_score_subtitle': 'Your quiz performance exceeded the class average.',
      'monitoring_kelas_title': 'Modern Physics • Learning Progress',
      'monitoring_kelas_selesai': '84% Completed',
      'monitoring_kelas_aktivitas': 'Real-Time Chat Discussion',
      'elemen_status_1': 'Completed',
      'elemen_status_2': 'In Progress',
      'elemen_status_3': 'Upcoming',
      'btn_kerjakan_quiz': 'Take Stage 2 Quiz',
    }
  };

  @override
  void initState() {
    super.initState();
    _startTabAutoSwitcher(); // 10 seconds timer!
    _startQuizAutoPlay();
    _startAISimulationLoop();
    _startChatAnimationLoop();
    _startMateriCheckAnimationLoop();
  }

  void _startTabAutoSwitcher() {
    _tabAutoSwitchTimer?.cancel();
    _tabAutoSwitchTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _activeTab = (_activeTab + 1) % 3;
        });
      }
    });
  }

  void _startMateriCheckAnimationLoop() {
    _materiCheckTimer?.cancel();
    _materiCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_activeTab == 0 && mounted) {
        setState(() {
          _materi3Checked = !_materi3Checked;
        });
      }
    });
  }

  void _startQuizAutoPlay() {
    _quizAutoPlayTimer?.cancel();
    _quizAutoPlayTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_activeTab == 2 && mounted) {
        setState(() {
          _quizStep = (_quizStep + 1) % 4;
          if (_quizStep == 0) {
            _selectedQuizOption = -1;
            _quizSubmitted = false;
            _liveScore = 70;
          } else if (_quizStep == 1) {
            _selectedQuizOption = 0;
            _liveScore = 80;
          } else if (_quizStep == 2) {
            _quizSubmitted = true;
            _liveScore = 95;
          } else if (_quizStep == 3) {
            _liveScore = 100;
          }
        });
      }
    });
  }

  void _startAISimulationLoop() {
    _aiAnimationTimer?.cancel();
    _aiAnimationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _triggerAIDemo();
      }
    });
  }

  void _startChatAnimationLoop() {
    _chatAnimationTimer?.cancel();
    _chatAnimationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_activeTab == 1 && mounted) {
        setState(() {
          _chatCount = (_chatCount % 4) + 1;
        });
      }
    });
  }

  void _triggerAIDemo() {
    setState(() {
      _isGeneratingAI = true;
      _aiStageCount = 0;
    });
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isGeneratingAI = false;
          _aiStageCount = 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabAutoSwitchTimer?.cancel();
    _quizAutoPlayTimer?.cancel();
    _aiAnimationTimer?.cancel();
    _chatAnimationTimer?.cancel();
    _materiCheckTimer?.cancel();
    _aiPromptController.dispose();
    super.dispose();
  }

  String _t(String key) {
    final currentLang = HubnerApp.languageNotifier.value;
    return _translations[currentLang]?[key] ?? _translations['Bahasa Indonesia']?[key] ?? key;
  }

  void _onManualTabSelect(int index) {
    setState(() {
      _activeTab = index;
    });
    _startTabAutoSwitcher();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return ValueListenableBuilder<String>(
      valueListenable: HubnerApp.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          body: AnimatedRainbowBackground(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Navbar
                  _buildNavBar(context),

                  // 2. Hero Section
                  _buildHeroSection(context, isDesktop, size),

                  // 3. Showcase Section (Strict Max Width 1100)
                  _buildShowcaseSection(context, isDesktop),

                  const SizedBox(height: 48),

                  // 4. Features & Benefits Grid ("Lebih Dari Sekadar LMS Biasa" - Strict Max Width 1100)
                  _buildFeaturesGrid(context, isDesktop),

                  const SizedBox(height: 48),

                  // 5. DEDICATED AI GENERATOR SECTION (Strict Max Width 1100)
                  _buildAIFeatureSection(context, isDesktop),

                  // 6. CTA Section with Wave Pattern (Strict Max Width 1100)
                  _buildCTASection(context),

                  // 7. Footer
                  _buildFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Hubner',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.normal,
                  letterSpacing: -1,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B52DF), Color(0xFF5B3DE6), Color(0xFF7D2AE8)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'edu',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: HubnerApp.languageNotifier.value,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.language_rounded, size: 14, color: Colors.black54),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    items: ['Bahasa Indonesia', 'English'].map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang,
                        child: Text(lang == 'English' ? 'EN' : 'ID'),
                      );
                    }).toList(),
                    onChanged: (newLang) {
                      if (newLang != null) {
                        HubnerApp.languageNotifier.value = newLang;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              HoverCard(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B52DF).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _t('navbar_masuk'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDesktop, Size size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                const SizedBox(width: 6),
                Text(
                  _t('star_badge'),
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _t('hero_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 44 : 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5B45E0),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              _t('hero_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          HoverCard(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B52DF).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _t('hero_cta'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SHOWCASE SECTION (Strict Max Width 1100)
  Widget _buildShowcaseSection(BuildContext context, bool isDesktop) {
    final String tab0Text = HubnerApp.languageNotifier.value == 'English' ? 'Classroom Card' : 'Card Kelas';
    final String tab1Text = HubnerApp.languageNotifier.value == 'English' ? 'Class Monitoring' : 'Monitoring Kelas';
    final String tab2Text = HubnerApp.languageNotifier.value == 'English' ? 'Take a Quiz' : 'Mengerjakan Quiz';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildTabButton(0, tab0Text, Icons.grid_view_rounded),
                _buildTabButton(1, tab1Text, Icons.analytics_rounded),
                _buildTabButton(2, tab2Text, Icons.quiz_rounded),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(_activeTab),
              child: _buildActiveMockup(isDesktop),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => _onManualTabSelect(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.black54, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMockup(bool isDesktop) {
    switch (_activeTab) {
      case 0:
        return _buildClassroomMockup(isDesktop);
      case 1:
        return _buildMonitoringMockup(isDesktop);
      case 2:
        return _buildQuizMockup(isDesktop);
      default:
        return const SizedBox.shrink();
    }
  }

  // Showcase 0: Card Kelas (With Animated Progress Line in Left Card & Animated Checkmark Transition in Right Card!)
  Widget _buildClassroomMockup(bool isDesktop) {
    final Color cardBg = _classroomCardColors[0]; // Soft Coral Blush
    final Color accent = _classroomAccentColors[0]; // Salmon Coral Accent

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _t('showcase_title_0'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _t('showcase_desc_0'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 24),

          // 50-50 Split Layout on Desktop / Stacked on Mobile
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE (50%): Classroom Identity Card WITH ANIMATED PROGRESS LINE!
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ClassroomCardPatternPainter(
                              patternIndex: 0,
                              accentColor: accent,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.school_rounded, size: 12, color: accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'SMA Kelas 11 • IPA 2',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Kode: FIS-11A',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Fisika Modern & Astronomi',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pengajar: Pak Dimas Supriadi, M.Pd\nTotal 32 Siswa Aktif',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ANIMATED PROGRESS LINE IN CLASSROOM IDENTITY CARD!
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progress Pembelajaran Kelas', style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    Text('68%', style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: accent)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 0.68),
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        minHeight: 6,
                                        backgroundColor: Colors.white,
                                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.menu_book_rounded, size: 12, color: Colors.black87),
                                      const SizedBox(width: 4),
                                      Text('3 Elemen', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.assignment_turned_in_rounded, size: 12, color: Colors.black87),
                                      const SizedBox(width: 4),
                                      Text('12 Tugas', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (isDesktop) const SizedBox(width: 20) else const SizedBox(height: 20),

              // RIGHT SIDE (50%): Expanded Elemen 2 with ANIMATED CHECKMARK TRANSITION (Unchecked -> Checked)!
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tahapan Belajar & Elemen Materi',
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),

                    // Elemen 1 (Selesai)
                    _buildAppElemenCard(
                      stageNumber: 1,
                      title: 'Vektor Dua Dimensi & Kinematika',
                      statusLabel: _t('elemen_status_1'),
                      statusBg: const Color(0xFFD1FAE5),
                      statusFg: const Color(0xFF059669),
                      statusIcon: Icons.check_circle_rounded,
                      cardBg: _classroomCardColors[1],
                      accentColor: _classroomAccentColors[1],
                    ),
                    const SizedBox(height: 10),

                    // Elemen 2 (Expanded with ANIMATED Materi Checkmarks!)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _classroomCardColors[3],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _classroomAccentColors[3].withOpacity(0.4), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Elemen 2: Hukum Gerak Newton & Gravitasi',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _t('elemen_status_2'),
                                  style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('3 Materi • 1 Kuis Evaluasi', style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54)),
                          const SizedBox(height: 10),

                          // Materi Sub-Cards (Item 3 animates between unchecked and checked!)
                          _buildAnimatedMateriSubCard('Hukum I Newton (Konsep Inersia Benda)', 'Materi Pembelajaran', _classroomAccentColors[3], isChecked: true),
                          _buildAnimatedMateriSubCard('Hukum II Newton (Persamaan F = m . a) & Aplikasi', 'Materi Pembelajaran', _classroomAccentColors[3], isChecked: true),
                          _buildAnimatedMateriSubCard('Hukum III Newton (Aksi - Reaksi)', 'Materi Pembelajaran', _classroomAccentColors[3], isChecked: _materi3Checked),
                          const SizedBox(height: 12),

                          // Interactive "Kerjakan Kuis Elemen 2" Button!
                          HoverCard(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _activeTab = 2; // Jump to Quiz Tab!
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _classroomAccentColors[3],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_circle_fill_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    _t('btn_kerjakan_quiz'),
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Elemen 3 (Akan Datang)
                    _buildAppElemenCard(
                      stageNumber: 3,
                      title: 'Terapan Fisika Kuantum & Foton',
                      statusLabel: _t('elemen_status_3'),
                      statusBg: const Color(0xFFF1F5F9),
                      statusFg: Colors.black54,
                      statusIcon: Icons.lock_rounded,
                      cardBg: const Color(0xFFF8FAFC),
                      accentColor: Colors.black38,
                      isLocked: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppElemenCard({
    required int stageNumber,
    required String title,
    required String statusLabel,
    required Color statusBg,
    required Color statusFg,
    required IconData statusIcon,
    required Color cardBg,
    required Color accentColor,
    bool isLocked = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Elemen $stageNumber: $title',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.black54 : Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 11, color: statusFg),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: statusFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMateriSubCard(String title, String subtitle, Color accentColor, {required bool isChecked}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isChecked ? accentColor.withOpacity(0.4) : const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.black45),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey<bool>(isChecked),
              size: 18,
              color: isChecked ? accentColor : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // Showcase 1: Monitoring Kelas (2 Top Cards: Total Siswa Join & Kehadiran, 2 Bottom Cards: Tugas Masuk % & Quiz Rata-Rata)
  Widget _buildMonitoringMockup(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _t('showcase_title_1'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _t('showcase_desc_1'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 24),

          // 50-50 Split Layout on Desktop / Stacked on Mobile
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE (50%): Progress & 4 STAT CARDS (2 Top Cards, 2 Bottom Cards as requested!)
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          _t('monitoring_kelas_title'),
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _t('monitoring_kelas_selesai'),
                            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 0.84),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // TOP ROW (2 CARDS: Total Siswa Join & Kehadiran Kelas)
                    Row(
                      children: [
                        Expanded(
                          child: _buildGridStatCard('Total Siswa Join', '32 / 32 Siswa', Icons.groups_rounded, _classroomCardColors[1], _classroomAccentColors[1]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildGridStatCard('Kehadiran Kelas', '96.8% Hadir', Icons.how_to_reg_rounded, _classroomCardColors[0], _classroomAccentColors[0]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // BOTTOM ROW (2 CARDS: Tugas dalam Persentase & Quiz Rata-Rata)
                    Row(
                      children: [
                        Expanded(
                          child: _buildGridStatCard('Tugas Masuk', '87.5%', Icons.task_alt_rounded, _classroomCardColors[3], _classroomAccentColors[3]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildGridStatCard('Rata-Rata Quiz', '88.5 Nilai', Icons.star_rounded, _classroomCardColors[4], _classroomAccentColors[4]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),

              // RIGHT SIDE (50%): Real Chat Discussion Stream
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('monitoring_kelas_aktivitas'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 10),

                    _buildRealChatBubbleLeft(
                      sender: 'agung',
                      text: 'di kelas mana ya pak',
                      time: '01:28',
                      avatarAsset: 'assets/icon_pack/avatar/sma_1.png',
                    ),
                    _buildRealChatBubbleLeft(
                      sender: 'agung',
                      text: 'tugas elemen 2 sudah saya kerjakan pak',
                      time: '14:16',
                      avatarAsset: 'assets/icon_pack/avatar/sma_1.png',
                    ),
                    _buildRealChatBubbleRight(
                      sender: 'Pak Dimas',
                      text: 'bagus sekali agung, nilai kuis kamu 100!',
                      time: '18:44',
                      avatarAsset: 'assets/icon_pack/avatar/guru_1.png',
                    ),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _chatCount >= 4
                          ? _buildRealChatBubbleLeft(
                              sender: 'siti',
                              text: 'terima kasih pak, kuisnya sangat interaktif!',
                              time: '21:32',
                              avatarAsset: 'assets/icon_pack/avatar/sma_2.png',
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridStatCard(String label, String value, IconData icon, Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.black87)),
                Text(value, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealChatBubbleLeft({
    required String sender,
    required String text,
    required String time,
    required String avatarAsset,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(avatarAsset, width: 30, height: 30, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sender, style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(text, style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(time, style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.black45)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealChatBubbleRight({
    required String sender,
    required String text,
    required String time,
    required String avatarAsset,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(sender, style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(text, style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(time, style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.white60)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipOval(
            child: Image.asset(avatarAsset, width: 30, height: 30, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }

  // Showcase 2: Mengerjakan Quiz
  Widget _buildQuizMockup(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _t('showcase_title_2'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _t('showcase_desc_2'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 24),

          // 60-40 Split Layout on Desktop / Stacked on Mobile
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE (60% Desktop): Quiz Answering Interface
              Expanded(
                flex: isDesktop ? 6 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          _t('quiz_soal_header'),
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
                          ),
                          child: Text(
                            _t('quiz_sisa_waktu'),
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _classroomCardColors[3],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _classroomAccentColors[3].withOpacity(0.4), width: 1.2),
                      ),
                      child: Text(
                        _t('quiz_soal_text'),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuizOptionRow(0, 'A', 'Keyboard'),
                    const SizedBox(height: 8),
                    _buildQuizOptionRow(1, 'B', 'Monitor'),
                    const SizedBox(height: 8),
                    _buildQuizOptionRow(2, 'C', 'Printer'),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black,
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _quizSubmitted ? _t('quiz_btn_sent') : _t('quiz_btn_kirim'),
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),

              // RIGHT SIDE (40% Desktop): Live Score Card
              Expanded(
                flex: isDesktop ? 4 : 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6FFFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: Color(0xFF14B8A6), shape: BoxShape.circle),
                            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _t('quiz_feedback_great'),
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F9484)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Skor Evaluasi Real-Time:',
                        style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: Text(
                              '$_liveScore',
                              key: ValueKey<int>(_liveScore),
                              style: GoogleFonts.poppins(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            ' / 100',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.70, end: _liveScore / 100.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: val,
                              minHeight: 8,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('quiz_score_subtitle'),
                        style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black87, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuizOptionRow(int optionIndex, String letter, String text) {
    final isSelected = _selectedQuizOption == optionIndex;
    final isCorrect = optionIndex == 0;
    Color borderColor = const Color(0xFFE2E8F0);
    Color optionBgColor = Colors.white;

    if (isSelected) {
      if (_quizSubmitted) {
        borderColor = isCorrect ? const Color(0xFF14B8A6) : const Color(0xFFEF4444);
        optionBgColor = isCorrect ? const Color(0xFFE6FFFA) : const Color(0xFFFEF2F2);
      } else {
        borderColor = const Color(0xFF9333EA);
        optionBgColor = const Color(0xFFF3E8FF);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: optionBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1.5)),
            alignment: Alignment.center,
            child: Text(letter, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.black87 : Colors.black45)),
          ),
          const SizedBox(width: 10),
          Text(text, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: Colors.black87)),
        ],
      ),
    );
  }

  // DEDICATED SECTION 3: Features Grid ("Lebih Dari Sekadar LMS Biasa" - Strict Max Width 1100)
  Widget _buildFeaturesGrid(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        children: [
          Text(
            _t('feature_grid_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('feature_grid_desc'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 32),

          // Wrap Layout with Strict Width Calculation so 3 cards align perfectly with 1100 max width!
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final cardWidth = isDesktop ? ((availableWidth - 40) / 3) : double.infinity;

              return Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.start,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildFeatureCard(
                      tag: _t('feature_card_0_tag'),
                      icon: Icons.chat_bubble_rounded,
                      title: _t('feature_card_0_title'),
                      description: _t('feature_card_0_desc'),
                      cardBgColor: _classroomCardColors[1],
                      accentColor: _classroomAccentColors[1],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildFeatureCard(
                      tag: _t('feature_card_1_tag'),
                      icon: Icons.calendar_month_rounded,
                      title: _t('feature_card_1_title'),
                      description: _t('feature_card_1_desc'),
                      cardBgColor: _classroomCardColors[0],
                      accentColor: _classroomAccentColors[0],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildFeatureCard(
                      tag: _t('feature_card_2_tag'),
                      icon: Icons.analytics_rounded,
                      title: _t('feature_card_2_title'),
                      description: _t('feature_card_2_desc'),
                      cardBgColor: _classroomCardColors[2],
                      accentColor: _classroomAccentColors[2],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String tag,
    required IconData icon,
    required String title,
    required String description,
    required Color cardBgColor,
    required Color accentColor,
  }) {
    return HoverCard(
      borderRadius: BorderRadius.circular(20),
      hoverBorderColor: accentColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.3), width: 1.0),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.black87,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // DEDICATED SECTION 5: AI STAGE GENERATOR (Strict Max Width 1100)
  Widget _buildAIFeatureSection(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE (40% Desktop): Yellow Description Card ONLY
          Expanded(
            flex: isDesktop ? 4 : 0,
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 24 : 18),
              decoration: BoxDecoration(
                color: _classroomCardColors[4],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _classroomAccentColors[4].withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _classroomAccentColors[4].withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _classroomAccentColors[4].withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: _classroomAccentColors[4]),
                        const SizedBox(width: 6),
                        Text(
                          _t('ai_section_title'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _classroomAccentColors[4],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('ai_section_subtitle'),
                    style: GoogleFonts.poppins(
                      fontSize: isDesktop ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t('ai_section_desc'),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 20),

          // RIGHT SIDE (60% Desktop): White Interactive AI Simulator Card OUTSIDE Yellow Card
          Expanded(
            flex: isDesktop ? 6 : 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aiPromptController,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: _t('ai_prompt_hint'),
                            isDense: true,
                            border: InputBorder.none,
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isGeneratingAI ? null : _triggerAIDemo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isGeneratingAI
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _t('ai_btn_generate'),
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF14B8A6)),
                      const SizedBox(width: 6),
                      Text(
                        _t('ai_result_title'),
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF14B8A6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Animated Stage Creation with 3-5 Materi Sub-Items per Elemen!
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _isGeneratingAI
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14B8A6))),
                                const SizedBox(width: 8),
                                Text('AI sedang merancang 3-5 materi per elemen...', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _buildAIGeneratedStageWithMateris(
                                stageTitle: 'Elemen 1: Vektor Dua Dimensi & Kinematika',
                                materis: [
                                  '1. Konsep Dasar Vektor & Skalar',
                                  '2. Penjumlahan Vektor Metode Analitis',
                                  '3. Kinematika Gerak Lurus Berubah Beraturan',
                                  '4. Persamaan Kecepatan & Percepatan Sudut',
                                ],
                                bg: const Color(0xFFE6FFFA),
                                accent: const Color(0xFF14B8A6),
                              ),
                              const SizedBox(height: 10),
                              _buildAIGeneratedStageWithMateris(
                                stageTitle: 'Elemen 2: Hukum Gerak Newton & Gravitasi',
                                materis: [
                                  '1. Hukum I Newton (Inersia Benda)',
                                  '2. Hukum II Newton (Persamaan F = m . a)',
                                  '3. Hukum III Newton (Aksi - Reaksi)',
                                  '4. Hukum Gravitasi Universal Newton',
                                ],
                                bg: const Color(0xFFEFF6FF),
                                accent: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIGeneratedStageWithMateris({
    required String stageTitle,
    required List<String> materis,
    required Color bg,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stageTitle,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${materis.length} Materi', style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.bold, color: accent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: materis.map((materi) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 12, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        materi,
                        style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // CTA Section (Strict Max Width 1100)
  Widget _buildCTASection(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1100),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ClassroomCardPatternPainter(
                  patternIndex: 0,
                  accentColor: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Text(
                    _t('cta_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('cta_desc'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  HoverCard(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _t('cta_btn'),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        children: [
          const Divider(color: Color(0xFFE2E8F0), thickness: 1.5),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2026 Hubner Ecosystem. Hak Cipta Dilindungi.',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// HoverCard Widget
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? hoverBorderColor;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.hoverBorderColor,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: (widget.hoverBorderColor ?? Colors.black).withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ClassroomCardPatternPainter Definition from class_page.dart
class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (patternIndex % 4) {
      case 0:
        final paint = Paint()
          ..color = accentColor.withOpacity(0.08)
          ..style = PaintingStyle.fill;
        final path = Path();
        path.moveTo(size.width * 0.45, 0);
        path.cubicTo(
          size.width * 0.65, size.height * 0.35,
          size.width * 0.35, size.height * 0.75,
          size.width * 0.85, size.height,
        );
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
        path.close();
        canvas.drawPath(path, paint);

        final paintWhite = Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        final pathWhite = Path();
        pathWhite.moveTo(size.width * 0.6, 0);
        pathWhite.cubicTo(
          size.width * 0.8, size.height * 0.4,
          size.width * 0.5, size.height * 0.8,
          size.width, size.height * 0.7,
        );
        pathWhite.lineTo(size.width, 0);
        pathWhite.close();
        canvas.drawPath(pathWhite, paintWhite);
        break;

      case 1:
        final paintRing = Paint()
          ..color = accentColor.withOpacity(0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 30, paintRing);
        canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 60, paintRing);
        break;

      case 2:
        final paintDots = Paint()
          ..color = accentColor.withOpacity(0.08)
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            canvas.drawCircle(
              Offset(size.width * 0.65 + (i * 12), size.height * 0.2 + (j * 12)),
              2.5,
              paintDots,
            );
          }
        }
        break;

      case 3:
        final paintStripe = Paint()
          ..color = accentColor.withOpacity(0.07)
          ..style = PaintingStyle.fill;
        final pathStripe = Path();
        pathStripe.moveTo(size.width * 0.5, 0);
        pathStripe.lineTo(size.width * 0.7, 0);
        pathStripe.lineTo(size.width, size.height * 0.5);
        pathStripe.lineTo(size.width, size.height * 0.8);
        pathStripe.close();
        canvas.drawPath(pathStripe, paintStripe);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
