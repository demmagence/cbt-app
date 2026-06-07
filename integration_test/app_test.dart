import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cbt_app/app.dart';
import 'package:cbt_app/services/auth_service.dart';
import 'package:cbt_app/services/firestore_service.dart';
import 'package:cbt_app/services/exam_code_service.dart';
import 'package:cbt_app/models/user_model.dart';
import 'package:cbt_app/models/exam_model.dart';
import 'package:cbt_app/models/exam_session_model.dart';
import 'package:cbt_app/models/exam_result_model.dart';

// Mocks definition
class MockAuthService extends Mock implements AuthService {}
class MockFirestoreService extends Mock implements FirestoreService {}
class MockExamCodeService extends Mock implements ExamCodeService {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late MockExamCodeService mockExamCodeService;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;

  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();
    mockExamCodeService = MockExamCodeService();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();

    // Default setups
    when(() => mockUser.uid).thenReturn('test-uid-123');
    when(() => mockUserCredential.user).thenReturn(mockUser);

    // Setup generic stubs for Firestore getCollection with exact types
    when(() => mockFirestoreService.getCollection<UserModel>(
          path: any(named: 'path'),
          fromJson: any(named: 'fromJson'),
          queryBuilder: any(named: 'queryBuilder'),
        )).thenAnswer((_) async => []);

    when(() => mockFirestoreService.getCollection<ExamModel>(
          path: any(named: 'path'),
          fromJson: any(named: 'fromJson'),
          queryBuilder: any(named: 'queryBuilder'),
        )).thenAnswer((_) async => []);

    when(() => mockFirestoreService.getCollection<ExamSessionModel>(
          path: any(named: 'path'),
          fromJson: any(named: 'fromJson'),
          queryBuilder: any(named: 'queryBuilder'),
        )).thenAnswer((_) async => []);

    when(() => mockFirestoreService.getCollection<ExamResultModel>(
          path: any(named: 'path'),
          fromJson: any(named: 'fromJson'),
          queryBuilder: any(named: 'queryBuilder'),
        )).thenAnswer((_) async => []);
  });

  group('CBT App - End-to-End Integration Tests', () {
    testWidgets('Verification: App starts at Login Screen and redirects to Dashboard based on user roles', (tester) async {
      // 1. Initial State: Unauthenticated user
      when(() => mockAuthService.getCurrentUser()).thenReturn(null);
      when(() => mockAuthService.authStateChanges).thenAnswer((_) => Stream.value(null));

      await tester.pumpWidget(
        CbtApp(
          authService: mockAuthService,
          firestoreService: mockFirestoreService,
          examCodeService: mockExamCodeService,
        ),
      );

      await tester.pumpAndSettle();

      // Verify Login Screen elements exist
      expect(find.text('CBT Portal'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
      expect(find.text('Masuk'), findsOneWidget);

      // 2. Scenario 1: Login as Admin
      final adminUser = UserModel(
        uid: 'test-admin-uid',
        name: 'Super Admin',
        email: 'admin@cbt.com',
        role: 'admin',
        createdAt: DateTime.now(),
        isActive: true,
      );

      when(() => mockAuthService.signIn('admin@cbt.com', 'admin123'))
          .thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-admin-uid');
      when(() => mockFirestoreService.getDocument<UserModel>(
            path: FirestoreService.usersPath,
            docId: 'test-admin-uid',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => adminUser);

      // Stub collections specifically for Admin Dashboard stats
      when(() => mockFirestoreService.getCollection<UserModel>(
            path: FirestoreService.usersPath,
            fromJson: any(named: 'fromJson'),
            queryBuilder: any(named: 'queryBuilder'),
          )).thenAnswer((_) async => [adminUser]);

      // Input admin credentials
      await tester.enterText(find.byType(TextField).at(0), 'admin@cbt.com');
      await tester.enterText(find.byType(TextField).at(1), 'admin123');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      // Verify Admin Dashboard is displayed
      expect(find.text('Dashboard Utama'), findsOneWidget);
      expect(find.text('Selamat datang kembali di CBT Admin Portal.'), findsOneWidget);

      // Sign out by opening Drawer
      when(() => mockAuthService.signOut()).thenAnswer((_) async => {});
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      // Verify returned to Login Screen
      expect(find.text('CBT Portal'), findsOneWidget);

      // 3. Scenario 2: Login as Guru
      final guruUser = UserModel(
        uid: 'test-guru-uid',
        name: 'Bapak Guru Bama',
        email: 'guru@cbt.com',
        role: 'guru',
        createdAt: DateTime.now(),
        isActive: true,
      );

      when(() => mockAuthService.signIn('guru@cbt.com', 'guru123'))
          .thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-guru-uid');
      when(() => mockFirestoreService.getDocument<UserModel>(
            path: FirestoreService.usersPath,
            docId: 'test-guru-uid',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => guruUser);

      // Input guru credentials
      await tester.enterText(find.byType(TextField).at(0), 'guru@cbt.com');
      await tester.enterText(find.byType(TextField).at(1), 'guru123');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      // Verify Guru Dashboard is displayed
      expect(find.text('CBT Guru Portal'), findsOneWidget);
      expect(find.text('Halo, Bapak Guru Bama! 👋'), findsOneWidget);

      // Sign out by opening Drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      // Verify returned to Login Screen
      expect(find.text('CBT Portal'), findsOneWidget);

      // 4. Scenario 3: Login as Siswa
      final siswaUser = UserModel(
        uid: 'test-siswa-uid',
        name: 'Siswa Deryl',
        email: 'siswa@cbt.com',
        role: 'siswa',
        createdAt: DateTime.now(),
        isActive: true,
      );

      when(() => mockAuthService.signIn('siswa@cbt.com', 'siswa123'))
          .thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-siswa-uid');
      when(() => mockFirestoreService.getDocument<UserModel>(
            path: FirestoreService.usersPath,
            docId: 'test-siswa-uid',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => siswaUser);

      // Input siswa credentials
      await tester.enterText(find.byType(TextField).at(0), 'siswa@cbt.com');
      await tester.enterText(find.byType(TextField).at(1), 'siswa123');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      // Verify Siswa Screen is displayed
      expect(find.text('Dashboard Siswa'), findsOneWidget);
      expect(find.text('Siswa Deryl'), findsOneWidget);
    });
  });
}
