# Lapisan Layanan (API & Services) — CBT App

Dokumen ini merinci arsitektur lapisan layanan (service layer) pada CBT App. Lapisan ini bertindak sebagai perantara antara lapisan antarmuka pengguna/state management (BLoC/Cubit) dan data source eksternal (Firebase Auth, Cloud Firestore, System Hardware).

---

## Ringkasan Layanan

| Nama Layanan | Lingkup Tanggung Jawab | Komponen Eksternal |
| :--- | :--- | :--- |
| **`AuthService`** | Otentikasi pengguna, manajemen akun, pembuatan user oleh admin. | Firebase Authentication |
| **`FirestoreService`** | Kueri & mutasi data generik (tambah, baca, ubah, hapus, streaming). | Cloud Firestore (`cbt-db`) |
| **`ExamCodeService`** | Pembuatan token ujian acak unik & validasi jadwal masuk ujian. | Cloud Firestore (`cbt-db`) |
| **`ScreenSecurityService`**| Pencegahan tangkapan layar (screenshot) dan rekaman layar. | Platform MethodChannel (FLAG_SECURE) |
| **`AntiCheatManager`** | Pemantauan lifecycle aplikasi, penguncian fullscreen, log cheat. | WidgetsBindingObserver & System UIs |
| **`CsvExportService`** | Ekspor rekapitulasi nilai siswa ke berkas CSV dan native sharing. | System Temp File & Share API |

---

## 1. `AuthService`
Layanan ini mengelola siklus sesi pengguna dan pendaftaran akun baru oleh administrator.

### API & Metode Utama

*   **`Stream<User?> get authStateChanges`**
    *   Mengalirkan perubahan status otentikasi (login/logout) untuk didengarkan oleh `AuthBloc`.
*   **`User? getCurrentUser()`**
    *   Mendapatkan data otentikasi user saat ini yang terikat pada instance lokal.
*   **`Future<UserCredential> signIn(String email, String password)`**
    *   Masuk menggunakan email dan password.
*   **`Future<void> signOut()`**
    *   Keluar dari sesi aplikasi saat ini.
*   **`Future<UserCredential> createUserAccount(String email, String password)`**
    *   **Fitur Khusus Admin**: Membuat akun kredensial baru di Firebase Auth menggunakan instance `FirebaseApp` sementara agar sesi masuk administrator saat ini tidak terputus.
*   **`Future<void> updatePassword(String newPassword)`**
    *   Memperbarui kata sandi pengguna yang sedang masuk.
*   **`Future<void> sendPasswordResetEmail(String email)`**
    *   Mengirim email pemulihan kata sandi kepada pengguna.

---

## 2. `FirestoreService`
Layanan database generik untuk mengabstraksikan operasi CRUD dan Real-time Streaming pada koleksi Firestore.

### API & Metode Utama

*   **`Future<T?> getDocument<T>({required String path, required String docId, required T Function(Map<String, dynamic> json, String id) fromJson})`**
    *   Membaca satu dokumen tunggal dan mengubahnya menjadi model objek Dart.
*   **`Future<List<T>> getCollection<T>({required String path, required T Function(Map<String, dynamic> json, String id) fromJson, Query Function(Query query)? queryBuilder})`**
    *   Membaca seluruh dokumen dalam koleksi (atau subkoleksi) dengan opsi filter/kueri khusus.
*   **`Stream<List<T>> streamCollection<T>({required String path, required T Function(Map<String, dynamic> json, String id) fromJson, Query Function(Query query)? queryBuilder})`**
    *   Mengaktifkan pemantauan real-time (snapshots) terhadap suatu koleksi. Berguna untuk dashboard monitoring guru.
*   **`Stream<T?> streamDocument<T>({required String path, required String docId, required T Function(Map<String, dynamic> json, String id) fromJson})`**
    *   Mengaktifkan pemantauan real-time terhadap dokumen tertentu.
*   **`Future<void> addDocument({required String path, required Map<String, dynamic> data, String? docId})`**
    *   Menambahkan dokumen baru. Jika `docId` disertakan, menggunakan metode `.set()`; jika tidak, menggunakan `.add()`.
*   **`Future<void> updateDocument({required String path, required String docId, required Map<String, dynamic> data})`**
    *   Mengubah field tertentu dalam dokumen secara parsial.
