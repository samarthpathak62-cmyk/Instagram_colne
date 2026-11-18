import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/user.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final supabase.SupabaseClient supabaseClient;

  AuthRemoteDataSourceImpl({required this.supabaseClient});

  User _fromSession(supabase.Session session) => UserModel.fromSupabaseUser(
        id: session.user.id,
        email: session.user.email,
        userMetadata: session.user.userMetadata,
      );

  @override
  Future<User?> getCurrentUser() async {
    final session = supabaseClient.auth.currentSession;
    return session == null ? null : _fromSession(session);
  }

  @override
  Future<User> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = result.session;
      if (session == null) {
        throw AuthException(
            message: 'No session was returned. Please log in again.');
      }
      return _fromSession(session);
    } on supabase.AuthException catch (error) {
      throw AuthException(message: error.message);
    }
  }

  @override
  Future<User?> signupWithEmailPassword({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    try {
      final result = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: SupabaseConstants.emailRedirectUrl,
        data: {
          if (username != null) 'username': username,
          if (fullName != null) 'full_name': fullName,
          if (fullName != null) 'display_name': fullName,
        },
      );
      // Supabase returns a user but no session if email confirmation is required.
      final session = result.session;
      return session == null ? null : _fromSession(session);
    } on supabase.AuthException catch (error) {
      throw AuthException(message: error.message);
    }
  }

  @override
  Future<void> logout() =>
      supabaseClient.auth.signOut(scope: supabase.SignOutScope.local);
}
