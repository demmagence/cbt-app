## Deskripsi PR
<!-- Berikan ringkasan perubahan yang diajukan dan issue yang diselesaikan (contoh: Menyelesaikan #52). -->

## Tipe Perubahan
- [ ] Fitur baru (Fitur non-breaking)
- [ ] Perbaikan Bug (Perbaikan non-breaking)
- [ ] Perubahan Breaking (Perubahan yang menyebabkan fitur yang ada tidak berfungsi sebagaimana mestinya)
- [ ] Dokumentasi saja / Refaktor Kode

## Checklist Peninjauan Kode (Code Review Checklist)
*Harap centang semua checklist di bawah ini sebelum meminta review:*

### 1. Struktur & Standar Kode
- [ ] Kode mengikuti struktur proyek CBT App (`lib/blocs`, `lib/screens`, `lib/services`, `lib/models`, `lib/widgets`).
- [ ] Penamaan berkas, kelas, metode, dan variabel mengikuti pedoman Dart/Flutter (`camelCase`, `PascalCase`, `snake_case` untuk aset).
- [ ] Tidak ada kode mati (unused imports, variables, functions) atau print statement/debug log yang tidak diperlukan.

### 2. State Management (BLoC / Cubit Pattern)
- [ ] Cubit/Bloc hanya digunakan untuk mengelola logika state UI.
- [ ] State bersifat `immutable` (menggunakan `Equatable` atau properti final).
- [ ] Events dan States terdefinisi dengan jelas dan bersih.

### 3. Layanan & Optimasi Firestore
- [ ] Query Firestore dioptimalkan (membatasi pembacaan dokumen, tidak memicu query berulang yang tidak perlu).
- [ ] Aturan penulisan/pembacaan Firestore mematuhi `firestore.rules`.
- [ ] Integrasi stream Firestore dibersihkan (canceled/disposed) saat widget di-dispose untuk mencegah kebocoran memori.

### 4. Penanganan Error & Keamanan
- [ ] Menggunakan blok `try-catch` yang tepat untuk operasi asinkron/jaringan/database.
- [ ] Menampilkan pesan kesalahan ramah pengguna (user-friendly) melalui snackbar/UI state, bukan debug stack trace.
- [ ] Tidak ada data sensitif (API key, credential) yang disimpan secara hardcode di kode sumber.

### 5. Desain UI & Performa
- [ ] Antarmuka menggunakan elemen Material Design 3 (MD3) secara konsisten.
- [ ] UI bersifat responsif terhadap berbagai ukuran layar.
- [ ] Tidak ada rebuild yang tidak perlu (penggunaan `const` constructor dan optimasi `BlocBuilder`/`BlocSelector`).

### 6. Verifikasi & Pengujian
- [ ] Kode lulus analisis statis secara bersih (`flutter analyze` bebas error/warning).
- [ ] Automated tests berjalan sukses dan lulus (`flutter test`).
- [ ] Pengujian integrasi manual E2E telah dicoba pada emulator/perangkat riil.

---
## Kontributor
- **Pengaju**: @wibisanabama / @Derylfabiensyah
- **Peninjau**: @Derylfabiensyah / @wibisanabama
