import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/exam_code_service.dart';

class CbtApp extends StatefulWidget {
  final AuthService? authService;
  final FirestoreService? firestoreService;
  final ExamCodeService? examCodeService;

  const CbtApp({
    super.key,
    this.authService,
    this.firestoreService,
    this.examCodeService,
  });

  @override
  State<CbtApp> createState() => _CbtAppState();
}

class _CbtAppState extends State<CbtApp> {
  late final AuthService _authService =
      widget.authService ?? FirebaseAuthService();
  late final FirestoreService _firestoreService =
      widget.firestoreService ?? FirestoreService();
  late final ExamCodeService _examCodeService =
      widget.examCodeService ??
      ExamCodeService(firestoreService: _firestoreService);
  late final AuthBloc _authBloc = AuthBloc(
    authService: _authService,
    firestoreService: _firestoreService,
  )..add(const AuthCheckRequested());
  late final _refresh = GoRouterRefreshStream(_authBloc.stream);
  late final _router = AppRouter.createRouter(_authBloc, refresh: _refresh);

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: _authService),
        RepositoryProvider<FirestoreService>.value(value: _firestoreService),
        RepositoryProvider<ExamCodeService>.value(value: _examCodeService),
      ],
      child: BlocProvider<AuthBloc>.value(
        value: _authBloc,
        child: Builder(
          builder: (context) {
            return MaterialApp.router(
              title: 'CBT App',
              theme: AppTheme.lightTheme,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
