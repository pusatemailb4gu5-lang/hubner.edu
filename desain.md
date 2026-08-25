# 🎨 Hubner Edu — Design System Specification

Panduan acuan resmi antarmuka (*UI/UX Design System*) aplikasi **Hubner Edu**.  
Desain mengadopsi struktur visual **WhatsApp iOS/Modern UI** (bersih, berbasis *grouped cards*, *pill cards*, tombol aksi bulat, *glassmorphic floating bar*, filter chips, avatar zoom rapat, dan tipografi berbobot tegas) dengan aturan mutlak: **Seluruh aksen hijau khas WhatsApp DIGANTIKAN oleh Ungu Hubner (Purple Core) No. 1**, dipadukan dengan **10 Pasangan Warna Resmi Identitas Classroom (Light & Dark Mode)**.

---

## 1. 🌟 Filosofi Desain (WhatsApp-Inspired + Hubner Purple)

1. **Grouped & Pill Card Containers**: Menu, data kelas, dan daftar anggota dikelompokkan ke dalam kartu melengkung (*radius 20–32px*) atau *Stadium Pill Shape*.
   - **Light Mode**: Kartu Putih Bersih (`#FFFFFF`) dengan border halus (`#E2E8F0`) di atas canvas abu-abu terang (`#F6F6F6`).
   - **Dark Mode**: Kartu Zinc Surface (`#1C1C1E` / `#18181B`) di atas canvas hitam pekat OLED (`#000000`).
2. **Zoomed Avatar & Logo Framing (*Tightly Scaled Circular Avatars*)**:
   - **Ukuran Card Tetap**: Dimensi container kartu tetap konsisten (tinggi `56–64px`).
   - **Gambar di-Zoom**: Gambar profil avatar, logo kelas, atau ikon diskusi di-zoom rapat (`Transform.scale(scale: 1.4 – 1.5)`) di dalam `ClipOval` / `BoxShape.circle` agar fokus visual karakter/wajah terlihat jelas dan premium tanpa mengubah dimensi kartu luar.
   - **Efek Dark Mode pada Media**: Di mode gelap, seluruh avatar, icon classroom, dan icon chat dilapisi efek blend lembut (`ColorFilter.mode(Colors.black.withValues(alpha: 0.10 - 0.12), BlendMode.darken)`) agar kontras gambar menyatu natural dengan canvas gelap tanpa silau.
3. **Classroom Card Illustration Standar (*No Black Outer Ring*)**:
   - **Ukuran Lebih Besar & Menonjol**: Ilustrasi/ikon kelas di sisi kanan card dibuat lebih besar (`102 x 102 px`), berposisi vertikal center.
   - **Tanpa Lingkaran Hitam**: Tidak menggunakan wrapper `CircleAvatar` tebal atau outline hitam tambahan di luar gambar.
   - **Teks Card di Mode Gelap Harus Putih**: Seluruh teks judul mata pelajaran, tag kelas/jurusan, dan jumlah siswa di atas kartu bernuansa deep colors wajib menggunakan teks **Putih Bersih (`#FFFFFF`)** untuk keterbacaan sempurna.
4. **Ungu Hubner Pengganti Hijau WhatsApp (*The Purple Replacement Rule*)**:
   - **FAB & Primary CTA**: Menggunakan solid **Ungu Hubner (`#7C3AED`)** (bukan hijau WhatsApp `#25D366`).
   - **Status Ring / Story Border**: Lingkaran status aktif menggunakan **Ungu Neon / Vivid (`#A855F7`)**.
   - **Notification Badges & Unread Counter**: Badge lingkaran / kapsul menggunakan **Ungu Hubner (`#7C3AED`)**.
   - **Filter Chips & Tombol Catatan Aktif**: Chip dan tombol catatan di Mode Gelap menggunakan container **Ungu Gelap (`#2E1065`)** dengan ikon/teks **Ungu Lilac (`#D6A5F8`)**.
   - **Outgoing Chat Bubble**: Gelembung pesan terkirim menggunakan **Ungu Deep WhatsApp (`#3B185F` / `#4C1D95`)** (menggantikan hijau tua `#005D4B`).
