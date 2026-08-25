# Spesifikasi Desain & Mockup Hubner Edu

Dokumen ini memuat spesifikasi tata letak, ukuran elemen, posisi, warna, dan token tipografi terpusat (`AppTypography`) untuk setiap layar aplikasi **Hubner Edu**.

---

## 1. Splash Screen (`splash_page.dart`)

Layar pembuka transisi awal saat aplikasi pertama kali dimuat.

```
+------------------------------------------+
|  ★ (star)                   ★ (star)     |
|         ☁ (cloud)                        |
|                                          |
|            +------------------+          |
|            |   (Icon Center)  |          |
|            |  school_rounded  |          |
|            +------------------+          |
|                                          |
|      ☁ (cloud)             ★ (star)      |
|                                          |
|          [ Hubner ] [ edu ]              |  <-- Alignment(0, 0.8)
+------------------------------------------+
```

### A. Background & Elemen Dekorasi
- **Latar Belakang**: Solid Brand Violet / Slate Dark
  - Light Mode: `const Color(0xFF7F52FC)` (Solid violet brand)
  - Dark Mode: `const Color(0xFF09090B)`
- **Awan Dekoratif (`Icons.cloud_rounded`)**:
  - Awan Kiri Atas: Ukuran `120px`, Warna `Colors.white` opacity `15%`, Posisi: `Top: statusBar + 20, Left: -20`
  - Awan Kanan Atas: Ukuran `140px`, Warna `Colors.white` opacity `18%`, Posisi: `Top: statusBar + 50, Right: -30`
  - Awan Kiri Bawah: Ukuran `100px`, Warna `Colors.white` opacity `12%`, Posisi: `Bottom: 120, Left: -20`
  - Awan Kanan Bawah: Ukuran `110px`, Warna `Colors.white` opacity `14%`, Posisi: `Bottom: 240, Right: -10`
- **Bintang Dekoratif (`Icons.star_rounded`)**:
  - Bintang 1 (Kiri Atas): Ukuran `18px`, Posisi `Top: statusBar + 80, Left: 60`, Opacity `60%`
  - Bintang 2 (Kanan Atas): Ukuran `24px`, Posisi `Top: statusBar + 140, Right: 80`, Opacity `80%`
  - Bintang 3 (Kiri Bawah): Ukuran `20px`, Posisi `Bottom: 180, Left: 50`, Opacity `50%`
  - Bintang 4 (Kanan Bawah): Ukuran `16px`, Posisi `Bottom: 300, Right: 60`, Opacity `60%`

### B. Logo Icon Tengah (Center Illustration)
- **Posisi**: Tengah layar (`Center`)
- **Animasi**: `FadeTransition` (Opacity 0.0 -> 1.0, Duration 800ms)
- **Container Lingkaran**:
  - Ukuran: Lebar `80px` x Tinggi `80px` (`logoFontSize * 2.5`)
  - Shape: `BoxShape.circle`
  - Background Color:
    - Light Mode: `Colors.white`
    - Dark Mode: `const Color(0xFF18181B)`
  - Border Stroke: `1.5px` solid (`Light: #E2E8F0`, `Dark: #27272A`)
  - Bayangan (*Shadow*): **None (Zero-Shadow)**
- **Ikon di Dalam Lingkaran**:
  - Ikon: `Icons.school_rounded`
  - Ukuran: `38.4px` (`logoFontSize * 1.2`)
  - Warna:
    - Light Mode: `const Color(0xFF7C3AED)`
    - Dark Mode: `const Color(0xFFA78BFA)`

### C. Branding Teks Logo Bawah (Bottom Brand)
- **Posisi**: `Align(alignment: Alignment(0, 0.8))` (Bagian bawah layar dengan jarak proporsional)
- **Animasi**: `SlideTransition` (geser dari bawah ke atas) & `FadeTransition`
- **Komponen Teks "Hubner"**:
  - Token Tipografi: `AppTypography.pageTitle(...)`
  - Font Family: **Plus Jakarta Sans**
  - Font Size: **`28.0px`** (`sizePageTitle`)
  - Font Weight: `FontWeight.normal` (400)
  - Letter Spacing: `-1.0px`
  - Warna: `Colors.white`
- **Jarak Antara Teks & Badge**: `8px` (`SizedBox(width: 8)`)
- **Badge Container "edu"**:
  - Padding: `Horizontal: 10px, Vertical: 4px`
  - Background Color:
    - Light Mode: `Colors.white`
    - Dark Mode: `const Color(0xFF7F52FC)`
  - Border Radius: `8px` (`BorderRadius.circular(8)`)
  - Bayangan (*Shadow*): **None (Zero-Shadow)**
- **Teks di Dalam Badge "edu"**:
  - Token Tipografi: `AppTypography.buttonLabel(...)`
  - Font Family: **Plus Jakarta Sans**
  - Font Size: **`18.0px`** (`sizeButtonAction`)
  - Font Weight: `FontWeight.bold` (700)
  - Warna:
    - Light Mode: `const Color(0xFF7C3AED)`
    - Dark Mode: `Colors.white`

---

## 2. Onboarding Screen (`onboarding_page.dart`)

Layar pengantar pengenalan fitur utama sebelum pengguna masuk ke alur autentikasi.

```
+------------------------------------------+
|  ☁ (cloud)                  ☁ (cloud)    |
|                                          |
|             [  GAMBAR ASSET  ]           |
|        'assets/images/onboarding.png'    |  <-- Illustration Header
|                                          |
|  ★ (star)                   ★ (star)     |
+------------------------------------------+
| +--------------------------------------+ |
| | Belajar & tumbuh bersama Hubner      | |  <-- Title (pageTitle, 28px/bold)
| |                                      | |
| | Kelola kelas, tugas sekolah, dan     | |  <-- Subtitle (chatBody, 20px)
| | kolaborasi belajar secara praktis... | |
| |                                      | |
| | +----------------------------------+ | |
| | |              Masuk               | | |  <-- Button (H: 54px, zero-shadow)
| | +----------------------------------+ | |
| +--------------------------------------+ |  <-- Bottom Sheet Container
+------------------------------------------+
```

### A. Header Visual / Hero Illustration
- **Latar Belakang Atas**: Solid Brand Violet / Slate Dark
  - Light Mode: `const Color(0xFF7F52FC)`
  - Dark Mode: `const Color(0xFF09090B)`
- **Awan Dekoratif (`Icons.cloud_rounded`)**:
  - Awan 1: Ukuran `120px`, Opacity `15%`, Posisi `Top: statusBar + 10, Left: -20`
  - Awan 2: Ukuran `150px`, Opacity `18%`, Posisi `Top: statusBar + 30, Right: -30`
  - Awan 3: Ukuran `80px`, Opacity `10%`, Posisi `Top: statusBar + 20, Left: 40% screenWidth`
  - Awan 4: Ukuran `90px`, Opacity `12%`, Posisi `Bottom: 40, Left: -10`
- **Bintang Dekoratif (`Icons.star_rounded`)**:
  - Bintang 1: Ukuran `16px`, Posisi `Top: statusBar + 40, Left: 60`, Opacity `60%`
  - Bintang 2: Ukuran `22px`, Posisi `Top: statusBar + 80, Right: 70`, Opacity `80%`
  - Bintang 3: Ukuran `18px`, Posisi `Bottom: 80, Left: 40`, Opacity `50%`
  - Bintang 4: Ukuran `14px`, Posisi `Bottom: 110, Right: 50`, Opacity `60%`
- **Karakter Ilustrasi Utama**:
  - Path Asset: `assets/images/onboarding.png`
  - Fit: `BoxFit.contain`
  - Padding: `Left: 28px, Top: statusBar + 20px, Right: 28px, Bottom: 40px`
  - Fallback Icon (Jika gambar gagal): `Icons.school_rounded` size `100px` opacity `20%`

### B. Bottom Sheet Card Container
- **Posisi**: Menempel di dasar layar (`Positioned(bottom: 0, left: 0, right: 0)`)
- **Padding Dalam**:
  - `Left: 28.0px, Top: 28.0px, Right: 28.0px, Bottom: 24.0px + safeAreaBottom`
- **Dekorasi Container**:
  - Background Color:
    - Light Mode: `Colors.white` (`#FFFFFF`)
    - Dark Mode: `const Color(0xFF18181B)`
  - Border Radius: Sudut melengkung hanya di bagian atas `BorderRadius.vertical(top: Radius.circular(32))`
  - Border Stroke: `1.0px` solid (`Light: #E2E8F0`, `Dark: #27272A`)
  - Bayangan (*Shadow*): **None (Zero-Shadow)**

### C. Tipografi Teks Onboarding
1. **Judul Utama (*Title*)**:
   - Teks: `"Belajar & tumbuh bersama Hubner"`
   - Token Tipografi: `AppTypography.pageTitle(...)`
   - Font Family: **Plus Jakarta Sans**
   - Font Size: **`28.0px`** (`sizePageTitle`)
   - Font Weight: `FontWeight.w900` (Black/Heavy)
   - Line Height: `1.2`
   - Warna:
     - Light Mode: `Colors.black` (`#000000`)
     - Dark Mode: `Colors.white` (`#FFFFFF`)

2. **Jarak Pemisah (Spacing 1)**: `14px` (`SizedBox(height: 14)`)

3. **Deskripsi Ringkas (*Subtitle*)**:
   - Teks: `"Kelola kelas, tugas sekolah, dan kolaborasi belajar secara praktis dan menyenangkan."`
   - Token Tipografi: `AppTypography.chatBody(...)`
   - Font Family: **DM Sans**
   - Font Size: **`20.0px`** (`sizeChatBody`)
   - Font Weight: `FontWeight.normal` (400)
   - Line Height: `1.5`
   - Warna:
     - Light Mode: `Colors.black87`
     - Dark Mode: `Colors.white70`

4. **Jarak Pemisah (Spacing 2)**: `28px` (`SizedBox(height: 28)`)

