import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../services/firestore_service.dart';
import '../../services/exam_code_service.dart';

// States
abstract class JoinExamState extends Equatable {
  const JoinExamState();

  @override
  List<Object?> get props => [];
}

class JoinExamInitial extends JoinExamState {
  const JoinExamInitial();
}

class JoinExamVerifying extends JoinExamState {
  const JoinExamVerifying();
}

class JoinExamCodeValid extends JoinExamState {
  final ExamModel exam;
  final ExamSessionModel? existingSession;

  const JoinExamCodeValid({required this.exam, this.existingSession});

  @override
  List<Object?> get props => [exam, existingSession];
}

class JoinExamSessionStarting extends JoinExamState {
  const JoinExamSessionStarting();
}

class JoinExamSuccess extends JoinExamState {
  final ExamSessionModel session;

  const JoinExamSuccess(this.session);

  @override
  List<Object?> get props => [session];
}

class JoinExamError extends JoinExamState {
  final String message;

  const JoinExamError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class JoinExamCubit extends Cubit<JoinExamState> {
  final FirestoreService _firestoreService;
  final ExamCodeService _examCodeService;

  JoinExamCubit({
    required FirestoreService firestoreService,
    required ExamCodeService examCodeService,
  }) : _firestoreService = firestoreService,
       _examCodeService = examCodeService,
       super(const JoinExamInitial());

  Future<void> verifyCode(String code, String userId) async {
    emit(const JoinExamVerifying());
    try {
      final exam = await _examCodeService.validateCode(code);
      if (exam == null) {
        emit(
          const JoinExamError(
            'Kode ujian tidak valid, tidak aktif, atau sudah kadaluwarsa.',
          ),
        );
        return;
      }

      // Check for existing session
      final existingSessions = await _firestoreService
          .getCollection<ExamSessionModel>(
            path: FirestoreService.examSessionsPath,
            fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
            queryBuilder: (q) => q
                .where('examId', isEqualTo: exam.id)
                .where('userId', isEqualTo: userId),
          );

      if (existingSessions.isNotEmpty) {
        final session = existingSessions.first;
        if (session.status == 'completed' ||
            session.status == 'auto_submitted') {
          emit(
            const JoinExamError(
              'Anda sudah menyelesaikan ujian ini dan tidak dapat mengikutinya kembali.',
            ),
          );
        } else {
          emit(JoinExamCodeValid(exam: exam, existingSession: session));
        }
      } else {
        emit(JoinExamCodeValid(exam: exam));
      }
    } catch (e) {
      emit(
        JoinExamError(
          'Terjadi kesalahan saat memverifikasi kode: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> startExam(ExamModel exam, String userId) async {
    if (state is JoinExamSessionStarting) {
      return;
    }
    emit(const JoinExamSessionStarting());
    try {
      final data = await _firestoreService.call('startExam', {
        'code': exam.code,
      });
      emit(
        JoinExamSuccess(
          ExamSessionModel.fromJson(
            Map<String, dynamic>.from(data['session'] as Map),
          ),
        ),
      );
    } catch (e) {
      emit(JoinExamError('Gagal memulai sesi ujian: $e'));
    }
  }
}
