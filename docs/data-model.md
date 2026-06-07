# Skema Model Data Firestore — CBT App

Dokumen ini merinci arsitektur database Cloud Firestore yang digunakan oleh CBT App (menggunakan database ID `cbt-db`). Database didesain secara hibrida menggunakan kombinasi koleksi tingkat-akar (root-level collections) dan subkoleksi (subcollections) untuk menyederhanakan kueri dan menerapkan aturan keamanan secara granular.

---

## Ringkasan Koleksi

| Nama Koleksi | Tipe Jalur (Path) | Kunci Utama (ID) | Deskripsi |
| :--- | :--- | :--- | :--- |
| **`users`** | Root | `uid` (dari Firebase Auth) | Data profil pengguna (Admin, Guru, Siswa). |
| **`exams`** | Root | `examId` (auto-generated) | Data metadata ujian yang dibuat oleh Guru. |
| **`questions`** | Subkoleksi dari `exams` | `questionId` (auto-generated) | Butir soal (pilihan ganda atau essay) untuk ujian tertentu. |
| **`exam_sessions`** | Root | `sessionId` (auto-generated) | Sesi pengerjaan ujian siswa (jawaban, status timer, anti-cheat log). |
| **`exam_results`** | Root | `resultId` (auto-generated) | Hasil akhir ujian (nilai PG, nilai essay, status penilaian, riwayat cheat). |
| **`question_bank`** | Root | `questionId` (auto-generated) | Repositori bank soal global yang dapat digunakan kembali oleh Guru. |

---

## 1. Koleksi: `users`
Koleksi ini menyimpan data otentikasi tambahan dan peran (role) dari setiap pengguna aplikasi. ID dokumen disamakan dengan `uid` dari Firebase Authentication.

### Struktur Field
| Nama Field | Tipe Data | Deskripsi | Aturan/Nilai |
| :--- | :--- | :--- | :--- |
| `uid` | `String` | ID Unik pengguna. | Harus cocok dengan ID Dokumen. |
| `name` | `String` | Nama lengkap pengguna. | Non-empty. |
| `email` | `String` | Alamat email terdaftar. | Valid format email. |
| `role` | `String` | Peran dalam sistem. | `"admin" \| "guru" \| "siswa"` |
| `isActive` | `Boolean` | Status keaktifan akun. | Akun non-aktif tidak dapat masuk aplikasi. |
| `createdAt` | `Timestamp` | Waktu akun dibuat. | Waktu server Firestore. |

### Contoh Dokumen JSON
```json
{
  "uid": "u8JgD1k3s8FlP9q1z7Xy0Wv3Ur4M",
  "name": "Budi Santoso",
  "email": "budi.siswa@cbtapp.com",
  "role": "siswa",
  "isActive": true,
  "createdAt": "2026-06-01T08:00:00.000Z"
}
```

---

## 2. Koleksi: `exams`
Menyimpan metadata dasar ujian yang dikonfigurasi oleh Guru.

### Struktur Field
| Nama Field | Tipe Data | Deskripsi | Aturan/Nilai |
| :--- | :--- | :--- | :--- |
| `id` | `String` | ID Dokumen ujian. | Harus cocok dengan ID Dokumen. |
| `title` | `String` | Judul atau nama ujian. | Contoh: `"Ujian Harian Matematika"` |
| `description` | `String` | Deskripsi singkat ujian. | Petunjuk pengerjaan. |
| `code` | `String` | Kode token unik untuk masuk ujian. | 6 karakter alfanumerik kapital (misal: `MATH99`). |
| `createdBy` | `String` | `uid` pembuat ujian (Guru). | Relasi ke `users.uid`. |
| `duration` | `Integer` | Durasi pengerjaan dalam menit. | Nilai positif. |
| `startDate` | `Timestamp` | Waktu mulai ujian dibuka. | Siswa tidak bisa bergabung sebelum waktu ini. |
| `endDate` | `Timestamp` | Batas akhir waktu ujian ditutup. | Siswa tidak bisa bergabung setelah waktu ini. |
| `isActive` | `Boolean` | Status ketersediaan ujian. | Ujian non-aktif tidak dapat diakses siswa. |
| `shuffleQuestions`| `Boolean` | Apakah soal diacak untuk tiap siswa. | `true \| false` |
| `shuffleOptions`  | `Boolean` | Apakah opsi PG diacak untuk tiap siswa. | `true \| false` |
| `totalQuestions`  | `Integer` | Jumlah total soal pada ujian ini. | Diupdate otomatis saat soal ditambah/dihapus. |

### Contoh Dokumen JSON
```json
{
  "id": "exam_math_101",
  "title": "Ujian Tengah Semester Aljabar",
  "description": "Dilarang menggunakan kalkulator.",
  "code": "ALGB77",
  "createdBy": "guru_uid_123",
  "duration": 90,
  "startDate": "2026-06-07T08:00:00.000Z",
  "endDate": "2026-06-07T12:00:00.000Z",
  "isActive": true,
  "shuffleQuestions": true,
  "shuffleOptions": true,
  "totalQuestions": 20
}
```

---