5. **Circular Action Buttons**: Tombol aksi header (`...`, kamera, cari, pensil, tombol kembali, dan icon hapus sampah) menggunakan lingkaran sempurna atau padding aksi proporsional.
6. **Glassmorphism Floating Bar**: Menu navigasi bawah melayang di atas konten dengan efek *Frosted Glass* (`BackdropFilter` blur 20) dan indikator aktif berbentuk kapsul (*pill*).

---

## 2. 🌈 10 Pasangan Warna Resmi Identitas Classroom (Light & Dark Mode)

Digunakan untuk **Pilihan Warna Card Classroom di Add/Edit Class, Kartu Home, Badge Materi, Slider Elemen, dan Tag Kategori**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                      10 PASANGAN WARNA IDENTITAS CLASSROOM                             │
├────┬──────────────────────┬──────────────────┬──────────────────┬──────────────────────┤
│ No │ Nama Identitas Warna │ ☀️ Light (Pastel)│ 🌙 Dark (Deep)   │ Karakter Mata Pelajaran / Tema │
├────┼──────────────────────┼──────────────────┼──────────────────┼──────────────────────┤
│ 01 │ Ungu / Lilac (Core)  │ #D6A5F8          │ #6B3BA3          │ Identitas Utama, DKV & Seni Rupa │
│ 02 │ Biru / Sky Blue      │ #9CC8FC          │ #2864A8          │ Matematika, Fisika, & Logika │
│ 03 │ Tosca / Emerald Mint │ #7DE3D0          │ #147D75          │ Biologi, Kesehatan & Farmasi │
│ 04 │ Orange / Amber Peach │ #F7BD84          │ #C76D10          │ Sejarah, Sosiologi & Geografi │
│ 05 │ Pink / Rose Magenta  │ #F794BE          │ #A82658          │ Bahasa, Sastra & Seni Budaya │
│ 06 │ Indigo / Royal Violet│ #A5B4FC          │ #4338CA          │ Teknik Komputer, Jaringan & IT │
│ 07 │ Lime / Fresh Olive   │ #BEF264          │ #4D7C0F          │ Agribisnis, Ekologi & Olahraga │
│ 08 │ Cyan / Ocean Wave    │ #67E8F9          │ #0E7490          │ Robotika, Multimedia & Animasi │
│ 09 │ Kuning / Amber Gold  │ #FDE047          │ #A16207          │ Kewirausahaan, Akuntansi & Bisnis │
│ 10 │ Slate / Steel Grey   │ #CBD5E1          │ #334155          │ PPKn, Hukum & Tata Kelola │
└────┴──────────────────────┴──────────────────┴──────────────────┴──────────────────────┘
```

### Detail Token Warna 10 Classroom di Dart / Flutter:
```dart
class HubnerClassroomColors {
  // ☀️ 10 WARNA LIGHT MODE (PASTEL & VIBRANT)
  static const List<Color> lightColors = [
    Color(0xFFD6A5F8), // 01. Lilac Purple (Core)
    Color(0xFF9CC8FC), // 02. Sky Blue
    Color(0xFF7DE3D0), // 03. Emerald Mint / Tosca
    Color(0xFFF7BD84), // 04. Amber Peach / Orange
    Color(0xFFF794BE), // 05. Rose Magenta / Pink
    Color(0xFFA5B4FC), // 06. Indigo Violet
    Color(0xFFBEF264), // 07. Fresh Lime
    Color(0xFF67E8F9), // 08. Ocean Cyan
    Color(0xFFFDE047), // 09. Amber Gold / Kuning
    Color(0xFFCBD5E1), // 10. Steel Slate / Grey
  ];