### D. Tombol Aksi Utama ("Masuk")
- **Container Tombol**:
  - Lebar: `double.infinity` (Lebar penuh kartu)
  - Tinggi: **`54px`**
  - Background Color: `const Color(0xFF7F52FC)` (Solid brand violet)
  - Border Radius: Kapsul membulat `28px` (`BorderRadius.circular(28)`)
  - Bayangan (*Shadow*): **None (Zero-Shadow)**
- **Button Widget (`ElevatedButton`)**:
  - Background Color: `Colors.transparent`
  - Shadow Color: `Colors.transparent`
  - Elevation: `0`
  - Shape: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))`
- **Teks Label Tombol**:
  - Teks: `"Masuk"`
  - Token Tipografi: `AppTypography.buttonLabel(...)`
  - Font Family: **Plus Jakarta Sans**
  - Font Size: **`18.0px`** (`sizeButtonAction`)
  - Font Weight: `FontWeight.bold` (700)
  - Warna: `Colors.white` (`#FFFFFF`)

---

## 3. Login Page (`login_page.dart`)

Layar autentikasi masuk akun pengguna (mendukung Email, ID User, dan Google Sign-In).

```
+------------------------------------------+
|  ( < ) [Circular Back Button]            |
|                                          |
|  Selamat datang kembali!                 |  <-- Welcome Title (buttonLabel, 18px bold)
|  Masuk untuk mengelola tugas Anda...     |  <-- Subtitle (timestamp, 15px)
|                                          |
|  Email / ID User                         |  <-- Label (buttonLabel, 18px bold)
|  [ ✉  Masukkan email atau ID User...  ]  |  <-- Field (H: 52px, Radius 24)
|                                          |
|  Kata Sandi                              |  <-- Label (buttonLabel, 18px bold)
|  [ 🔒  Masukkan kata sandi...       👁 ]  |  <-- Field (H: 52px, Radius 24)
|                                          |
|                     Lupa Kata Sandi?     |  <-- Link (timestamp, 15px w500)
|                                          |
|  +------------------------------------+  |
|  |               Masuk                |  |  <-- Button (H: 52px, Radius 30, #7F52FC)
|  +------------------------------------+  |
|                                          |
|  ----------- Atau lanjutkan dengan ------|  <-- Divider (1px #E2E8F0)
|                                          |
|  +------------------------------------+  |
|  |  [G]  Masuk dengan Google          |  |  <-- Google Button (H: 48px, Radius 24)
|  +------------------------------------+  |
|                                          |
|  Belum memiliki akun? Daftar Sekarang    |  <-- Register Link (buttonLabel, 18px)
+------------------------------------------+
```

### A. Layout Responsif
- **Mobile (`screenWidth <= 500`)**: SingleChildScrollView dengan padding `Horizontal: 28px, Vertical: 20px`.
- **Tablet / Desktop (`screenWidth > 500`)**: Split 2 Kolom (Kiri: Panel Ilustrasi Onboarding Brand, Kanan: Formulir Login).

### B. Tombol Kembali (*Circular Back Button*)
- **Ukuran**: Lebar `44px` x Tinggi `44px`
- **Shape**: `BoxShape.circle`
- **Background**: `Colors.white` (Light) / `#18181B` (Dark)
- **Border**: `1.0px` solid (`#E2E8F0` / `#27272A`)
- **Icon**: `Icons.chevron_left_rounded` (`24px`, `#000000` / `#FFFFFF`)
- **Shadow**: **None (Zero-Shadow)**

### C. Header Teks
- **Judul**: `"Selamat datang kembali!"` (Tablet) / `"Masuk"` (Mobile)
  - Token: `AppTypography.buttonLabel(...)`
  - Font Size: **`18.0px`** | Font Weight: `FontWeight.bold` (700)
  - Warna: `Colors.black` (Light) / `Colors.white` (Dark)
- **Subtitle**: `"Masuk untuk mengelola tugas Anda dengan mudah."`
  - Token: `AppTypography.timestamp(...)`
  - Font Size: **`15.0px`** | Font Weight: `FontWeight.normal` (400)
  - Warna: `Colors.black45` (Light) / `Colors.white60` (Dark)

### D. Formulir Input
1. **Field Email / ID User**:
   - Label: `"Email / ID User"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, bold, `Colors.black45` / `white70`)
   - Container: Tinggi `52px`, `BorderRadius.circular(24)`, Background `#FFFFFF` / `#18181B`
   - Border: `1.0px` solid (`#F1F5F9` / `#27272A`), Focused Border `1.0px` (`#000000` / `#FFFFFF`)
   - Prefix Icon: `Icons.alternate_email_rounded` (`20px`, `Colors.black38` / `white38`)
   - Hint: `"Masukkan email atau ID User Anda"` -> `AppTypography.subtitle(...)` (**`15.5px`**)
   - Teks Input: `AppTypography.timestamp(...)` (**`15.0px`**)

2. **Field Kata Sandi**:
   - Label: `"Kata Sandi"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, bold)
   - Prefix Icon: `Icons.lock_outline_rounded` (`20px`)
   - Suffix Icon: `Icons.visibility_outlined` / `Icons.visibility_off_outlined` (`20px`, interaktif)
   - Hint: `"Masukkan kata sandi Anda"` -> `AppTypography.subtitle(...)` (**`15.5px`**)

3. **Tautan "Lupa Kata Sandi?"**:
   - Posisi: Rata kanan (`Alignment.centerRight`)
   - Token: `AppTypography.timestamp(...)` -> Font Size: **`15.0px`**, `FontWeight.w500`
   - Warna: `const Color(0xFF6D28D9)` (Light) / `const Color(0xFFA78BFA)` (Dark)

### E. Tombol Aksi Login
- **Tombol Utama ("Masuk")**:
  - Container: Lebar `double.infinity`, Tinggi **`52px`**, Radius `30px` (`BorderRadius.circular(30)`)
  - Warna: `const Color(0xFF7F52FC)` (Solid brand violet), **Zero-Shadow**
  - Teks: `"Masuk"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `Colors.white`)
  - Loading State: `ThreeDotsLoader(size: 5, colors: [Colors.white, ...])`
- **Pemisah ("Atau lanjutkan dengan")**:
  - Garis divider horizontal `1.0px` (`#E2E8F0`) dengan teks tengah `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black38`)
- **Tombol Google Sign-In (`GoogleSignInButton`)**:
  - Ukuran: Lebar `double.infinity`, Tinggi **`48px`**, Radius `24px`
  - Border: `1.0px` solid (`#E2E8F0`), Background `Colors.white`, **Zero-Shadow**
  - Ikon Google: `20px` SVG
  - Teks: `"Masuk dengan Google"` -> `14.5px`, `FontWeight.w600`, `Colors.black87`

### F. Footer Ajakan Daftar
- Teks Pembuka: `"Belum memiliki akun? "` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `Colors.black54` / `white60`)
- Teks Tautan: `"Daftar Sekarang"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `Light: #6D28D9`, `Dark: #A78BFA`)

---

## 4. Register Page (`register_page.dart`)

Layar registrasi akun baru (mendukung pendaftaran Guru & Siswa, serta verifikasi instan akun Google).

```
+------------------------------------------+
|  ( < ) [Circular Back Button]            |
|                                          |
|  Buat Akun                               |  <-- Title (buttonLabel, 18px bold)
|  Daftar untuk mengelola tugas Anda...    |  <-- Subtitle (timestamp, 15px)
|                                          |
|  Nama Lengkap                            |  <-- Label (timestamp, 15px w500)
|  [ 👤  Masukkan nama lengkap Anda...  ]  |  <-- Field (H: 52px, Radius 24)
|                                          |
|  Alamat Email   [✓ Terverifikasi Google] |  <-- Google Verified Badge
|  [ ✉  Masukkan email Anda...          ]  |  <-- Field (H: 52px, Radius 24)
|                                          |
|  Kata Sandi                              |  <-- Field Password (Jika manual)
|  Konfirmasi Kata Sandi                   |  <-- Field Konfirmasi Password
|                                          |
|  Jenis Kelamin                           |  <-- Gender Selector
|  [  ♂ Laki-laki  ]   [  ♀ Perempuan  ]   |  <-- 2 Pills (H: 44px, Radius 20)
|                                          |
|  Peran / Role Pengguna                   |  <-- Role Selector
|  [  🎓 Guru  ]       [  🧑 Siswa  ]      |  <-- 2 Cards (H: 44px, Radius 20)
|                                          |
|  Tingkat Sekolah / Kelas Siswa           |  <-- Role-specific Dropdown
|  [  Jenjang SMA                    ▼  ]  |  <-- Dropdown (Radius 20, zero-shadow)
|                                          |
|  +------------------------------------+  |
|  |               Daftar               |  |  <-- Button (H: 52px, Radius 30, #7F52FC)
|  +------------------------------------+  |
|                                          |
|  Sudah memiliki akun? Masuk Sekarang     |  <-- Login Link (buttonLabel, 18px)
+------------------------------------------+
```

### A. Layout Responsif
- **Mobile (`screenWidth <= 500`)**: SingleChildScrollView dengan padding `Horizontal: 28px, Vertical: 20px`.
- **Tablet / Desktop (`screenWidth > 500`)**: Split 2 Kolom (Kiri: Hero Branding, Kanan: Form Pendaftaran).

### B. Header Teks
- **Judul**: `"Buat Akun"` / `"Daftar"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `Colors.black` / `Colors.white`)
- **Subtitle**: `"Daftar untuk mengelola tugas Anda dengan mudah."` -> `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black45` / `Colors.white60`)

### C. Formulir Data Diri
1. **Field Nama Lengkap**:
   - Label: `"Nama Lengkap"` -> `AppTypography.timestamp(...)` (**`15.0px`**, `FontWeight.w500`)
   - Field: Tinggi `52px`, `BorderRadius.circular(24)`, Prefix `Icons.person_outline_rounded` (`20px`)
   - Hint: `"Masukkan nama lengkap Anda"` -> `AppTypography.subtitle(...)` (**`15.5px`**)

2. **Field Alamat Email**:
   - Label: `"Alamat Email"` -> `AppTypography.timestamp(...)` (**`15.0px`**, `FontWeight.w500`)
   - **Badge Verifikasi Google** (Saat daftar via Google):
     - Container: Padding `Horizontal: 6px, Vertical: 2px`, Background `#DCFCE7`, Radius `20px`
     - Ikon: `Icons.verified_rounded` (`11px`, `#16A34A`)
     - Teks: `"Terverifikasi Google"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, `#16A34A`)
   - Field: ReadOnly jika Google Sign-In, Background abu-abu muda (`#F1F5F9` / `#27272A`)

