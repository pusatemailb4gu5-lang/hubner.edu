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
  // 1. MASTER SCALE TOKENS (Ubah angka di sini, seluruh aplikasi otomatis berubah!)
  // =========================================================================
  static const double sizePageTitle          = 28.0; // Judul Halaman Utama / Profil Display
  static const double sizeChatHeaderTitle    = 18.5; // Judul Header Chat (Nama Grup/Kontak)
  static const double sizeChatHeaderSubtitle = 18.0; // Subjudul Header Chat (Status/Anggota)
  static const double sizeDiscussionTitle    = 18.0; // Judul Item di Tab Diskusi
  static const double sizeChatBody           = 20.0; // Isi Teks Pesan di Daun/Bubble Chat
  static const double sizeSearchInput        = 17.0; // Kolom Input Pencarian & Hint
  static const double sizeSenderName         = 18.0; // Nama Pengirim di Daun Chat
  static const double sizeReplyTitle         = 16.5; // Nama Pengirim Reply
  static const double sizeReplySubtitle      = 16.5; // Isi Ringkasan Reply
  static const double sizeSectionHeader      = 18.0; // Judul Bagian / Kartu ("Hari Ini", "Daftar Kelas")
  static const double sizeCardTitle          = 16.5; // Judul Kartu Kelas / Catatan
  static const double sizeTimestamp          = 15.0; // Jam / Keterangan Waktu Pesan & Jadwal
  static const double sizeBodySubtitle       = 15.5; // Keterangan Subtitle / Role ("Siswa · SMA/SMK")
  static const double sizeDocumentTitle      = 18.5; // Nama Berkas Dokumen (Disamakan dengan Judul Chat Grup 18.5px)
  static const double sizeButtonAction       = 15.0; // Tombol Aksi ("Catatan", "Statistik", dsb.)
  static const double sizeTagChannel         = 13.5; // Tag Channel (#umum, #diskusi)
  static const double sizeDropdown           = 15.0; // Tombol & Opsi Menu Dropdown Selector
  static const double sizeCheckbox           = 15.0; // Teks Label Checkbox & Multi-selector (18px)
  static const double sizeFileSize           = 12.0; // Ukuran Berkas Lampiran (KB/MB)
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
