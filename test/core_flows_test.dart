import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cbt_app/blocs/auth/auth_bloc.dart';
import 'package:cbt_app/blocs/auth/auth_event.dart';
import 'package:cbt_app/blocs/auth/auth_state.dart';
import 'package:cbt_app/blocs/siswa/exam_session_bloc.dart';
import 'package:cbt_app/blocs/siswa/exam_session_event.dart';
import 'package:cbt_app/blocs/siswa/exam_session_state.dart';
import 'package:cbt_app/config/routes/app_router.dart';
import 'package:cbt_app/models/user_model.dart';
import 'package:cbt_app/services/auth_service.dart';
import 'package:cbt_app/services/exam_draft_store.dart';
import 'package:cbt_app/services/firestore_service.dart';

class _AuthFake implements AuthService {
  _AuthFake();
  String? uid;
  String loginUid = 'student';
  int signOutCount = 0;

  @override
  String? getCurrentUid() => uid;
  @override
  Future<String> signIn(String email, String password) async => loginUid;
  @override
  Future<void> signOut() async {
    signOutCount++;
    uid = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
}

class _DraftMemory extends ExamDraftStore {
  final Map<String, Map<String, dynamic>> values = {};
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      values[key] == null ? null : Map<String, dynamic>.from(values[key]!);
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

Map<String, dynamic> _bundle({Map<String, dynamic> answers = const {}}) {
  final now = DateTime.now();
  return {
    'serverNow': now.toIso8601String(),
    'cachedAt': now.toIso8601String(),
    'exam': {
      'id': 'exam',
      'title': 'Ujian',
      'description': '',
      'code': 'ABC123',
      'createdBy': 'teacher',
      'duration': 30,
      'startDate': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'endDate': now.add(const Duration(hours: 1)).toIso8601String(),
      'isActive': true,
      'shuffleQuestions': false,
      'shuffleOptions': false,
      'totalQuestions': 1,
    },
    'session': {
      'id': 'student_exam',
      'userId': 'student',
      'examId': 'exam',
      'startedAt': now.toIso8601String(),
      'expiresAt': now.add(const Duration(minutes: 30)).toIso8601String(),
      'status': 'in_progress',
      'questionOrder': ['essay'],
      'optionOrders': <String, dynamic>{},
      'answers': answers,
      'appSwitchCount': 0,
      'appSwitchLogs': <dynamic>[],
    },
    'questions': [
      {
        'id': 'essay',
        'type': 'essay',
        'text': 'Jawab',
        'maxScore': 10,
        'points': 10,
        'order': 0,
      },
    ],
    'result': null,
  };
}

Map<String, dynamic> _result() => {
  'id': 'student_exam',
  'sessionId': 'student_exam',
  'userId': 'student',
  'examId': 'exam',
  'pgScore': 0,
  'totalScore': 0,
  'gradingStatus': 'pending_essay',
  'submittedAt': DateTime.now().toIso8601String(),
  'appSwitchCount': 0,
};

Future<T> _nextState<T>(ExamSessionBloc bloc) async {
  if (bloc.state is T) return bloc.state as T;
  return bloc.stream
      .firstWhere((state) => state is T)
      .then((state) => state as T);
}

void main() {
  testWidgets('back dari halaman detail kembali ke halaman sebelumnya', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Utama')),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) => const DetailBackScope(
            fallbackLocation: '/home',
            child: Scaffold(body: Text('Detail')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Utama'), findsOneWidget);
  });

  testWidgets('detail tanpa riwayat back ke dashboard dan tidak keluar', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Utama')),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) => const DetailBackScope(
            fallbackLocation: '/home',
            child: Scaffold(body: Text('Detail')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Detail'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Utama'), findsOneWidget);
  });

