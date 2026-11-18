import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/core/usecase/usecase.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/domain/repositories/auth_repository.dart';

class SignupUser implements UseCase<User?, SignupParams> {
  final AuthRepository repository;

  SignupUser(this.repository);

  @override
  Future<Either<Failure, User?>> call(SignupParams params) async {
    return await repository.signupWithEmailPassword(
      email: params.email,
      password: params.password,
      username: params.username,
      fullName: params.fullName,
    );
  }
}

class SignupParams extends Equatable {
  final String email;
  final String password;
  final String? username;
  final String? fullName;

  const SignupParams(
      {required this.email,
      required this.password,
      this.username,
      this.fullName});

  @override
  List<Object?> get props => [email, password, username, fullName];
}
