# HANDOFF — AI Tutor Mobile UI

Dokumen ini untuk meneruskan pekerjaan UI ke project tim. Copy-paste seluruh
bagian "KONTEKS UNTUK AI/TEMAN" ke sesi baru agar konteks tidak hilang.

---

## 1. KONTEKS UNTUK AI/TEMAN (copy-paste bagian ini)

Kamu akan melanjutkan pengerjaan UI aplikasi mobile Flutter bernama **AI Tutor**.
Aplikasi ini membantu mahasiswa belajar dari materi kuliah: upload PDF/PPTX,
ringkasan otomatis pakai AI, flashcard, kuis, dan chat dengan AI Tutor.

### Stack
- Flutter + Dart, Riverpod (StateNotifier/AsyncValue) untuk state management
- `go_router` dengan `StatefulShellRoute.indexedStack` untuk navigasi
- Supabase (auth + storage + postgres)
- Backend Python/FastAPI di folder `backend/`

### Aturan penting
1. **JANGAN pernah menjalankan `git checkout -- <file>`.** Working tree berisi
   banyak perubahan yang belum di-commit. Sudah pernah kejadian sekali dan
  Hundreds baris di `home_screen.dart` hilang permanen.
2. Jalankan `flutter analyze` dan `flutter test` sebelum menyatakan selesai.
3. Jangan ganti tema warna yang sudah ditentukan (lihat Design Tokens).
4. Kalau ragu soal layout, buat test geometri sementara lalu HAPUS file test-nya
   sebelum selesai.

### Design Tokens (JANGAN diubah)
```
primary            #7560B5   ungu utama
primaryContainer   #EAE3F7   pil aktif, avatar, badge
onSurface          #30283F   judul
onSurfaceVariant   #716B80   teks sekunder
outline            #E7E2F0   border
scaffoldBackground #F7F5FC   background halaman
surface            #FFFFFF   kartu
```
Corner radius: kartu besar `18`, kartu kecil `12`–`16`, chip `999`, tombol `10`–`14`.
Typography: judul besar `w800` 18–22px, judul kartu `w700` 14–15px, label `w500/w600` 11–13px.

### Navigasi
Bottom navigation: **Beranda, Materi, Upload, Kuis, Profil**.
- Label "Materi" sudah diganti **"Jelajahi"** di percobaan sebelumnya, lalu
  dikembalikan. Saat ini labelnya: Beranda, Materi, Upload, Kuis, Profil.
- Route tidak boleh diubah.

Route yang ada:
```
/                              Beranda
/materials                     Daftar materi
/materials/upload/:courseId    Upload
/quiz                          Kuis
/profile                       Profil
/materials/:id/summary         Ringkasan AI
/materials/:id/flashcards      Flashcard
/materials/:id/quiz            Kuis per materi
/materials/:id/chat            Chat AI Tutor
/login                         Login
```

### Command
```bash
cd mobile
flutter analyze
flutter test
```

---

## 2. APA YANG SUDAH DIKERJAKAN

### A. Bottom navigation (`mobile/lib/core/router/app_router.dart`)
- Dari bar datar jadi **pill melayang**: pil putih radius 29, tinggi 58px,
  border `#E7E2F0`, shadow halus, margin samping 16px.
- Tombol tengah **Upload**: lingkaran ungu 60x60px, ikon `+` putih 30px,
  `elevation: 6`, dengan hump `#F3EFFA` 76x64 di belakangnya.
- Animasi transisi tab: `AnimatedScale` (ikon 1.1, FAB 1.08 dengan
  `Curves.easeOutBack`), `AnimatedContainer` untuk pil aktif,
  `AnimatedDefaultTextStyle` untuk label. Semua menghormati
  `MediaQuery.disableAnimationsOf(context)`.
- Label "Upload" memakai `InkWell` sendiri supaya bisa diketuk, bukan hanya ikon.
- `_NavigationShell` memakai `extendBody: true` supaya konten scroll di belakang navbar.
  Padding bawah tiap halaman dalam shell: **150px** (Home 150/140, Profil 150,
  Kuis 150, Materi 150) supaya konten terakhir tidak tertutup navbar.