*   **`Future<void> deleteDocument({required String path, required String docId})`**
    *   Menghapus dokumen dari database.

---

## 3. `ExamCodeService`
Mengelola pembuatan token ujian yang unik dan memvalidasi kelayakan siswa saat akan masuk ruang ujian.

### API & Metode Utama

*   **`Future<String> generateUniqueCode()`**
    *   Menghasilkan 6 karakter alfanumerik kapital acak dan memverifikasi keunikan ke database. Jika kode sudah terpakai, algoritma akan terus mengulang hingga menemukan kode baru yang unik.
*   **`Future<ExamModel?> validateCode(String code)`**
    *   Memvalidasi kode ujian masukan siswa dengan kriteria:
        1. Kode harus cocok (case-insensitive).
        2. Ujian harus aktif (`isActive == true`).
        3. Waktu saat ini harus berada di antara `startDate` dan `endDate` dari jadwal ujian.
    *   Mengembalikan objek `ExamModel` jika valid, dan `null` jika tidak valid atau tidak aktif.

---

## 4. `ScreenSecurityService`
Layanan keamanan tingkat rendah untuk mencegah kebocoran soal ujian melalui tangkapan layar (screenshot) dan rekaman layar ponsel pintar siswa.

### API & Metode Utama

*   **`static final ScreenSecurityService instance`**
    *   Singleton instance.
*   **`Future<void> enable()`**
    *   Mengirimkan pesan ke platform native Android melalui MethodChannel (`com.cbt_app/screen_security`) untuk mengaktifkan `FLAG_SECURE` pada window WindowManager. Ini akan merender layar menjadi hitam pada rekaman layar dan memblokir fungsi tangkapan layar OS.
*   **`Future<void> disable()`**
    *   Menghapus flag pengamanan native dari window agar ponsel kembali ke mode normal setelah ujian selesai.

---

## 5. `AntiCheatManager`
Pengelola alur integritas pengerjaan ujian. Mengawasi fokus aplikasi siswa saat pengerjaan ujian berlangsung.

### API & Metode Utama

*   **`static final AntiCheatManager instance`**
    *   Singleton instance yang dicampur (mix-in) dengan `WidgetsBindingObserver`.
*   **`void enable()`**
    *   Mengaktifkan anti-cheat: Mendaftarkan observer status siklus hidup aplikasi (lifecycle observer), memaksa UI sistem masuk ke mode lengket layar penuh (`SystemUiMode.immersiveSticky`), mengunci tangkapan layar via `ScreenSecurityService`, dan mereset statistik pelanggaran sesi.
*   **`void disable()`**
    *   Menonaktifkan anti-cheat: Melepas observer, menonaktifkan penguncian layar, dan mengembalikan UI sistem ke mode standar (`edgeToEdge`).
*   **`void onAppSwitched(AppSwitchCallback callback)`**
    *   Mendaftarkan fungsi callback yang dipicu setiap kali terdeteksi pelanggaran siswa meninggalkan aplikasi (misal: membuka browser, menerima telepon, menekan tombol home).
*   **`void onResumed(VoidCallback callback)`**
    *   Mendaftarkan callback saat aplikasi kembali fokus (resumed) untuk memicu dialog peringatan kecurangan di layar siswa.
*   **`void enforceFullscreen()`**
    *   Memastikan UI sistem disembunyikan kembali untuk mempersempit kesempatan siswa keluar layar.

---

## 6. `CsvExportService`
Membantu Guru merekapitulasi data nilai siswa dari format database Firestore ke berkas CSV yang siap diolah di program spreadsheet (Excel/Google Sheets).

### API & Metode Utama

*   **`Future<void> exportAndShareResults({required ExamModel exam, required List<ExamResultModel> results, required Map<String, UserModel> studentMap})`**
    *   Menerjemahkan data ujian, hasil nilai, dan profil siswa menjadi struktur baris data CSV.
    *   Menulis berkas temporer di direktori sistem (`Directory.systemTemp`) dengan nama berkas aman (`Hasil_Ujian_[Title]_[Code].csv`).
    *   Memicu dialog native share (`share_plus`) agar guru dapat langsung mengirim berkas tersebut melalui Email, WhatsApp, Google Drive, atau media penyimpanan lokal.