  // 🌙 10 WARNA DARK MODE (DEEP & RICH CONTRAST)
  static const List<Color> darkColors = [
    Color(0xFF6B3BA3), // 01. Deep Lilac (Core)
    Color(0xFF2864A8), // 02. Deep Sky Blue
    Color(0xFF147D75), // 03. Deep Teal / Tosca
    Color(0xFFC76D10), // 04. Deep Amber / Orange
    Color(0xFFA82658), // 05. Deep Rose / Magenta
    Color(0xFF4338CA), // 06. Deep Indigo
    Color(0xFF4D7C0F), // 07. Deep Olive Lime
    Color(0xFF0E7490), // 08. Deep Ocean Cyan
    Color(0xFFA16207), // 09. Deep Amber Gold
    Color(0xFF334155), // 10. Deep Slate Steel
  ];

  /// Helper untuk mengambil warna kartu berdasarkan index & tema aktif
  static Color getColor(int index, {required bool isDark}) {
    final int safeIdx = index % 10;
    return isDark ? darkColors[safeIdx] : lightColors[safeIdx];
  }

  /// Helper warna teks kontras pada card (Selalu Putih di Dark Mode)
  static Color getCardTextColor({required bool isDark}) {
    return isDark ? Colors.white : Colors.black87;
  }
}
```

---

## 3. 🎨 Palet Warna Sistem (*System Color Tokens*)

### A. Palet Ungu Hubner Utama (Pengganti Hijau WhatsApp)
| Token Warna | Nilai Hex | Fungsi / Penggunaan (Menggantikan Hijau WhatsApp) |
| :--- | :--- | :--- |
| **`hubnerPurplePrimary`** | `#7C3AED` | **Tombol FAB (+)**, CTA Utama ("Pindai/Simpan"), Badge Notifikasi Unread, Tab Aktif |
| **`hubnerPurpleVivid`** | `#A855F7` | **Status Ring Glowing**, Dot Online / Indikator Aktif, Ikon Terverifikasi |
| **`hubnerPurpleLight`** | `#D6A5F8` | Slider Ungu Pastel 01, Aksen Highlight, Ikon Catatan di Mode Gelap |
| **`hubnerPurpleContainerDark`** | `#2E1065` | Latar Filter Chip Aktif & Latar Ikon Catatan di Mode Gelap |
| **`hubnerPurpleBubbleDark`** | `#3B185F` | **Outgoing Chat Bubble** di Mode Gelap (Pengganti Bubble Hijau WhatsApp) |
| **`hubnerPurpleSoftLight`** | `#EDE9FE` | Latar Filter Chip Aktif di Mode Terang, Latar Icon Container |

---