3. **Field Password & Konfirmasi Password**:
   - Tampil jika registrasi manual (bukan Google).
   - Label: `"Kata Sandi"` & `"Konfirmasi Kata Sandi"` -> `AppTypography.timestamp(...)` (**`15.0px`**, `FontWeight.w500`)
   - Prefix: `Icons.lock_outline_rounded`, Suffix: Toggle Eye Visibility Icon.

4. **Selector Jenis Kelamin (Gender Pills)**:
   - 2 Tombol Berdampingan: Tinggi **`44px`**, Radius `20px` (`BorderRadius.circular(20)`)
   - **Status Aktif**: Background `#7F52FC` (Light/Dark) / `#000000`, Ikon putih, Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, Putih)
   - **Status Inaktif**: Background `#FFFFFF` / `#18181B`, Border `1.0px` (`#F1F5F9` / `#27272A`), Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, Abu-abu)

5. **Selector Peran Pengguna (Role: Guru vs Siswa)**:
   - 2 Tombol Berdampingan: Tinggi **`44px`**, Radius `20px`
   - Ikon: `Icons.school_rounded` (Guru), `Icons.person_rounded` (Siswa)
   - **Status Terpilih**: Background `#7F52FC`, Border `#7F52FC` `1.5px`, Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, Putih)
   - **Status Tidak Terpilih**: Background `#FFFFFF` / `#18181B`, Border `#7F52FC` `1.0px`, Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, Hitam / Putih)

6. **Pengaturan Khusus Sesuai Peran**:
   - **Jika Peran Guru**:
     - Label: `"Tingkat Sekolah"` -> `AppTypography.timestamp(...)` (**`15.0px`**, `FontWeight.w500`)
     - Dropdown: Pilihan `['SD', 'SMP', 'SMA', 'SMK']`, Container Radius `20px`, Border `1.0px` (`#F1F5F9`), `elevation: 0` (**Zero-Shadow**), Teks Item `AppTypography.dropdownItem(...)` (**`18.0px`**).
   - **Jika Peran Siswa**:
     - Label: `"Kelas Siswa"` -> Dropdown `Kelas 1` s/d `Kelas 12`.
     - Label: `"Jurusan / Peminatan"` (Jika SMA/SMK) -> Dropdown `['IPA', 'IPS', 'Bahasa', 'Umum', 'Kejuruan']`.

### D. Tombol Aksi Register
- **Tombol Utama ("Daftar")**:
  - Container: Lebar `double.infinity`, Tinggi **`52px`**, Radius `30px` (`BorderRadius.circular(30)`)
  - Warna: `const Color(0xFF7F52FC)`, **Zero-Shadow**
  - Teks: `"Daftar"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `Colors.white`)
- **Pemisah & Tombol Google**:
  - Garis divider horizontal `1.0px` + Tombol `GoogleSignInButton` (`48px`, Radius `24px`, **Zero-Shadow**).

### E. Footer Ajakan Masuk
- Teks Pembuka: `"Sudah memiliki akun? "` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `Colors.black54` / `white60`)
- Teks Tautan: `"Masuk Sekarang"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `Light: #6D28D9`, `Dark: #A78BFA`)

---

## 5. Home Page (`home_page.dart` & `main_navigation_page.dart`)

Layar beranda utama yang menyajikan ringkasan aktivitas belajar, statistik progres, dan daftar Classroom.

```
+------------------------------------------+
|  (☼) [Theme Toggle]      (🔔) [Notif]    |  <-- Top Controls Row (H: 42px)
|                                          |
|  Siswa · SMA/SMK                         |  <-- Role Subtitle (bodySubtitle, 15.5px)
|  Budi Pratama                            |  <-- User Name (pageTitle, 28px bold)
|                                          |
|  [ 🔍  Cari materi, elemen...   ] [ 📝 ] |  <-- Search Bar & Quick Notes
|                                          |
|  +------------------------------------+  |
|  |  [✓] Tugas               0/12      |  |  <-- Lavender Stat Card (H: 142px)
|  |  0% tercapai                       |  |
|  |  ================================  |  |
|  +------------------------------------+  |
|                                          |
|  Classroom Saya            ( ⚙ Kelola )  |  <-- Section Header (pageTitle, 28px)
|                                          |
|  +------------------+ +----------------+ |
|  | [Icon] Biologi   | | [Icon] Fisika  | |  <-- Classroom Grid Cards
|  | Kelas 11 IPA 1   | | Kelas 11 IPA 2 | |      (Radius 24, Zero-Shadow)
|  | 32 Siswa         | | 30 Siswa       | |
|  +------------------+ +----------------+ |
|                                          |
|  +------------------------------------+  |
|  | [🏠]   [💬]   [📚]   [📁]   [👤]   |  |  <-- Floating Bottom Nav (H: 68px)
|  +------------------------------------+  |
+------------------------------------------+
```

### A. Top Header & Profil Pengguna
- **Top Control Buttons (Tinggi: 42px x 42px, Bulat, Border 1.2px, Zero-Shadow)**:
  - **Pojok Kiri**: Toggle Dark/Light Mode (`Icons.wb_sunny_rounded` / `Icons.nightlight_round`, size `20px`).
  - **Pojok Kanan**: Tombol Notifikasi (`Icons.notifications_none_rounded`, size `20px`).
- **Informasi Peran & Nama**:
  - Subtitle Peran: `"Siswa · SMA/SMK"` / `"Pengajar · SMA/SMK"` -> `AppTypography.bodySubtitle(...)` (**`15.5px`**, `FontWeight.w500`).
  - Nama Pengguna: `"Budi Pratama"` -> `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`, `Height: 1.15`).
- **Avatar Profil Lingkaran (Tinggi: 58px x 58px)**:
  - Container bulat dengan `Transform.scale(1.45)` untuk framing ilustrasi avatar HD.
  - Fallback inisial 2 huruf jika foto belum ada (`FontWeight.w800`, size `20px`).

### B. Search Bar & Quick Notes Row
- **Kolom Pencarian (`_HomeSearchAndNotesRow`)**:
  - Tinggi: **`48px`**, Radius: `20px` (`BorderRadius.circular(20)`)
  - Background: Glassmorphic Transparan / `#18181B`
  - Border: `1.0px` solid (`#E2E8F0` / `#27272A`), **Zero-Shadow**
  - Prefix Icon: `Icons.search_rounded` (`20px`, `Colors.black45` / `white60`)
  - Hint: `"Cari elemen CP, materi, atau topik..."` -> `AppTypography.searchInput(...)` (**`18.0px`**)
- **Tombol Catatan Cepat (Quick Notes Button)**:
  - Ukuran: `48px x 48px`, Radius `20px`, Border `1.0px` solid
  - Ikon: `Icons.edit_note_rounded` (`22px`)

### C. Kartu Progres Belajar & Statistik (Student View)
1. **Kartu Progres Tugas (Lavender Card)**:
   - Tinggi: **`142px`**, Radius: `24px` (`BorderRadius.circular(24)`)
   - Background: Custom Lavender Pattern (`#F3E8FF` / `#581C87`)
   - Badge Judul: Ikon `assignment_turned_in_rounded` + Label `"Tugas"` (`14.7px`, bold)
   - Counter Tugas: Angka Selesai **`28.1px`** `w900` + Total `/$total` **`15.2px`** `w700`
   - Progress Bar: Linear progress bar (Tinggi `6px`, Radius `6px`, Warna `#7E22CE`)
2. **Kartu Quiz & Nilai (Gold Card)**:
   - Tinggi: **`142px`**, Radius: `24px`
   - Background: Gradient Gold/Kuning Soft (`#FEF3C7` -> `#FFFBEB`)
   - Fitur Interaktif: Flip rotasi halaman untuk melihat Skor Terakhir / Rata-rata Nilai.

### D. Section "Classroom Saya"
- **Header Bagian**:
  - Judul Bagian: `"Classroom Saya"` -> `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.w700`)
  - Tombol Kelola Kelas: Bouncy Circular Button `44px x 44px` (`Icons.dashboard_customize_rounded`) / Teks *"Selesai"* dengan centang ungu (`AppTypography.buttonLabel`).
- **Kartu Classroom (Classroom Grid Cards)**:
  - Radius: **`24px`** (`BorderRadius.circular(24)`)
  - Border: **`1.2px`** solid (`#E2E8F0` / `#27272A`), **Zero-Shadow**
  - Warna Kartu: Dinamis berdasarkan palette pastel terkurasi (`_classroomCardColors` / `_classroomCardDarkColors`)
  - Ikon Classroom: Container bulat `48px x 48px` dengan ilustrasi avatar/icon classroom HD.
  - Nama Classroom: `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.bold`)
  - Keterangan Tingkat/Pengajar: `AppTypography.bodySubtitle(...)` (**`15.5px`**)
  - Counter Anggota / Siswa: `AppTypography.microBadge(...)` (**`11.0px`**)

### E. Floating Bottom Navigation Bar (`main_navigation_page.dart`)
- **Container Navigasi Mengambang (*Floating Pill*)**:
  - Posisi: `Positioned(bottom: 16, left: 20, right: 20)`
  - Tinggi: **`68px`**
  - Radius: `32px` (`BorderRadius.circular(32)`)
  - Background: Glassmorphic White (`Colors.white.withOpacity(0.92)`) / Dark (`#18181B`)
  - Border: `1.0px` solid (`#E2E8F0` / `#27272A`), **Zero-Shadow**
- **5 Menu Navigasi Utama**:
  1. **Beranda**: `Icons.cottage_rounded`
  2. **Diskusi**: `Icons.chat_bubble_rounded` (Mendukung unread count badge)
  3. **Classroom**: `Icons.school_rounded`
  4. **Dokumen**: `Icons.folder_shared_rounded`
  5. **Profil**: `Icons.person_rounded`
