import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthProfileChanged extends AuthEvent {
  final UserModel? user;
  final String uid;
  const AuthProfileChanged(this.user, this.uid);
  @override
  List<Object?> get props => [user, uid];
}
