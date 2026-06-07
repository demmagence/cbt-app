# CBT App — Computer Based Test Application with Anti-Cheat

Aplikasi Computer Based Test (CBT) berbasis Flutter dan Firebase yang modern, aman, dan dirancang khusus untuk menyelenggarakan ujian sekolah/institusi dengan integritas tinggi. Dilengkapi dengan deteksi kecurangan tingkat lanjut, pengerjaan offline-resilient, serta dashboard manajemen untuk Admin, Guru, dan Siswa.

---

## 🚀 Fitur Utama

### 1. 🛡️ Sistem Anti-Cheat (Integritas Ujian)
*   **Fullscreen Immersive Sticky Mode**: Mengunci antarmuka aplikasi dalam mode layar penuh. Mencegah siswa membuka panel notifikasi atau bar navigasi sistem secara tidak sengaja.
*   **Pencegahan Tangkapan Layar & Rekaman**: Mengintegrasikan flag keamanan native (`FLAG_SECURE`) untuk memblokir tangkapan layar (screenshot) dan membuat rekaman layar menjadi hitam.
*   **Deteksi Perpindahan Aplikasi (App Switch Detection)**: Mencatat frekuensi dan durasi (dalam detik) setiap kali siswa meninggalkan layar ujian (misalnya menerima panggilan, membuka aplikasi lain). Pelanggaran dicatat langsung di database untuk evaluasi guru.
*   **Offline Connection Banner**: Menampilkan status koneksi internet siswa secara real-time dan menjamin jawaban tersimpan dengan aman di database lokal saat offline.

### 2. 👥 Manajemen Akses & Pengguna (Multi-Role)
*   **Administrator**:
    *   Dashboard analitik data statistik sistem.
    *   Manajemen akun Guru & Siswa (CRUD, aktivasi/deaktivasi akun).
*   **Guru (Pendidik)**:
    *   Manajemen bank soal global dan pembuatan kuis/ujian.
    *   Pengacakan otomatis butir soal & opsi pilihan ganda per siswa.
    *   **Monitoring Real-time**: Memantau pengerjaan siswa yang sedang berlangsung secara langsung (melihat status pengerjaan & jumlah pelanggaran keluar aplikasi).
    *   Penilaian manual soal essay beserta umpan balik tertulis.
    *   Ekspor nilai ujian ke format CSV dan native sharing.
*   **Siswa (Peserta Ujian)**:
    *   Bergabung ke ujian menggunakan token kode unik 6-karakter yang dijadwalkan secara presisi.
    *   Lembar pengerjaan interaktif yang menyimpan jawaban secara otomatis (auto-save).
    *   Riwayat pengerjaan ujian dan evaluasi nilai (setelah diperiksa Guru).

---

## 🛠️ Stack Teknologi