  test(
    'autentikasi menerima profil aktif dan keluar saat profil dinonaktifkan',
    () async {
      final auth = _AuthFake();
      final profiles = StreamController<dynamic>.broadcast();
      final active = UserModel(
        uid: 'student',
        name: 'Siswa',
        email: 'siswa@example.com',
        role: 'siswa',
        createdAt: DateTime(2026),
        isActive: true,
      );
      final service = FirestoreService.test(
        get: (path, docId) async => active,
        stream: (path, docId) => profiles.stream,
      );
      final bloc = AuthBloc(authService: auth, firestoreService: service);
      bloc.add(
        const AuthLoginRequested(
          email: 'siswa@example.com',
          password: 'password',
        ),
      );
      await bloc.stream.firstWhere((state) => state is AuthAuthenticated);
      profiles.add(active.copyWith(isActive: false));
      await bloc.stream.firstWhere((state) => state is AuthUnauthenticated);
      expect(auth.signOutCount, 1);
      await bloc.close();
      await profiles.close();
    },
  );

  test(
    'draf jawaban dipulihkan setelah aplikasi ditutup saat offline',
    () async {
      final drafts = _DraftMemory();
      final calls = <String>[];
      final online = FirestoreService.test(
        call: (name, data) async {
          calls.add(name);
          return _bundle();
        },
        stream: (path, docId) => const Stream<dynamic>.empty(),
      );
      final first = ExamSessionBloc(
        firestoreService: online,
        draftStore: drafts,
        connectivity: const Stream<bool>.empty(),
      );
      first.add(const ExamStarted(examId: 'exam', userId: 'student'));
      await _nextState<ExamSessionActive>(first);
      first.add(
        const EssayAnswerUpdated(questionId: 'essay', text: 'Jawaban terakhir'),
      );
      await first.stream.firstWhere(
        (state) =>
            state is ExamSessionActive &&
            state.session.answers['essay'] == 'Jawaban terakhir',
      );
      await first.close();

      final offline = FirestoreService.test(
        call: (name, data) async => throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'offline',
        ),
        stream: (path, docId) => const Stream<dynamic>.empty(),
      );
      final restored = ExamSessionBloc(
        firestoreService: offline,
        draftStore: drafts,
        connectivity: const Stream<bool>.empty(),
      );
      restored.add(const ExamStarted(examId: 'exam', userId: 'student'));
      final state = await _nextState<ExamSessionActive>(restored);
      expect(state.session.answers['essay'], 'Jawaban terakhir');
      expect(state.isOffline, isTrue);
      await restored.close();
    },
  );

  test(
    'submit yang gagal disimpan dan otomatis diulang setelah tersambung',
    () async {
      final drafts = _DraftMemory();
      var submitAttempts = 0;
      final service = FirestoreService.test(
        call: (name, data) async {
          if (name == 'loadExam') return _bundle();
          if (name == 'saveAnswers') return {'saved': true};
          if (name == 'submitExam') {
            submitAttempts++;
            if (submitAttempts == 1) {
              throw FirebaseFunctionsException(
                code: 'unavailable',
                message: 'offline',
              );
            }
            return _result();
          }
          return {'saved': true};
        },
        stream: (path, docId) => const Stream<dynamic>.empty(),
      );
      final bloc = ExamSessionBloc(
        firestoreService: service,
        draftStore: drafts,
        connectivity: const Stream<bool>.empty(),
      );
      bloc.add(const ExamStarted(examId: 'exam', userId: 'student'));
      await _nextState<ExamSessionActive>(bloc);
      bloc.add(const EssayAnswerUpdated(questionId: 'essay', text: 'Final'));
      await bloc.stream.firstWhere(
        (state) =>
            state is ExamSessionActive &&
            state.session.answers['essay'] == 'Final',
      );
      bloc.add(const ExamSubmitted());
      await bloc.stream.firstWhere(
        (state) => state is ExamSessionSubmitting && state.error != null,
      );
      expect(drafts.values['student_exam']?['pendingSubmit'], isTrue);
      bloc.add(const ConnectivityChanged(isOffline: false));
      await _nextState<ExamSessionCompleted>(bloc);
      expect(submitAttempts, 2);
      expect(drafts.values.containsKey('student_exam'), isFalse);
      await bloc.close();
    },
  );
}
