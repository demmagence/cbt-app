import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

class CbtApp extends StatelessWidget {
  const CbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>(create: (context) => AuthService()),
        RepositoryProvider<FirestoreService>(create: (context) => FirestoreService()),
      ],
      child: BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        )..add(const AuthCheckRequested()),
        child: Builder(
          builder: (context) {
            final authBloc = context.read<AuthBloc>();
            final router = AppRouter.createRouter(authBloc);

            return MaterialApp.router(
              title: 'CBT App',
              theme: AppTheme.lightTheme,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