- **Indikator Menu Aktif**:
  - Background Pill: `const Color(0xFF7F52FC)` (Solid brand violet)
  - Ikon Aktif: `Colors.white`, Ukuran `22px`
  - Ikon Inaktif: `Colors.black45` / `white45`, Ukuran `22px`
- **Label Menu**:
  - Token Tipografi: `AppTypography.microBadge(...)`
  - Font Size: **`11.0px`** (`sizeMicroBadge`)
  - Font Weight: `isClosest ? FontWeight.w800 : FontWeight.w500`

---

## 6. Pop-up & Sub-Menu Beranda

Modul dialog interaktif, dropdown overlay, dan peringatan di halaman Beranda.

```
+-------------------------------------------------------------+
|  [ Overlay Catatan Cepat ]      [ Notifikasi & Aktivitas ]  |
|  +---------------------------+  +-------------------------+ |
|  | Catatan Cepat   [+Tambah] |  | [Semua] [Kelas] [Tugas] | |
|  | ------------------------- |  | ----------------------- | |
|  | • Catatan Matematika      |  | 🎓 Classroom Fisika     | |
|  |   Hari ini, 10:30         |  |    100% selesai         | |
|  +---------------------------+  +-------------------------+ |
|                                                             |
|  [ Pop-up Peringatan Hapus Classroom & Cadangan Drive ]     |
|  +--------------------------------------------------------+ |
|  | (☁!) Peringatan Cadangan                               | |
|  | [!] Google Drive belum terhubung! Data TIDAK BISA...   | |
|  | [ Batal ]  [ Hubungkan Drive ]  [ Tetap Hapus ]        | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### A. Pop-up Overlay Catatan Cepat (`_showQuickNotesOverlay`)
- **Tipe Tampilan**: Floating Dropdown Overlay (`showDialog` transparan dengan anchor button)
- **Posisi Anchor**: Terbuka tepat di bawah tombol ikon catatan (`top: buttonTop + buttonHeight - 10`)
- **Lebar Dinamis (*Auto-fit Width*)**:
  - Judul Pendek (<= 10 karakter): **`240px`**
  - Judul Sedang (11 - 20 karakter): **`275px`**
  - Judul Panjang (> 20 karakter): **`315px`** (Batas maksimal)
- **Container Dropdown**:
  - Radius: **`20px`** (`BorderRadius.circular(20)`)
  - Background: `Colors.white` (Light) / `#18181B` (Dark)
  - Border: `1.2px` solid (`#E2E8F0` / `#27272A`), **Zero-Shadow**
  - Max Height: **`360px`** (Scrollable ListView)
- **Header Dropdown**:
  - Judul: `"Catatan Cepat"` -> `AppTypography.sectionHeader(...)` (**`18.0px`**, bold)
  - Tombol Action: Ikon `add_rounded` + Label `"Tambah"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `#2563EB` / `#38BDF8`)
- **Item Daftar Catatan**:
  - Judul Catatan: `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w600`)
  - Status Waktu Diperbarui: `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black45` / `white60`)
  - Empty State: Ilustrasi icon note + Teks *"Belum ada catatan. Klik Tambah untuk membuat baru."*

---

### B. Pop-up / Layar Notifikasi & Aktivitas (`notifications_page.dart`)
- **AppBar Header**:
  - Judul: `"Notifikasi & Aktivitas"` -> `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, bold)
  - Tombol Kembali: `Icons.arrow_back_ios_new_rounded` (`20px`)
  - Garis Pemisah Bawah: `1.0px` (`#F1F5F9`)
- **Filter Chips Bar**:
  - Pilihan Filter: `['Semua', 'Classroom Selesai', 'Tugas Selesai']`
  - Tinggi Chip: **`36px`**, Radius **`20px`**, Padding `Horizontal: 14px`
  - **Status Aktif**: Background `#7F52FC` (Solid brand violet), Teks Putih `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`)
  - **Status Inaktif**: Background `#F1F5F9` / `#27272A`, Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, `Colors.black54`)
- **Daftar Item Notifikasi**:
  - Ikon Kategori: Container bulat `38px x 38px`
    - Tipe Classroom: `Icons.school_rounded` warna biru `#2563EB` di atas `#EFF6FF`
    - Tipe Tugas: `Icons.assignment_turned_in_rounded` warna hijau `#16A34A` di atas `#DCFCE7`
  - Teks Deskripsi Aktivitas: `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w500`)
  - Keterangan Waktu (*Timestamp*): `AppTypography.timestamp(...)` (**`15.0px`**, format `HH:mm` untuk hari ini, `dd/MM HH:mm` untuk hari sebelumnya)

---

### C. Pop-up Peringatan Cadangan & Hapus Classroom (`_showDeleteClassroomDialog`)
- **Dialog Container (`AlertDialog`)**:
  - Radius: **`20px`** (`BorderRadius.circular(20)`), Background `Colors.white`, **Zero-Shadow**
  - Padding: `24px`
- **Header Dialog**:
  - Ikon: `Icons.cloud_off_rounded` (`24px`, `#EA580C` Oranye)
  - Judul: `"Peringatan Cadangan"` -> `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, `FontWeight.bold`, `Colors.black`)
- **Warning Alert Box Container**:
  - Padding: `12px`, Background `#FEF2F2`, Border `1.0px` solid `#FECACA`, Radius `12px`
  - Ikon: `Icons.warning_amber_rounded` (`20px`, `#DC2626` Merah)
  - Teks Peringatan: `"Google Drive belum terhubung! Data classroom '$title' TIDAK DAPAT DIPULIHKAN jika dihapus sekarang."` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, `#B91C1C`, Line Height `1.3`)
- **Deskripsi Pesan Cadangan**:
  - Teks: `"Hubungkan akun Google Drive untuk mencadangkan data secara otomatis sebelum menghapus, atau tetap hapus secara permanen."` -> `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black87`)
- **3 Tombol Aksi Dialog**:
  1. **Tombol "Batal"**:
     - Widget: `TextButton`, Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`, `Colors.black54`)
  2. **Tombol "Hubungkan Drive"**:
     - Widget: `OutlinedButton` (Border `1.0px` `#2563EB`, Radius `10px`)
     - Teks: `"Hubungkan Drive"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `#2563EB`)
  3. **Tombol "Tetap Hapus"**:
     - Widget: `ElevatedButton` (Background `#EF4444` Merah, Radius `10px`, Elevation `0`, **Zero-Shadow**)
     - Teks: `"Tetap Hapus"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `Colors.white`)

---

## 7. Halaman Detail Classroom (`class_page.dart` & `desktop_classroom_page.dart`)

Layar interaktif utama ruang kelas yang memuat menu slider cepat, timeline tahapan CP, materi, tugas, dan manajemen pembelajaran.

```
+--------------------------------------------------------------+
|  ( < ) [Back]      Fisika Terapan 11 IPA 1      ( 💬 ) ( ⚙ ) |  <-- Header App Bar
|                    Drs. Bambang · SMA                        |
|                                                              |
|  +----+  +----+  +----+  +----+  +----+                      |
|  | 📖 |  | 📅 |  | 👥 |  | 📊 |  | 📑 |                      |  <-- Horizontal Menu Slider
|  | CP |  |Jadw|  |Siswa| |Stat|  |Lapor|                      |      (5 Bouncy Cards)
|  +----+  +----+  +----+  +----+  +----+                      |
|                                                              |
|  [ Tahapan CP ]   [ Tugas & Quiz ]   [ Diskusi ]             |  <-- Main Tab Bar
|                                                              |
|  +--------------------------------------------------------+  |
|  |  ( 1 ) Elemen 1: Kinematika Gerak Lurus   [ Selesai ✅] |  |  <-- Stage Card
|  |  ----------------------------------------------------  |  |      (Radius 20, Zero-Shadow)
|  |  • 📄 Materi 1: Gerak Lurus Beraturan (GLB)            |  |
|  |  • 📝 Tugas 1: Analisis Kecepatan dan Percepatan       |  |
|  +--------------------------------------------------------+  |
+--------------------------------------------------------------+
```

### A. Top Header & Navigasi Kelas
- **Tombol Kembali (*Back Button*)**: Circular Button `44px x 44px`, Radius `22px`, Border `1.0px` (`#E2E8F0` / `#27272A`), **Zero-Shadow**.
- **Informasi Utama Header**:
  - Judul Classroom: `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`, `Colors.black` / `Colors.white`).
  - Subtitle Pengajar & Jenjang: `AppTypography.bodySubtitle(...)` (**`15.5px`**, `FontWeight.w500`).
- **Tombol Aksi Header Kanan**:
  - Tombol Chat Room Kelas: Container bulat `44px x 44px` (`Icons.chat_bubble_outline_rounded`).
  - Tombol Pengaturan Kelas / Edit: Container bulat `44px x 44px` (`Icons.settings_outlined`).

### B. Horizontal Action Slider (`_BouncyMenuSliderCard`)
Baris horizontal scrollable berisi 5 kartu aksi cepat dengan feedback animasi sentuh (*Bouncy Effect*):
1. **Capaian Pembelajaran (CP)**:
   - Icon: `Icons.auto_stories_rounded` (`20px`, `#7E22CE`)
   - Card Background: `#D6A5F8` (Pastel Ungu)
   - Teks: `"Capaian\nPembelajaran"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w700`, 2 Baris)
2. **Jadwal Pembelajaran**:
   - Icon: `Icons.calendar_month_rounded` (`20px`, `#1D4ED8`)
   - Card Background: `#9CC8FC` (Pastel Biru)
   - Teks: `"Jadwal\nPembelajaran"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w700`)
3. **Kelola Siswa**:
   - Icon: `Icons.people_alt_rounded` (`20px`, `#047857`)
   - Card Background: `#7DE3D0` (Pastel Hijau Mint)
   - Teks: `"Kelola\nSiswa"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w700`)
