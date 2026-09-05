# CBT App

Aplikasi Computer-Based Test berbasis Flutter untuk perangkat Android. Aplikasi menyediakan akses terpisah bagi admin, guru, dan siswa dengan Firebase sebagai layanan autentikasi, database, dan backend.

## Fitur

### Admin

- Membuat dan mengelola akun guru serta siswa.
- Menonaktifkan akses pengguna tanpa menghapus riwayat ujian.
- Melihat statistik pengguna dan ujian.

### Guru

- Membuat dan mengatur jadwal ujian.
- Mengelola soal pilihan ganda dan esai.
- Menggunakan bank soal.
- Memantau sesi ujian secara langsung.
- Mengumpulkan paksa sesi siswa.
- Menilai jawaban esai dan mengekspor hasil ke CSV.

### Siswa

- Mengikuti ujian menggunakan kode enam karakter.
- Menyimpan dan memulihkan draf jawaban.
- Melanjutkan sinkronisasi setelah koneksi kembali tersedia.
- Melihat hasil ujian.

Penilaian, batas waktu, pengacakan soal, dan validasi akses dijalankan oleh backend. Kunci jawaban tidak dikirim ke aplikasi siswa.

## Teknologi

- Flutter 3.44.0 dan Dart 3.12.0
- Firebase Authentication
- Cloud Firestore Enterprise
- Cloud Functions for Firebase, Node.js 22
- BLoC/Cubit dan GoRouter

## Persyaratan

- Flutter SDK dengan Dart 3.11 atau lebih baru
- Android SDK
- JDK 21
- Node.js 22
- Firebase CLI
- FlutterFire CLI

## Instalasi

```powershell
git clone https://github.com/demmagence/cbt-app.git
cd cbt-app
flutter pub get
npm --prefix functions ci
```

Konfigurasikan Firebase untuk platform Android:

```powershell
flutterfire configure
```

Gunakan konfigurasi berikut:

- Firebase project: `cbt-app-wibisana`
- Android application ID: `com.demmagence.cbtapp`
- Firestore database: `cbt-db`
- Cloud Functions region: `asia-southeast2`

File `lib/firebase_options.dart` dan `android/app/google-services.json` tidak disimpan dalam Git.

## Menjalankan Aplikasi

```powershell
flutter run
```

Untuk menjalankan dengan Firebase Emulator Suite:

```powershell
npx -y firebase-tools@latest emulators:start --project demo-cbt --only auth,firestore,functions
```

Jalankan seed dan aplikasi dari terminal lain:

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
node functions/scripts/seed-emulator.js
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

## Pengujian

```powershell
flutter analyze --no-pub
flutter test
npm --prefix functions test
npx -y firebase-tools@latest emulators:exec --project demo-cbt --only firestore,auth "npm --prefix functions run test:emulator"
```

Pengujian mencakup autentikasi, navigasi, pemulihan jawaban, retry submit, aturan akses Firestore, migrasi data, penilaian server, dan simulasi 50 siswa serentak.

## Build Android

Build debug:

```powershell
flutter build apk --debug
```

Build release memerlukan `android/key.properties` dan keystore yang valid:

```powershell
flutter build apk --release
```

APK dihasilkan di `build/app/outputs/flutter-apk/`.

## Struktur Proyek

```text
android/             Konfigurasi aplikasi Android
assets/              Aset aplikasi
functions/           Backend, migrasi, dan pengujian emulator
lib/                 Kode aplikasi Flutter
test/                Pengujian inti Flutter
firebase.json        Konfigurasi Firebase
firestore.rules      Aturan akses Firestore
firestore.indexes.json
```

## Status Produksi

Aplikasi telah menghasilkan APK release bertanda tangan dan lulus pengujian lokal. Aplikasi belum boleh digunakan untuk ujian produksi karena Cloud Functions dan Cloud Scheduler belum diterapkan pada proyek Firebase.

Deployment backend memerlukan paket Firebase Blaze dengan akun billing. Migrasi data produksi hanya boleh dijalankan setelah backup Firestore, seluruh ujian aktif selesai, dan hasil pratinjau migrasi diperiksa.
