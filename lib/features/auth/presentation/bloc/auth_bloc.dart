import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:instagram_clone/core/usecase/usecase.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/get_current_user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/login_user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/signup_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'dart:async';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUser loginUser;
  final SignupUser signupUser;
  final GetCurrentUser getCurrentUser;
  final supabase.SupabaseClient supabaseClient; // Needed for auth state changes
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  AuthBloc({
    required this.loginUser,
    required this.signupUser,
    required this.getCurrentUser,
    required this.supabaseClient,
  }) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignupRequested>(_onSignupRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<_AuthCallbackFailed>((event, emit) => emit(AuthFailure(event.message)));
    on<_AuthUserChanged>(
        _onAuthUserChanged); // Internal event for stream updates

    // Listen to Supabase auth state changes
    _authStateSubscription =
        supabaseClient.auth.onAuthStateChange.listen((data) {
      // Initial state is handled by the session check; only a real session
      // can move the app past the sign-in screen.
      if (data.event == supabase.AuthChangeEvent.initialSession) return;
      final user = data.session?.user;
      if (user != null) {
        add(_AuthUserChanged(UserModel.fromSupabaseUser(
          id: user.id,
          email: user.email,
          userMetadata: user.userMetadata,
        )));
      } else if (data.event == supabase.AuthChangeEvent.signedOut) {
        add(const _AuthUserChanged(null));
      }
    }, onError: (Object error, StackTrace _) {
      if (supabaseClient.auth.currentSession == null &&
          error is supabase.AuthException &&
          !isClosed) {
        add(_AuthCallbackFailed(error.message));
      }
    });

    // Initial check
    add(AuthCheckRequested());
  }

  @override
  Future<void> close() async {
    await _authStateSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoginRequested(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await loginUser(
        LoginParams(email: event.email, password: event.password));
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(Authenticated(user)),
    );
  }

  Future<void> _onSignupRequested(
      AuthSignupRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await signupUser(SignupParams(
      email: event.email,
      password: event.password,
      username: event.username,
      fullName: event.fullName,
    ));
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(user == null
          ? AuthEmailConfirmationRequired(event.email)
          : Authenticated(user)),
    );
  }

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    try {
      await supabaseClient.auth.signOut(scope: supabase.SignOutScope.local);
    } on supabase.AuthException catch (error) {
      if (supabaseClient.auth.currentSession == null) {
        emit(Unauthenticated());
      } else {
        emit(AuthFailure(error.message));
      }
    }
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    final result = await getCurrentUser(NoParams());
    result.fold(
      (failure) =>
          emit(Unauthenticated()), // Assume unauthenticated if error fetching
      (user) {
        if (user != null) {
          emit(Authenticated(user));
        } else {
          emit(Unauthenticated());
        }
      },
    );
  }

  void _onAuthUserChanged(_AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(Authenticated(event.user!));
    } else {
      emit(Unauthenticated());
    }
  }
}