4. **Statistik Lengkap**:
   - Icon: `Icons.insights_rounded` (`20px`, `#C2410C`)
   - Card Background: `#F7BD84` (Pastel Oranye)
   - Teks: `"Statistik\nLengkap"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w700`)
5. **Laporan Hasil Belajar**:
   - Icon: `Icons.assignment_outlined` (`20px`, `#BE185D`)
   - Card Background: `#F794BE` (Pastel Pink)
   - Teks: `"Laporan Hasil\nBelajar"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w700`)

---

## 8. Pop-up & Panel Menu Slider Classroom

Spesifikasi modal bottom sheet, dialog, dan panel samping untuk setiap opsi pada menu slider Classroom.

```
+-------------------------------------------------------------+
|  [ Modal Statistik Lengkap Kelas ]                          |
|  +--------------------------------------------------------+ |
|  | (📊) Statistik Lengkap Kelas                           | |
|  |      Fisika Terapan 11 IPA 1                           | |
|  |  +--------------------+  +--------------------+        | |
|  |  | 👥 Total Siswa: 32 |  | 📑 Tahapan CP: 5   |        | |
|  |  +--------------------+  +--------------------+        | |
|  |  | 📖 Total Materi: 18|  | 📝 Total Tugas: 12 |        | |
|  |  +--------------------+  +--------------------+        | |
|  +--------------------------------------------------------+ |
|                                                             |
|  [ Pop-up Capaian Pembelajaran ]  [ Pop-up Atur Jadwal ]    |
|  +-----------------------------+  +-----------------------+ |
|  | 📖 Capaian Pembelajaran(CP) |  | 📅 Jadwal Pelajaran   | |
|  | [ Text Area CP...         ] |  | • Senin: 08:00 - 09:30| |
|  | [ Batal ]    [ Simpan CP ]  |  | [+ Tambah]   [Simpan] | |
|  +-----------------------------+  +-----------------------+ |
+-------------------------------------------------------------+
```

### A. Pop-up Modal Statistik Lengkap Kelas (`_showClassStatistics`)
- **Tipe Tampilan**: Modal Bottom Sheet (`showModalBottomSheet` dengan sudut atas melengkung)
- **Container**:
  - Padding: `Left: 20px, Top: 16px, Right: 20px, Bottom: 32px`
  - Radius: `BorderRadius.vertical(top: Radius.circular(28))`
  - Background: `Colors.white` (Light) / `#18181B` (Dark), **Zero-Shadow**
- **Header Statistik**:
  - Top Pill Handle: `40px x 4px`, Radius `2px`, Warna abu-abu transparan.
  - Ikon Bulat: Background `#F3E8FF`, Ikon `Icons.bar_chart_rounded` (`22px`, `#7E22CE`).
  - Judul: `"Statistik Lengkap Kelas"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w800`).
  - Subtitle Nama Kelas: `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black45` / `white54`).
- **Grid 4 Kartu Ringkasan Statistik (`_buildStatCard`)**:
  - Container: Radius **`18px`**, Padding `Horizontal: 14px, Vertical: 12px`, Border `1.0px` solid (`#E2E8F0` / `#3F3F46`).
  - **1. Total Siswa**: Ikon `people_alt_rounded`, Warna `#3B82F6` (Biru).
  - **2. Tahapan CP**: Ikon `layers_rounded`, Warna `#10B981` (Hijau).
  - **3. Total Materi**: Ikon `menu_book_rounded`, Warna `#F59E0B` (Kuning).
  - **4. Total Tugas**: Ikon `task_alt_rounded`, Warna `#EC4899` (Pink).
  - **Tipografi Angka & Label**:
    - Nilai Angka (*Value*): `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, `FontWeight.w800`).
    - Nama Metrik (*Label*): `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black54` / `white54`).

---

### B. Pop-up / Side Panel Capaian Pembelajaran (`_showCPDialog` / `_showEditCpInline`)
- **Container**: Radius **`24px`**, Background `Colors.white` / `#18181B`, **Zero-Shadow**.
- **Header**:
  - Ikon: `Icons.auto_stories_rounded` (`24px`, `#7C3AED` Ungu).
  - Judul: `"Capaian Pembelajaran (CP)"` -> `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, `FontWeight.bold`).
- **Area Input Teks CP**:
  - Container Input: Multi-line TextFormField (Min Lines: 5, Max Lines: 10).
  - Border: `1.0px` solid (`#E2E8F0` / `#27272A`), Radius `16px`, Background `#F8FAFC` / `#18181B`.
  - Teks CP: `AppTypography.chatBody(...)` (**`20.0px`**, `Line Height: 1.5`).
- **Tombol Aksi**:
  - Tombol *"Batal"* / *"Tutup"*: `TextButton`, `AppTypography.buttonLabel(...)` (**`18.0px`**).
  - Tombol *"Simpan CP"*: `ElevatedButton` (Warna `#7F52FC`, Radius `14px`, Elevation `0`), Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, bold putih).

---

### C. Pop-up / Side Panel Jadwal Pembelajaran (`_showTeachingScheduleDialog` / `_showEditJadwalInline`)
- **Container**: Radius **`24px`**, Background `Colors.white` / `#18181B`, **Zero-Shadow**.
- **Header**:
  - Ikon: `Icons.calendar_month_rounded` (`24px`, `#2563EB` Biru).
  - Judul: `"Jadwal Pembelajaran"` -> `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, `FontWeight.bold`).
- **Daftar Jadwal Per Hari**:
  - Container Item Hari: Radius `14px`, Border `1.0px` (`#E2E8F0`), Background `#F8FAFC`.
  - Dropdown Pilihan Hari (*Senin, Selasa, Rabu, Kamis, Jumat, Sabtu*): `AppTypography.dropdownItem(...)` (**`18.0px`**).
  - Time Picker Jam Mulai & Selesai: `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.bold`).
- **Tombol Aksi**:
  - Tombol *"Tambah Jadwal"*: `OutlinedButton` dengan ikon `add_rounded`, Teks `AppTypography.buttonLabel(...)` (**`18.0px`**).
  - Tombol *"Simpan Jadwal"*: `ElevatedButton` (Warna `#7F52FC`, Radius `14px`, Elevation `0`, **Zero-Shadow**).

---

### D. Pop-up Laporan Hasil Belajar (`_showLearningReport`)
- **Container Modal**: Radius **`28px`** (Sudut atas), Background `Colors.white` / `#18181B`, **Zero-Shadow**.
- **Header**:
  - Ikon: `Icons.description_rounded` (`22px`, `#E11D48` Merah Muda di atas `#FFE4E6`).
  - Judul: `"Laporan Hasil Belajar"` -> `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.w800`).
- **Daftar Kartu Elemen CP**:
  - Container: Radius `16px`, Border `1.0px` solid (`#E2E8F0` / `#3F3F46`), Margin bottom `8px`.
  - Nomor Indeks: Circle Avatar `28px x 28px` warna `#E0F2FE` dengan angka `AppTypography.buttonLabel` (**`18.0px`**, `#0369A1`).
  - Nama Elemen: `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`).
  - Counter Materi: `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black45`).
  - Badge Status:
    - Status *Selesai*: Background `#D1FAE5`, Teks `#047857` `AppTypography.buttonLabel` (**`18.0px`**, bold).
    - Status *Aktif / Proses*: Background `#DBEAFE`, Teks `#1D4ED8` `AppTypography.buttonLabel` (**`18.0px`**, bold).

---

## 9. Halaman Detail Capaian Pembelajaran (`detail_cp_page.dart`)

Layar pengelolaan mendalam per elemen CP, meliputi kurikulum materi, tugas penugasan, quiz evaluasi, serta mode edit langsung (*live auto-save*).

```
+--------------------------------------------------------------+
|  ( < ) [Back]      Elemen 1: Kinematika Gerak       [✏ Edit] |  <-- Header App Bar
|                    [ Status: Aktif  ▼ ]                      |
|                                                              |
|  +--------------------------------------------------------+  |
|  |  ( 01 )  Elemen 1: Kinematika Gerak Lurus              |  |  <-- CP Hero Header Card
|  |  Peserta didik mampu menganalisis besaran gerak...     |  |      (Pastel Theme, Zero-Shadow)
|  +--------------------------------------------------------+  |
|                                                              |
|  +--------------------------------------------------------+  |
|  |  📁 Materi 1: Gerak Lurus Beraturan (GLB)         ( ⌵ )|  |  <-- Materi Accordion Card
|  |  ----------------------------------------------------  |  |
|  |  • 📝 Tugas: Analisis Kecepatan dan Waktu              |  |
|  |  • ❓ Quiz: Latihan Soal GLB & GLBB                    |  |
|  |  • 📄 Dokumen: Modul_Fisika_GLB.pdf                    |  |
|  |                                                        |  |
|  |  [ + Tambah Aktivitas ]                                |  |  <-- Triggers Floating 3 Circles
|  +--------------------------------------------------------+  |
|                                                              |
|  [ + Tambah Materi Baru ]                                    |  <-- Add Materi Button
+--------------------------------------------------------------+
```

### A. Top AppBar & Header Kontrol
- **Tombol Kembali (*Back Button*)**: Circular Button `44px x 44px`, Radius `22px`, Border `1.0px`, **Zero-Shadow**.
- **Judul Elemen CP**: `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`).
- **Selector Status Elemen Dropdown**:
  - Container: Radius `20px`, Padding `Horizontal: 12px, Vertical: 6px`.
  - Pilihan Status: *Aktif* (`#DBEAFE` / `#1D4ED8`), *Selesai* (`#D1FAE5` / `#047857`), *Akan Datang* (`#FEF3C7` / `#B45309`).
  - Label Tipografi: `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`).
- **Tombol Toggle Mode Edit (`Icons.edit_rounded` / `Icons.check_rounded`)**:
  - Container bulat `42px x 42px`, Border `1.2px`.

### B. CP Hero Header Card
- **Warna Card**: Dinamis sesuai index elemen (`_classroomCardColors` / `_classroomCardDarkColors`), Radius **`28px`**, **Zero-Shadow**.
- **Watermark Angka Elemen**: Teks angka besar (`01`, `02`, dsb.) dengan opacity `25%`.
- **Judul Elemen**:
  - View Mode: `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`).
  - Edit Mode: TextFormField inline dengan auto-save debounce 600ms.
