# CBT App — Panduan Proses Code Review

Dokumen ini mendefinisikan alur peninjauan kode (Code Review) dan kriteria kelulusan Pull Request (PR) dalam pengembangan **CBT App**. Hal ini bertujuan untuk menjaga kualitas kode, mencegah regresi, dan memastikan keamanan aturan Firestore.

---

## 1. Alur Kerja Git & Pull Request

1. **Pembuatan Cabang (Branching)**:
   * Setiap pekerjaan issue baru harus dibuat di cabang terpisah dari `main`.
   * Format nama cabang: `feat/issue-XX-nama-fitur` atau `fix/issue-XX-deskripsi-bug`.
2. **Pekerjaan Lokal & Verifikasi**:
   * Selesaikan tugas secara bertahap di cabang lokal.
   * Pastikan kode lulus analisis statis secara bersih (`flutter analyze`).
   * Jalankan automated tests (`flutter test`) untuk meminimalkan regresi.
3. **Pengajuan Pull Request (PR)**:
   * Setelah selesai, push cabang ke origin dan buat PR baru di GitHub dengan target branch `main`.
   * Deskripsikan perubahan yang dilakukan dan isi checklist pada template PR secara jujur.
4. **Proses Peninjauan (Review)**:
   * Setiap PR **wajib ditinjau dan disetujui** oleh partner (Deryl meninjau PR Bama, Bama meninjau PR Deryl).
   * **Dilarang keras melakukan merge sendiri (self-merge)** tanpa persetujuan peninjau.
   * Peninjau memeriksa kode berdasarkan kriteria kelulusan di bawah.
5. **Penggabungan (Merge)**:
   * Setelah mendapatkan persetujuan (`Approved`) dan build CI/lokal lulus, PR dapat digabungkan ke `main` menggunakan metode `Merge commit` atau `Squash and merge`.

---

## 2. Kriteria Kelulusan Pull Request (PR Criteria)

Peninjau harus memastikan kode yang diajukan memenuhi standar berikut sebelum memberikan persetujuan:

### A. Kepatuhan Arsitektur (BLoC/Cubit Pattern)
* Proyek ini memisahkan UI dan Logika Bisnis menggunakan pola BLoC/Cubit.
* UI (`lib/screens`) tidak boleh mengandung state lokal yang kompleks atau logika bisnis langsung. Gunakan `BlocBuilder`, `BlocListener`, atau `BlocConsumer` untuk mereaksikan perubahan state.
* Cubit/Bloc (`lib/blocs`) tidak boleh mengimpor paket UI seperti `dart:ui`, `package:flutter/material.dart`, atau objek context.

### B. Optimasi Database & Query Firestore
* Pengambilan data koleksi harus dioptimalkan. Hindari memicu pengambilan berulang dalam metode build.
* Setiap stream snapshot Firestore harus dibersihkan secara tepat melalui penutupan langganan (`StreamSubscription.cancel()`) di dalam method `dispose()`.
* Perubahan skema data harus divalidasi silang terhadap berkas `firestore.rules` untuk menghindari penolakan hak akses (`Permission Denied`) di sisi klien.

### C. Keamanan & Kebocoran Kredensial
* Tidak boleh ada hardcoded API keys, email, password, atau credential di dalam codebase.
* Data pengguna sensitif (seperti jawaban siswa atau hasil nilai mentah esai sebelum dinilai) tidak boleh dapat diakses oleh peran siswa.

### D. Performa UI & Pengalaman Pengguna (UX)
* Menggunakan widget konstanta (`const`) di mana pun memungkinkan untuk mengurangi overhead render ulang.
* Memastikan semua input form memiliki validator yang relevan dan menampilkan feedback error yang jelas.
* Penggunaan MD3 secara konsisten (menggunakan token warna dari `Theme.of(context).colorScheme`).
