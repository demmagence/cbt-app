# CBT App — Audit Keamanan Aturan Firestore (Security Rules Audit)

Dokumen ini mendokumentasikan hasil audit keamanan komprehensif terhadap berkas `firestore.rules` pada **CBT App**. Audit dievaluasi berdasarkan kriteria Senior Security Auditor dan Penetration Tester Firestore.

---

## 1. Ringkasan Eksekutif

*   **Skor Keamanan**: **5 / 5 (Secure)**
*   **Status**: **SANGAT AMAN**
*   **Kesimpulan**: Aturan keamanan Firestore dirancang dengan sangat ketat menggunakan pendekatan *least privilege access*, validasi skema tipe data secara mendalam, serta pencegahan eksploitasi dan manipulasi data dari sisi klien.

---

## 2. Penilaian Detil Kriteria Audit

### A. Kebijakan Hak Akses & Peran (Role-Based Access Control)
*   Aturan tidak mempercayai klaim data dari sisi klien (`request.resource.data`) untuk penentuan peran. 
*   Sistem membaca dokumen tepercaya di `/users/$(request.auth.uid)` via fungsi `getUserRole()` untuk memastikan peran (`admin`, `guru`, `siswa`) benar-benar terdaftar dan divalidasi oleh sistem.
*   Akun yang dinonaktifkan (`isActive == false`) secara otomatis kehilangan seluruh hak akses tulis/baca.

### B. Validasi Skema & Tipe Data (Type Safety)
*   Setiap koleksi utama didefinisikan dengan fungsi validator skema (contoh: `isValidUser`, `isValidExam`, `isValidQuestion`, `isValidExamSession`, `isValidExamResult`).
*   Validator memeriksa secara spesifik:
    *   Tipe data dasar (`is string`, `is int`, `is bool`, `is timestamp`, `is map`, `is list`).
    *   Keberadaan field wajib dan penolakan field tak terdaftar menggunakan `hasOnly()` dan `hasAll()`.
    *   Ukuran maksimum string dan panjang array untuk menghindari Resource Exhaustion / Denial of Service (DoS) (contoh: limit nama/email <= 100 karakter, soal <= 2000 karakter, log app-switch <= 1000 entri).

### C. Pencegahan Manipulasi Nilai (The Update & Self-Grading Bypass)
*   **Hasil Ujian (`exam_results`)**:
    *   **Saat Pembuatan (Siswa)**: Siswa diizinkan membuat dokumen hasil ujiannya sendiri, namun aturan melarang keras adanya field `essayScore`, `essayGrades`, `gradedAt`, atau `gradedBy`. Status awal dipaksa berada dalam kondisi `pending_essay` atau `auto_submitted`.
    *   **Saat Penilaian (Guru)**: Guru hanya diizinkan mengupdate hasil ujian untuk ujian yang dibuat oleh dirinya sendiri. Aturan menggunakan `diff()` untuk memastikan Guru **tidak dapat mengubah** informasi asli sesi ujian siswa, seperti `userId`, `examId`, `sessionId`, `pgScore` (skor pilihan ganda otomatis), atau `submittedAt`. Guru hanya diizinkan mengisi nilai esai dan feedback saja.

### D. Pencegahan Kecurangan Sesi Ujian (`exam_sessions`)
*   Siswa diizinkan mengupdate sesi ujian mereka sendiri yang sedang berlangsung.
*   Namun, aturan menetapkan bahwa `examId` dan `startedAt` bersifat **immutabel** (tidak dapat diubah setelah dibuat). Hal ini mencegah siswa memanipulasi waktu mulai ujian untuk memperpanjang durasi kerja secara ilegal.

---

## 3. Matriks Hasil Audit Keamanan

| ID Temuan | Komponen | Deskripsi Kerentanan | Tingkat Bahaya | Status Mitigasi |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | **Users** | Privilege Escalation (Siswa mendaftarkan diri sendiri sebagai Admin/Guru) | **Aman (5)** | **Tereduksi**: Pendaftaran user baru hanya diizinkan bagi Admin (`isAdmin()`). |
| **SEC-02** | **Exams** | Modification Bypass (Mengedit atau menghapus ujian milik guru lain) | **Aman (5)** | **Tereduksi**: Diperiksa kepemilikan dokumen `createdBy == request.auth.uid`. |
| **SEC-03** | **Results** | Self-Grading (Siswa mengisi skor esai mereka sendiri agar langsung lulus) | **Aman (5)** | **Tereduksi**: Siswa dilarang mengirimkan kolom nilai esai saat pembuatan dokumen. |
| **SEC-04** | **Sessions** | Timer Bypass (Siswa mengubah waktu mulai `startedAt` untuk mendapat sisa waktu tambahan) | **Aman (5)** | **Tereduksi**: Kolom `startedAt` ditandai immutabel saat update dokumen. |

---

## 4. Rekomendasi Pemeliharaan
Aturan saat ini telah berada dalam kondisi optimal dan aman untuk tahap produksi. Tidak diperlukan perubahan kode rules tambahan.