- **Deskripsi / Ringkasan CP**:
  - `AppTypography.chatBody(...)` (**`20.0px`**, `Line Height: 1.5`).

---

## 10. Mode Edit Elemen CP & Materi

Mode pengeditan langsung di tempat (*inline editing*) untuk mempermudah guru merombak susunan materi:
1. **Live Autosave**: Setiap ketikan pada judul elemen, deskripsi CP, atau judul materi otomatis tersimpan ke Firestore dengan delay *debounce 600ms*.
2. **Reordering & Deletion**:
   - Ikon Hapus Materi / Tugas: Ikon tong sampah merah lembut (`Icons.delete_outline_rounded`).
   - Dialog Konfirmasi Hapus: `AlertDialog` Radius `20px`, Tombol Batal & Hapus Permanen (`AppTypography.buttonLabel` **`18.0px`**).

---

## 11. Pop-up Pembuat Aktivitas (Tugas, Quiz, dan Materi)

```
+-------------------------------------------------------------+
|  [ Pop-up Pilihan Aktivitas Melayang (Elastic Bounce) ]     |
|                                                             |
|         (( 📝 ))              (( ❓ ))             (( 📖 ))  |
|          Tugas                 Quiz                Materi   |
|       Pastel Blue          Pastel Orange        Pastel Mint |
|       (86x86px)              (86x86px)           (86x86px)  |
|                                                             |
|  [ Pop-up Buat / Edit Tugas ]                               |
|  +--------------------------------------------------------+ |
|  | (📝) Buat Tugas Baru                                   | |
|  | Judul: [ Tugas_1                                     ] | |
|  | Tanggal: [ 25/08/2026 ]  s/d  [ 01/09/2026           ] | |
|  | Tipe: (•) Individu   ( ) Kelompok                      | |
|  | Mode: (•) Teks Instruksi   ( ) Upload PDF              | |
|  | [ Batal ]                             [ Simpan Tugas ] | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### A. Pop-up Pilihan Aktivitas Melayang (`_showAddTaskChoice`)
- **Animasi & Efek**: `CurvedAnimation` dengan `Curves.elasticOut`, Latar Belakang `BackdropFilter` Blur (`sigma: 8.0`).
- **3 Tombol Lingkaran Frameless (`_buildFramelessCircleItem`)**:
  - Ukuran: Diameter **`86px x 86px`**, `BoxShape.circle`, **Zero-Shadow**.
  1. **Tombol Tugas**:
     - Background: `#9CC8FC` (Pastel Blue) / `#2864A8` (Dark)
     - Ikon: `Icons.assignment_outlined` (`26px`, `#1E3A8A`)
     - Label: `"Tugas"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w800`)
  2. **Tombol Quiz**:
     - Background: `#F7BD84` (Pastel Orange) / `#C76D10` (Dark)
     - Ikon: `Icons.quiz_outlined` (`26px`, `#7C2D12`)
     - Label: `"Quiz"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w800`)
  3. **Tombol Materi**:
     - Background: `#7DE3D0` (Pastel Mint) / `#147D75` (Dark)
     - Ikon: `Icons.menu_book_rounded` (`26px`, `#064E3B`)
     - Label: `"Materi"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w800`)

---

### B. Pop-up Form Buat / Edit Tugas (`_showCreateTugasDialog` / `_openTaskDialog`)
- **Container Dialog**:
  - Lebar: Responsif (Maks **`640px`** di Tablet/Desktop, `94% screenWidth` di Mobile).
  - Max Height: `88% screenHeight`.
  - Radius: **`28px`** (`BorderRadius.circular(28)`), Background `Colors.white` / `#1C1C1E`, **Zero-Shadow**.
- **Header Dialog**:
  - Background: `#9CC8FC` (Pastel Blue) / `#2864A8` (Dark Blue).
  - Ikon Bulat: Lingkaran Putih `42px x 42px`, Ikon `Icons.assignment_rounded` (`22px`, `#000000`).
  - Judul: `"Buat Tugas Baru"` / `"Edit Tugas"` -> `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, `FontWeight.bold`, `Colors.black` / `Colors.white`).
- **Elemen Formulir Tugas**:
  1. **Judul Tugas**: Input text (Default: `"Tugas_1"`, `"Tugas_2"`, dsb.), `AppTypography.timestamp` (**`15.0px`**).
  2. **Tanggal Pengerjaan**: Rentang tanggal Mulai & Selesai (Format otomatis `dd/MM/yyyy`).
  3. **Tipe Penugasan**: Selector Pill *Individu* vs *Kelompok* -> `AppTypography.buttonLabel(...)` (**`18.0px`**).
  4. **Mode Soal Tugas**: Switcher *Teks Instruksi* vs *Lampiran Berkas PDF* -> `AppTypography.buttonLabel(...)` (**`18.0px`**).
- **Tombol Aksi**:
  - Tombol *"Batal"*: `TextButton`, `AppTypography.buttonLabel(...)` (**`18.0px`**).
  - Tombol *"Simpan Tugas"*: `ElevatedButton` (Warna `#7F52FC`, Radius `16px`, Elevation `0`), Teks `AppTypography.buttonLabel(...)` (**`18.0px`**, bold putih).

---

### C. Pop-up Form Buat / Edit Quiz (`_showCreateQuizDialog` / `_openQuizDialog`)
- **Container Dialog**: Radius **`28px`**, Header Pastel Orange `#F7BD84` / `#C76D10`, **Zero-Shadow**.
- **Header Dialog**:
  - Ikon Bulat Putih `42px x 42px`, Ikon `Icons.quiz_rounded` (`22px`).
  - Judul: `"Buat Quiz Baru"` / `"Edit Quiz"` -> `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, bold).
- **Elemen Formulir Quiz**:
  1. **Judul Quiz**: Input text field -> `AppTypography.timestamp` (**`15.0px`**).
  2. **Durasi Waktu Pengerjaan**: Input menit (Contoh: `30 Menit`) -> `AppTypography.cardTitle` (**`16.5px`**).
  3. **Daftar Butir Soal (Multiple Choice)**:
     - Pertanyaan: Multi-line TextFormField `AppTypography.chatBody` (**`20.0px`**).
     - Opsi Jawaban (A, B, C, D): Container `Radius: 14px`, Radio selector `AppTypography.checkboxLabel` (**`18.0px`**).
     - Kunci Jawaban Benar: Selector checklist hijau `#16A34A`.

---

### D. Pop-up Tambah Materi Baru (`_showAddMateriDialog`)
- **Container Dialog (`AlertDialog`)**:
  - Radius: **`20px`**, Background `Colors.white` / `#141416`, **Zero-Shadow**.
- **Header & Input**:
  - Judul: `"Tambah Materi Baru"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`).
  - Input: Hint `"Contoh: Materi 1: Pengenalan Konsep"` -> `AppTypography.timestamp` (**`15.0px`**).
- **Tombol Aksi**:
  - *"Batal"* (`TextButton`) + *"Tambah"* (`ElevatedButton` warna hitam/ungu, `AppTypography.buttonLabel` **`18.0px`**).

---

## 12. Halaman Laporan & Monitoring Pembelajaran (`laporan_page.dart` & `monitoring_page.dart`)

Layar analitik komprehensif bagi Guru dan Siswa untuk memantau progres ketuntasan materi, rekapitulasi nilai tugas & quiz, serta presensi kelas secara real-time.

```
+--------------------------------------------------------------+
|  Laporan & Monitoring                        [ 📊 Ekspor ]   |  <-- Page Title (28px bold)
|  Analisis progres tugas, quiz, dan presensi                  |  <-- Subtitle (15.5px)
|                                                              |
|  [ Classroom: Fisika 11 ▼ ] [ Elemen: CP 1 ▼ ] [ Semua (•) ] |  <-- Filter Bar (36px, Radius 20)
|                                                              |
|  +-------------------+  +-------------------+  +-----------+ |
|  | ⭐ Rata-rata Kelas |  | 📈 Ketuntasan     |  | 👥 Hadir  | |  <-- Hero Metrics Row
|  |     88.5 / 100    |  |     92% Selesai   |  |   31/32   | |
|  +-------------------+  +-------------------+  +-----------+ |
|                                                              |
|  Tabel Rekapitulasi Nilai & Aktivitas Siswa                  |
|  ==========================================================  |  <-- Track Scroll Indicator
|  | Nama Siswa        | Tugas 1 | Tugas 2 | Quiz 1 | Status  |
|  | ----------------- | ------- | ------- | ------ | ------- |
|  | Budi Pratama      |   90    |   85    |   95   | Tuntas  |
|  | Siti Rahma        |   95    |   90    |  100   | Tuntas  |
|  +---------------------------------------------------------+ |
+--------------------------------------------------------------+
```

### A. Top Header & Filter Bar
- **Judul Halaman**: `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`, `Colors.black` / `Colors.white`).
- **Subtitle Deskripsi**: `AppTypography.bodySubtitle(...)` (**`15.5px`**, `FontWeight.w500`).
- **Filter Dropdowns & Selector**:
  - Dropdown Kelas / Classroom: `AppTypography.dropdownItem(...)` (**`18.0px`**).
  - Dropdown Elemen CP & Materi: `AppTypography.dropdownItem(...)` (**`18.0px`**).
  - Filter Switcher (*Semua / Tugas / Quiz*): Tinggi **`36px`**, Radius **`20px`**, Teks `AppTypography.buttonLabel` (**`18.0px`**).

### B. Hero Metrics Stat Row
- **3 Kartu Metrik Ringkasan**:
  1. **Rata-rata Nilai Kelas**: Ikon Bintang `#F59E0B`, Angka Nilai **`28.0px`** `w900`, Subtitle `15.0px`.
  2. **Ketuntasan Kelas**: Ikon Grafik `#10B981`, Persentase **`28.0px`** `w900` + Mini progress bar.
  3. **Presensi Siswa**: Ikon People `#3B82F6`, Rasio Kehadiran **`28.0px`** `w900`.