### B. Palet Dark Mode (WhatsApp Dark Theme Standard)
```dart
// ==================== DARK MODE TOKENS ====================
const darkBackground         = Color(0xFF000000); // Latar Canvas Hitam OLED (Pitch Black)
const darkBackgroundSubtle   = Color(0xFF0C0C0E); // Latar alternatif lembut
const darkSurface            = Color(0xFF1C1C1E); // Grouped Card & Pill Container (Gaya iOS Dark)
const darkSurfaceMuted       = Color(0xFF2C2C2E); // Input Field, Search Bar & Inactive Chips
const darkBorder             = Color(0xFF27272A); // Border kartu & modal (Zinc-800)
const darkDivider            = Color(0xFF2C2C2E); // Garis pemisah internal list tile

// Text Tokens (Dark Mode)
const darkTextPrimary        = Color(0xFFFFFFFF); // Teks judul & nama kontak (Putih Terang)
const darkTextSecondary      = Color(0xFFD4D4D8); // Teks subjudul & pesan baca (Abu Terang)
const darkTextMuted          = Color(0xFF71717A); // Teks waktu, hint, tanggal (Zinc-500)

// Classroom Card Text Tokens (Dark Mode)
const darkClassroomTitle     = Color(0xFFFFFFFF); // Judul mapel pada kartu kelas (Putih Bersih)
const darkClassroomTagText   = Color(0xFFFFFFFF); // Teks pada pill tag kelas & siswa
const darkClassroomTagBg     = Color(0x40000000); // Latar pill tag (Black 25% Opacity)
const darkClassroomTagBorder = Color(0x33FFFFFF); // Border pill tag (White 20% Opacity)

// WhatsApp Elements in Hubner Purple (Dark Mode)
const darkFabBackground      = Color(0xFF7C3AED); // FAB Tambah / Buat (+)
const darkStatusRingActive   = Color(0xFFA855F7); // Cincin Status Cerita Ungu Neon
const darkUnreadBadge        = Color(0xFF7C3AED); // Badge counter jumlah unread (cth: "140")
const darkFilterChipActiveBg = Color(0xFF2E1065); // Filter chip aktif ("Semua")
const darkFilterChipActiveTx = Color(0xFFD6A5F8); // Teks filter chip aktif
const darkNotesIconContainer = Color(0xFF2E1065); // Container bulat ikon catatan
const darkNotesIconColor     = Color(0xFFD6A5F8); // Warna ikon buku catatan
const darkChatBubbleOutgoing = Color(0xFF3B185F); // Bubble pesan keluar (Ungu Gelap)
const darkChatBubbleIncoming = Color(0xFF18181B); // Bubble pesan masuk (Zinc Gelap)
const darkGlassNavBar        = Color(0xD918181B); // Frosted Glass Bottom Bar (85% Opacity)
const darkGlassPillActive    = Color(0xFF27272A); // Pill background tab aktif di Bottom Bar
```

---

### C. Palet Light Mode
```dart
// ==================== LIGHT MODE TOKENS ====================
const lightBackground        = Color(0xFFF6F6F6); // Canvas Abu-abu terang WhatsApp
const lightSurface           = Color(0xFFFFFFFF); // Grouped & Pill Card Putih Bersih
const lightSurfaceMuted      = Color(0xFFF0F2F5); // Container input & lingkaran tombol aksi
const lightBorder            = Color(0xFFE2E8F0); // Border kartu & modal
const lightDivider           = Color(0xFFE5E7EB); // Garis pemisah dalam grouped card

// Text Tokens (Light Mode)
const lightTextPrimary       = Color(0xFF0F172A); // Teks judul hitam pekat
const lightTextSecondary     = Color(0xFF475569); // Teks subjudul / deskripsi
const lightTextMuted         = Color(0xFF94A3B8); // Teks waktu, hint, placeholder

// WhatsApp Elements in Hubner Purple (Light Mode)
const lightFabBackground     = Color(0xFF7C3AED); // FAB Tambah / Buat (+)
const lightStatusRingActive  = Color(0xFF7C3AED); // Cincin Status Ungu
const lightUnreadBadge       = Color(0xFF7C3AED); // Badge counter unread
const lightFilterChipActiveBg= Color(0xFFEDE9FE); // Filter chip aktif
const lightFilterChipActiveTx= Color(0xFF6D28D9); // Teks filter chip aktif
const lightNotesIconContainer= Color(0xFFFEF3C7); // Container bulat ikon catatan (Amber 100)
const lightNotesIconColor    = Color(0xFFEA580C); // Warna ikon buku catatan (Orange 600)
const lightChatBubbleOutgoing= Color(0xFFE9D5FF); // Bubble pesan keluar (Lavender)
const lightChatBubbleIncoming= Color(0xFFFFFFFF); // Bubble pesan masuk (Putih)
const lightGlassNavBar       = Color(0xD9FFFFFF); // Frosted Glass Bottom Bar (85% Opacity)
```

---

## 4. 🎴 Standar Kartu Oval (Pill Card) & Avatar Ter-Zoom

