import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../models/question_model.dart';
import '../../models/exam_result_model.dart';
import '../../services/firestore_service.dart';
import '../../services/exam_draft_store.dart';
import 'exam_session_event.dart';
import 'exam_session_state.dart';

class ExamSessionBloc extends Bloc<ExamSessionEvent, ExamSessionState> {
  final FirestoreService _firestoreService;
  final ExamDraftStore _drafts;
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<bool>? _connectivity;
  StreamSubscription<ExamSessionModel?>? _remote;
  final Stopwatch _elapsed = Stopwatch();
  DateTime _serverNow = DateTime.now();
  Map<String, dynamic>? _bundle;
  ExamSessionActive? _active;
  Future<void> _diskWrites = Future.value();
  String? _key;
  bool _pendingSubmit = false;
  bool _submitting = false;
  bool _syncing = false;
  bool _dirty = false;
  bool _closing = false;
  bool _logging = false;
  final List<Map<String, dynamic>> _pendingLogs = [];
  bool get _disposed => _closing || isClosed;
  bool _offline = false;
  int _revision = 0;

  ExamSessionBloc({
    required FirestoreService firestoreService,
    ExamDraftStore? draftStore,
    Stream<bool>? connectivity,
  }) : _firestoreService = firestoreService,
       _drafts = draftStore ?? ExamDraftStore(),
       super(const ExamSessionInitial()) {
    on<ExamStarted>(_start);
    on<AnswerSelected>(
      (event, emit) => _answer(event.questionId, event.answerIndex, emit),
    );
    on<EssayAnswerUpdated>(
      (event, emit) => _answer(event.questionId, event.text, emit),
    );
    on<SyncAnswersRequested>(_sync);
    on<ExamSubmitted>(_submit);
    on<TimerTicked>((event, emit) => _tick(emit));
    on<TimerExpired>(
      (event, emit) => add(const ExamSubmitted(isAutoSubmit: true)),
    );
    on<AppResumed>((event, emit) => _tick(emit));
    on<QuestionNavigated>((event, emit) {
      final current = state;
      if (current is! ExamSessionActive ||
          event.index < 0 ||
          event.index >= current.questions.length) {
        return;
      }
      _show(
        current.copyWith(
          currentIndex: event.index,
          visitedQuestions: {
            ...current.visitedQuestions,
            current.questions[event.index].id,
          },
        ),
        emit,
      );
    });
    on<FlagToggled>((event, emit) {
      final current = state;
      if (current is! ExamSessionActive) {
        return;
      }
      final flags = {...current.flaggedQuestions};
      if (!flags.add(event.questionId)) {
        flags.remove(event.questionId);
      }
      _show(current.copyWith(flaggedQuestions: flags), emit);
    });
    on<AppSwitchDetected>((event, emit) async {
      final current = state;
      if (current is! ExamSessionActive) {
        return;
      }
      _show(
        current.copyWith(
          session: current.session.copyWith(
            appSwitchCount: current.session.appSwitchCount + 1,
            appSwitchLogs: [...current.session.appSwitchLogs, event.log],
          ),
        ),
        emit,
      );
      _pendingLogs.add({
        'eventId':
            '${event.log.timestamp.microsecondsSinceEpoch}_${_pendingLogs.length}',
        'duration': event.log.duration,
      });
      await _persist().catchError((Object _) {});
      unawaited(_flushLogs());
    });
    on<ConnectivityChanged>((event, emit) {
      _offline = event.isOffline;
      if (state is ExamSessionActive) {
        _show((state as ExamSessionActive).copyWith(isOffline: _offline), emit);
      }
      if (!_offline) {
        add(
          _pendingSubmit ? const ExamSubmitted() : const SyncAnswersRequested(),
        );
      }
    });
    on<RemoteSessionChanged>((event, emit) {
      if (event.session.status != 'in_progress' &&
          state is! ExamSessionCompleted) {
        add(const ExamSubmitted());
      }
    });
    _connectivity =
        (connectivity ??
                Connectivity().onConnectivityChanged.map(
                  (values) =>
                      values.isEmpty ||
                      values.contains(ConnectivityResult.none),
                ))
            .listen((offline) {
              if (!_disposed) {
                add(ConnectivityChanged(isOffline: offline));
              }
            });
  }

  void _show(ExamSessionActive value, Emitter<ExamSessionState> emit) {
    _active = value;
    emit(value);
  }

  Future<void> _persist() {
    if (_bundle == null || _active == null || _key == null) {
      return Future.value();
    }
    final key = _key!;
    final value = <String, dynamic>{
      ..._bundle!,
      'draftAnswers': Map<String, dynamic>.from(_active!.session.answers),
      'pendingSubmit': _pendingSubmit,
      'dirty': _dirty,
      'pendingLogs': List<Map<String, dynamic>>.from(_pendingLogs),
    };
    // Serialize disk writes so rapid edits cannot overwrite a newer draft.
    _diskWrites = _diskWrites
        .catchError((Object _) {})
        .then((_) => _drafts.write(key, value));
    return _diskWrites;
  }

