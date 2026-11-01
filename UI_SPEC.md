# INSTRUKSI REFACTOR UI/UX FLUTTER — TEMA PINTEREST PLAYFUL & FLOATING PILL NAVBAR

Tolong perbarui tampilan UI Flutter di project ini agar mengikuti Design System dan arsitektur widget berikut secara presisi. JANGAN merusak business logic, fungsi state, atau routing yang sudah berjalan.

## 1. PALET WARNA & TEMA (WAJIB LIGHT THEME HANGAT)
Buat class `AppColors` / `AppTheme` dengan nilai Hex persis berikut:
- `surface` (Background Scaffold utama): `Color(0xFFFBF9F5)` (Warm Off-White / Cream)
- `surfaceSubtle` (Background elemen sekunder): `Color(0xFFF4EFE8)`
- `charcoal` (Elemen gelap utama / tombol hitam / card gelap): `Color(0xFF22252A)`
- `primary` (Indigo-Lavender utama): `Color(0xFF7C74EB)`
- `primaryDark`: `Color(0xFF5B50E6)`
- `lavenderCard` (Card ungu muda): `Color(0xFFB4B0F8)`
- `lavenderSoft` (Background stat card ungu): `Color(0xFFF2F1FE)`
- `lavenderBorder`: `Color(0xFFCBC8FA)`
- `peach` (Header Course & aksen oranye): `Color(0xFFFF9E67)`
- `peachSoft` (Background stat card oranye): `Color(0xFFFFF4EC)`
- `peachBorder`: `Color(0xFFF7C6A3)`
- `terracotta` (Batang grafik aktif): `Color(0xFFB85423)`
- `terracottaMuted` (Batang grafik biasa): `Color(0xFFDDA384)`
- `ink` (Teks utama): `Color(0xFF1E2024)`
- `inkSecondary` (Teks sekunder): `Color(0xFF5C5F66)`
- `inkMeta` (Teks kecil/metadata): `Color(0xFF8A8E99)`
- `borderLine`: `Color(0xFFE8E2D9)`

Gunakan font `Plus Jakarta Sans` (via `GoogleFonts.plusJakartaSansTextTheme()`) dengan ketebalan judul `FontWeight.w800` (ExtraBold).

---

## 2. FLOATING PILL BOTTOM NAVIGATION BAR (TANPA TEKS LABEL)
Jangan gunakan `BottomNavigationBar` kaku bawaan. Gunakan `Stack` pada Main Wrapper atau `extendBody: true` pada `Scaffold`, lalu tempatkan kapsul mengambang di bawah:
- **Margin luar**: `EdgeInsets.fromLTRB(20, 0, 20, 16)`
- **Dekorasi Kapsul**:
  - `color: Color(0xFFEFECE6).withOpacity(0.95)`
  - `borderRadius: BorderRadius.circular(999)`
  - `border: Border.all(color: Colors.white, width: 1.5)`
  - `boxShadow`: lembut (`blurRadius: 30, offset: Offset(0, 12), color: Colors.black12`)
- **Isi 5 Slot Ikon Saja (Tanpa Text Label)**:
  1. Index 0 (Beranda): Icon `home`
  2. Index 1 (Materi): Icon `book_open`
  3. Index 2 (Upload - Tombol Tengah Menonjol): Lingkaran ukuran `52x52`, `BoxDecoration` gradient `LinearGradient(colors: [Color(0xFF5B50E6), Color(0xFF8C84F7)])`, icon `Icons.add` putih ukuran 26, memiliki shadow ungu.
  4. Index 3 (Kuis): Icon `calendar_today` / `assignment_turned_in_outlined`
  5. Index 4 (Profil): Icon `person_outline`
- **State Aktif (Index 0, 1, 3, 4)**:
  - Jika tab aktif, bungkus icon dengan `AnimatedContainer` ukuran `width: 56, height: 48`, `decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: [...])`, warna icon `Color(0xFF22252A)`.
  - Jika tidak aktif, background transparan, warna icon `Color(0xFF22252A).withOpacity(0.55)`.
- Sembunyikan navbar ini saat berada di layar **Login** dan **Mengerjakan Kuis**.

---

## 3. KOMPONEN KHUSUS PER LAYAR

### A. LAYAR BERANDA (HOME SCREEN)
Susun dengan `SingleChildScrollView` (padding horizontal `20px`, bottom padding `110px` agar tidak tertutup floating navbar) dengan urutan vertikal:
1. **Header Sapaan**:
   - Kiri: Avatar bulat `52x52` berlatar ungu muda `Color(0xFFD8D4F8)` + kolom teks `"Halo, Nadia"` (22px ExtraBold) dan subteks icon petir ungu `"Streak: 5 hari beruntun • Siap belajar hari ini?"`.
   - Kanan: Tombol lonceng notifikasi bulat `48x48` putih dengan border tipis dan titik merah (`#FF6B57`) di kanan atas.