Spesifikasi baku untuk daftar teman, anggota classroom, daftar peserta ujian, dan item grup:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       STANDAR PILL CARD & ZOOM AVATAR                       │
├─────────────────────────┬───────────────────────────────────────────────────┤
│ Kelengkungan Card (Pill)│ BorderRadius.circular(32) atau StadiumBorder      │
│ Tinggi Card             │ 60.0 – 64.0 px (TETAP & TIDAK BERUBAH)            │
│ Ukuran Avatar Lingkaran │ Diameter 44.0 – 48.0 px (BoxShape.circle)         │
│ Rasio Zoom Gambar       │ Transform.scale(scale: 1.45) di dalam ClipOval    │
│ Efek Dark Mode Media    │ ColorFilter BlendMode.darken (Opacity 10%)        │
│ Light Mode Card         │ Background #FFFFFF, Border #E2E8F0 (1.2px)        │
│ Dark Mode Card          │ Background #1C1C1E, Border #27272A (1.0px)        │
│ Teks Nama Kontak        │ Plus Jakarta Sans (Bold, 15.0px)                  │
│ Teks Subtitle / ID      │ DM Sans (Regular, 13.0px, Color Slate/Zinc)       │
│ Tombol Aksi Kanan       │ Trash Icon #EF4444 (20px)                         │
└─────────────────────────┴───────────────────────────────────────────────────┘
```

---

## 5. 🔤 Standar Tipografi Resmi (*Typography Scale & Android Standard*)

Standar tipografi resmi Hubner Edu mengacu pada arsitektur baku **Area Pesan Halaman Chat** (`chat_room_page.dart`):
- **Headings, Display Names, Tab Titles & Action Buttons**: Menggunakan `GoogleFonts.plusJakartaSans` (Tegas, solid, modern, geometris).
- **Body Text, Message Bubbles, Subtitles, Timestamps & Form Inputs**: Menggunakan `GoogleFonts.dmSans` (Sangat nyaman dan mudah dibaca pada paragraf chat, keterangan waktu, dan kolom form).

### A. Tabel Hierarki & Ukuran Font Baku
| Kategori Komponen | Ukuran Font | Bobot (*Weight*) | Font Family | Contoh Implementasi di Chat & App |
| :--- | :--- | :--- | :--- | :--- |
| **Large Page Title** | `28.0` – `30.0` px | `FontWeight.bold` (w700/w800) | Plus Jakarta Sans | Judul halaman besar ("Chat", "Laporan Perkembangan", "Hubner Edu") |
| **Chat Header Title (AppBar)** | `18.0` – `20.0` px | `FontWeight.bold` (w700) | Plus Jakarta Sans | **Nama grup / kontak di Header Chat** ("#umum", "Kelas Matematika", "Bagus") |
| **Chat Header Subtitle** | `18.0` px | `FontWeight.w500` (w500) | DM Sans | Keterangan status di header ("3 anggota", "Online", "Terakhir dilihat...") |
| **Chat Message / Primary Body** | `20.0` px | `FontWeight.normal` (w400) | DM Sans | **Isi teks bubble pesan chat** ("tes", "Selamat pagi semuanya..."), deskripsi utama materi |
| **Input TextField Chat / Form** | `20.0` px | `FontWeight.normal` (w400) | DM Sans | Kolom input pesan ("Tulis pesan...", "Cari...", "Keterangan...") |
| **Sender Display Name** | `18.0` px | `FontWeight.bold` (w700) | Plus Jakarta Sans | **Nama pengirim di bubble chat** ("Bagus Setia Budi", "Pak Guru") |
| **Reply Sender Title** | `16.5` px | `FontWeight.bold` (w700) | Plus Jakarta Sans | Nama pengirim reply bubble ("agung", "ayong") |
| **Reply Message Subtitle** | `16.5` px | `FontWeight.normal` (w400) | DM Sans | Isi ringkasan reply di bubble chat |
| **Timestamp / Waktu Pesan** | `15.0` px | `FontWeight.w500` (w500) | DM Sans | **Keterangan jam di bubble chat** ("10:04", "10:06", "Kemarin") |
| **Document Title / File Name** | `14.5` px | `FontWeight.bold` (w700) | Plus Jakarta Sans | Nama file attachment ("robbyfirmansyah...pdf", "Modul.docx") |
| **Subtitle / Sub-label Deskripsi** | `14.0` – `15.0` px | `FontWeight.normal` (w400) | DM Sans | Keterangan sub-item ("Siswa · SMA/SMK", "Materi Pembelajaran") |
| **File Size / Meta Info** | `12.0` px | `FontWeight.normal` (w400) | DM Sans | Ukuran file lampiran ("927.3 KB", "1.2 MB") |
| **Micro Badge / HD Tag** | `10.0` – `11.0` px | `FontWeight.bold` (w700) | Plus Jakarta Sans | Tag kecil status ("HD", "Guru", "Admin") |

### B. Aturan Mutlak Batas Ukuran Terkecil (*Android Minimum Legibility Rule*)
1. **Batas Font Minimum**: Ukuran font terkecil yang diizinkan di seluruh aplikasi Android adalah **`10.0 px`** (khusus badge micro/HD tag).
2. **Body & Isi Teks Chat**: Menggunakan standar baku **`20.0 px`** (`GoogleFonts.dmSans`) agar teks sangat jelas terbaca dan proporsional.
3. **Format Penggunaan Terpusat (`style.css` Flutter - `AppTypography`)**:
   Seluruh halaman **TIDAK LAGI** menulis angka ukuran font secara manual, melainkan memanggil token terpusat dari `lib/core/theme/app_typography.dart`:
   ```dart
   import 'package:hubner/core/theme/app_typography.dart';

   // Judul Header Chat:
   Text(channelTitle, style: AppTypography.chatHeaderTitle(color: Colors.white))

   // Subjudul Header Chat (18.0 px):
   Text(subtitle, style: AppTypography.chatHeaderSubtitle(color: Colors.white60))

   // Isi Pesan Chat (20.0 px):
   Text(message, style: AppTypography.chatBody(color: Colors.white))

   // Kolom Input Pesan / Pencarian:
   TextField(
     style: AppTypography.messageInput(color: Colors.white),
     decoration: InputDecoration(hintStyle: AppTypography.messageInput(color: Colors.white38)),
   )

   // Nama Pengirim & Waktu Pesan:
   Text(senderName, style: AppTypography.senderName(color: senderColor))
   Text(timeText, style: AppTypography.timestamp(color: Colors.white60))
   ```
   > **Keuntungan**: Cukup ubah 1 baris angka di `lib/core/theme/app_typography.dart`, seluruh ukuran dan font di aplikasi langsung terupdate serentak!

---

## 6. 🔘 Bentuk Komponen & Kelengkungan (*Radius Tokens*)

```
┌──────────────────────────────────────────────────────────┐
│                   STANDAR RADIUS                         │
├──────────────────────────┬───────────────────────────────┤
│ Tombol Aksi & FAB        │ BoxShape.circle (Bulat Penuh) │
│ Drawer Attachment Icons  │ BoxShape.circle (Bulat Penuh) │
│ Badge Nomor (01–10)      │ BoxShape.circle (Bulat Penuh) │
│ Color Picker Circles     │ BoxShape.circle (Bulat Penuh) │
│ Pill Card (Member/Friend)│ BorderRadius.circular(32)     │
│ Grouped Cards Container  │ BorderRadius.circular(20–24)  │
│ Filter Chips             │ BorderRadius.circular(20)     │
│ Search Bar Pill          │ BorderRadius.circular(24)     │
│ Floating Bottom Nav Bar  │ BorderRadius.circular(36)     │
│ Primary CTA (Pill)       │ BorderRadius.circular(28)     │
│ Chat Bubble (Outgoing)   │ BorderRadius.circular(18)     │
│ Notification Badge       │ BorderRadius.circular(12)     │
│ Modal Dialogs / Sheets   │ BorderRadius.circular(28)     │
└──────────────────────────┴───────────────────────────────┘
```

---

## 7. ⚪ Standar Ikon Aksi Bulat Solid & Aturan Bebas Bayangan (*Zero-Shadow Rule*)

Seluruh tombol aksi bulat, tombol kirim, drawer lampiran media, dan container ikon wajib mengadopsi standar **Flat Round Solid** tanpa bayangan:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│             STANDAR IKON AKSI BULAT SOLID & ZERO SHADOW                     │
├─────────────────────────┬───────────────────────────────────────────────────┤
│ Bentuk Container        │ BoxShape.circle (Lingkaran Sempurna)              │
│ Gaya Warna Latar        │ Solid Flat Color (Tanpa Gradasi)                  │
│ Efek Bayangan / Elevasi │ TIDAK ADA / HAPUS SELURUH BAYANGAN (boxShadow: [])│
│ Warna Ikon di Dalam     │ Putih Bersih (Colors.white)                       │
│ Ukuran Container Ikon   │ 52.0 – 56.0 px (Drawer) / 40.0 – 44.0 px (Chat)   │
│ Label Teks di Bawah     │ Plus Jakarta Sans (13.0px, FontWeight.w600)       │
└─────────────────────────┴───────────────────────────────────────────────────┘
```