## 3. Subkoleksi: `questions` (di bawah `exams/{examId}/questions`)
Menyimpan daftar butir soal untuk ujian spesifik. Pendekatan subkoleksi dipilih untuk mendukung skala jumlah soal yang besar tanpa menyentuh batas ukuran dokumen Firestore (1MB).

### Struktur Field
| Nama Field | Tipe Data | Deskripsi | Aturan/Nilai |
| :--- | :--- | :--- | :--- |
| `id` | `String` | ID Dokumen soal. | Harus cocok dengan ID Dokumen. |
| `type` | `String` | Jenis pertanyaan. | `"pg"` (Pilihan Ganda) atau `"essay"` |
| `text` | `String` | Narasi/pertanyaan soal. | Mendukung format teks/markdown biasa. |
| `options` | `Array (String)` | Daftar pilihan jawaban. | `null` atau kosong jika `type` = `"essay"`. |
| `correctAnswer` | `Integer` | Indeks jawaban benar (0-based). | `null` jika `type` = `"essay"`. |
| `essayGuideline`| `String` | Panduan guru untuk menilai essay. | `null` jika `type` = `"pg"`. |
| `maxScore` | `Number` | Skor maksimal untuk soal ini. | Default `1` untuk PG. |
| `points` | `Number` | Bobot poin / skor default. | Default `1`. |
| `order` | `Integer` | Urutan tampil default. | Urutan sekuensial (0, 1, 2, ...). |

### Contoh Dokumen JSON (Pilihan Ganda)
```json
{
  "id": "q_001",
  "type": "pg",
  "text": "Berapakah hasil dari 2 + 2?",
  "options": ["2", "3", "4", "5"],
  "correctAnswer": 2,
  "maxScore": 1,
  "points": 1,
  "order": 0
}
```

### Contoh Dokumen JSON (Essay)
```json
{
  "id": "q_002",
  "type": "essay",
  "text": "Jelaskan definisi dari Aljabar Linear menurut pendapat Anda!",
  "essayGuideline": "Siswa harus menyebutkan minimal kata kunci: matriks, ruang vektor, transformasi linier.",
  "maxScore": 10,
  "points": 10,
  "order": 1
}
```

---

## 4. Koleksi: `exam_sessions`
Digunakan untuk merekam sesi aktif pengerjaan ujian oleh siswa. Ini memfasilitasi persistensi jawaban secara real-time, sinkronisasi sisa waktu pengerjaan, dan pencatatan pelanggaran integritas (kecurangan).

### Struktur Field
| Nama Field | Tipe Data | Deskripsi | Aturan/Nilai |
| :--- | :--- | :--- | :--- |
| `id` | `String` | ID Sesi (biasanya gabungan `userId_examId`). | Harus cocok dengan ID Dokumen. |
| `examId` | `String` | ID Dokumen ujian. | Relasi ke `exams.id`. |
| `userId` | `String` | `uid` Siswa yang mengerjakan. | Relasi ke `users.uid`. |
| `startedAt` | `Timestamp` | Waktu siswa mulai mengklik masuk ujian. | Digunakan untuk menghitung sisa waktu pengerjaan. |
| `endedAt` | `Timestamp` | Waktu siswa mengirimkan lembar jawaban. | `null` jika status masih `"in_progress"`. |
| `status` | `String` | Status pengerjaan sesi. | `"in_progress" \| "completed" \| "auto_submitted"` |
| `questionOrder` | `Array (String)`| Daftar ID Soal dalam urutan teracak. | Menjamin konsistensi pengacakan soal per siswa. |
| `optionOrders` | `Map (Array (Integer))` | Peta indeks opsi PG teracak untuk tiap soal. | Key: `questionId`, Value: `[2, 0, 1, 3]`. |
| `answers` | `Map (Any)` | Jawaban siswa yang tersimpan real-time. | Key: `questionId`, Value: `int` (indeks pilihan) atau `String` (essay). |
| `appSwitchCount`| `Integer` | Berapa kali siswa keluar dari layar aplikasi. | Nilai bertambah saat event *pause* terdeteksi. |
| `appSwitchLogs` | `Array (Map)` | Rincian detail log aktivitas keluar aplikasi. | Lihat struktur log di bawah. |

### Struktur `AppSwitchLog` (Map di dalam `appSwitchLogs`)
*   `timestamp`: `Timestamp` — Waktu kejadian aplikasi ditinggalkan.
*   `duration`: `Integer` — Lama waktu (dalam detik) di luar aplikasi sebelum kembali.
*   `type`: `String` — Jenis pelanggaran (misalnya: `"app_switch"`).

### Contoh Dokumen JSON
```json
{
  "id": "session_siswa1_examMath",
  "examId": "exam_math_101",
  "userId": "u8JgD1k3s8FlP9q1z7Xy0Wv3Ur4M",
  "startedAt": "2026-06-07T08:00:00.000Z",
  "endedAt": "2026-06-07T09:15:00.000Z",
  "status": "completed",
  "questionOrder": ["q_002", "q_001"],
  "optionOrders": {
    "q_001": [3, 1, 0, 2]
  },
  "answers": {
    "q_001": 3,
    "q_002": "Aljabar linear adalah cabang matematika yang mempelajari tentang matriks dan ruang vektor..."
  },
  "appSwitchCount": 1,
  "appSwitchLogs": [
    {
      "timestamp": "2026-06-07T08:30:10.000Z",
      "duration": 15,
      "type": "app_switch"
    }
  ]
}
```