### C. Tabel Rekapitulasi & Real-time Scroll Indicator
- **Indikator Scroll Horizontal (`_buildTableScrollIndicator`)**:
  - Tinggi: **`3.5px`**, Radius: `2px`, Margin `horizontal: 20px`.
  - Track Background: `#7C3AED` dengan opacity `14%` (Light) / `22%` (Dark).
  - Thumb Indicator: Solid Ungu `#7C3AED` dengan posisi dinamis sesuai offset scroll.
- **Tabel Nilai Siswa**:
  - Header Row: Background `#F8FAFC` / `#18181B`, Teks `AppTypography.buttonLabel` (**`18.0px`**, bold).
  - Nilai Tugas & Quiz: Teks `AppTypography.cardTitle` (**`16.5px`**, bold).
  - Badge Status Ketuntasan:
    - *Tuntas*: Background `#D1FAE5`, Teks `#047857` `AppTypography.buttonLabel` (**`18.0px`**).
    - *Belum Tuntas*: Background `#FEE2E2`, Teks `#DC2626` `AppTypography.buttonLabel` (**`18.0px`**).

---

## 13. Halaman Dokumen & In-App File Viewer

Modul penyimpanan berkas terpadu terintegrasi Google Drive dan penampil file interaktif langsung di dalam aplikasi.

```
+--------------------------------------------------------------+
|  Dokumen                                     [ + Buat Folder]|  <-- Page Title (28px)
|  Kelola & pratinjau berkas bersama           [ + Upload File]|  <-- Subtitle (12px)
|                                                              |
|  [ ☁ Hubungkan Google Drive untuk sinkronisasi otomatis > ]  |  <-- Cloud Drive Banner
|                                                              |
|  📁 Root > Fisika_11_IPA > Modul_Semester_1                  |  <-- Breadcrumbs (18px)
|                                                              |
|  +--------------------------------------------------------+  |
|  | [PDF] Modul_Kinematika_Gerak.pdf              ( ⋯ )    |  |  <-- Document Card
|  |       1.4 MB · Diunggah oleh Drs. Bambang · 25/08/2026 |  |      (Title: 18.5px bold)
|  +--------------------------------------------------------+  |
+--------------------------------------------------------------+
```

### A. Tab Dokumen (`main_navigation_page.dart` DocumentsTab)
- **Top Header Dokumen**:
  - Judul: `"Dokumen"` -> `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`).
  - Subtitle: `"Kelola & pratinjau berkas bersama"` -> `AppTypography.fileSize(...)` (**`12.0px`**).
- **Google Drive Banner (*Cloud Drive Sync*)**:
  - Container: Radius **`20px`**, Background `#F0FDF4` / `#18181B`, Border `1.0px` solid `#DCFCE7` / `#27272A`.
  - Ikon: `GoogleDriveLogoWidget(size: 24)` + Teks status koneksi akun Google.
- **Breadcrumbs Folder Navigation**:
  - Ikon Folder `#F59E0B` (`20px`) + Teks Breadcrumb `AppTypography.buttonLabel(...)` (**`18.0px`**, bold).
- **Tombol Aksi Dokumen**:
  - Tombol *"Buat Folder"*: `OutlinedButton` Border `1.2px` `#7F52FC`, Radius `16px`.
  - Tombol *"Upload Berkas"*: `ElevatedButton` `#7F52FC`, Radius `16px`, Elevation `0`, **Zero-Shadow**.
- **Kartu Daftar Berkas (*Document Card*)**:
  - Container: Radius **`20px`**, Border **`1.0px`** solid (`#E2E8F0` / `#27272A`), **Zero-Shadow**.
  - Ikon Berkas Berdasarkan Format (MIME):
    - *PDF*: `Icons.picture_as_pdf_rounded` (`#EF4444` Merah)
    - *Gambar*: `Icons.image_rounded` (`#8B5CF6` Ungu)
    - *Audio*: `Icons.audiotrack_rounded` (`#10B981` Hijau)
    - *Video*: `Icons.videocam_rounded` (`#DC2626` Merah Tua)
    - *Spreadsheet/Excel*: `Icons.table_chart_rounded` (`#059669` Emerald)
    - *Word/Doc*: `Icons.description_rounded` (`#2563EB` Biru)
    - *Folder*: `Icons.folder_rounded` (`#F59E0B` Kuning)
  - **Nama Berkas**:
    - Token Tipografi: `AppTypography.documentTitle(...)`
    - Font Family: **Plus Jakarta Sans**
    - Font Size: **`18.5px`** (`sizeDocumentTitle`)
    - Font Weight: `FontWeight.bold` (700)
  - **Keterangan Ukuran & Waktu Berkas**:
    - Token Tipografi: `AppTypography.fileSize(...)`
    - Font Size: **`12.0px`** (`sizeFileSize`)
    - Format Ukuran Otomatis: `KB`, `MB`, `GB` (Contoh: `2.4 MB · Diunggah oleh Budi · 14:20`).

---

### B. In-App File Viewer Dialog (`InAppFileViewerDialog`)
- **Container Modal Viewer**:
  - Dialog Window: Radius **`24px`**, Background `Colors.black87` (Gelap elegean untuk fokus baca), **Zero-Shadow**.
- **Header Viewer**:
  - Judul Berkas: `AppTypography.documentTitle(...)` (**`18.5px`**, `FontWeight.bold`, `Colors.white`).
  - Info Pengunggah: `AppTypography.fileSize(...)` (**`12.0px`**, `Colors.white70`).
  - Tombol Action: Tombol Download / Buka di Browser Google Drive + Tombol Tutup Silang.
- **Dukungan Format Pratinjau**:
  1. **Image Viewer**: Mendukung gesture zoom, pan, dan rotate.
  2. **PDF Viewer**: Penampil dokumen PDF tersemat dengan navigasi halaman.
  3. **Audio Player**: Custom widget pemutar audio (Tombol Play/Pause, slider linier durasi `00:00 / 03:45`, dan indikator loading).
  4. **Text / Code Viewer**: Kontainer teks dengan scroll lancar, `AppTypography.chatBody(...)` (**`20.0px`**).

---

## 14. Halaman Diskusi & Chat Room (`chat_room_page.dart` & Tab Diskusi)

Modul ruang obrolan real-time untuk diskusi materi antar Guru dan Siswa, penugasan kelompok, serta pesan personal.

```
+--------------------------------------------------------------+
|  ( < ) [Back]      Fisika 11 IPA 1 (Diskusi)       ( ℹ Info )|  <-- Chat Header (18.5px)
|                    32 Anggota Terdaftar                      |
|                                                              |
|  [Budi - Siswa]                                              |
|  +-------------------------------------+                     |
|  | Pak, untuk soal nomor 3 di tugas... | (10:15)             |  <-- Peer Bubble (White/Dark)
|  +-------------------------------------+                     |
|                                                              |
|                                            [Drs. Bambang]    |
|                     +--------------------------------------+ |
|             (10:17) | Silakan gunakan rumus GLBB dipercepat| |  <-- Teacher/My Bubble (#7F52FC)
|                     +--------------------------------------+ |
|                                                              |
|  +---------------------------------------------------------+ |
|  | [📎]  Ketik pesan diskusi...                     [ 🎤 ]  | |  <-- Bottom Input Bar (20px)
|  +---------------------------------------------------------+ |
+--------------------------------------------------------------+
```

### A. Tab Daftar Ruang Diskusi (`main_navigation_page.dart` DiscussionTab)
- **Top Header**:
  - Judul: `"Diskusi"` -> `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`).
  - Tombol *"Buat Ruang Diskusi"*: Modal pemilihan anggota kelas / teman + pengaturan hak akses admin.
- **Filter Switcher Bar**:
  - Filter: `['Semua', 'Classroom', 'Teman']` -> Tinggi **`36px`**, Radius **`20px`**, Teks `AppTypography.buttonLabel` (**`18.0px`**).
- **Item Kartu Ruang Diskusi**:
  - Avatar Grup: Stacked Circle Avatars (`28px x 28px`).
  - Nama Ruang: `AppTypography.cardTitle(...)` (**`16.5px`**, `FontWeight.bold`).
  - Snippet Pesan Terakhir: `AppTypography.timestamp(...)` (**`15.0px`**).
  - Unread Badge: Lingkaran ungu `#7F52FC` dengan angka counter `AppTypography.microBadge` (**`11.0px`**, putih).

---

### B. Halaman Ruang Obrolan (`chat_room_page.dart`)
- **AppBar Header**:
  - Tombol Kembali: Circular Button `44px x 44px`, Radius `22px`, **Zero-Shadow**.
  - Judul Room: `AppTypography.chatHeaderTitle(...)` (**`18.5px`**, `FontWeight.bold`).
  - Subtitle Anggota: `AppTypography.channelTag(...)` (**`13.0px`**).
  - Tombol Info Grup: `Icons.info_outline_rounded` (`22px`).
- **Chat Bubbles & Tipografi Pesan**:
  - **1. Bubble Pesan Pengguna / Guru (*My Message - Right Alignment*)**:
    - Background: `const Color(0xFF7F52FC)` (Solid brand violet), **Zero-Shadow**.
    - Radius: `20px` dengan sudut kanan bawah `4px` (`BorderRadius.only(...)`).
    - Teks Pesan: `AppTypography.chatBody(...)` (**`20.0px`**, `FontWeight.normal`, `Colors.white`, `Line Height: 1.4`).
    - Waktu Kirim (*Timestamp*): `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.white70`).
  - **2. Bubble Pesan Lawan Bicara / Teman (*Peer Message - Left Alignment*)**:
    - Background: `Colors.white` (Light) / `#18181B` (Dark).
    - Border: `1.0px` solid (`#E2E8F0` / `#27272A`), **Zero-Shadow**.
    - Radius: `20px` dengan sudut kiri bawah `4px`.
    - Teks Pesan: `AppTypography.chatBody(...)` (**`20.0px`**, `Colors.black87` / `Colors.white`).
    - Label Peran Guru: Badge `#DCFCE7` hijau dengan teks `AppTypography.microBadge` (**`11.0px`**, `#16A34A`).