*   **Framework**: [Flutter](https://flutter.dev) (iOS & Android)
*   **Bahasa Pemrograman**: [Dart](https://dart.dev)
*   **State Management**: [Flutter BLoC & Cubit](https://pub.dev/packages/flutter_bloc)
*   **Database & Backend**:
    *   [Firebase Authentication](https://firebase.google.com/docs/auth) (Manajemen Sesi Akun)
    *   [Cloud Firestore](https://firebase.google.com/docs/firestore) (Penyimpanan Data Real-time dengan Multi-Database `cbt-db`)
*   **Dependensi Kunci**:
    *   `equatable` (Perbandingan nilai objek state)
    *   `share_plus` & `csv` (Ekspor rekapitulasi nilai)
    *   `intl` (Format tanggal & waktu lokalisasi)
    *   `mocktail` & `integration_test` (Kerangka pengujian otomatis)

---

## 📁 Struktur Direktori Proyek

```text
cbt_app/
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md  # Template kontribusi PR developer
├── docs/                         # Dokumentasi teknis mendalam
│   ├── api-services.md           # Detail lapisan Service & API
│   ├── architecture.md           # Struktur BLoC/Cubit & Alur Data
│   ├── bug-fixing-report.md      # Laporan pemindaian bug E2E
│   ├── code-review.md            # Panduan peninjauan kode tim
│   ├── firestore-rules-audit.md  # Laporan audit aturan keamanan
│   └── integration-testing.md    # Panduan pengujian integrasi manual
├── integration_test/             # Skrip automated E2E integration test
│   └── app_test.dart
├── lib/
│   ├── blocs/                    # Logika Bisnis & Pengatur Status (BLoC/Cubit)
│   │   ├── admin/
│   │   ├── auth/
│   │   ├── guru/
│   │   └── siswa/
│   ├── config/                   # Konfigurasi Tema (MD3) & Rute Navigasi
│   ├── models/                   # Definisi Model Data & Serialisasi JSON
│   ├── screens/                  # Antarmuka Pengguna (UI Screens)
│   ├── services/                 # Abstraksi Layanan & API SDK
│   ├── widgets/                  # Komponen UI Reusable
│   ├── app.dart                  # Titik masuk utama MaterialApp & DI
│   └── main.dart                 # Inisialisasi awal Flutter & Firebase
├── test/                         # Unit & Widget Testing
│   └── app_widget_test.dart
├── firestore.rules               # Aturan keamanan Cloud Firestore
└── pubspec.yaml                  # Konfigurasi proyek & dependensi Dart
```

---

## ⚙️ Cara Memulai (Getting Started)

### Prasyarat
1. Pastikan Anda telah menginstal [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi `>=3.0.0`).
2. Instal [Firebase CLI](https://firebase.google.com/docs/cli) dan masuk ke akun Firebase Anda.

### Langkah Instalasi

1.  **Kloning Repositori**:
    ```bash
    git clone https://github.com/demmagence/cbt-app.git
    cd cbt-app
    ```

2.  **Ambil Dependensi Proyek**:
    ```bash
    flutter pub get
    ```

3.  **Setup Firebase**:
    *   Hubungkan proyek dengan Firebase Console Anda menggunakan FlutterFire CLI:
        ```bash
        flutterfire configure
        ```
    *   Pastikan Anda mengaktifkan **Firebase Authentication** (metode Email/Sandi) dan **Cloud Firestore**.
    *   *Catatan*: Aplikasi dikonfigurasi menggunakan database ID non-default yaitu `cbt-db` pada Firestore. Pastikan Anda membuat database dengan ID `cbt-db` di konsol Firebase Anda sebelum menjalankan aplikasi.

4.  **Terapkan Aturan Keamanan Firestore**:
    Terapkan berkas `firestore.rules` ke Firebase Console Anda:
    ```bash
    firebase deploy --only firestore:rules
    ```

5.  **Jalankan Aplikasi**:
    Hubungkan perangkat fisik Android/iOS atau emulator, kemudian jalankan:
    ```bash
    flutter run
    ```

---

## 🧪 Pengujian & Kualitas Kode

Aplikasi ini menerapkan standar kualitas kode yang ketat untuk memastikan stabilitas sistem.

*   **Analisis Statis (Linter)**:
    Pastikan kode Anda bebas dari warning/error analisis sebelum mengajukan PR:
    ```bash
    flutter analyze
    ```

*   **Unit & Widget Testing**:
    Jalankan seluruh pengujian widget dan unit menggunakan perintah:
    ```bash
    flutter test
    ```

*   **Integration Testing (E2E)**:
    Jalankan pengujian skenario ujung-ke-ujung (End-to-End) otomatis:
    ```bash
    flutter test integration_test/app_test.dart
    ```

---

## 🤝 Kontribusi & Code Review

Kami menggunakan proses peninjauan kode yang terstandarisasi sebelum melakukan penggabungan ke branch `main`.
*   Semua fitur baru atau perbaikan bug wajib dibuat di branch terpisah (contoh: `feat/fitur-baru` atau `fix/bug-tertentu`).
*   Saat mengajukan Pull Request (PR), silakan isi template checklist peninjauan yang tersedia.
*   Baca selengkapnya di [docs/code-review.md](file:///c:/Users/wibis/Documents/Code/Project/cbt_app/docs/code-review.md) untuk memahami kriteria kelulusan PR.

---

## 📄 Lisensi

Proyek ini dilindungi di bawah lisensi internal tim pengembang. Hak Cipta © 2026.
