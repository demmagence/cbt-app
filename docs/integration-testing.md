# CBT App — E2E Integration Testing Manual

Dokumen ini berisi panduan pengujian integrasi manual End-to-End (E2E) dan skenario kasus pengujian untuk memastikan kelancaran alur sistem CBT App dari ketiga peran pengguna (Admin, Guru, Siswa).

---

## 1. Skenario Pengujian Integrasi

### Skenario 1: Admin Flow (Manajemen Akun)
*   **Tujuan**: Memverifikasi pembuatan akun Guru dan Siswa oleh Admin, serta memastikan otentikasi login berjalan lancar.
*   **Langkah Eksekusi**:
    1. Buka aplikasi CBT App, masuk menggunakan kredensial Admin (`admin@cbt.com` / `admin123`).
    2. Arahkan ke tab **Manajemen User** di dasbor Admin.
    3. Klik tombol **Tambah User Baru** (FAB `+`).
    4. Isi form pembuatan akun Guru (Nama: `Guru Budi`, Email: `budi@cbt.com`, Role: `Guru`, Password: `password123`).
    5. Klik **Simpan**. Verifikasi akun muncul di daftar.
    6. Klik tombol **Tambah User Baru** lagi untuk membuat akun Siswa (Nama: `Siswa Andi`, Email: `andi@cbt.com`, Role: `Siswa`, Password: `password123`).
    7. Klik **Simpan**. Verifikasi akun muncul di daftar.
    8. Keluar (Logout) dari akun Admin.
*   **Hasil yang Diharapkan**:
    *   Admin berhasil login dan melihat dasbor Admin.
    *   Akun Guru dan Siswa baru berhasil ditambahkan tanpa memutuskan sesi login Admin yang sedang aktif.
    *   Data akun tersinkronisasi dengan benar di Firestore database `cbt-db` pada koleksi `/users`.

---

### Skenario 2: Guru Flow (Pembuatan Ujian & Kelola Soal)
*   **Tujuan**: Memverifikasi pembuatan ujian, perolehan kode ujian unik 6 karakter, penambahan/pengurutan soal, dan pengelolaan Bank Soal.
*   **Langkah Eksekusi**:
    1. Masuk menggunakan akun Guru yang baru dibuat (`budi@cbt.com` / `password123`).
    2. Arahkan ke halaman **Daftar Ujian**, klik **Buat Ujian Baru** (FAB `+`).
    3. Isi form pembuatan ujian (Judul: `Ujian Harian Matematika`, Deskripsi: `Bab Aljabar`, Durasi: `60 menit`, Waktu Mulai/Selesai valid).
    4. Klik **Simpan**. Salin kode ujian unik 6 karakter yang dihasilkan di dialog sukses.
    5. Klik tombol **Kelola Soal** pada ujian yang baru dibuat.
    6. Tambahkan 2 soal Pilihan Ganda (PG) dengan opsi A, B, C, D dan tentukan jawaban yang benar.
    7. Tambahkan 1 soal Essay dengan skor maksimal 20 dan pedoman penilaian.
    8. Gunakan fitur drag & drop (`ReorderableListView`) untuk menukar urutan soal.
    9. Simpan perubahan. Pastikan metrik jumlah soal diperbarui di dasbor.
    10. Keluar dari akun Guru.
*   **Hasil yang Diharapkan**:
    *   Guru berhasil masuk dan melihat metrik kosong di dasbor.
    *   Kode ujian unik 6 karakter (alfanumerik) berhasil digenerasikan.
    *   Soal dapat ditambahkan dan diurutkan secara visual.
    *   Jumlah soal (`totalQuestions`) di dokumen ujian utama otomatis sinkron.

---

### Skenario 3: Siswa Flow (Pengerjaan Ujian)
*   **Tujuan**: Memverifikasi verifikasi kode ujian, inisialisasi sesi, proses pengerjaan soal acak, dan submit jawaban.
*   **Langkah Eksekusi**:
    1. Masuk menggunakan akun Siswa (`andi@cbt.com` / `password123`).
    2. Masukkan kode ujian unik 6 karakter yang disalin sebelumnya di kolom "Kode Ujian" dan klik **Verifikasi**.
    3. Periksa informasi detail ujian di halaman konfirmasi, lalu klik **Mulai Ujian**.
    4. Jawab soal nomor 1 (PG) dan nomor 2 (PG).
    5. Jawab soal nomor 3 (Essay) dengan mengetikkan jawaban teks.
    6. Klik tombol **Selesai & Kumpul Jawaban**. Setujui dialog konfirmasi.