  Future<void> _start(ExamStarted event, Emitter<ExamSessionState> emit) async {
    if (state is ExamSessionLoading || _submitting) {
      return;
    }
    emit(const ExamSessionLoading());
    _timer?.cancel();
    await _remote?.cancel();
    _key = '${event.userId}_${event.examId}';
    try {
      Map<String, dynamic>? local;
      try {
        local = await _drafts.read(_key!);
      } catch (_) {}
      _pendingLogs.clear();
      if (local?['pendingLogs'] is List) {
        _pendingLogs.addAll(
          (local!['pendingLogs'] as List).map(
            (value) => Map<String, dynamic>.from(value as Map),
          ),
        );
      }
      Map<String, dynamic> data;
      try {
        data = await _firestoreService.call('loadExam', {
          'examId': event.examId,
        });
        _offline = false;
        data['cachedAt'] = DateTime.now().toIso8601String();
      } on FirebaseFunctionsException catch (e) {
        if (local == null ||
            !['unavailable', 'deadline-exceeded'].contains(e.code)) {
          rethrow;
        }
        data = local;
        _offline = true;
      }
      if (_disposed) {
        return;
      }
      _bundle = data;
      if (data['result'] != null) {
        await _complete(Map<String, dynamic>.from(data['result'] as Map), emit);
        return;
      }
      final exam = ExamModel.fromJson(
        Map<String, dynamic>.from(data['exam'] as Map),
      );
      var session = ExamSessionModel.fromJson(
        Map<String, dynamic>.from(data['session'] as Map),
      );
      final questions = (data['questions'] as List)
          .map(
            (q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)),
          )
          .toList();
      if (questions.isEmpty || session.expiresAt == null) {
        throw StateError('Sesi tidak memiliki soal atau batas waktu.');
      }
      _dirty = local?['dirty'] == true;
      if (_dirty && local?['draftAnswers'] is Map) {
        session = session.copyWith(
          answers: {
            ...session.answers,
            ...Map<String, dynamic>.from(local!['draftAnswers'] as Map),
          },
        );
      }
      _pendingSubmit = local?['pendingSubmit'] == true;
      _serverNow = DateTime.parse(data['serverNow'] as String);
      if (_offline) {
        _serverNow = _serverNow.add(
          DateTime.now().difference(DateTime.parse(data['cachedAt'] as String)),
        );
      }
      _elapsed
        ..reset()
        ..start();
      _show(
        ExamSessionActive(
          exam: exam,
          session: session,
          questions: questions,
          currentIndex: 0,
          remainingTime: _remaining(session),
          flaggedQuestions: const {},
          visitedQuestions: {questions.first.id, ...session.answers.keys},
          isOffline: _offline,
          saveMessage: _dirty
              ? 'Draf lokal; menunggu sinkronisasi'
              : 'Jawaban tersinkron',
        ),
        emit,
      );
      await _persist().catchError((Object _) {});
      if (state is! ExamSessionActive) {
        return;
      }
      if (_disposed) {
        return;
      }
      _remote = _firestoreService
          .streamDocument<ExamSessionModel>(
            path: FirestoreService.examSessionsPath,
            docId: session.id,
            fromJson: (json, id) => ExamSessionModel.fromJson(json, id: id),
          )
          .listen((session) {
            if (session != null && !_disposed) {
              add(RemoteSessionChanged(session));
            }
          }, onError: (Object _) {});
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed) {
          return;
        }
        add(const TimerTicked(0));
        if (_elapsed.elapsed.inSeconds % 5 == 0) {
          add(
            _pendingSubmit
                ? const ExamSubmitted()
                : const SyncAnswersRequested(),
          );
        }
      });
      if (_pendingSubmit || _remaining(session) == 0) {
        add(const ExamSubmitted());
      } else if (_dirty) {
        add(const SyncAnswersRequested());
      }
    } catch (e) {
      if (!_disposed) {
        emit(ExamSessionError('Gagal memuat sesi: $e'));
      }
    }
  }

  int _remaining(ExamSessionModel session) => session.expiresAt!
      .difference(_serverNow.add(_elapsed.elapsed))
      .inSeconds
      .clamp(0, 86400);

  void _tick(Emitter<ExamSessionState> emit) {
    final current = state;
    if (current is! ExamSessionActive) {
      return;
    }
    final remaining = _remaining(current.session);
    _show(current.copyWith(remainingTime: remaining), emit);
    if (remaining == 0) {
      add(const ExamSubmitted(isAutoSubmit: true));
    }
  }

  Future<void> _answer(
    String id,
    dynamic answer,
    Emitter<ExamSessionState> emit,
  ) async {
    final current = state;
    if (current is! ExamSessionActive || _remaining(current.session) == 0) {
      return;
    }
    final question = current.questions.where((q) => q.id == id).firstOrNull;
    if (question == null ||
        (question.isPg
            ? answer is! int ||
                  answer < 0 ||
                  answer >= (question.options?.length ?? 0)
            : answer is! String || answer.length > 10000)) {
      return;
    }
    _dirty = true;
    _revision++;
    _show(
      current.copyWith(
        session: current.session.copyWith(
          answers: {...current.session.answers, id: answer},
        ),
        saveMessage: 'Menyimpan draf...',
      ),
      emit,
    );
    try {
      await _persist();
      if (state is ExamSessionActive && !_disposed) {
        _show(
          (state as ExamSessionActive).copyWith(
            saveMessage: 'Draf lokal; menunggu sinkronisasi',
          ),
          emit,
        );
      }
    } catch (_) {
      if (state is ExamSessionActive && !_disposed) {
        _show(
          (state as ExamSessionActive).copyWith(
            saveMessage: 'Penyimpanan lokal gagal; jangan tutup aplikasi',
          ),
          emit,
        );
      }
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!_disposed) {
        add(const SyncAnswersRequested());
      }
    });
  }

  Future<void> _sync(
    SyncAnswersRequested event,
    Emitter<ExamSessionState> emit,
  ) async {
    unawaited(_flushLogs());
    if (!_dirty ||
        _syncing ||
        _submitting ||
        _offline ||
        state is! ExamSessionActive) {
      return;
    }
    _syncing = true;
    final revision = _revision;
    final current = state as ExamSessionActive;
    try {
      await _firestoreService.call('saveAnswers', {
        'sessionId': current.session.id,
        'answers': current.session.answers,
      });
      if (revision == _revision) {
        _dirty = false;
        await _persist();
        if (!_disposed && state is ExamSessionActive) {
          _show(
            (state as ExamSessionActive).copyWith(
              saveMessage: 'Jawaban tersinkron',
            ),
            emit,
          );
        }
      }
    } catch (e) {
      if (!_disposed && state is ExamSessionActive) {
        _show(
          (state as ExamSessionActive).copyWith(
            saveMessage: 'Belum tersinkron; mencoba kembali',
          ),
          emit,
        );
      }
      if (e is FirebaseFunctionsException &&
          e.code == 'failed-precondition' &&
          !_disposed) {
        add(const ExamSubmitted());
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _flushLogs() async {
    if (_logging || _offline || _active == null || _disposed) {
      return;
    }
    _logging = true;
    final sessionId = _active!.session.id;
    try {
      while (_pendingLogs.isNotEmpty && !_disposed) {
        final log = _pendingLogs.first;
        await _firestoreService.call('logAppSwitch', {
          'sessionId': sessionId,
          ...log,
        });
        _pendingLogs.remove(log);
        await _persist();
      }
    } catch (_) {
      // Keep advisory events in the local draft and retry on reconnect.
    } finally {
      _logging = false;
    }
  }

  Future<void> _submit(
    ExamSubmitted event,
    Emitter<ExamSessionState> emit,
  ) async {
    if (_submitting || _active == null || state is ExamSessionCompleted) {
      return;
    }
    _submitting = true;
    _pendingSubmit = true;
    _debounce?.cancel();
    emit(ExamSessionSubmitting(isOffline: _offline));
    try {
      // A local storage failure must not prevent an online submission.
      await _persist().catchError((Object _) {});
      final data = await _firestoreService.call('submitExam', {
        'sessionId': _active!.session.id,
        'answers': _active!.session.answers,
      });
      await _complete(data, emit);
    } catch (e) {
      if (!_disposed) {
        emit(
          ExamSessionSubmitting(
            isOffline: _offline,
            error:
                'Pengumpulan belum dikonfirmasi server. Draf tetap disimpan. $e',
          ),
        );
      }
    } finally {
      _submitting = false;
    }
  }

  Future<void> _complete(
    Map<String, dynamic> data,
    Emitter<ExamSessionState> emit,
  ) async {
    _pendingSubmit = false;
    _timer?.cancel();
    _debounce?.cancel();
    await _diskWrites.catchError((Object _) {});
    try {
      if (_key != null) {
        await _drafts.remove(_key!);
      }
    } catch (_) {}
    _active = null;
    _bundle = null;
    if (!_disposed) {
      emit(ExamSessionCompleted(ExamResultModel.fromJson(data)));
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    _timer?.cancel();
    _debounce?.cancel();
    await _connectivity?.cancel();
    await _remote?.cancel();
    await _diskWrites.catchError((Object _) {});
    return super.close();
  }
}
