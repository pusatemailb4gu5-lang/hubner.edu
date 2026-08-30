import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the [ThemeData] used by the app.
///
/// The design is built on the **Inter** font family and a green-leaning brand
/// palette (see [AppColors]).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = AppColors.isDarkMode
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 35.1,
        fontWeight: FontWeight.w700,
        color: AppColors.brandTextMain,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 25.7,
        fontWeight: FontWeight.w700,
        color: AppColors.brandTextMain,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 21.1,
        fontWeight: FontWeight.w700,
        color: AppColors.brandTextMain,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 17.6,
        fontWeight: FontWeight.w600,
        color: AppColors.brandTextMain,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16.4,
        fontWeight: FontWeight.w500,
        color: AppColors.brandTextMain,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 15.2,
        fontWeight: FontWeight.w500,
        color: AppColors.brandTextMain,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.brandTextMuted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15.2,
        fontWeight: FontWeight.w600,
        color: AppColors.brandTextMain,
      ),
    );

    return base.copyWith(
      canvasColor: Colors.white,
      scaffoldBackgroundColor: AppColors.brandBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandAccent,
        surface: AppColors.brandSurface,
        onPrimary: Colors.white,
        onSurface: AppColors.brandTextMain,
      ),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: AppColors.brandTextMain),
      dividerColor: AppColors.brandBorder,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.isDarkMode ? Colors.white : Colors.black,
        selectionColor: AppColors.isDarkMode ? Colors.white24 : const Color(0xFFE2E8F0),
        selectionHandleColor: AppColors.isDarkMode ? Colors.white : Colors.black,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