*   **Hasil yang Diharapkan**:
    *   Siswa berhasil diverifikasi masuk ke halaman ujian.
    *   Urutan soal diacak jika opsi acak diaktifkan.
    *   Jawaban siswa berhasil dikirim dan status pengerjaan berubah menjadi `completed` / `pending_essay`.

---

### Skenario 4: Scoring Flow (Penilaian Otomatis & Esai)
*   **Tujuan**: Memverifikasi sistem peninjauan nilai PG otomatis dan alur antrean koreksi esai guru.
*   **Langkah Eksekusi**:
    1. Masuk kembali sebagai Guru (`budi@cbt.com`).
    2. Buka menu **Antrean Koreksi Essay** (atau tab koreksi di hasil ujian).
    3. Pilih hasil pengerjaan `Siswa Andi` yang berstatus `pending_essay`.
    4. Periksa lembar jawaban digital siswa: koreksi PG otomatis (centang hijau jika benar, silang merah jika salah).
    5. Berikan skor pada jawaban Essay siswa (misalnya 15 dari 20) dan feedback tulisan.
    6. Klik **Simpan Nilai**.
*   **Hasil yang Diharapkan**:
    *   Sistem secara otomatis menghitung nilai PG berdasarkan kunci jawaban.
    *   Guru dapat menilai esai dengan skor valid (tidak melampaui skor maksimal).
    *   Status kelulusan hasil ujian berubah menjadi `graded` dan total skor dihitung ulang secara otomatis.

---

### Skenario 5: Timer & Auto-Submit Flow
*   **Tujuan**: Memverifikasi penutupan sesi pengerjaan otomatis saat waktu ujian habis.
*   **Langkah Eksekusi**:
    1. Masuk kembali sebagai Siswa baru.
    2. Mulai ujian baru yang memiliki sisa waktu sangat sedikit (misalnya 1 menit).
    3. Biarkan ujian berjalan tanpa menekan tombol kumpul.
    4. Tunggu sampai hitung mundur (countdown timer) mencapai `00:00`.
*   **Hasil yang Diharapkan**:
    *   Aplikasi menampilkan dialog hitung mundur.
    *   Saat waktu habis, halaman ujian terkunci dan secara otomatis mengirimkan jawaban yang sempat terisi ke Firestore.
    *   Status sesi ujian di Firestore berubah menjadi `auto_submitted`.

---

### Skenario 6: Anti-Cheat & Live Monitoring Flow
*   **Tujuan**: Memverifikasi pelacakan pelanggaran app switch (keluar aplikasi) dan aksi kumpul paksa oleh Guru.
*   **Langkah Eksekusi**:
    1. Buka aplikasi sebagai Guru di perangkat A, buka menu **Live Monitoring Ujian** untuk ujian aktif.
    2. Buka aplikasi sebagai Siswa di perangkat B, mulai ujian.
    3. Di perangkat Siswa, tekan tombol home / pindah ke aplikasi lain (background) selama 5 detik, lalu kembali ke aplikasi ujian.
    4. Verifikasi bahwa Siswa mendapatkan dialog peringatan kecurangan dan guru melihat jumlah pelanggaran meningkat secara real-time di layar pemantauan.
    5. Di layar pemantauan Guru, klik tombol **Kumpul Paksa** untuk sesi siswa tersebut.
*   **Hasil yang Diharapkan**:
    *   Lifecycle state `paused` dan `resumed` terdeteksi secara akurat.
    *   Log perpindahan disimpan ke Firestore beserta durasinya.
    *   Guru dapat memaksa kumpul sesi ujian siswa, yang akan langsung mengeluarkan siswa dari halaman ujian di perangkatnya dengan status `completed` / `auto_submitted`.

---

### Skenario 7: Edge Cases (Offline Handling & Crash Recovery)
*   **Tujuan**: Memverifikasi kelancaran pengerjaan saat terjadi offline internet dan pemulihan state saat aplikasi crash/ditutup paksa.
*   **Langkah Eksekusi**:
    1. Sebagai Siswa, masuk ke halaman ujian aktif.
    2. Matikan koneksi internet (aktifkan mode pesawat).
    3. Jawab beberapa soal. Matikan/keluar paksa aplikasi (force close).
    4. Buka kembali aplikasi CBT App. Hubungkan kembali internet.
*   **Hasil yang Diharapkan**:
    *   Offline persistence Firestore menyinkronkan data lokal.
    *   Siswa kembali masuk ke status pengerjaan ujian terakhir (waktu sisa dipotong sesuai waktu elapsed di dunia nyata).
    *   Semua jawaban yang diisi saat offline berhasil di-sync ke Firestore ketika online kembali.