---

## 5. Koleksi: `exam_results`
Menyimpan hasil evaluasi dan penilaian akhir dari ujian siswa. Siswa dapat melihat skor PG secara instan jika diperbolehkan, dan Guru dapat melakukan pemeriksaan manual untuk soal essay di sini.

### Struktur Field
| Nama Field | Tipe Data | Deskripsi | Aturan/Nilai |
| :--- | :--- | :--- | :--- |
| `id` | `String` | ID Dokumen hasil. | Biasanya sama dengan ID sesi. |
| `examId` | `String` | ID Dokumen ujian. | Relasi ke `exams.id`. |
| `userId` | `String` | `uid` Siswa. | Relasi ke `users.uid`. |
| `sessionId` | `String` | ID Sesi pengerjaan. | Relasi ke `exam_sessions.id`. |
| `pgScore` | `Number` | Skor yang diperoleh dari pilihan ganda. | Dihitung otomatis saat submit. |
| `essayScore` | `Number` | Total skor dari penilaian essay. | `null` jika belum dinilai Guru. |
| `totalScore` | `Number` | Nilai total gabungan PG + Essay. | Menjadi final jika `gradingStatus` = `"graded"`. |
| `gradingStatus` | `String` | Status pemeriksaan nilai. | `"graded" \| "pending_essay" \| "auto_submitted"` |
| `essayGrades` | `Map (Map)` | Nilai & feedback spesifik untuk tiap soal essay. | Key: `questionId`, Value: `EssayGrade`. |
| `submittedAt` | `Timestamp` | Tanggal pengiriman jawaban. | Diambil dari `endedAt` sesi. |
| `gradedAt` | `Timestamp` | Tanggal Guru menyelesaikan penilaian essay. | `null` jika belum diperiksa. |
| `gradedBy` | `String` | `uid` Guru yang melakukan penilaian. | Relasi ke `users.uid`. |
| `appSwitchCount`| `Integer` | Total pelanggaran app-switch selama ujian. | Disalin dari sesi ujian untuk kemudahan pelaporan Guru. |

### Struktur `EssayGrade` (Map di dalam `essayGrades`)
*   `score`: `Number` — Poin yang diberikan Guru untuk soal ini (tidak boleh melebihi `maxScore` soal).
*   `feedback`: `String` — Masukan atau evaluasi tertulis dari Guru untuk siswa.

### Contoh Dokumen JSON
```json
{
  "id": "session_siswa1_examMath",
  "examId": "exam_math_101",
  "userId": "u8JgD1k3s8FlP9q1z7Xy0Wv3Ur4M",
  "sessionId": "session_siswa1_examMath",
  "pgScore": 1,
  "essayScore": 8.5,
  "totalScore": 9.5,
  "gradingStatus": "graded",
  "essayGrades": {
    "q_002": {
      "score": 8.5,
      "feedback": "Penjelasan sangat baik, namun kurang mengaitkan dengan contoh transformasi linear."
    }
  },
  "submittedAt": "2026-06-07T09:15:00.000Z",
  "gradedAt": "2026-06-07T14:30:00.000Z",
  "gradedBy": "guru_uid_123",
  "appSwitchCount": 1
}
```

---

## 6. Koleksi: `question_bank`
Bank soal global yang menyimpan daftar soal yang pernah dibuat oleh Guru agar bisa diimpor kembali ke ujian baru di masa depan secara efisien.

### Struktur Field
Struktur field dari `question_bank` identik dengan subkoleksi `questions`, dengan tambahan field pelacakan metadata pembuatan:
*   `id`: `String` — ID Dokumen unik.
*   `type`: `String` — `"pg" \| "essay"`.
*   `text`: `String` — Teks soal.
*   `options`: `Array (String)` — Opsi pilihan (PG saja).
*   `correctAnswer`: `Integer` — Indeks jawaban benar (PG saja).
*   `essayGuideline`: `String` — Pedoman penskoran (essay saja).
*   `maxScore`: `Number` — Skor maksimal.
*   `createdBy`: `String` — `uid` Guru pembuat soal bank ini. Relasi ke `users.uid`.
*   `tags`: `Array (String)` — Tag klasifikasi materi (misal: `["Matematika", "Kelas X", "Aljabar"]`).
*   `createdAt`: `Timestamp` — Waktu soal dimasukkan ke bank soal.

### Contoh Dokumen JSON
```json
{
  "id": "qb_q_999",
  "type": "pg",
  "text": "Sebutkan planet terdekat dari Matahari!",
  "options": ["Venus", "Bumi", "Merkurius", "Mars"],
  "correctAnswer": 2,
  "maxScore": 1,
  "createdBy": "guru_uid_123",
  "tags": ["Fisika", "Astronomi", "SMP Kelas 7"],
  "createdAt": "2026-06-05T03:00:00.000Z"
}
```
