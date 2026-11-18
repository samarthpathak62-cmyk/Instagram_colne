part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class AuthSignupRequested extends AuthEvent {
  final String email;
  final String password;
  final String? username;
  final String? fullName;

  const AuthSignupRequested(
      {required this.email,
      required this.password,
      this.username,
      this.fullName});

  @override
  List<Object?> get props => [email, password, username, fullName];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

// Internal event triggered by Supabase auth state changes
class _AuthUserChanged extends AuthEvent {
  final User? user;

  const _AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}

class _AuthCallbackFailed extends AuthEvent {
  final String message;
  const _AuthCallbackFailed(this.message);

  @override
  List<Object> get props => [message];
}
