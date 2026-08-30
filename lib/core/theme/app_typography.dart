import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Typography Design Tokens (CSS-like Master Style System)
///
/// Digunakan sebagai satu-satunya pusat kendali ukuran, bobot (*weight*),
/// dan jenis font (*font family*) untuk seluruh aplikasi Hubner Edu.
///
/// Jika ingin mengubah ukuran/font seluruh aplikasi, cukup ubah token di file ini!
class AppTypography {
  AppTypography._();

  // =========================================================================
  // 0. SCREEN HORIZONTAL MARGIN TOKENS (Acuan Standar Tampilan Layar Full App)
  // =========================================================================
  /// Margin / Padding horizontal layar acuan Home Page (kiri & kanan: 14.0px)
  static const double screenHorizontalMargin = 14.0;
  static const double horizontalPadding = 14.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: screenHorizontalMargin);
  static const EdgeInsets pageHorizontalPadding = EdgeInsets.symmetric(horizontal: screenHorizontalMargin);

  /// Helper untuk membuat EdgeInsets dengan margin horizontal standar
  static EdgeInsets pagePadding({double top = 0, double bottom = 0}) =>
      EdgeInsets.only(left: screenHorizontalMargin, right: screenHorizontalMargin, top: top, bottom: bottom);

  // =========================================================================
  // 1. MASTER SCALE TOKENS (Acuan Standar Desain: Profil, Menu & Onboarding)
  // =========================================================================
  static const double sizePageTitle          = 24.0; // Judul Halaman Utama / Display Besar (Acuan Onboarding & Profil)
  static const double sizeChatHeaderTitle    = 17.0; // Judul Header Bar / Appbar Atas ("Profil", "Catatan", Kelas)
  static const double sizeChatHeaderSubtitle = 13.0; // Subjudul Header Bar (Status / Anggota)
  static const double sizeSectionHeader      = 16.0; // Judul Section Header (Acuan Profil: "Informasi Akun", "Pengaturan")
  static const double sizeCardTitle          = 15.0; // Judul Kartu Utama / Label Menu (Acuan Menu Profil & List Card)
  static const double sizeDiscussionTitle    = 15.5; // Judul Item di Tab Diskusi
  static const double sizeDocumentTitle      = 15.0; // Nama Berkas Dokumen
  static const double sizeChatBody           = 15.0; // Isi Teks Pesan & Deskripsi (Acuan Onboarding Body)
  static const double sizeSearchInput        = 14.5; // Kolom Input Pencarian & Hint
  static const double sizeSenderName         = 14.5; // Nama Pengirim di Daun Chat
  static const double sizeButtonAction       = 14.5; // Tombol Aksi ("Masuk", "Catatan", dsb.)
  static const double sizeDropdown           = 14.5; // Tombol & Opsi Menu Dropdown Selector
  static const double sizeCheckbox           = 14.5; // Teks Label Checkbox & Multi-selector
  static const double sizeBodySubtitle       = 13.5; // Keterangan Subtitle / Role ("Pengajar · SMA", "Siswa")
  static const double sizeReplyTitle         = 13.5; // Nama Pengirim Reply
  static const double sizeTagChannel         = 13.0; // Tag Channel (#umum, #diskusi)
  static const double sizeReplySubtitle      = 13.0; // Isi Ringkasan Reply
  static const double sizeTimestamp          = 12.5; // Jam / Tanggal / Nilai Trailing Menu Profil
  static const double sizeFileSize           = 11.5; // Ukuran Berkas Lampiran (KB/MB)
  static const double sizeMicroBadge         = 11.0; // Tag Status / HD Badge / Counter Reaksi

  // =========================================================================
  // 2. TYPOGRAPHY TOKENS (Fungsi Helper Style untuk Komponen UI)
  // =========================================================================

  /// 1. Judul Halaman Besar / Display Name (.page-title)
  static TextStyle pageTitle({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizePageTitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 2. Judul Header Chat di Bar Atas (.chat-header-title)
  static TextStyle chatHeaderTitle({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeChatHeaderTitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 3. Subjudul Header Chat di Bar Atas (.chat-header-subtitle)
  static TextStyle chatHeaderSubtitle({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeChatHeaderSubtitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 4. Isi Pesan Utama di Daun Chat (.chat-body)
  static TextStyle chatBody({
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle? fontStyle,
    double? letterSpacing,
    double height = 1.3,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeChatBody,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 5. Kolom Input Teks Pesan & Form (.message-input)
  static TextStyle messageInput({
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeChatBody,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 6. Kolom Input Pencarian & Hint (.search-input)
  static TextStyle searchInput({
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeSearchInput,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 7. Nama Pengirim di Daun Chat (.sender-name)
  static TextStyle senderName({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeSenderName,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 8. Teks Mention @nama di Daun Chat (.mention-tag)
  static TextStyle mentionTag({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeChatBody,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 9. Judul Pengirim Reply (.reply-title)
  static TextStyle replyTitle({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeReplyTitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 10. Isi Pesan Reply (.reply-subtitle)
  static TextStyle replySubtitle({
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeReplySubtitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 11. Keterangan Waktu / Jam Pesan & Jadwal (.timestamp)
  static TextStyle timestamp({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeTimestamp,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 12. Judul Obrolan di Daftar Diskusi (.discussion-title)
  static TextStyle discussionTitle({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeDiscussionTitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 13. Tag Channel / Kategori (.channel-tag)
  static TextStyle channelTag({
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeTagChannel,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 14. Judul Bagian / Section Header (.section-header)
  static TextStyle sectionHeader({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeSectionHeader,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 15. Judul Kartu Kelas / Catatan (.card-title)
  static TextStyle cardTitle({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeCardTitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 16. Subjudul / Role Pengguna / Metadata Deskripsi (.subtitle)
  static TextStyle subtitle({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeBodySubtitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// Alias for subtitle
  static TextStyle bodySubtitle({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) =>
      subtitle(
        color: color,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
        fontSize: fontSize,
      );

  /// 17. Nama File Dokumen Lampiran (.document-title)
  static TextStyle documentTitle({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeDocumentTitle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 18. Ukuran File Lampiran (.file-size)
  static TextStyle fileSize({
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize ?? sizeFileSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 19. Label Tombol Aksi (.button-label)
  static TextStyle buttonLabel({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeButtonAction,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 20. Micro Tag / HD Badge (.micro-badge)
  static TextStyle microBadge({
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeMicroBadge,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 21. Teks Tombol / Label Dropdown & Selector (.dropdown-button)
  static TextStyle dropdown({
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeDropdown,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 22. Teks Opsi Menu Dropdown (.dropdown-item)
  static TextStyle dropdownItem({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeDropdown,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 23. Teks Label Checkbox & Multi-selector (.checkbox-label)
  static TextStyle checkboxLabel({
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? fontSize,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize ?? sizeCheckbox,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }
}