### A. Palet Resmi Ikon Lampiran & Aksi Chat (*Attachment & Action Palette*)
| Aksi / Tombol | Warna Latar Solid (Hex) | Ikon Material (White) | Deskripsi / Fungsi |
| :--- | :--- | :--- | :--- |
| **Kamera** | `#7C3AED` (Ungu) | `Icons.photo_camera_rounded` | Ambil foto / kamera langsung |
| **Galeri** | `#EC4899` (Pink/Magenta) | `Icons.photo_library_rounded` | Unggah gambar / media galeri |
| **Dokumen** | `#2563EB` (Biru) | `Icons.insert_drive_file_rounded` | Kirim berkas PDF / Word / Excel / ZIP |
| **Link Tugas** | `#D97706` (Oranye/Amber) | `Icons.assignment_rounded` | Kirim tautan tugas kelas |
| **Link Materi** | `#059669` (Hijau/Emerald)| `Icons.menu_book_rounded` | Kirim tautan materi belajar |
| **Link Quiz** | `#6366F1` (Indigo/Violet)| `Icons.extension_rounded` | Kirim tautan kuis / asesmen |
| **Tombol Kirim (Send)**| `#7C3AED` (Ungu Hubner) | `Icons.send_rounded` | Tombol kirim pesan / media |
| **Toggle Keyboard/Panel**| Outline `#E2E8F0` / `#27272A` | `Icons.keyboard_alt_rounded` (`#10B981`) | Tombol keyboard hijau tanpa background |

### B. Aturan Bebas Bayangan (*Zero-Shadow Rule*)
- **DILARANG** menambahkan `BoxShadow`, `elevation`, atau gradasi pada:
  1. Tombol Kirim / Send Button
  2. Tombol Ikon Drawer Lampiran (*Camera, Gallery, Document, Task, Material, Quiz*)
  3. Tombol HD Toggle & Tombol Batal/Close (X)
  4. Gelembung Pesan Chat (*Chat Bubble*)
  5. List Item Dokumen & File Manager Cards
- **Tampilan Bersih & Rapat**: Seluruh komponen tampil *flat modern*, ringan, cepat dirender, dan tidak memiliki efek blur bayangan yang memberatkan performa rendering GPU Android.

---

*Spesifikasi desain ini adalah acuan baku pembangunan visual seluruh fitur di Hubner Edu.*