- **Bottom Chat Input Bar**:
  - Container: Tinggi Dinamis (Max 5 Baris), Background `Colors.white` / `#18181B`, Border `1.0px` top stroke.
  - Tombol Lampiran (*Attachment Button*): Ikon `attach_file_rounded` (`22px`) -> Menu pilihan Gambar, Dokumen PDF, Audio, dan Google Drive.
  - Kolom Input Teks: TextFormField `AppTypography.chatBody(...)` (**`20.0px`**), Hint `"Ketik pesan diskusi..."`.
  - Tombol Voice Note / Kirim Pesan: Bouncy Circle Button `44px x 44px`, Warna `#7F52FC`, Ikon `send_rounded` putih, **Zero-Shadow**.

---

## 15. Halaman Profil & Pengaturan Akun (`main_navigation_page.dart` ProfileTab)

Layar pusat informasi identitas pengguna, pengelolaan avatar karakter, integrasi cloud drive, dan preferensi aplikasi.

```
+------------------------------------------+
|  Profil Pengguna                         |  <-- Page Title (28px bold)
|                                          |
|            (( 👤 ))                      |  <-- Avatar Character HD (84x84px)
|         [ 📷 Ganti ]                     |
|                                          |
|         Budi Pratama                     |  <-- User Name (pageTitle, 28px)
|      [ 🎓 Siswa · SMA ]                  |  <-- Role Badge (buttonLabel, 18px)
|      ID: USER-892147 [ 📋 ]              |  <-- User ID Copy Chip (15px)
|      budi.pratama@sekolah.sch.id         |  <-- Email (bodySubtitle, 15.5px)
|                                          |
|  PENGATURAN AKUN                         |  <-- Section Header (13px bold)
|  +------------------------------------+  |
|  | 👤  Edit Data Diri           ( > ) |  |  <-- Setting Tile Card (Radius 20)
|  | ☁   Google Drive        Terhubung  |  |      (buttonLabel, 18px)
|  +------------------------------------+  |
|                                          |
|  PREFERENSI APLIKASI                     |
|  +------------------------------------+  |
|  | 🌙  Tema Aplikasi           Terang |  |
|  | 🔔  Notifikasi Belajar       [ • ] |  |
|  +------------------------------------+  |
|                                          |
|  [ 🚪 Keluar dari Akun ]                 |  <-- Logout Button (Red #EF4444)
+------------------------------------------+
```

### A. Header Identitas Profil
- **Avatar Karakter Utama**:
  - Ukuran: Diameter **`84px x 84px`**, `BoxShape.circle`, Border `2.0px` `#7F52FC`.
  - Tombol Kamera (*Change Avatar*): Lingkaran kecil `28px` pojok bawah avatar untuk memilih koleksi avatar resmi Hubner (Kategori SD, SMP, SMA, dan Guru).
- **Nama Pengguna**:
  - `AppTypography.pageTitle(...)` (**`28.0px`**, `FontWeight.bold`, `Height: 1.15`).
- **Badge Peran Pengguna (*Role Badge*)**:
  - Container: Padding `Horizontal: 12px, Vertical: 4px`, Radius `20px`, Background `#F3E8FF` (Guru) / `#EFF6FF` (Siswa).
  - Teks: `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `#7E22CE` / `#1D4ED8`).
- **Chip Salin ID Pengguna (*User ID Copy Chip*)**:
  - Container: Padding `Horizontal: 10px, Vertical: 4px`, Radius `16px`, Background `#F1F5F9` / `#27272A`.
  - Ikon: `Icons.copy_rounded` (`14px`) + ID Text `AppTypography.timestamp(...)` (**`15.0px`**).
- **Email Pengguna**:
  - `AppTypography.bodySubtitle(...)` (**`15.5px`**, `Colors.black54` / `Colors.white60`).

---

### B. Grup Pengaturan Akun (*Settings Section Cards*)
- **Section Headers**:
  - Teks: `"PENGATURAN AKUN"`, `"PREFERENSI APLIKASI"`, `"TENTANG & BANTUAN"`.
  - Token Tipografi: `AppTypography.channelTag(...)` (**`13.0px`**, `FontWeight.bold`, `letterSpacing: 0.8`).
- **Setting Tile Card (`_buildSettingTile`)**:
  - Container: Radius **`20px`**, Background `#F8FAFC` / `#18181B`, Border `1.0px` solid (`#F1F5F9` / `#27272A`), **Zero-Shadow**.
  - Ikon Bulat Putih: Diameter `30px`, Ikon `18px`.
  - **Judul Menu**: `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.w600`).
  - **Trailing Info**: `AppTypography.timestamp(...)` (**`15.0px`**, `Colors.black45`) + Ikon `chevron_right_rounded`.
- **Daftar Menu Profil**:
  1. **Edit Data Diri**: Ubah nama, jenis kelamin, jenjang sekolah, dan kelas.
  2. **Google Drive Sync**: Hubungkan akun Google untuk penyimpanan otomatis tugas & dokumen.
  3. **Tema Tampilan (*Theme Mode*)**: Toggle Mode Terang (*Light*) vs Mode Gelap (*Dark*).
  4. **Notifikasi Belajar**: Pengingat deadline tugas, jadwal mengajar, dan mention diskusi.
  5. **Bahasa & Zona Waktu**: Pilihan bahasa dan zona waktu aktif (`Asia/Jakarta`).
  6. **Pusat Bantuan & FAQ**: Panduan penggunaan fitur Hubner Edu.
  7. **Tentang Aplikasi**: Versi rilis resmi aplikasi (`Hubner Edu v2.4.0`).

---

### C. Tombol Keluar & Dialog Konfirmasi (*Log Out*)
- **Tombol Keluar (*Logout Button*)**:
  - Container: Lebar `double.infinity`, Tinggi **`50px`**, Radius `16px`, Background `#FEF2F2` (Light) / `#27272A` (Dark).
  - Ikon: `Icons.logout_rounded` (`20px`, `#EF4444` Merah).
  - Teks: `"Keluar dari Akun"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, `FontWeight.bold`, `#EF4444`).
- **Dialog Konfirmasi Logout (`AlertDialog`)**:
  - Radius: **`20px`**, Background `Colors.white` / `#18181B`, **Zero-Shadow**.
  - Judul: `"Keluar dari Akun"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**, bold).
  - Pesan: `"Apakah Anda yakin ingin keluar dari akun ini?"` -> `AppTypography.buttonLabel(...)` (**`18.0px`**).
  - Tombol *"Batal"*: `TextButton`, `AppTypography.buttonLabel` (**`18.0px`**).
  - Tombol *"Keluar"*: `ElevatedButton` (Background `#EF4444` Merah, Radius `12px`, Elevation `0`, **Zero-Shadow**).

---

## 16. Ringkasan Master Token Tipografi Terkait (`app_typography.dart`)

| Nama Token | Font Family | Default Size (px) | Digunakan Pada |
| :--- | :--- | :---: | :--- |
| `AppTypography.pageTitle` | Plus Jakarta Sans | **28.0px** | Logo Hubner, Judul Onboarding, Nama User di Beranda & Profil, Judul Classroom, Judul Dokumen, Laporan & Diskusi |
| `AppTypography.documentTitle` | Plus Jakarta Sans | **18.5px** | Nama Berkas Dokumen di List Berkas & In-App File Viewer Dialog |
| `AppTypography.chatHeaderTitle` | Plus Jakarta Sans | **18.5px** | Header Notifikasi, Header Dialog CP & Jadwal, Header Chat Room, Nilai Statistik |
| `AppTypography.sectionHeader` | Plus Jakarta Sans | **18.0px** | Judul Header Dropdown Catatan Cepat, Header Tabel Laporan |
| `AppTypography.buttonLabel` | Plus Jakarta Sans | **18.0px** | Badge "edu", Tombol Aksi, Filter Chips, Menu Settings Tile Profil, Role Badge Profil, Status Tuntas/Belum Tuntas |
| `AppTypography.cardTitle` | Plus Jakarta Sans | **16.5px** | Judul Kartu Kelas, Menu Slider, Judul Ruang Diskusi di List Tab Diskusi, Nilai Tugas & Quiz di Tabel Laporan |
| `AppTypography.bodySubtitle` | DM Sans | **15.5px** | Subtitle Role User, Email di Profil, Subtitle Header Laporan, Nama Pengajar & Jenjang di Header Classroom |
| `AppTypography.searchInput` | DM Sans | **18.0px** | Kolom Input Pencarian Beranda & Search Bar Dokumen |
| `AppTypography.chatBody` | DM Sans | **20.0px** | Bubble Chat Pesan Diskusi (Guru & Siswa), Input Kolom Pesan Chat, Deskripsi Onboarding, Isi Teks CP |
| `AppTypography.timestamp` | DM Sans | **15.0px** | Waktu Chat Bubble, Subtitle Halaman, Waktu Notifikasi, ID User Copy di Profil, Trailing Menu Profil |
| `AppTypography.subtitle` | DM Sans | **15.5px** | Placeholder / Hint Text pada Form Input |
| `AppTypography.dropdownItem`| Plus Jakarta Sans | **18.0px** | Pilihan Opsi Dropdown Tingkat Sekolah, Kelas, Filter Kelas Laporan, Breadcrumb Folder |
| `AppTypography.checkboxLabel`| Plus Jakarta Sans | **18.0px** | Opsi Pilihan Ganda Soal Quiz & Checklist Hak Akses Anggota |
| `AppTypography.channelTag` | Plus Jakarta Sans | **13.0px** | Subtitle Anggota di Chat Room Header, Label Section Header Profil (Akun, Preferensi, Bantuan) |
| `AppTypography.fileSize` | DM Sans | **12.0px** | Ukuran Berkas Dokumen (KB/MB/GB), Keterangan Subtitle Dokumen |
| `AppTypography.microBadge` | Plus Jakarta Sans | **11.0px** | Label Menu Floating Bottom Nav, Badge Guru di Chat Bubble, Badge Counter Kelas & Unread Chat |

---
