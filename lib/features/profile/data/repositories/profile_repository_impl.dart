import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:dartz/dartz.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/profile/domain/entities/profile.dart';
import 'package:instagram_clone/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Profile>> getProfile(String userId) async {
    try {
      final response = await remoteDataSource.getProfile(userId);
      return Right(response);
    } on ServerException catch (error) {
      return Left(ServerFailure(message: error.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Profile>> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    XFile? profileImage,
  }) async {
    try {
      final updatedProfile = await remoteDataSource.updateProfile(
        userId: userId,
        username: username,
        fullName: fullName,
        bio: bio,
        profileImage: profileImage,
      );
      return Right(updatedProfile);
    } on ServerException catch (error) {
      return Left(ServerFailure(message: error.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
