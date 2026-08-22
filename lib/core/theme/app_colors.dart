import 'package:flutter/material.dart';

/// Color tokens extracted from the HTML/Tailwind config of the design
/// (see `brand` & `meeting` palettes in the source design).
class AppColors {
  AppColors._();

  static String themeMode = 'Terang'; // 'Terang', 'Gelap', 'Hitam'

  static bool get isDarkMode => themeMode == 'Gelap' || themeMode == 'Hitam';

  // Brand
  static Color get brandBg {
    if (themeMode == 'Hitam') return const Color(0xFF000000);
    return isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  }

  static Color get brandSurface {
    if (themeMode == 'Hitam') return const Color(0xFF121212);
    return isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  }

  static Color get brandSidebar {
    if (themeMode == 'Hitam') return const Color(0xFF121212);
    return isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  }

  static Color get brandPrimary =>
      const Color(0xFF7F52FC); // Violet `#7F52FC` as primary brand color
  static Color get brandPrimaryLight {
    if (themeMode == 'Hitam') return const Color(0xFF1F1F1F);
    return isDarkMode ? const Color(0xFF2E244D) : const Color(0xFFD4C5FF); // Light violet/lavender `#D4C5FF`
  }

  static Color get brandBadgeBlue => const Color(0xFF7F52FC); // Vibrant violet for badges & accents
  static Color get brandAccent => const Color(0xFFFFC854); // Soft yellow `#FFC854`
  static Color get brandTextMain {
    if (themeMode == 'Hitam') return const Color(0xFFFFFFFF);
    return isDarkMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF000000); // Pure black text
  }

  static Color get brandTextMuted {
    if (themeMode == 'Hitam') return const Color(0xFF8E8E93);
    return isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  }

  static Color get brandBorder {
    if (themeMode == 'Hitam') return const Color(0xFF262626);
    return isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  }

  static Color get brandChartBar {
    if (themeMode == 'Hitam') return const Color(0xFF262626);
    return isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  }

  static Color get brandChartBarActive =>
      const Color(0xFF000000); // Black for active chart bar

  // Task status colors
  static Color get taskInProgress => const Color(0xFF059669);
  static Color get taskToDo => const Color(0xFFD97706);
  static Color get taskInReview => const Color(0xFF8AA6A3);

  // Meeting cards (collaborative pastel palette with white/black buttons theme)
  static Color get meetingBlue =>
      isDarkMode ? const Color(0xFF1E3A8A) : const Color(0xFFD7EAF7);
  static Color get meetingYellow =>
      isDarkMode ? const Color(0xFF3F3A1E) : const Color(0xFFF6EDC8);
  static Color get meetingPink =>
      isDarkMode ? const Color(0xFF3E2D32) : const Color(0xFFF3DCDC);
  static Color get meetingPurple =>
      isDarkMode ? const Color(0xFF2F3B36) : const Color(0xFFDCEBE4);
  static Color get meetingOrange =>
      isDarkMode ? const Color(0xFF3D332B) : const Color(0xFFF4E2D2);
  static Color get meetingGreen =>
      isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFDDF0E8);

  // Misc
  static Color get danger => const Color(0xFFEF4444);
  static Color get success => const Color(0xFF22C55E);
  static Color get slateDark => const Color(0xFF1E293B);

  /// Soft shadow for elevated surfaces (cards, sidebar pills, etc).
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: isDarkMode
          ? const Color(0x3D000000)
          : const Color(0x14000000), // Darker shadows in dark mode
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
