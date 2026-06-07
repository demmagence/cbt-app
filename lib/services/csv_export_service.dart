import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/exam_model.dart';
import '../models/exam_result_model.dart';
import '../models/user_model.dart';

class CsvExportService {
  Future<void> exportAndShareResults({
    required ExamModel exam,
    required List<ExamResultModel> results,
    required Map<String, UserModel> studentMap,
  }) async {
    final List<List<dynamic>> rows = [];

    // 1. Add CSV Headers
    rows.add([
      'No',
      'Nama Siswa',
      'Email',
      'Nilai PG',
      'Nilai Essay',
      'Total Nilai',
      'Waktu Pengumpulan',
      'Status Penilaian'
    ]);

    // 2. Add Student Results
    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      final student = studentMap[r.userId];
      final name = student?.name ?? 'Siswa Tidak Dikenal';
      final email = student?.email ?? 'Tidak ada email';
      final isPending = r.gradingStatus == 'pending_essay';

      rows.add([
        i + 1,
        name,
        email,
        r.pgScore,
        isPending ? 'Belum Dinilai' : (r.essayScore ?? 0),
        isPending ? 'Pending' : r.totalScore,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(r.submittedAt),
        r.gradingStatus == 'graded' ? 'Selesai' : 'Pending Koreksi Essay'
      ]);
    }

    // 3. Convert to CSV String
    final String csvString = Csv().asCodec().encode(rows);

    // 4. Save to Temporary File using system temp directory
    final tempDir = Directory.systemTemp;
    // Replace characters that might be invalid in file paths
    final safeTitle = exam.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final file = File('${tempDir.path}/Hasil_Ujian_${safeTitle}_${exam.code}.csv');
    await file.writeAsString(csvString);

    // 5. Share via Native Share
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      subject: 'Hasil Ujian ${exam.title} (${exam.code})',
      text: 'Berikut dilampirkan berkas hasil pengerjaan siswa untuk ujian "${exam.title}" dengan kode ${exam.code}.',
    );
  }
}