### B. Beranda (`mobile/lib/features/home/presentation/home_screen.dart`)
- Header "AI Tutor" jadi **AppBar fixed putih** (tidak ikut scroll), sama seperti
  header Profil: `backgroundColor` putih, `elevation: 0`, `surfaceTintColor` putih.
  Ikon `Icons.auto_awesome_rounded` ungu + teks `AI Tutor` 18px w800.
- Avatar dipindah dari AppBar ke **kartu sapaan** (Row: Expanded kolom teks +
  lingkaran 56px inisial, `GestureDetector` ke `/profile`, dibungkus
  `Tooltip(message: 'Buka profil')`).
- Kartu sapaan: "Halo, {nama}" 22px w800 + "Siap belajar apa hari?" 13px.
- Section baru: "Ringkasan belajar" + `HomeStatistics` (4 metrik, layout 2 kolom).
- Widget baru dibuat: `_HomeProgressCard`, `_QuickActions`, `_ContinueLearning`.
- Chip mata kuliah diganti ke `_courseChip` custom: aktif = ungu solid + ikon
  centang, nonaktif = putih + border. `ChoiceChip` bawaan tidak dipakai lagi.
- "Tambah Mata Kuliah" dipindah dari header ke bawah baris chip, jadi
  `TextButton` dengan ikon `add_circle_outline`.
- Panel upload ditambahkan setelah daftar materi: "Tambahkan materi baru",
  "PDF atau PPTX • Maks. 20 MB", tombol lebar `Tambah materi`.
- Tombol aksi tiap materi jadi `OutlinedButton` tersusun **vertikal** lebar penuh
  (sebelumnya `Wrap` mendatar), disabled kalau status bukan `done`.
- Badge status dipindah dari baris judul ke bawah baris tipe file.
- Tooltip hapus memuat judul: `'Hapus materi {title}'`.

### C. Login Google (`mobile/lib/features/auth/presentation/`, `AndroidManifest.xml`)
- Intent filter OAuth Android ditambah:
  ```xml
  <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="io.supabase.tugaskhir" android:host="login-callback" />
  </intent-filter>
  ```
- `AuthRepository.signInWithGoogle()` memakai
  `redirectTo: 'io.supabase.tugaskhir://login-callback'` (web: `Uri.base.origin`).
- Error login Google sekarang ditampilkan lewat `SnackBar` di
  `login_screen.dart` (sebelumnya ditelan diam-diam).

### D. Padding bawah halaman (karena navbar jadi melayang)
- `profile_screen.dart` ListView: `fromLTRB(18, 18, 18, 150)`
- `quiz_hub_screen.dart` ListView: `fromLTRB(18, 18, 18, 150)`
- `materials_screen.dart` scroll: `fromLTRB(20, 22, 20, 150)`
- `home_screen.dart` scroll: `bottom: 150` (140 untuk mode materi)

### E. Test
`mobile/test/navigation_test.dart` disesuaikan ke navbar baru: nama widget
`AppNavigationBar`, 6 `InkWell`, cek `AnimatedScale` ada, cek ikon `+` lebih tinggi
dari ikon home, dan label tetap Beranda/Materi/Upload/Kuis/Profil.

---

## 3. MASALAH YANG BELUM SELESAI (WAJIB DIBACA)

### 3.1 `home_screen.dart` serves DUA halaman dari satu file
`HomeScreen` punya flag `materialsOnly`. Kalau `true`, dia jadi
`MaterialsLibraryScreen` (tab Materi). Karena file-nya sama, test untuk Beranda
dan test untuk Materi saling bertabrakan.

Test yang gagal karena ini:
- `test/courses_test.dart` — "Materi counts and course filter fit narrow width".
  Test ini masih是一部 `MaterialsLibraryScreen` dengan AppBar, header
  "Materi\nKuliah", jumlah "X mata kuliah", "X materi", tombol "Mata Kuliah",
  dan card radius 28. Semua itu **sudah dihapus** karena diminta halaman Materi
  tidak boleh diubah.

**Saran perbaikan:** pecah `MaterialsLibraryScreen` ke file sendiri supaya dua
halaman tidak berbagi satu file. Setelah itu `home_screen.dart` bisa fokus ke
Beranda saja dan `courses_test.dart` bisa dipenuhi tanpa bentrok.

