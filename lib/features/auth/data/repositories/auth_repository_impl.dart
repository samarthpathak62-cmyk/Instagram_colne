import 'package:dartz/dartz.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.loginWithEmailPassword(
        email: email,
        password: password,
      );
      return Right(user);
    } on AuthException catch (error) {
      return Left(AuthenticationFailure(error.message));
    } catch (_) {
      return const Left(
          ServerFailure(message: 'Could not reach Veyro. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, User?>> signupWithEmailPassword({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    try {
      final user = await remoteDataSource.signupWithEmailPassword(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
      );
      return Right(user);
    } on AuthException catch (error) {
      return Left(AuthenticationFailure(error.message));
    } catch (_) {
      return const Left(
          ServerFailure(message: 'Could not reach Veyro. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      return Right(user);
    } on AuthException catch (error) {
      return Left(AuthenticationFailure(error.message));
    } catch (_) {
      return const Left(
          ServerFailure(message: 'Could not reach Veyro. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      return const Right(null);
    } on AuthException catch (error) {
      return Left(AuthenticationFailure(error.message));
    } catch (_) {
      return const Left(
          ServerFailure(message: 'Could not reach Veyro. Please try again.'));
    }
  }
}