2. **Grid Statistik 2x2 (Gaya Cutout Pojok Kiri Atas)**:
   - Buat custom widget `CutoutStatCard`:
     - `Container` dengan `borderRadius: BorderRadius.circular(26)`, border tebal `2px` (`#F7C6A3` untuk tema Peach, `#CBC8FA` untuk tema Lavender), background (`#FFF4EC` untuk Peach, `#F2F1FE` untuk Lavender).
     - Gunakan `Stack`: Di pojok kiri atas (`Positioned(top: 0, left: 0)`), pasang `Container` ukuran `48x40` dengan `borderRadius: BorderRadius.only(topLeft: Radius.circular(24), bottomRight: Radius.circular(20))` warna solid (`#FFAE78` atau `#A5A0F6`) berisi icon kecil warna hitam.
     - Di bagian tengah bawah, tampilkan label kecil (12px bold) dan angka besar (`28px–30px` ExtraBold): `24 Materi`, `128 Flashcard`, `82/100 Rata-rata kuis`, `68% Target mingguan`.
3. **Hero Card "Lanjutkan Belajar"**:
   - `Container` `borderRadius: BorderRadius.circular(30)`, warna `Color(0xFF8E87F0)` (ungu).
   - Gunakan `Stack`: Di sisi kiri (lebar 68%) tampilkan pill `"Basis Data"` (`Colors.white24`), judul `"Normalisasi Database"` (22px ExtraBold putih), teks `"Progres belajar: 65% selesai"`, `LinearProgressIndicator` warna kuning-oranye `Color(0xFFFFAE42)`, dan tombol bulat hitam `48x48` berisi panah kanan putih + teks `"Lanjutkan belajar"`.
   - Di kanan bawah (`Positioned(right: -8, bottom: -8)`), tampilkan ilustrasi ikon Piala (Trophy) besar warna kuning-emas miring `-14 derajat`.
4. **Card "Target Belajar Minggu Ini" (Gaya Grafik Kapsul Terracotta)**:
   - `Container` `borderRadius: BorderRadius.circular(30)`, warna `Color(0xFFFBEAE0)`, border `2px` `Color(0xFFF4CEB8)`.
   - Atas: Lingkaran hitam `40x40` berisi icon chart + judul `"Target belajar"` + pill toggle `"Mingguan | 5 jam"`.
   - Tengah: Dua metrik bersebelahan dipisah garis vertikal (`"3j 24m tercapai dari 5 jam"` dan `"68% • hari Rab: 1 jam"`).
   - Grafik Batang (Sen–Min): `Row` berisi 7 kolom batang kapsul vertikal (`borderRadius: BorderRadius.circular(999)`). Batang hari yang aktif berwarna `Color(0xFFB85423)` (Terracotta gelap) dan di bagian atas dalam kapsul terdapat lingkaran kecil menampilkan angka menit (`45`, `30`, `60`, dst).
5. **Aksi Cepat (3 Kolom)**:
   - `Row` berisi 3 kartu membulat (`radius 22px`): `Ringkasan AI` (putih), `Latihan flashcard` (putih), dan `Tanya AI Tutor` (hitam `#22252A` dengan teks putih).
6. **Materi Terbaru**:
   - Daftar kartu putih (`radius 24px`) untuk `Normalisasi Database.pdf` (badge hijau Siap, progress bar ungu 65%) dan `Transaksi dan Konkurensi.pptx` (badge amber 42%).

### B. LAYAR COURSE & MATERI (GAYA "MY COURSES" PINTEREST)
1. **Header Oranye Melengkung**:
   - Bagian atas memakai `Container` warna Peach `Color(0xFFFF9E67)` dengan padding bawah ekstra.
   - Tampilkan tombol back bulat transparan, tombol `"Tambah course"` kapsul hitam di kanan atas, judul besar `"Course &\nMateri"` (28px ExtraBold hitam), ilustrasi Topi Toga di kanan, dan 2 kapsul ringkasan di bawahnya: Kapsul Hitam (`"3 Course"`) & Kapsul Oranye Muda (`"24 Materi"`).
2. **Body Sheet Melengkung**:
   - Di bawah header oranye, gunakan `Transform.translate(offset: Offset(0, -20))` pada `Container` dengan `decoration: BoxDecoration(color: Color(0xFFFBF9F5), borderRadius: BorderRadius.vertical(top: Radius.circular(32)))`.
3. **Course Pills & Search**:
   - Horizontal list pill course (`Basis Data`, `Algoritma`, `Jaringan Komputer`), search bar berbentuk kapsul penuh (`radius 999`), dan filter status (`Semua`, `Siap`, `Diproses`, `Gagal`).
4. **Kartu Materi Bergantian (Charcoal & Lavender)**:
   - Kartu materi genap memakai background Hitam Charcoal `Color(0xFF22252A)` (teks putih), kartu ganjil memakai background Ungu Muda `Color(0xFFB4B0F8)` (teks hitam), `borderRadius: BorderRadius.circular(28)`.
   - Di pojok kanan bawah setiap kartu materi, pasang tombol bulat putih `48x48` dengan border hitam `2px` berisi icon panah kanan `Icons.arrow_forward`.

### C. LAYAR LAINNYA (UPLOAD, DETAIL MATERI, RINGKASAN, FLASHCARD, KUIS, CHAT AI, PROFIL)
- Pertahankan seluruh fitur dan state, tetapi sesuaikan semua permukaan kartu menggunakan `borderRadius: BorderRadius.circular(24)`, tombol utama berbentuk kapsul penuh (`StadiumBorder` / `Radius.circular(999)`) dengan warna `Color(0xFF22252A)` atau `Color(0xFF7C74EB)`, dan background layar `Color(0xFFFBF9F5)`.