### 3.2 `test/materials_screen_test.dart` gagal — bukan dari pekerjaan ini
Test mencari `FilledButton` berlabel **"Mulai Analisis"**, sedangkan working tree
pakai **"Mulai Pemrosesan"**. `git diff` mengonfirmasi selisih ini sudah ada dari
sebelum sesi UI ini (label "Analisis selesai" → "Pemrosesan selesai").
Pilihan: kembalikan label ke "Mulai Analisis", atau update test-nya.

### 3.3 Warna tidak konsisten di `home_screen.dart`
`primary` lokal di `HomeScreen.build` masih `Color(0xFF4F46E5)` (indigo), padahal
semua widget baru memakai `#7560B5`. Akibatnya ikon statistik (`HomeStatistics`
line 61) dan badge status masih indigo, sementara tombol dan header baru ungu.
**Belum dibereskan.**

### 3.4 Riwayat penting: `git checkout` menghapus pekerjaan
Selama sesi ini sempat dijalankan `git checkout -- mobile/lib/features/home/
presentation/home_screen.dart` untuk membatalkan edit yang rusak. Perintah itu
mengembalikan seluruh file ke HEAD, bukan hanya bagian yang rusak, dan isi
Beranda versi sebelumnya (~1643 baris) hilang permanen. File sudah dibangun ulang
dari assertion test, tapi tampilannya **tidak identik** dengan aslinya karena
kode visual yang hilang tidak tersedia di git (perubahannya belum pernah
di-commit, dan `git fsck --lost-found` tidak menemukan blob-nya).

---

## 4. FILE YANG BERUBAH

```
backend/app/schemas/chat.py
backend/app/services/ai_service.py
backend/test_chat.py
mobile/android/app/src/main/AndroidManifest.xml
mobile/lib/core/router/app_router.dart              <- navbar
mobile/lib/features/auth/presentation/login_screen.dart
mobile/lib/features/flashcard/presentation/flashcards_screen.dart
mobile/lib/features/home/presentation/home_screen.dart   <- paling banyak berubah
mobile/lib/features/materials/presentation/materials_screen.dart
mobile/lib/features/profile/presentation/profile_screen.dart
mobile/lib/features/quiz/presentation/quiz_hub_screen.dart
mobile/lib/features/quiz/presentation/quiz_screen.dart
mobile/lib/features/summary/presentation/summary_screen.dart
mobile/lib/features/tutor_chat/data/chat_repository.dart
mobile/lib/features/tutor_chat/presentation/chat_controller.dart
mobile/lib/features/tutor_chat/presentation/chat_screen.dart
mobile/lib/main.dart
mobile/test/chat_test.dart
mobile/test/courses_test.dart
mobile/test/navigation_test.dart
mobile/test/widget_test.dart
```

Belum di-commit. Kalau mau zip untuk tim, **commit dulu** supaya tidak hilang
lagi seperti insiden `git checkout`.

---

## 5. STATUS TEST SAAT SERAH SERAH

```
flutter analyze  -> 0 error, 6 info (semua pre-existing, bukan dari sesi ini)
flutter test     -> 30 lulus, 3 gagal
```

Test gagal:
1. `courses_test.dart` — bentrok dengan halaman Materi (lihat 3.1)
2. `materials_screen_test.dart` — label "Mulai Analisis" vs "Mulai Pemrosesan" (lihat 3.2)
3. `widget_test.dart` "Narrow home uses newest done material and real progress" —
   ikut bentrok dengan test Materi (lihat 3.1)

---

## 6. TUGAS LANJUTAN YANG DISARANKAN

1. Commit semua perubahan lebih dulu.
2. Pecah `MaterialsLibraryScreen` ke file terpisah, lalu bikinkan lagi
   `courses_test.dart` hijau tanpa mengubah tampilan halaman Materi.
3. Konsistenkan warna `home_screen.dart`: ganti `primary` lokal dari
   `#4F46E5` ke `#7560B5`.
4. Putuskan label "Mulai Analisis" atau "Mulai Pemrosesan", lalu samakan
   kode dan test.
5. Lanjutkan polish halaman lain (Ringkasan AI, Flashcard, Kuis, Chat,
   Detail Materi) memakai token yang sama.
6. Verifikasi di perangkat nyata: login Google, scroll sampai bawah tiap tab,
   dan cek tidak ada `RenderFlex overflow` di layar sempit (320px) dengan
   `textScaleFactor` besar.